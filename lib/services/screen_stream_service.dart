import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'adb_service.dart';
import 'native_minicap_stream_service.dart';

enum StreamState {
  connecting,
  streaming,
  paused,
  error,
  disconnected,
}

abstract class IScreenStreamService {
  Stream<Uint8List> get frameStream;
  StreamState get state;
  void startStream();
  void stopStream();
  void setStreamEnabled(bool enabled);
  void requestResolution(int width, int height);
  void triggerImmediateRefresh();
  void dispose();
}

/// STF minicap WebSocket 流服务
class StfMinicapStreamService extends ChangeNotifier implements IScreenStreamService {
  final String wsUrl;
  final int initialWidth;
  final int initialHeight;

  StreamState _state = StreamState.disconnected;
  final StreamController<Uint8List> _streamController = StreamController<Uint8List>.broadcast();
  WebSocket? _ws;
  StreamSubscription? _wsSubscription;
  bool _isEnabled = true;
  bool _isDisposed = false;
  int _currentWidth;
  int _currentHeight;
  Timer? _reconnectTimer;

  StfMinicapStreamService({
    required this.wsUrl,
    this.initialWidth = 540,
    this.initialHeight = 1209,
  })  : _currentWidth = initialWidth,
        _currentHeight = initialHeight {
    startStream();
  }

  @override
  Stream<Uint8List> get frameStream => _streamController.stream;

  @override
  StreamState get state => _state;

  @override
  void startStream() {
    if (_isDisposed || _state == StreamState.streaming) return;
    _connectWebSocket();
  }

  Future<void> _connectWebSocket() async {
    _state = StreamState.connecting;
    notifyListeners();

    try {
      _ws = await WebSocket.connect(wsUrl).timeout(const Duration(milliseconds: 1500));
      _state = StreamState.streaming;
      notifyListeners();

      if (kDebugMode) {
        debugPrint('[StfMinicapStream] Connected to $wsUrl successfully for current device');
      }

      _ws?.add('size ${_currentWidth}x$_currentHeight');
      if (_isEnabled) {
        _ws?.add('on');
      }

      _wsSubscription = _ws?.listen(
        (data) {
          if (data is List<int> && !_streamController.isClosed && !_isDisposed) {
            _streamController.add(data is Uint8List ? data : Uint8List.fromList(data));
          } else if (data is String) {
            if (kDebugMode) {
              debugPrint('[StfMinicapStream] Control message: $data');
            }
          }
        },
        onError: (err) {
          if (kDebugMode) {
            debugPrint('[StfMinicapStream] Error: $err');
          }
          _reconnect();
        },
        onDone: () {
          if (!_isDisposed) {
            _reconnect();
          }
        },
        cancelOnError: true,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[StfMinicapStream] Connect failed: $e, will retry');
      }
      _reconnect();
    }
  }

  void _reconnect() {
    _wsSubscription?.cancel();
    _wsSubscription = null;
    _ws?.close();
    _ws = null;
    _state = StreamState.disconnected;
    notifyListeners();

    if (!_isDisposed) {
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(const Duration(seconds: 2), () {
        if (!_isDisposed && _state != StreamState.streaming) {
          _connectWebSocket();
        }
      });
    }
  }

  @override
  void setStreamEnabled(bool enabled) {
    if (_isEnabled == enabled) return;
    _isEnabled = enabled;
    _state = enabled ? StreamState.streaming : StreamState.paused;
    _ws?.add(enabled ? 'on' : 'off');
    notifyListeners();
  }

  @override
  void requestResolution(int width, int height) {
    _currentWidth = (width * 0.75).round();
    _currentHeight = (height * 0.75).round();
    _ws?.add('size ${_currentWidth}x$_currentHeight');
  }

  @override
  void triggerImmediateRefresh() {}

  @override
  void stopStream() {
    _reconnectTimer?.cancel();
    _ws?.add('off');
    _wsSubscription?.cancel();
    _wsSubscription = null;
    _ws?.close();
    _ws = null;
    _state = StreamState.disconnected;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _reconnectTimer?.cancel();
    _wsSubscription?.cancel();
    _ws?.close();
    _streamController.close();
    super.dispose();
  }
}

/// 智能复合屏幕流服务（优先内置自驱 NativeMinicap 60 FPS 满速硬件直连）
class SmartScreenStreamService extends ChangeNotifier implements IScreenStreamService {
  final String serial;
  final int realWidth;
  final int realHeight;

  IScreenStreamService? _activeService;
  final StreamController<Uint8List> _streamController = StreamController<Uint8List>.broadcast();
  StreamSubscription? _activeSubscription;
  bool _isDisposed = false;

  SmartScreenStreamService({
    required this.serial,
    required this.realWidth,
    required this.realHeight,
  }) {
    _initStream();
  }

  @override
  Stream<Uint8List> get frameStream => _streamController.stream;

  @override
  StreamState get state => _activeService?.state ?? StreamState.connecting;

  Future<void> _initStream() async {
    // 方案 1 (最优先)：启动应用内置自驱 NativeMinicapStreamService (60 FPS 原生硬件直连)
    try {
      if (_isDisposed) return;
      final nativeService = NativeMinicapStreamService(
        serial: serial,
        realWidth: realWidth,
        realHeight: realHeight,
        localPort: 17400 + (serial.hashCode.abs() % 100),
      );
      _bindService(nativeService);
      return;
    } catch (_) {}

    // 方案 2：动态解析 STF 外部端口
    final port = await AdbService.resolveDeviceScreenPort(serial);
    if (_isDisposed) return;

    if (port != null && port > 0) {
      final wsUrl = 'ws://127.0.0.1:$port';
      try {
        final ws = await WebSocket.connect(wsUrl).timeout(const Duration(milliseconds: 600));
        await ws.close();

        if (_isDisposed) return;
        final stfService = StfMinicapStreamService(
          wsUrl: wsUrl,
          initialWidth: (realWidth * 0.75).round(),
          initialHeight: (realHeight * 0.75).round(),
        );
        _bindService(stfService);
        return;
      } catch (_) {}
    }

    if (_isDisposed) return;
    // 方案 3：回退到 ADB 原生流
    final adbService = AdbScreenStreamService(serial: serial);
    _bindService(adbService);
  }

  void _bindService(IScreenStreamService service) {
    _activeSubscription?.cancel();
    _activeService?.dispose();
    _activeService = service;

    _activeSubscription = service.frameStream.listen((bytes) {
      if (!_streamController.isClosed && !_isDisposed) {
        _streamController.add(bytes);
      }
    });
    notifyListeners();
  }

  @override
  void startStream() {
    _activeService?.startStream();
  }

  @override
  void stopStream() {
    _activeService?.stopStream();
  }

  @override
  void setStreamEnabled(bool enabled) {
    _activeService?.setStreamEnabled(enabled);
  }

  @override
  void requestResolution(int width, int height) {
    _activeService?.requestResolution(width, height);
  }

  @override
  void triggerImmediateRefresh() {
    _activeService?.triggerImmediateRefresh();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _activeSubscription?.cancel();
    _activeService?.dispose();
    _streamController.close();
    super.dispose();
  }
}

class AdbScreenStreamService extends ChangeNotifier implements IScreenStreamService {
  final String serial;
  StreamState _state = StreamState.disconnected;
  final StreamController<Uint8List> _streamController = StreamController<Uint8List>.broadcast();
  bool _isEnabled = true;
  bool _isLoopRunning = false;
  bool _isDisposed = false;

  AdbScreenStreamService({required this.serial}) {
    startStream();
  }

  @override
  Stream<Uint8List> get frameStream => _streamController.stream;

  @override
  StreamState get state => _state;

  @override
  void startStream() {
    if (_state == StreamState.streaming) return;
    _state = StreamState.streaming;
    notifyListeners();

    if (!_isLoopRunning) {
      _runAdaptiveCaptureLoop();
    }
  }

  Future<void> _runAdaptiveCaptureLoop() async {
    _isLoopRunning = true;

    while (!_isDisposed && _state == StreamState.streaming) {
      if (_isEnabled) {
        try {
          final bytes = await AdbService.captureScreen(serial);
          if (bytes != null && !_streamController.isClosed && !_isDisposed) {
            _streamController.add(bytes);
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[AdbStreamService] Loop capture error: $e');
          }
        }
      }

      await Future.delayed(const Duration(milliseconds: 30));
    }

    _isLoopRunning = false;
  }

  @override
  void triggerImmediateRefresh() {
    if (_isDisposed || !_isEnabled) return;
    Future.delayed(const Duration(milliseconds: 50), () async {
      try {
        final bytes = await AdbService.captureScreen(serial);
        if (bytes != null && !_streamController.isClosed && !_isDisposed) {
          _streamController.add(bytes);
        }
      } catch (_) {}
    });
  }

  @override
  void stopStream() {
    _state = StreamState.disconnected;
    notifyListeners();
  }

  @override
  void setStreamEnabled(bool enabled) {
    if (_isEnabled == enabled) return;
    _isEnabled = enabled;
    _state = enabled ? StreamState.streaming : StreamState.paused;
    if (enabled && !_isLoopRunning) {
      _runAdaptiveCaptureLoop();
    }
    notifyListeners();
  }

  @override
  void requestResolution(int width, int height) {}

  @override
  void dispose() {
    _isDisposed = true;
    _state = StreamState.disconnected;
    _streamController.close();
    super.dispose();
  }
}

class MockScreenStreamService extends ChangeNotifier implements IScreenStreamService {
  final String streamUrl;
  StreamState _state = StreamState.disconnected;
  final StreamController<Uint8List> _streamController = StreamController<Uint8List>.broadcast();
  bool _isEnabled = true;
  Timer? _connectTimer;

  MockScreenStreamService({required this.streamUrl}) {
    startStream();
  }

  @override
  Stream<Uint8List> get frameStream => _streamController.stream;

  @override
  StreamState get state => _state;

  bool get isEnabled => _isEnabled;

  @override
  void startStream() {
    if (_state == StreamState.streaming) return;
    _state = StreamState.connecting;
    notifyListeners();

    _connectTimer?.cancel();
    _connectTimer = Timer(const Duration(milliseconds: 100), () {
      _state = StreamState.streaming;
      notifyListeners();
    });
  }

  @override
  void stopStream() {
    _connectTimer?.cancel();
    _state = StreamState.disconnected;
    notifyListeners();
  }

  @override
  void setStreamEnabled(bool enabled) {
    if (_isEnabled == enabled) return;
    _isEnabled = enabled;
    _state = enabled ? StreamState.streaming : StreamState.paused;
    notifyListeners();
  }

  @override
  void requestResolution(int width, int height) {
    if (kDebugMode) {
      debugPrint('[StreamService] Request resolution: ${width}x$height');
    }
  }

  @override
  void triggerImmediateRefresh() {}

  @override
  void dispose() {
    _connectTimer?.cancel();
    _streamController.close();
    super.dispose();
  }
}
