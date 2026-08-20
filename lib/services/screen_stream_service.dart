import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'adb_service.dart';

enum StreamState { connecting, streaming, paused, error, disconnected }

class ScreenViewport {
  final double logicalWidth;
  final double logicalHeight;
  final double devicePixelRatio;
  final int rotation;

  const ScreenViewport({
    required this.logicalWidth,
    required this.logicalHeight,
    required this.devicePixelRatio,
    required this.rotation,
  });

  @override
  bool operator ==(Object other) {
    return other is ScreenViewport &&
        other.logicalWidth == logicalWidth &&
        other.logicalHeight == logicalHeight &&
        other.devicePixelRatio == devicePixelRatio &&
        other.rotation == rotation;
  }

  @override
  int get hashCode =>
      Object.hash(logicalWidth, logicalHeight, devicePixelRatio, rotation);
}

class ScreenProjection {
  final int width;
  final int height;

  const ScreenProjection(this.width, this.height);
}

ScreenProjection calculateStfScreenProjection({
  required ScreenViewport viewport,
  required int realWidth,
  required int realHeight,
}) {
  var logicalWidth = viewport.logicalWidth;
  var logicalHeight = viewport.logicalHeight;
  if (viewport.rotation == 90 || viewport.rotation == 270) {
    final rotatedWidth = logicalHeight;
    logicalHeight = logicalWidth;
    logicalWidth = rotatedWidth;
  }

  if (logicalWidth <= 0 || logicalHeight <= 0) {
    return ScreenProjection(
      (realWidth * 0.36).ceil(),
      (realHeight * 0.36).ceil(),
    );
  }

  final density = viewport.devicePixelRatio.clamp(1.0, 1.5).toDouble();
  var width = logicalWidth * density;
  var height = logicalHeight * density;

  final minimumWidth = realWidth * 0.36;
  if (width < minimumWidth) {
    final scale = minimumWidth / width;
    width *= scale;
    height *= scale;
  }

  final minimumHeight = realHeight * 0.36;
  if (height < minimumHeight) {
    final scale = minimumHeight / height;
    width *= scale;
    height *= scale;
  }

  return ScreenProjection(width.ceil(), height.ceil());
}

abstract class IScreenStreamService extends ChangeNotifier {
  Stream<Uint8List> get frameStream;
  StreamState get state;
  String? get errorMessage => null;
  void startStream();
  void stopStream();
  void setStreamEnabled(bool enabled);
  void requestResolution(int width, int height);
  void updateViewport(ScreenViewport viewport) {}
  void triggerImmediateRefresh();
}

/// STF minicap WebSocket 流服务
class StfMinicapStreamService extends IScreenStreamService {
  final String wsUrl;
  final int realWidth;
  final int realHeight;

  StreamState _state = StreamState.disconnected;
  String? _errorMessage;
  final StreamController<Uint8List> _streamController =
      StreamController<Uint8List>.broadcast();
  WebSocket? _ws;
  StreamSubscription? _wsSubscription;
  late bool _isEnabled;
  bool _isDisposed = false;
  bool _isStoppedManually = false;
  late int _currentWidth;
  late int _currentHeight;
  int? _lastSentWidth;
  int? _lastSentHeight;
  Timer? _reconnectTimer;

  StfMinicapStreamService({
    required this.wsUrl,
    required this.realWidth,
    required this.realHeight,
    bool initiallyEnabled = true,
  }) {
    _isEnabled = initiallyEnabled;
    _currentWidth = (realWidth * 0.36).ceil();
    _currentHeight = (realHeight * 0.36).ceil();
    startStream();
  }

  @override
  Stream<Uint8List> get frameStream => _streamController.stream;

  @override
  StreamState get state => _state;

  @override
  String? get errorMessage => _errorMessage;

  @override
  void startStream() {
    if (_isDisposed ||
        _state == StreamState.connecting ||
        _ws?.readyState == WebSocket.open) {
      return;
    }
    _isStoppedManually = false;
    unawaited(_connectWebSocket());
  }

  Future<void> _connectWebSocket() async {
    _setState(StreamState.connecting);

    try {
      final socket = await WebSocket.connect(
        wsUrl,
      ).timeout(const Duration(milliseconds: 1500));
      if (_isDisposed || _isStoppedManually) {
        await socket.close();
        return;
      }

      _ws = socket;
      _errorMessage = null;
      _lastSentWidth = null;
      _lastSentHeight = null;
      _setState(_isEnabled ? StreamState.streaming : StreamState.paused);

      if (kDebugMode) {
        debugPrint(
          '[StfMinicapStream] Connected to $wsUrl successfully for current device',
        );
      }

      if (_isEnabled) {
        _sendProjection(force: true);
        socket.add('on');
      }

      _wsSubscription = socket.listen(
        (data) {
          if (data is List<int> &&
              !_streamController.isClosed &&
              !_isDisposed) {
            _streamController.add(
              data is Uint8List ? data : Uint8List.fromList(data),
            );
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
          _scheduleReconnect('STF 屏幕连接中断，正在重试');
        },
        onDone: () {
          if (!_isDisposed && !_isStoppedManually) {
            _scheduleReconnect('STF 屏幕连接已关闭，正在重试');
          }
        },
        cancelOnError: true,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[StfMinicapStream] Connect failed: $e, will retry');
      }
      _scheduleReconnect('无法连接 STF 屏幕服务，正在重试');
    }
  }

  void _setState(StreamState nextState) {
    _state = nextState;
    notifyListeners();
  }

  void _scheduleReconnect(String message) {
    if (_isDisposed || _isStoppedManually) return;
    _wsSubscription?.cancel();
    _wsSubscription = null;
    _ws?.close();
    _ws = null;
    _errorMessage = message;
    _setState(StreamState.error);

    if (!_isDisposed && !_isStoppedManually) {
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(const Duration(seconds: 2), () {
        if (!_isDisposed && !_isStoppedManually) {
          unawaited(_connectWebSocket());
        }
      });
    }
  }

  void _sendProjection({bool force = false}) {
    final socket = _ws;
    if (socket?.readyState != WebSocket.open) return;
    if (!force &&
        _lastSentWidth == _currentWidth &&
        _lastSentHeight == _currentHeight) {
      return;
    }

    socket?.add('size ${_currentWidth}x$_currentHeight');
    _lastSentWidth = _currentWidth;
    _lastSentHeight = _currentHeight;
  }

  @override
  void setStreamEnabled(bool enabled) {
    if (_isEnabled == enabled) return;
    _isEnabled = enabled;
    final socket = _ws;
    if (socket?.readyState == WebSocket.open) {
      if (enabled) {
        _sendProjection(force: true);
        socket?.add('on');
        _setState(StreamState.streaming);
      } else {
        socket?.add('off');
        _setState(StreamState.paused);
      }
      return;
    }

    _setState(enabled ? StreamState.connecting : StreamState.paused);
    if (enabled) startStream();
  }

  @override
  void requestResolution(int width, int height) {
    if (width <= 0 || height <= 0) return;
    if (_currentWidth == width && _currentHeight == height) return;
    _currentWidth = width;
    _currentHeight = height;
    _sendProjection();
  }

  @override
  void updateViewport(ScreenViewport viewport) {
    final projection = calculateStfScreenProjection(
      viewport: viewport,
      realWidth: realWidth,
      realHeight: realHeight,
    );
    requestResolution(projection.width, projection.height);
  }

  @override
  void triggerImmediateRefresh() {}

  @override
  void stopStream() {
    _isStoppedManually = true;
    _reconnectTimer?.cancel();
    if (_ws?.readyState == WebSocket.open && _isEnabled) {
      _ws?.add('off');
    }
    _wsSubscription?.cancel();
    _wsSubscription = null;
    _ws?.close();
    _ws = null;
    _setState(StreamState.disconnected);
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

/// 设备屏幕流装配入口，仅绑定 Web STF 使用的屏幕 WebSocket。
class SmartScreenStreamService extends IScreenStreamService {
  final String serial;
  final int realWidth;
  final int realHeight;
  final String? initialStreamUrl;

  IScreenStreamService? _activeService;
  final StreamController<Uint8List> _streamController =
      StreamController<Uint8List>.broadcast();
  StreamSubscription? _activeSubscription;
  Timer? _resolutionRetryTimer;
  StreamState _state = StreamState.connecting;
  String? _errorMessage;
  ScreenViewport? _lastViewport;
  bool _isEnabled = true;
  bool _isResolving = false;
  bool _isDisposed = false;

  SmartScreenStreamService({
    required this.serial,
    required this.realWidth,
    required this.realHeight,
    this.initialStreamUrl,
  }) {
    unawaited(_resolveStfStream());
  }

  @override
  Stream<Uint8List> get frameStream => _streamController.stream;

  @override
  StreamState get state => _activeService?.state ?? _state;

  @override
  String? get errorMessage => _activeService?.errorMessage ?? _errorMessage;

  Future<void> _resolveStfStream() async {
    if (_isDisposed || _isResolving || _activeService != null) return;
    _isResolving = true;
    _state = StreamState.connecting;
    _errorMessage = null;
    notifyListeners();

    try {
      var wsUrl = initialStreamUrl?.trim();
      if (wsUrl == null || wsUrl.isEmpty) {
        final port = await AdbService.resolveDeviceScreenPort(serial);
        if (port != null && port > 0) {
          wsUrl = 'ws://127.0.0.1:$port';
        }
      }

      if (_isDisposed) return;
      if (wsUrl == null || wsUrl.isEmpty) {
        _setResolutionError();
        return;
      }

      final stfService = StfMinicapStreamService(
        wsUrl: wsUrl,
        realWidth: realWidth,
        realHeight: realHeight,
        initiallyEnabled: _isEnabled,
      );
      _bindService(stfService);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[SmartScreenStream] STF address resolution failed: $error');
      }
      if (!_isDisposed) _setResolutionError();
    } finally {
      _isResolving = false;
    }
  }

  void _setResolutionError() {
    _state = StreamState.error;
    _errorMessage = '未找到当前设备的 STF 屏幕服务，正在重试';
    notifyListeners();
    _resolutionRetryTimer?.cancel();
    _resolutionRetryTimer = Timer(const Duration(seconds: 2), () {
      unawaited(_resolveStfStream());
    });
  }

  void _bindService(IScreenStreamService service) {
    _resolutionRetryTimer?.cancel();
    _resolutionRetryTimer = null;
    _activeSubscription?.cancel();
    _activeService?.removeListener(_handleActiveStateChanged);
    _activeService?.dispose();
    _activeService = service;
    service.addListener(_handleActiveStateChanged);
    final viewport = _lastViewport;
    if (viewport != null) service.updateViewport(viewport);

    _activeSubscription = service.frameStream.listen((bytes) {
      if (!_streamController.isClosed && !_isDisposed) {
        _streamController.add(bytes);
      }
    });
    _handleActiveStateChanged();
  }

  void _handleActiveStateChanged() {
    if (_isDisposed) return;
    notifyListeners();
  }

  @override
  void startStream() {
    final service = _activeService;
    if (service != null) {
      service.startStream();
    } else {
      unawaited(_resolveStfStream());
    }
  }

  @override
  void stopStream() {
    _resolutionRetryTimer?.cancel();
    _activeService?.stopStream();
    _state = StreamState.disconnected;
    notifyListeners();
  }

  @override
  void setStreamEnabled(bool enabled) {
    if (_isEnabled == enabled) return;
    _isEnabled = enabled;
    final service = _activeService;
    if (service != null) {
      service.setStreamEnabled(enabled);
    } else {
      _state = enabled ? StreamState.connecting : StreamState.paused;
      notifyListeners();
      if (enabled) unawaited(_resolveStfStream());
    }
  }

  @override
  void requestResolution(int width, int height) {
    _activeService?.requestResolution(width, height);
  }

  @override
  void updateViewport(ScreenViewport viewport) {
    _lastViewport = viewport;
    _activeService?.updateViewport(viewport);
  }

  @override
  void triggerImmediateRefresh() {
    _activeService?.triggerImmediateRefresh();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _resolutionRetryTimer?.cancel();
    _activeSubscription?.cancel();
    _activeService?.removeListener(_handleActiveStateChanged);
    _activeService?.dispose();
    _streamController.close();
    super.dispose();
  }
}

class AdbScreenStreamService extends IScreenStreamService {
  final String serial;
  StreamState _state = StreamState.disconnected;
  final StreamController<Uint8List> _streamController =
      StreamController<Uint8List>.broadcast();
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

class MockScreenStreamService extends IScreenStreamService {
  final String streamUrl;
  StreamState _state = StreamState.disconnected;
  final StreamController<Uint8List> _streamController =
      StreamController<Uint8List>.broadcast();
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
