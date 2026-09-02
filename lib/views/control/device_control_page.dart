import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/device_model.dart';
import '../../services/device_control_service.dart';
import '../../services/device_session_manager.dart';
import '../../services/device_session.dart';
import '../../services/screen_stream_service.dart';
import '../../services/stf_lite_runtime_service.dart';
import '../../theme/app_theme.dart';
import '../../l10n/l10n.dart';
import 'widgets/app_header.dart';
import 'widgets/device_screen_stage.dart';
import 'widgets/device_workspace.dart';

class DeviceControlPage extends StatefulWidget {
  final ThemeController themeController;
  final DeviceSessionManager sessionManager;
  final String initialSerial;

  const DeviceControlPage({
    super.key,
    required this.themeController,
    required this.sessionManager,
    required this.initialSerial,
  });

  @override
  State<DeviceControlPage> createState() => _DeviceControlPageState();
}

class _DeviceControlPageState extends State<DeviceControlPage> {
  final FocusNode _keyboardFocusNode = FocusNode();
  bool _isScreenVisible = true;
  late String _selectedSerial;

  @override
  void initState() {
    super.initState();
    _selectedSerial = widget.initialSerial;
    widget.sessionManager.addListener(_handleSessionsChanged);
    widget.sessionManager
        .sessionFor(_selectedSerial)
        ?.setStreamQuality(ScreenStreamQuality.full);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(widget.sessionManager.start());
    });
  }

  void _handleSessionsChanged() {
    if (mounted) setState(() {});
  }

  List<DeviceModel> get _devices => widget.sessionManager.sessions
      .map((session) => session.device)
      .toList(growable: false);

  DeviceSession? get _currentSession {
    final selected = widget.sessionManager.sessionFor(_selectedSerial);
    if (selected != null) return selected;
    final sessions = widget.sessionManager.sessions;
    return sessions.isEmpty ? null : sessions.first;
  }

  DeviceModel? get _currentDevice => _currentSession?.device;

  Future<void> _scanAdbDevices() => widget.sessionManager.refresh();

  void _returnToOverview() {
    if (!mounted) return;
    unawaited(Navigator.of(context).maybePop());
  }

  String? get _scanErrorInfo => widget.sessionManager.errorMessage;
  bool get _isScanning => widget.sessionManager.isScanning;

  String _localizedRuntimeError(BuildContext context) {
    final strings = L10n.of(context);
    return switch (widget.sessionManager.runtime.errorCode) {
      StfLiteRuntimeErrorCode.resourcesUnavailable =>
        strings.stf_lite_runtime_unavailable,
      StfLiteRuntimeErrorCode.startupFailed =>
        strings.stf_lite_runtime_start_failed(
          widget.sessionManager.runtime.errorMessage ??
              strings.stf_lite_runtime_not_ready,
        ),
      StfLiteRuntimeErrorCode.runtimeNotReady =>
        strings.stf_lite_runtime_not_ready,
      StfLiteRuntimeErrorCode.sidecarExited => strings.stf_lite_sidecar_exited,
      null => widget.sessionManager.runtime.errorMessage ?? '',
    };
  }

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    widget.sessionManager.removeListener(_handleSessionsChanged);
    widget.sessionManager
        .sessionFor(_selectedSerial)
        ?.setStreamQuality(ScreenStreamQuality.preview);
    super.dispose();
  }

  void _handleDeviceChanged(DeviceModel newDevice) {
    if (newDevice.serial == _currentDevice?.serial) return;
    _currentSession?.setStreamQuality(ScreenStreamQuality.preview);
    setState(() => _selectedSerial = newDevice.serial);
    widget.sessionManager
        .sessionFor(newDevice.serial)
        ?.setStreamQuality(ScreenStreamQuality.full);
  }

  void _handleToggleRotation() {
    final session = _currentSession;
    if (session == null) return;
    final currentRotation = session.device.display.rotation;
    final nextRotation = (currentRotation == 0) ? 90 : 0;
    session.updateDevice(
      session.device.copyWith(
        display: session.device.display.copyWith(rotation: nextRotation),
      ),
    );
    session.controlService.setRotation(nextRotation);
  }

  void _handleToggleScreenVisibility() {
    setState(() {
      _isScreenVisible = !_isScreenVisible;
    });
    _currentSession?.streamService.setStreamEnabled(_isScreenVisible);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _currentSession?.controlService.keyPress(DeviceKeyAction.back);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final activeSession = _currentSession;
    final currentDevice = activeSession?.device;
    final hasReadyDevice =
        widget.sessionManager.isRuntimeAvailable && activeSession != null;

    return Focus(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: tokens.bg,
        body: SafeArea(
          child: Column(
            children: [
              if (!hasReadyDevice)
                AppHeader(
                  currentDevice: currentDevice,
                  currentTheme: widget.themeController.currentTheme,
                  availableDevices: _devices,
                  onDeviceSelected: _handleDeviceChanged,
                  onRefreshDevices: _scanAdbDevices,
                  onToggleTheme: widget.themeController.toggleTheme,
                  onBackToOverview: _returnToOverview,
                  isScanning: _isScanning,
                ),

              // 主体内容：左侧手机舞台，右侧设备控制工作区
              Expanded(
                child: hasReadyDevice
                    ? LayoutBuilder(
                        builder: (context, constraints) {
                          const navigationBarHeight = 48.0;
                          const minRightWorkspaceWidth = 520.0;
                          const minStageWidth = 280.0;
                          final screenHeight = math
                              .max(
                                0.0,
                                constraints.maxHeight - navigationBarHeight,
                              )
                              .toDouble();
                          final deviceAspectRatio =
                              currentDevice!.display.width /
                              currentDevice.display.height;
                          final screenAspectRatio =
                              currentDevice.display.isLandscape
                              ? 1.0 / deviceAspectRatio
                              : deviceAspectRatio;
                          final aspectFittedWidth =
                              screenHeight * screenAspectRatio;
                          final maxStageWidth = math
                              .max(
                                minStageWidth,
                                constraints.maxWidth - minRightWorkspaceWidth,
                              )
                              .toDouble();
                          final leftStageWidth = math
                              .min(
                                maxStageWidth,
                                math.max(minStageWidth, aspectFittedWidth),
                              )
                              .toDouble();

                          return Row(
                            children: [
                              // 左侧手机屏幕主舞台 (实时真机画面与手势)
                              SizedBox(
                                width: leftStageWidth,
                                child: DeviceScreenStage(
                                  device: currentDevice,
                                  controlService: activeSession.controlService,
                                  streamService: activeSession.streamService,
                                  fpsStatsNotifier: activeSession.fpsStats,
                                  isVisible: _isScreenVisible,
                                ),
                              ),

                              // 右侧设备工具箱
                              Expanded(
                                child: Column(
                                  children: [
                                    AppHeader(
                                      currentDevice: currentDevice,
                                      currentTheme:
                                          widget.themeController.currentTheme,
                                      availableDevices: _devices,
                                      onDeviceSelected: _handleDeviceChanged,
                                      onRefreshDevices: _scanAdbDevices,
                                      onToggleTheme:
                                          widget.themeController.toggleTheme,
                                      onBackToOverview: _returnToOverview,
                                      isScanning: _isScanning,
                                    ),
                                    Expanded(
                                      child: DeviceWorkspace(
                                        device: currentDevice,
                                        controlService:
                                            activeSession.controlService,
                                        toolsService:
                                            activeSession.toolsService,
                                        streamService:
                                            activeSession.streamService,
                                        fpsStats: activeSession.fpsStats,
                                        onToggleRotation: _handleToggleRotation,
                                        onToggleScreenVisibility:
                                            _handleToggleScreenVisibility,
                                        isScreenVisible: _isScreenVisible,
                                      ),
                                    ),
                                  ],
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
                              Icons.usb_rounded,
                              size: 54,
                              color: tokens.primary.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '请通过 USB 连接 Android 手机',
                              style: TextStyle(
                                color: tokens.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '并在手机上开启【开发者选项】与【USB 调试】',
                              style: TextStyle(
                                color: tokens.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            if (_localizedRuntimeError(context).isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                _localizedRuntimeError(context),
                                style: TextStyle(
                                  color: tokens.textSecondary.withValues(
                                    alpha: 0.6,
                                  ),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                            if (_scanErrorInfo != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                _scanErrorInfo!,
                                style: TextStyle(
                                  color: tokens.danger,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: tokens.primary,
                                foregroundColor: tokens.textPrimary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              icon: _isScanning
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.refresh_rounded, size: 18),
                              label: const Text('重新检测设备'),
                              onPressed: _isScanning ? null : _scanAdbDevices,
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
