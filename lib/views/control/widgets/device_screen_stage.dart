import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/device_model.dart';
import '../../../services/android_keyboard_mapper.dart';
import '../../../services/device_control_service.dart';
import '../../../services/scaling_coordinator.dart';
import '../../../services/screen_stream_service.dart';
import '../../../theme/app_theme.dart';
import 'fast_screen_renderer.dart';

class DeviceScreenStage extends StatefulWidget {
  final DeviceModel device;
  final IDeviceControlService controlService;
  final IScreenStreamService streamService;
  final ValueNotifier<ScreenFpsStats> fpsStatsNotifier;
  final bool isVisible;

  const DeviceScreenStage({
    super.key,
    required this.device,
    required this.controlService,
    required this.streamService,
    required this.fpsStatsNotifier,
    this.isVisible = true,
  });

  @override
  State<DeviceScreenStage> createState() => _DeviceScreenStageState();
}

class _DeviceScreenStageState extends State<DeviceScreenStage> {
  late final FocusNode _rawKeyboardFocusNode;
  bool _pasteShortcutActive = false;

  late ScalingCoordinator _coordinator;
  Offset? _touchPosition;
  bool _isPointerDown = false;
  bool _isLongPressActive = false;
  Timer? _longPressVisualTimer;
  ScreenViewport? _latestViewport;
  ScreenViewport? _submittedViewport;
  bool _viewportUpdateScheduled = false;

  @override
  void initState() {
    super.initState();
    _rawKeyboardFocusNode = FocusNode(onKeyEvent: _handleKeyboardPassthrough);
    _initCoordinator();
  }

  @override
  void didUpdateWidget(covariant DeviceScreenStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.device.display.width != widget.device.display.width ||
        oldWidget.device.display.height != widget.device.display.height) {
      _initCoordinator();
      _submittedViewport = null;
    }
    if (oldWidget.streamService != widget.streamService) {
      widget.fpsStatsNotifier.value = ScreenFpsStats.empty;
      _submittedViewport = null;
      final viewport = _latestViewport;
      if (viewport != null) {
        _scheduleViewportUpdate(viewport);
      }
    }
    if (oldWidget.device.serial != widget.device.serial) {
      widget.fpsStatsNotifier.value = ScreenFpsStats.empty;
    }
  }

  @override
  void dispose() {
    _longPressVisualTimer?.cancel();
    _rawKeyboardFocusNode.dispose();
    super.dispose();
  }

  void _handleFpsChanged(ScreenFpsStats stats) {
    if (mounted) {
      widget.fpsStatsNotifier.value = stats;
    }
  }

  void _initCoordinator() {
    _coordinator = ScalingCoordinator(
      realWidth: widget.device.display.width,
      realHeight: widget.device.display.height,
    );
  }

  void _updateViewportAfterLayout(Rect renderRect) {
    if (renderRect.width <= 0 || renderRect.height <= 0) return;
    final viewport = ScreenViewport(
      logicalWidth: renderRect.width,
      logicalHeight: renderRect.height,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
      rotation: widget.device.display.rotation,
    );
    _latestViewport = viewport;
    if (viewport == _submittedViewport) return;
    _scheduleViewportUpdate(viewport);
  }

  void _scheduleViewportUpdate(ScreenViewport viewport) {
    _latestViewport = viewport;
    if (_viewportUpdateScheduled) return;
    _viewportUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewportUpdateScheduled = false;
      if (!mounted) return;
      final latest = _latestViewport;
      if (latest == null || latest == _submittedViewport) return;
      _submittedViewport = latest;
      widget.streamService.updateViewport(latest);
    });
  }

  void _handlePointerDown(PointerDownEvent event, Rect renderRect) {
    if (!renderRect.contains(event.localPosition)) return;

    // Mirror STF Web: clicking the device screen activates the raw keyboard
    // bridge, while the phone's own IME remains responsible for composition.
    if (!_rawKeyboardFocusNode.hasFocus) {
      _rawKeyboardFocusNode.requestFocus();
    }
    final relX = event.localPosition.dx - renderRect.left;
    final relY = event.localPosition.dy - renderRect.top;

    final norm = _coordinator.mapToDeviceCoords(
      boundingW: renderRect.width,
      boundingH: renderRect.height,
      relX: relX,
      relY: relY,
      rotation: widget.device.display.rotation,
    );

    _longPressVisualTimer?.cancel();
    _isLongPressActive = false;
    _longPressVisualTimer = Timer(const Duration(milliseconds: 450), () {
      if (mounted && _isPointerDown) {
        setState(() {
          _isLongPressActive = true;
        });
      }
    });

    setState(() {
      _isPointerDown = true;
      _touchPosition = event.localPosition;
    });

    widget.controlService.touchDown(contact: 0, xP: norm.xP, yP: norm.yP);
    widget.controlService.touchCommit();
  }

  void _handlePointerMove(PointerMoveEvent event, Rect renderRect) {
    if (!_isPointerDown) return;

    final relX = event.localPosition.dx - renderRect.left;
    final relY = event.localPosition.dy - renderRect.top;

    final norm = _coordinator.mapToDeviceCoords(
      boundingW: renderRect.width,
      boundingH: renderRect.height,
      relX: relX,
      relY: relY,
      rotation: widget.device.display.rotation,
    );

    setState(() {
      _touchPosition = event.localPosition;
    });

    widget.controlService.touchMove(contact: 0, xP: norm.xP, yP: norm.yP);
    widget.controlService.touchCommit();
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (!_isPointerDown) return;

    _longPressVisualTimer?.cancel();

    setState(() {
      _isPointerDown = false;
      _isLongPressActive = false;
      _touchPosition = null;
    });

    unawaited(_finishPointerGesture());
  }

  Future<void> _finishPointerGesture() async {
    await widget.controlService.touchUp(contact: 0);
    if (mounted) {
      widget.streamService.triggerImmediateRefresh();
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (!_isPointerDown) return;

    _longPressVisualTimer?.cancel();

    setState(() {
      _isPointerDown = false;
      _isLongPressActive = false;
      _touchPosition = null;
    });

    // Web STF closes a gesture on pointer leave/cancel as well as mouseup.
    unawaited(_finishPointerGesture());
  }

  void _handleKeyPress(DeviceKeyAction key) {
    widget.controlService.keyPress(key);
    widget.streamService.triggerImmediateRefresh();
  }

  Future<void> _pasteDesktopClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) return;

    if (kDebugMode) {
      debugPrint(
        '[DeviceInput:${widget.device.serial}] desktop paste requested '
        'chars=${text.length}',
      );
    }
    final pasted = await widget.controlService.pasteText(text);
    if (pasted && mounted) {
      widget.streamService.triggerImmediateRefresh();
    }
  }

  KeyEventResult _handleKeyboardPassthrough(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    final isMeta =
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed;

    // Clipboard paste is the one intentional desktop-to-device text path.
    if (event is KeyUpEvent &&
        key == LogicalKeyboardKey.keyV &&
        _pasteShortcutActive) {
      _pasteShortcutActive = false;
      return KeyEventResult.handled;
    }

    if ((event is KeyDownEvent || event is KeyRepeatEvent) &&
        isMeta &&
        key == LogicalKeyboardKey.keyV) {
      if (event is KeyDownEvent) {
        _pasteShortcutActive = true;
        unawaited(_pasteDesktopClipboard());
      }
      return KeyEventResult.handled;
    }

    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      final keyName = AndroidKeyboardMapper.keyNameFor(event);
      if (keyName == null) return KeyEventResult.ignored;
      widget.controlService.rawKeyDown(keyName);
      return KeyEventResult.handled;
    }

    if (event is KeyUpEvent) {
      if (AndroidKeyboardMapper.isCharsetSwitch(event)) {
        widget.controlService.rawKeyPress(AndroidKeyboardMapper.switchCharset);
      } else {
        final keyName = AndroidKeyboardMapper.keyNameFor(event);
        if (keyName == null) return KeyEventResult.ignored;
        widget.controlService.rawKeyUp(keyName);
      }
      widget.streamService.triggerImmediateRefresh();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(right: BorderSide(color: tokens.outline, width: 1)),
      ),
      child: Column(
        children: [
          // 核心屏幕区域
          Expanded(
            child: widget.isVisible
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      final stageSize = Size(
                        constraints.maxWidth,
                        constraints.maxHeight,
                      );
                      final renderRect = _coordinator.calculateRenderRect(
                        stageSize,
                        widget.device.display.rotation,
                      );
                      _updateViewportAfterLayout(renderRect);

                      return Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: (e) => _handlePointerDown(e, renderRect),
                        onPointerMove: (e) => _handlePointerMove(e, renderRect),
                        onPointerUp: _handlePointerUp,
                        onPointerCancel: _handlePointerCancel,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Container(
                                color: tokens.bg,
                                child: Center(
                                  child: Container(
                                    width: renderRect.width,
                                    height: renderRect.height,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0F172A),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: tokens.metalEdge,
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: tokens.primary.withValues(
                                            alpha: 0.15,
                                          ),
                                          blurRadius: 20,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: AnimatedBuilder(
                                      animation: widget.streamService,
                                      builder: (context, _) {
                                        final state =
                                            widget.streamService.state;
                                        return Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            FastScreenRenderer(
                                              frameStream: widget
                                                  .streamService
                                                  .frameStream,
                                              placeholder: _buildPlaceholder(
                                                context,
                                                state: state,
                                                errorMessage: widget
                                                    .streamService
                                                    .errorMessage,
                                              ),
                                              onFpsChanged: _handleFpsChanged,
                                            ),
                                            if (state != StreamState.streaming)
                                              _buildStreamStatusOverlay(
                                                context,
                                                state: state,
                                                errorMessage: widget
                                                    .streamService
                                                    .errorMessage,
                                              ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            Positioned(
                              left: renderRect.left,
                              top: renderRect.top,
                              width: renderRect.width,
                              height: renderRect.height,
                              // The raw keyboard bridge is focused
                              // programmatically after a screen pointer down.
                              // It must not participate in hit testing, so it
                              // cannot retarget or cancel the touch gesture.
                              child: IgnorePointer(
                                child: _buildRawKeyboardBridge(),
                              ),
                            ),

                            // 触控指示光标 Feedback (包含长按脉冲特效)
                            if (_isPointerDown && _touchPosition != null)
                              Positioned(
                                left:
                                    _touchPosition!.dx -
                                    (_isLongPressActive ? 23 : 18),
                                top:
                                    _touchPosition!.dy -
                                    (_isLongPressActive ? 23 : 18),
                                child: IgnorePointer(
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: _isLongPressActive ? 46 : 36,
                                    height: _isLongPressActive ? 46 : 36,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _isLongPressActive
                                          ? const Color(
                                              0xFF00D591,
                                            ).withValues(alpha: 0.35)
                                          : tokens.primary.withValues(
                                              alpha: 0.3,
                                            ),
                                      border: Border.all(
                                        color: _isLongPressActive
                                            ? const Color(0xFF00D591)
                                            : tokens.primary,
                                        width: _isLongPressActive ? 2.5 : 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color:
                                              (_isLongPressActive
                                                      ? const Color(0xFF00D591)
                                                      : tokens.primary)
                                                  .withValues(alpha: 0.5),
                                          blurRadius: _isLongPressActive
                                              ? 16
                                              : 10,
                                          spreadRadius: _isLongPressActive
                                              ? 4
                                              : 2,
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Container(
                                        width: _isLongPressActive ? 12 : 8,
                                        height: _isLongPressActive ? 12 : 8,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: tokens.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  )
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.visibility_off_rounded,
                          size: 48,
                          color: tokens.textSecondary.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '屏幕已隐藏以节省性能',
                          style: TextStyle(
                            color: tokens.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),

          // 底部虚拟按键栏
          _buildNavigationBar(context),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(
    BuildContext context, {
    required StreamState state,
    String? errorMessage,
  }) {
    final tokens = context.tokens;
    final isError = state == StreamState.error;
    final isPaused = state == StreamState.paused;
    final label = switch (state) {
      StreamState.streaming => '等待 STF 屏幕首帧...',
      StreamState.paused => 'STF 屏幕流已暂停',
      StreamState.error => errorMessage ?? 'STF 屏幕服务不可用',
      StreamState.disconnected => 'STF 屏幕连接已断开',
      StreamState.connecting => '正在连接 STF 屏幕流...',
    };

    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  tokens.bgSecondary,
                  const Color(0xFF1E293B),
                  tokens.bg,
                ],
              ),
            ),
          ),
        ),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isError || isPaused)
                Icon(
                  isError
                      ? Icons.signal_wifi_statusbar_connected_no_internet_4
                      : Icons.pause_circle_outline_rounded,
                  size: 34,
                  color: isError ? const Color(0xFFEF4444) : tokens.primary,
                )
              else
                SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: tokens.primary,
                  ),
                ),
              const SizedBox(height: 14),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isError ? const Color(0xFFFCA5A5) : tokens.textPrimary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStreamStatusOverlay(
    BuildContext context, {
    required StreamState state,
    String? errorMessage,
  }) {
    final tokens = context.tokens;
    final isError = state == StreamState.error;
    final isConnecting = state == StreamState.connecting;
    final label = switch (state) {
      StreamState.connecting => '正在连接 STF 屏幕流...',
      StreamState.paused => 'STF 屏幕流已暂停',
      StreamState.error => errorMessage ?? 'STF 屏幕服务不可用',
      StreamState.disconnected => 'STF 屏幕连接已断开',
      StreamState.streaming => '',
    };
    return ColoredBox(
      color: const Color(0xD90F172A),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isConnecting)
                SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: tokens.primary,
                  ),
                )
              else
                Icon(
                  isError
                      ? Icons.signal_wifi_statusbar_connected_no_internet_4
                      : state == StreamState.paused
                      ? Icons.pause_circle_outline_rounded
                      : Icons.link_off_rounded,
                  size: 34,
                  color: isError
                      ? const Color(0xFFEF4444)
                      : tokens.textSecondary,
                ),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isError
                      ? const Color(0xFFFCA5A5)
                      : tokens.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationBar(BuildContext context) {
    final tokens = context.tokens;

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: tokens.bgSecondary,
        border: Border(top: BorderSide(color: tokens.outline, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavButton(
            icon: Icons.menu_rounded,
            tooltip: 'Menu (菜单)',
            onPressed: () => _handleKeyPress(DeviceKeyAction.menu),
            tokens: tokens,
          ),
          _buildNavButton(
            icon: Icons.home_rounded,
            tooltip: 'Home (主页)',
            onPressed: () => _handleKeyPress(DeviceKeyAction.home),
            tokens: tokens,
          ),
          _buildNavButton(
            icon: Icons.crop_square_rounded,
            tooltip: 'App Switch (任务切换)',
            onPressed: () => _handleKeyPress(DeviceKeyAction.appSwitch),
            tokens: tokens,
          ),
          _buildNavButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Back (返回)',
            onPressed: () => _handleKeyPress(DeviceKeyAction.back),
            tokens: tokens,
          ),
        ],
      ),
    );
  }

  Widget _buildRawKeyboardBridge() {
    return ExcludeSemantics(
      child: Focus(
        focusNode: _rawKeyboardFocusNode,
        canRequestFocus: true,
        skipTraversal: true,
        child: const SizedBox.expand(),
      ),
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    required AppColorTokens tokens,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onPressed,
        child: Tooltip(
          message: tooltip,
          child: Center(
            child: Icon(icon, size: 20, color: tokens.textSecondary),
          ),
        ),
      ),
    );
  }
}
