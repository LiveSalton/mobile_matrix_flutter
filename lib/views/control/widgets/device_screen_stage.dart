import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/device_model.dart';
import '../../../services/device_control_service.dart';
import '../../../services/scaling_coordinator.dart';
import '../../../services/screen_stream_service.dart';
import '../../../theme/app_theme.dart';
import 'fast_screen_renderer.dart';

class DeviceScreenStage extends StatefulWidget {
  final DeviceModel device;
  final IDeviceControlService controlService;
  final IScreenStreamService streamService;
  final bool isVisible;

  const DeviceScreenStage({
    super.key,
    required this.device,
    required this.controlService,
    required this.streamService,
    this.isVisible = true,
  });

  @override
  State<DeviceScreenStage> createState() => _DeviceScreenStageState();
}

class _DeviceScreenStageState extends State<DeviceScreenStage> {
  late final FocusNode _imeFocusNode;
  late final TextEditingController _imeController;

  late ScalingCoordinator _coordinator;
  Offset? _touchPosition;
  NormalizedPoint? _lastNormalizedPoint;
  bool _isPointerDown = false;
  bool _isLongPressActive = false;
  Timer? _longPressVisualTimer;

  @override
  void initState() {
    super.initState();
    _imeFocusNode = FocusNode(onKeyEvent: _handleKeyboardPassthrough);
    _imeController = TextEditingController();
    _initCoordinator();
  }

  @override
  void didUpdateWidget(covariant DeviceScreenStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.device.display.width != widget.device.display.width ||
        oldWidget.device.display.height != widget.device.display.height) {
      _initCoordinator();
    }
  }

  @override
  void dispose() {
    _longPressVisualTimer?.cancel();
    _imeFocusNode.dispose();
    _imeController.dispose();
    super.dispose();
  }

  void _initCoordinator() {
    _coordinator = ScalingCoordinator(
      realWidth: widget.device.display.width,
      realHeight: widget.device.display.height,
    );
  }

  void _handlePointerDown(PointerDownEvent event, Rect renderRect) {
    if (!renderRect.contains(event.localPosition)) return;

    // Mirror STF Web: the device screen gesture activates the hidden desktop
    // input bridge, so no separate input UI is needed.
    if (!_imeFocusNode.hasFocus) {
      _imeFocusNode.requestFocus();
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
      _lastNormalizedPoint = norm;
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
      _lastNormalizedPoint = norm;
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
  }

  void _handleKeyPress(DeviceKeyAction key) {
    widget.controlService.keyPress(key);
    widget.streamService.triggerImmediateRefresh();
  }

  void _handleImeChanged(String text) {
    if (text.isEmpty) return;

    final composing = _imeController.value.composing;
    if (composing.isValid && !composing.isCollapsed) {
      return;
    }

    // Only commit finalized IME text. Pinyin and other composing text stays in
    // the hidden bridge until the desktop IME selects a candidate.
    _imeController.clear();
    unawaited(_sendTextToDevice(text));
  }

  Future<void> _sendTextToDevice(String text) async {
    final sent = await widget.controlService.typeText(text);
    if (sent && mounted) {
      widget.streamService.triggerImmediateRefresh();
    }
  }

  Future<void> _pasteDesktopClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) return;

    _imeController.clear();
    final pasted = await widget.controlService.pasteText(text);
    if (pasted && mounted) {
      widget.streamService.triggerImmediateRefresh();
    }
  }

  void _submitInput(String value) {
    final text = value;
    if (text.isNotEmpty) {
      _imeController.clear();
      unawaited(_sendTextToDevice(text));
      return;
    }

    _handleKeyPress(DeviceKeyAction.enter);
  }

  KeyEventResult _handleKeyboardPassthrough(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    final isMeta =
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed;

    // 1. 拦截 Cmd+V (Mac) / Ctrl+V (Win/Linux) 剪贴板直通
    if (event is KeyDownEvent && isMeta && key == LogicalKeyboardKey.keyV) {
      unawaited(_pasteDesktopClipboard());
      return KeyEventResult.handled;
    }

    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final hasLocalInput =
        _imeController.text.isNotEmpty ||
        (_imeController.value.composing.isValid &&
            !_imeController.value.composing.isCollapsed);

    // 2. 物理控制按键映射 (退格、回车、Tab、Escape、方向键)
    if (key == LogicalKeyboardKey.backspace) {
      if (hasLocalInput) return KeyEventResult.ignored;
      widget.controlService.keyPress(DeviceKeyAction.delete);
      widget.streamService.triggerImmediateRefresh();
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (_imeController.value.composing.isValid &&
          !_imeController.value.composing.isCollapsed) {
        return KeyEventResult.ignored;
      }
      if (_imeController.text.isNotEmpty) {
        _submitInput(_imeController.text);
        return KeyEventResult.handled;
      }
      widget.controlService.keyPress(DeviceKeyAction.enter);
      widget.streamService.triggerImmediateRefresh();
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.escape) {
      if (hasLocalInput) return KeyEventResult.ignored;
      widget.controlService.keyPress(DeviceKeyAction.back);
      widget.streamService.triggerImmediateRefresh();
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.tab) {
      if (hasLocalInput) return KeyEventResult.ignored;
      widget.controlService.keyPress(DeviceKeyAction.tab);
      widget.streamService.triggerImmediateRefresh();
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.arrowUp) {
      if (hasLocalInput) return KeyEventResult.ignored;
      widget.controlService.keyPress(DeviceKeyAction.dpadUp);
      widget.streamService.triggerImmediateRefresh();
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.arrowDown) {
      if (hasLocalInput) return KeyEventResult.ignored;
      widget.controlService.keyPress(DeviceKeyAction.dpadDown);
      widget.streamService.triggerImmediateRefresh();
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      if (hasLocalInput) return KeyEventResult.ignored;
      widget.controlService.keyPress(DeviceKeyAction.dpadLeft);
      widget.streamService.triggerImmediateRefresh();
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.arrowRight) {
      if (hasLocalInput) return KeyEventResult.ignored;
      widget.controlService.keyPress(DeviceKeyAction.dpadRight);
      widget.streamService.triggerImmediateRefresh();
      return KeyEventResult.handled;
    }

    // 其余字符按键全部放行给 TextField 进行原生输入法（IME）处理
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
          // 顶部信息条
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: tokens.bgSecondary.withValues(alpha: 0.5),
              border: Border(
                bottom: BorderSide(
                  color: tokens.outline.withValues(alpha: 0.3),
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.smartphone_rounded, size: 16, color: tokens.primary),
                const SizedBox(width: 8),
                Text(
                  widget.device.displayName,
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${widget.device.display.width}×${widget.device.display.height}',
                  style: TextStyle(color: tokens.textSecondary, fontSize: 11),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${widget.device.display.rotation}°',
                    style: TextStyle(
                      color: tokens.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                if (_lastNormalizedPoint != null && _isPointerDown)
                  Text(
                    'Touch: (${(_lastNormalizedPoint!.xP * 100).toStringAsFixed(0)}%, ${(_lastNormalizedPoint!.yP * 100).toStringAsFixed(0)}%)',
                    style: TextStyle(
                      color: tokens.primary,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
              ],
            ),
          ),

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

                      return Stack(
                        children: [
                          Positioned(
                            left: renderRect.left,
                            top: renderRect.top,
                            width: 1,
                            height: 1,
                            child: _buildHiddenImeBridge(),
                          ),

                          // 交互层捕获
                          Positioned.fill(
                            child: Listener(
                              behavior: HitTestBehavior.opaque,
                              onPointerDown: (e) =>
                                  _handlePointerDown(e, renderRect),
                              onPointerMove: (e) =>
                                  _handlePointerMove(e, renderRect),
                              onPointerUp: _handlePointerUp,
                              onPointerCancel: _handlePointerCancel,
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
                                    child: FastScreenRenderer(
                                      frameStream:
                                          widget.streamService.frameStream,
                                      placeholder: _buildPlaceholder(context),
                                    ),
                                  ),
                                ),
                              ),
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
                                        : tokens.primary.withValues(alpha: 0.3),
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

  Widget _buildPlaceholder(BuildContext context) {
    final tokens = context.tokens;

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
                '正在建立 60 FPS 极速屏幕流...',
                style: TextStyle(color: tokens.textPrimary, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
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

  Widget _buildHiddenImeBridge() {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: Opacity(
          opacity: 0,
          child: TextField(
            focusNode: _imeFocusNode,
            controller: _imeController,
            autofocus: false,
            showCursor: false,
            enableInteractiveSelection: false,
            maxLines: 1,
            textInputAction: TextInputAction.send,
            style: const TextStyle(
              color: Colors.transparent,
              fontSize: 1,
              height: 1,
            ),
            cursorColor: Colors.transparent,
            decoration: const InputDecoration.collapsed(hintText: ''),
            onChanged: _handleImeChanged,
            onSubmitted: _submitInput,
          ),
        ),
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
