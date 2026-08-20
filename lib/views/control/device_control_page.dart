import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/device_model.dart';
import '../../services/adb_service.dart';
import '../../services/device_control_service.dart';
import '../../services/screen_stream_service.dart';
import '../../theme/app_theme.dart';
import 'widgets/app_header.dart';
import 'widgets/device_screen_stage.dart';
import 'widgets/device_workspace.dart';

class DeviceControlPage extends StatefulWidget {
  final ThemeController themeController;

  const DeviceControlPage({super.key, required this.themeController});

  @override
  State<DeviceControlPage> createState() => _DeviceControlPageState();
}

class _DeviceControlPageState extends State<DeviceControlPage> {
  final FocusNode _keyboardFocusNode = FocusNode();
  bool _isScreenVisible = true;
  bool _isScanning = false;
  String _adbPathInfo = '';
  String? _scanErrorInfo;

  List<DeviceModel> _devices = [];
  DeviceModel? _currentDevice;
  IDeviceControlService? _controlService;
  IScreenStreamService? _streamService;

  @override
  void initState() {
    super.initState();
    _scanAdbDevices();
  }

  Future<void> _scanAdbDevices() async {
    setState(() {
      _isScanning = true;
      _scanErrorInfo = null;
    });

    try {
      final adbPath = await AdbService.resolveAdbPath();
      final realDevices = await AdbService.getConnectedDevices();

      if (mounted) {
        setState(() {
          _adbPathInfo = adbPath;
          _devices = realDevices;
          _scanErrorInfo = AdbService.lastError;

          if (realDevices.isNotEmpty) {
            final match = realDevices.firstWhere(
              (d) => d.serial == _currentDevice?.serial,
              orElse: () => realDevices.first,
            );
            _setupDeviceServices(match);
          } else {
            _controlService?.dispose();
            _controlService = null;
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
          _scanErrorInfo = '检测异常: $e';
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

    _currentDevice = device;
    _controlService = AdbDeviceControlService(
      serial: device.serial,
      realWidth: device.display.width,
      realHeight: device.display.height,
    );

    // 挂载智能复合屏幕流服务（优先直连 STF minicap 60 FPS，失败平滑回退）
    _streamService = SmartScreenStreamService(
      serial: device.serial,
      realWidth: device.display.width,
      realHeight: device.display.height,
    );
  }

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    _controlService?.dispose();
    _streamService?.dispose();
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

    return Focus(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: tokens.bg,
        body: SafeArea(
          child: Column(
            children: [
              // 顶部导航栏
              AppHeader(
                currentDevice: _currentDevice,
                availableDevices: _devices,
                onDeviceSelected: _handleDeviceChanged,
                onRefreshDevices: _scanAdbDevices,
                onToggleTheme: widget.themeController.toggleTheme,
                onToggleRotation: _handleToggleRotation,
                onToggleScreenVisibility: _handleToggleScreenVisibility,
                isScreenVisible: _isScreenVisible,
                isScanning: _isScanning,
              ),

              // 主体内容：双栏响应式工作台
              Expanded(
                child:
                    _currentDevice != null &&
                        _controlService != null &&
                        _streamService != null
                    ? LayoutBuilder(
                        builder: (context, constraints) {
                          final isWideScreen = constraints.maxWidth >= 720;
                          final leftStageWidth = isWideScreen
                              ? (_currentDevice!.display.isLandscape
                                    ? 520.0
                                    : 380.0)
                              : constraints.maxWidth * 0.45;

                          return Row(
                            children: [
                              // 左侧手机屏幕主舞台 (实时真机画面与手势)
                              SizedBox(
                                width: leftStageWidth,
                                child: DeviceScreenStage(
                                  device: _currentDevice!,
                                  controlService: _controlService!,
                                  streamService: _streamService!,
                                  isVisible: _isScreenVisible,
                                ),
                              ),

                              // 右侧工具箱与群控工作区 (真机 Shell/输入/按键)
                              Expanded(
                                child: DeviceWorkspace(
                                  device: _currentDevice!,
                                  controlService: _controlService!,
                                  streamService: _streamService!,
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
