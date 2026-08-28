import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/device_model.dart';
import '../../services/adb_service.dart';
import '../../services/device_control_service.dart';
import '../../services/device_tools_service.dart';
import '../../services/screen_stream_service.dart';
import '../../services/stf_lite_runtime_service.dart';
import '../../theme/app_theme.dart';
import '../../l10n/l10n.dart';
import 'widgets/app_header.dart';
import 'widgets/device_screen_stage.dart';
import 'widgets/device_workspace.dart';
import 'widgets/fast_screen_renderer.dart';

class DeviceControlPage extends StatefulWidget {
  final ThemeController themeController;

  const DeviceControlPage({super.key, required this.themeController});

  @override
  State<DeviceControlPage> createState() => _DeviceControlPageState();
}

class _DeviceControlPageState extends State<DeviceControlPage> {
  final FocusNode _keyboardFocusNode = FocusNode();
  final ValueNotifier<ScreenFpsStats> _fpsStatsNotifier = ValueNotifier(
    ScreenFpsStats.empty,
  );
  bool _isScreenVisible = true;
  bool _isScanning = false;
  String _adbPathInfo = '';
  String? _scanErrorInfo;

  List<DeviceModel> _devices = [];
  DeviceModel? _currentDevice;
  IDeviceControlService? _controlService;
  DeviceToolsService? _toolsService;
  IScreenStreamService? _streamService;
  final StfLiteRuntimeService _stfLiteRuntime = StfLiteRuntimeService();

  @override
  void initState() {
    super.initState();
    _stfLiteRuntime.addListener(_handleRuntimeChanged);
    _scanAdbDevices();
  }

  void _handleRuntimeChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _scanAdbDevices() async {
    setState(() {
      _isScanning = true;
      _scanErrorInfo = null;
    });

    try {
      final adbPath = await AdbService.resolveAdbPath();
      final runtimeStarted = await _stfLiteRuntime.start();
      final stfSessions = runtimeStarted
          ? await _stfLiteRuntime.getSessions()
          : const <StfLiteSessionInfo>[];
      final realDevices = await AdbService.getConnectedDevices();
      final sessionsBySerial = <String, StfLiteSessionInfo>{
        for (final session in stfSessions) session.serial: session,
      };
      final devices = realDevices
          .map((device) {
            final session = sessionsBySerial[device.serial];
            if (session == null) return device;
            final display = device.display.copyWith(
              width: session.width > 0 ? session.width : null,
              height: session.height > 0 ? session.height : null,
              rotation: session.rotation,
              streamUrl: session.screenUrl,
            );
            return device.copyWith(display: display);
          })
          .toList(growable: false);

      if (mounted) {
        setState(() {
          _adbPathInfo = adbPath;
          _devices = devices;
          _scanErrorInfo =
              AdbService.lastError ??
              (runtimeStarted ? null : _localizedRuntimeError(context));

          if (devices.isNotEmpty) {
            final match = devices.firstWhere(
              (d) => d.serial == _currentDevice?.serial,
              orElse: () => devices.first,
            );
            _setupDeviceServices(match);
          } else {
            _controlService?.dispose();
            _controlService = null;
            _toolsService?.dispose();
            _toolsService = null;
            _streamService?.stopStream();
            _streamService?.dispose();
            _streamService = null;
            _currentDevice = null;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _scanErrorInfo = '${L10n.of(context).remote_debug_read_failed}: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  void _setupDeviceServices(DeviceModel device) {
    _streamService?.stopStream();
    _streamService?.dispose();
    _controlService?.dispose();
    _toolsService?.dispose();

    _currentDevice = device;
    _controlService = StfLiteDeviceControlService(
      serial: device.serial,
      runtime: _stfLiteRuntime,
    );
    _toolsService = DeviceToolsService(serial: device.serial);

    // 与 Web 控制台共用 STF 设备屏幕 WebSocket，不启动另一套 minicap。
    _streamService = SmartScreenStreamService(
      serial: device.serial,
      realWidth: device.display.width,
      realHeight: device.display.height,
      initialStreamUrl: device.display.streamUrl,
    );
  }

  String? _localizedRuntimeError(BuildContext context) {
    final strings = L10n.of(context);
    return switch (_stfLiteRuntime.errorCode) {
      StfLiteRuntimeErrorCode.resourcesUnavailable =>
        strings.stf_lite_runtime_unavailable,
      StfLiteRuntimeErrorCode.startupFailed =>
        strings.stf_lite_runtime_start_failed(
          _stfLiteRuntime.errorMessage ?? strings.stf_lite_runtime_not_ready,
        ),
      StfLiteRuntimeErrorCode.runtimeNotReady =>
        strings.stf_lite_runtime_not_ready,
      StfLiteRuntimeErrorCode.sidecarExited => strings.stf_lite_sidecar_exited,
      null => _stfLiteRuntime.errorMessage,
    };
  }

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    _fpsStatsNotifier.dispose();
    _controlService?.dispose();
    _toolsService?.dispose();
    _streamService?.dispose();
    _stfLiteRuntime.removeListener(_handleRuntimeChanged);
    _stfLiteRuntime.dispose();
    super.dispose();
  }

  void _handleDeviceChanged(DeviceModel newDevice) {
    if (newDevice.serial == _currentDevice?.serial) return;
    setState(() {
      _setupDeviceServices(newDevice);
    });
  }

  void _handleToggleRotation() {
    if (_currentDevice == null) return;
    final currentRotation = _currentDevice!.display.rotation;
    final nextRotation = (currentRotation == 0) ? 90 : 0;
    setState(() {
      _currentDevice = _currentDevice!.copyWith(
        display: _currentDevice!.display.copyWith(rotation: nextRotation),
      );
    });
    _controlService?.setRotation(nextRotation);
  }

  void _handleToggleScreenVisibility() {
    setState(() {
      _isScreenVisible = !_isScreenVisible;
    });
    _streamService?.setStreamEnabled(_isScreenVisible);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _controlService?.keyPress(DeviceKeyAction.back);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final hasReadyDevice =
        _stfLiteRuntime.isAvailable &&
        _currentDevice != null &&
        _controlService != null &&
        _streamService != null &&
        _toolsService != null;

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
                  currentDevice: _currentDevice,
                  currentTheme: widget.themeController.currentTheme,
                  availableDevices: _devices,
                  onDeviceSelected: _handleDeviceChanged,
                  onRefreshDevices: _scanAdbDevices,
                  onToggleTheme: widget.themeController.toggleTheme,
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
                              _currentDevice!.display.width /
                              _currentDevice!.display.height;
                          final screenAspectRatio =
                              _currentDevice!.display.isLandscape
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
                                  device: _currentDevice!,
                                  controlService: _controlService!,
                                  streamService: _streamService!,
                                  fpsStatsNotifier: _fpsStatsNotifier,
                                  isVisible: _isScreenVisible,
                                ),
                              ),

                              // 右侧设备工具箱
                              Expanded(
                                child: Column(
                                  children: [
                                    AppHeader(
                                      currentDevice: _currentDevice,
                                      currentTheme:
                                          widget.themeController.currentTheme,
                                      availableDevices: _devices,
                                      onDeviceSelected: _handleDeviceChanged,
                                      onRefreshDevices: _scanAdbDevices,
                                      onToggleTheme:
                                          widget.themeController.toggleTheme,
                                      isScanning: _isScanning,
                                    ),
                                    Expanded(
                                      child: DeviceWorkspace(
                                        device: _currentDevice!,
                                        controlService: _controlService!,
                                        toolsService: _toolsService!,
                                        streamService: _streamService!,
                                        fpsStats: _fpsStatsNotifier,
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
                            if (_adbPathInfo.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                'ADB 探测路径: $_adbPathInfo',
                                style: TextStyle(
                                  color: tokens.textSecondary.withValues(
                                    alpha: 0.6,
                                  ),
                                  fontSize: 11,
                                  fontFamily: 'monospace',
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
