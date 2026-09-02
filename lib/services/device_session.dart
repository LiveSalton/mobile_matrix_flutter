import 'package:flutter/foundation.dart';

import '../models/device_model.dart';
import '../models/screen_fps_stats.dart';
import 'device_control_service.dart';
import 'device_tools_service.dart';
import 'screen_stream_service.dart';
import 'stf_lite_runtime_service.dart';

enum DeviceSessionState { connecting, ready, disconnected, error }

/// Runtime resources belonging to exactly one Android device serial.
class DeviceSession extends ChangeNotifier {
  final StfLiteRuntimeService runtime;
  final String serial;
  final ValueNotifier<ScreenFpsStats> fpsStats = ValueNotifier(
    ScreenFpsStats.empty,
  );

  DeviceModel _device;
  late IDeviceControlService controlService;
  late DeviceToolsService toolsService;
  late IScreenStreamService streamService;
  DeviceSessionState _state = DeviceSessionState.connecting;
  ScreenStreamQuality _quality = ScreenStreamQuality.preview;
  bool _isDisposed = false;

  DeviceSession({
    required DeviceModel device,
    required this.runtime,
    IScreenStreamService? streamService,
  }) : serial = device.serial,
       _device = device {
    controlService = StfLiteDeviceControlService(
      serial: device.serial,
      runtime: runtime,
    );
    toolsService = DeviceToolsService(serial: device.serial);
    this.streamService =
        streamService ??
        SmartScreenStreamService(
          serial: device.serial,
          realWidth: device.display.width,
          realHeight: device.display.height,
          initialStreamUrl: device.display.streamUrl,
        );
    this.streamService.addListener(_handleStreamChanged);
    this.streamService.setQuality(_quality);
    _handleStreamChanged();
  }

  DeviceModel get device => _device;
  DeviceSessionState get state => _state;
  bool get isReady => _state == DeviceSessionState.ready;

  void updateDevice(DeviceModel device) {
    if (_isDisposed || device.serial != serial) return;
    final streamChanged =
        device.display.width != _device.display.width ||
        device.display.height != _device.display.height ||
        device.display.streamUrl != _device.display.streamUrl;
    _device = device;
    if (streamChanged) _replaceStream(device);
    notifyListeners();
  }

  void setStreamQuality(ScreenStreamQuality quality) {
    if (_isDisposed) return;
    _quality = quality;
    streamService.setQuality(quality);
  }

  void _replaceStream(DeviceModel device) {
    final oldStream = streamService;
    oldStream.removeListener(_handleStreamChanged);
    oldStream.dispose();
    streamService = SmartScreenStreamService(
      serial: serial,
      realWidth: device.display.width,
      realHeight: device.display.height,
      initialStreamUrl: device.display.streamUrl,
    );
    streamService.setQuality(_quality);
    streamService.addListener(_handleStreamChanged);
  }

  void _handleStreamChanged() {
    if (_isDisposed) return;
    final nextState = switch (streamService.state) {
      StreamState.connecting => DeviceSessionState.connecting,
      StreamState.streaming || StreamState.paused => DeviceSessionState.ready,
      StreamState.disconnected => DeviceSessionState.disconnected,
      StreamState.error => DeviceSessionState.error,
    };
    if (_state != nextState) {
      _state = nextState;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    streamService.removeListener(_handleStreamChanged);
    streamService.dispose();
    toolsService.dispose();
    controlService.dispose();
    fpsStats.dispose();
    super.dispose();
  }
}
