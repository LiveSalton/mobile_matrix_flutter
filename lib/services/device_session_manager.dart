import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/device_model.dart';
import 'adb_service.dart';
import 'device_session.dart';
import 'stf_lite_runtime_service.dart';

typedef ConnectedDevicesReader = Future<List<DeviceModel>> Function();
typedef StfSessionsReader = Future<List<StfLiteSessionInfo>> Function();
typedef DeviceSessionBuilder =
    DeviceSession Function(DeviceModel device, StfLiteRuntimeService runtime);

/// Owns the single STF Lite runtime and serial-keyed device sessions.
class DeviceSessionManager extends ChangeNotifier {
  final StfLiteRuntimeService runtime;
  final ConnectedDevicesReader _readDevices;
  late final StfSessionsReader _readStfSessions;
  final DeviceSessionBuilder _buildSession;
  final Duration refreshInterval;
  final Map<String, DeviceSession> _sessions = <String, DeviceSession>{};
  final Map<String, int> _missedScans = <String, int>{};

  Timer? _refreshTimer;
  bool _isScanning = false;
  bool _isDisposed = false;
  String? _errorMessage;

  DeviceSessionManager({
    StfLiteRuntimeService? runtime,
    ConnectedDevicesReader? readDevices,
    StfSessionsReader? readStfSessions,
    DeviceSessionBuilder? buildSession,
    this.refreshInterval = const Duration(seconds: 5),
  }) : runtime = runtime ?? StfLiteRuntimeService(),
       _readDevices = readDevices ?? AdbService.getConnectedDevices,
       _buildSession =
           buildSession ??
           ((device, runtime) =>
               DeviceSession(device: device, runtime: runtime)) {
    _readStfSessions = readStfSessions ?? this.runtime.getSessions;
  }

  bool get isScanning => _isScanning;
  String? get errorMessage => _errorMessage;
  bool get isRuntimeAvailable => runtime.isAvailable;
  List<DeviceSession> get sessions => List.unmodifiable(_sessions.values);
  DeviceSession? sessionFor(String serial) => _sessions[serial];

  Future<void> start() async {
    if (_isDisposed) return;
    await refresh();
    if (_isDisposed) return;
    _refreshTimer ??= Timer.periodic(
      refreshInterval,
      (_) => unawaited(refresh()),
    );
  }

  Future<void> refresh() async {
    if (_isDisposed || _isScanning) return;
    _isScanning = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final runtimeStarted = await runtime.start();
      final stfSessions = runtimeStarted
          ? await _readStfSessions()
          : const <StfLiteSessionInfo>[];
      final devices = await _readDevices();
      final sessionsBySerial = <String, StfLiteSessionInfo>{
        for (final session in stfSessions) session.serial: session,
      };
      final mergedDevices = devices
          .map(
            (device) =>
                _mergeStfSession(device, sessionsBySerial[device.serial]),
          )
          .toList(growable: false);
      final seen = <String>{};
      for (final device in mergedDevices) {
        seen.add(device.serial);
        _missedScans.remove(device.serial);
        final existing = _sessions[device.serial];
        if (existing == null) {
          final session = _buildSession(device, runtime);
          _sessions[device.serial] = session;
          session.addListener(_handleSessionChanged);
        } else {
          existing.updateDevice(device);
        }
      }
      for (final serial in _sessions.keys.toList(growable: false)) {
        if (seen.contains(serial)) continue;
        final misses = (_missedScans[serial] ?? 0) + 1;
        _missedScans[serial] = misses;
        if (misses >= 2) {
          final removed = _sessions.remove(serial);
          _missedScans.remove(serial);
          removed?.removeListener(_handleSessionChanged);
          removed?.dispose();
        }
      }
      if (!runtimeStarted && _sessions.isEmpty) {
        _errorMessage = runtime.errorMessage;
      }
    } catch (error) {
      _errorMessage = error.toString().replaceFirst('Exception: ', '');
    } finally {
      _isScanning = false;
      if (!_isDisposed) notifyListeners();
    }
  }

  DeviceModel _mergeStfSession(
    DeviceModel device,
    StfLiteSessionInfo? session,
  ) {
    if (session == null) return device;
    return device.copyWith(
      display: device.display.copyWith(
        width: session.width > 0 ? session.width : null,
        height: session.height > 0 ? session.height : null,
        rotation: session.rotation,
        streamUrl: session.screenUrl,
      ),
      isPresent: session.present,
      isReady: session.isReady,
      status: session.isReady
          ? DeviceConnectionStatus.using
          : DeviceConnectionStatus.disconnected,
    );
  }

  void _handleSessionChanged() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _refreshTimer?.cancel();
    _refreshTimer = null;
    for (final session in _sessions.values) {
      session.removeListener(_handleSessionChanged);
      session.dispose();
    }
    _sessions.clear();
    runtime.dispose();
    super.dispose();
  }
}
