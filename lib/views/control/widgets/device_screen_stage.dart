import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/device_model.dart';
import '../../../models/device_key_event.dart';
import '../../../models/screen_fps_stats.dart';
import '../../../services/android_keyboard_mapper.dart';
import '../../../services/device_control_service.dart';
import '../../../services/scaling_coordinator.dart';
import '../../../services/screen_stream_service.dart';
import '../../../theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import 'fast_screen_renderer.dart';

class DeviceScreenStage extends StatefulWidget {
  static const double bottomNavigationHeight = 48.0;

  final DeviceModel device;
  final IDeviceControlService controlService;
  final IScreenStreamService streamService;
  final ValueNotifier<ScreenFpsStats> fpsStatsNotifier;
  final bool isVisible;
  final bool keyboardEnabled;
  final bool showBottomNavigation;
  final Alignment screenAlignment;
  final double? maxScreenWidth;
  final double navigationBarHeight;

  const DeviceScreenStage({
    super.key,
    required this.device,
    required this.controlService,
    required this.streamService,
    required this.fpsStatsNotifier,
    this.isVisible = true,
    this.keyboardEnabled = true,
    this.showBottomNavigation = true,
    this.screenAlignment = Alignment.center,
    this.maxScreenWidth,
    this.navigationBarHeight = bottomNavigationHeight,
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
  int _pointerMoveCount = 0;
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
    if (oldWidget.device.display.rotation != widget.device.display.rotation) {
      _submittedViewport = null;
      final viewport = _latestViewport;
      if (viewport != null) {
        _scheduleViewportUpdate(viewport);
      }
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
    if (widget.keyboardEnabled && !_rawKeyboardFocusNode.hasFocus) {
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
      _pointerMoveCount = 0;
      _touchPosition = event.localPosition;
    });

    if (kDebugMode) {
      debugPrint(
        '[DeviceInput:${widget.device.serial}] down '
        'local=${event.localPosition} render=$renderRect '
        'normalized=$norm rotation=${widget.device.display.rotation}',
      );
    }

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
      _pointerMoveCount += 1;
    });

    if (kDebugMode && (_pointerMoveCount == 1 || _pointerMoveCount % 10 == 0)) {
      debugPrint(
        '[DeviceInput:${widget.device.serial}] move '
        'count=$_pointerMoveCount local=${event.localPosition} '
        'normalized=$norm',
      );
    }

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

    if (kDebugMode) {
      debugPrint(
        '[DeviceInput:${widget.device.serial}] up '
        'moves=$_pointerMoveCount local=${event.localPosition}',
      );
    }

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

  void _dispatchKeyResult(Future<bool> request) {
    unawaited(
      request
          .then<void>((success) {
            if (kDebugMode && !success) {
              debugPrint(
                '[DeviceInput:${widget.device.serial}] key event rejected',
              );
            }
          })
          .catchError((Object error) {
            if (kDebugMode) {
              debugPrint(
                '[DeviceInput:${widget.device.serial}] key event failed: $error',
              );
            }
          }),
    );
  }

  DeviceKeyModifiers _keyboardModifiers() {
    final keyboard = HardwareKeyboard.instance;
    final lockModes = keyboard.lockModesEnabled;
    return DeviceKeyModifiers(
      shift: keyboard.isShiftPressed,
      ctrl: keyboard.isControlPressed,
      alt: keyboard.isAltPressed,
      meta: keyboard.isMetaPressed,
      capsLock: lockModes.contains(KeyboardLockMode.capsLock),
      scrollLock: lockModes.contains(KeyboardLockMode.scrollLock),
      numLock: lockModes.contains(KeyboardLockMode.numLock),
    );
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
      _dispatchKeyResult(
        widget.controlService.rawKeyDown(
          keyName,
          modifiers: _keyboardModifiers(),
        ),
      );
      return KeyEventResult.handled;
    }

    if (event is KeyUpEvent) {
      if (AndroidKeyboardMapper.isCharsetSwitch(event)) {
        _dispatchKeyResult(
          widget.controlService.rawKeyPress(
            AndroidKeyboardMapper.switchCharset,
            modifiers: _keyboardModifiers(),
          ),
        );
      } else {
        final keyName = AndroidKeyboardMapper.keyNameFor(event);
        if (keyName == null) return KeyEventResult.ignored;
        _dispatchKeyResult(
          widget.controlService.rawKeyUp(
            keyName,
            modifiers: _keyboardModifiers(),
          ),
        );
      }
      widget.streamService.triggerImmediateRefresh();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  Rect _calculateRenderRect(Size stageSize) {
    final renderRect = _coordinator.calculateRenderRect(
      stageSize,
      widget.device.display.rotation,
    );
    final maxWidth = widget.maxScreenWidth;
    if (maxWidth == null || maxWidth <= 0 || renderRect.width <= maxWidth) {
      return renderRect;
    }

    final targetAspect = widget.device.display.isLandscape
        ? 1.0 / _coordinator.realRatio
        : _coordinator.realRatio;
    final width = maxWidth.clamp(1.0, stageSize.width).toDouble();
    final height = width / targetAspect;
    final remainingWidth = stageSize.width - width;
    final remainingHeight = stageSize.height - height;
    final horizontalFactor = (widget.screenAlignment.x + 1) / 2;
    final verticalFactor = (widget.screenAlignment.y + 1) / 2;

    return Rect.fromLTWH(
      remainingWidth * horizontalFactor,
      remainingHeight * verticalFactor,
      width,
      height,
    );
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
                      final renderRect = _calculateRenderRect(stageSize);
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
                                child: Align(
                                  alignment: widget.screenAlignment,
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
                                              rotation: widget
                                                  .device
                                                  .display
                                                  .rotation,
                                              placeholder: _buildPlaceholder(
                                                context,
                                                state: state,
                                                errorMessage: widget
                                                    .streamService
                                                    .errorMessage,
                                                errorCode: widget
                                                    .streamService
                                                    .errorCode,
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
                                                errorCode: widget
                                                    .streamService
                                                    .errorCode,
                                              ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            if (widget.keyboardEnabled)
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
          if (widget.showBottomNavigation) _buildNavigationBar(context),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(
    BuildContext context, {
    required StreamState state,
    String? errorMessage,
    ScreenStreamErrorCode? errorCode,
  }) {
    final tokens = context.tokens;
    final isError = state == StreamState.error;
    final isPaused = state == StreamState.paused;
    final strings = L10n.of(context);
    final label = switch (state) {
      StreamState.streaming => strings.stf_lite_screen_waiting,
      StreamState.paused => strings.stf_lite_screen_paused,
      StreamState.error =>
        errorMessage ?? _localizedStreamError(strings, errorCode),
      StreamState.disconnected => strings.stf_lite_screen_disconnected,
      StreamState.connecting => strings.stf_lite_screen_connecting,
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
    ScreenStreamErrorCode? errorCode,
  }) {
    final tokens = context.tokens;
    final isError = state == StreamState.error;
    final isConnecting = state == StreamState.connecting;
    final strings = L10n.of(context);
    final label = switch (state) {
      StreamState.connecting => strings.stf_lite_screen_connecting,
      StreamState.paused => strings.stf_lite_screen_paused,
      StreamState.error =>
        errorMessage ?? _localizedStreamError(strings, errorCode),
      StreamState.disconnected => strings.stf_lite_screen_disconnected,
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

  String _localizedStreamError(L10n strings, ScreenStreamErrorCode? errorCode) {
    return switch (errorCode) {
      ScreenStreamErrorCode.sessionMissing =>
        strings.stf_lite_screen_session_missing,
      ScreenStreamErrorCode.connectionError =>
        strings.stf_lite_screen_connection_error,
      ScreenStreamErrorCode.interrupted => strings.stf_lite_screen_interrupted,
      ScreenStreamErrorCode.closed => strings.stf_lite_screen_closed,
      ScreenStreamErrorCode.disconnected =>
        strings.stf_lite_screen_disconnected,
      null => strings.stf_lite_screen_service_unavailable,
    };
  }

  Widget _buildNavigationBar(BuildContext context) {
    final tokens = context.tokens;

    return Container(
      height: widget.navigationBarHeight,
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
            child: Icon(icon, size: 18, color: tokens.textSecondary),
          ),
        ),
      ),
    );
  }
}
