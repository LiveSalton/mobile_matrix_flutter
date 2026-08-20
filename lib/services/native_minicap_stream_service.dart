import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'adb_service.dart';
import 'screen_stream_service.dart';

/// 内置自驱原生 minicap 60 FPS 硬件级屏幕流直连服务
class NativeMinicapStreamService extends ChangeNotifier implements IScreenStreamService {
  final String serial;
  final int realWidth;
  final int realHeight;
  final int localPort;

  StreamState _state = StreamState.disconnected;
  final StreamController<Uint8List> _streamController = StreamController<Uint8List>.broadcast();
  Process? _serverProcess;
  Socket? _socket;
  StreamSubscription? _socketSubscription;
  bool _isEnabled = true;
  bool _isDisposed = false;
  Timer? _reconnectTimer;

  // 内部帧拼装 Buffer
  final BytesBuilder _buffer = BytesBuilder(copy: false);
  bool _bannerParsed = false;
  int _targetFrameSize = 0;

  NativeMinicapStreamService({
    required this.serial,
    required this.realWidth,
    required this.realHeight,
    this.localPort = 17404,
  }) {
    startStream();
  }

  @override
  Stream<Uint8List> get frameStream => _streamController.stream;

  @override
  StreamState get state => _state;

  @override
  void startStream() {
    if (_isDisposed || _state == StreamState.streaming) return;
    _startNativeMinicapPipeline();
  }

  Future<void> _startNativeMinicapPipeline() async {
    _state = StreamState.connecting;
    notifyListeners();

    try {
      final adb = await AdbService.resolveAdbPath();

      // 1. 确保手机上有 minicap.apk
      final checkRes = await Process.run(adb, ['-s', serial, 'shell', 'ls', '/data/local/tmp/minicap.apk']);
      if (checkRes.exitCode != 0 || checkRes.stdout.toString().contains('No such file')) {
        // 从 Flutter asset 提取并推送
        final apkBytes = await rootBundle.load('assets/minicap/minicap.apk');
        final tempDir = Directory.systemTemp;
        final tempApk = File('${tempDir.path}/minicap_$serial.apk');
        await tempApk.writeAsBytes(apkBytes.buffer.asUint8List());

        await Process.run(adb, ['-s', serial, 'push', tempApk.path, '/data/local/tmp/minicap.apk']);
        try {
          await tempApk.delete();
        } catch (_) {}
      }

      // 2. 清理旧进程与 forward 规则
      await Process.run(adb, ['-s', serial, 'shell', 'pkill', '-f', 'minicap']);
      await Process.run(adb, ['-s', serial, 'forward', '--remove', 'tcp:$localPort']);

      final virtW = (realWidth * 0.75).round();
      final virtH = (realHeight * 0.75).round();

      // 3. 启动真机 app_process minicap
      final minicapCmd =
          'CLASSPATH=/data/local/tmp/minicap.apk app_process /system/bin io.devicefarmer.minicap.Main -S -Q 80 -P $realWidth' 'x' '$realHeight@$virtW' 'x' '$virtH/0';

      _serverProcess = await Process.start(adb, ['-s', serial, 'shell', minicapCmd]);

      // 监听进程 stdout 和 stderr 判断是否启动成功
      final completer = Completer<bool>();
      void handleLog(String line) {
        if (kDebugMode) debugPrint('[NativeMinicap:$serial] $line');
        if (line.contains('Listening on socket') || line.contains('PID:')) {
          if (!completer.isCompleted) completer.complete(true);
        }
      }

      _serverProcess?.stdout.transform(const SystemEncoding().decoder).listen(handleLog);
      _serverProcess?.stderr.transform(const SystemEncoding().decoder).listen(handleLog);

      _serverProcess?.exitCode.then((code) {
        if (!_isDisposed) {
          if (kDebugMode) debugPrint('[NativeMinicap:$serial] Process exited with code $code');
          _serverProcess = null;
          _scheduleReconnect();
        }
      });

      // 4. 等待 minicap 监听完成
      await completer.future.timeout(
        const Duration(milliseconds: 1500),
        onTimeout: () => true,
      );

      // 5. 绑定本地端口 forward
      await Process.run(adb, ['-s', serial, 'forward', 'tcp:$localPort', 'localabstract:minicap']);

      // 6. 连接本地 Socket 获取极速 JPEG 流
      await _connectSocket();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NativeMinicap] Pipeline start error: $e');
      }
      _scheduleReconnect();
    }
  }

  Future<void> _connectSocket() async {
    try {
      _socket = await Socket.connect('127.0.0.1', localPort, timeout: const Duration(seconds: 2));
      _state = StreamState.streaming;
      _bannerParsed = false;
      _buffer.clear();
      _targetFrameSize = 0;
      notifyListeners();

      if (kDebugMode) {
        debugPrint('[NativeMinicap] Direct hardware TCP socket connected at port $localPort!');
      }

      _socketSubscription = _socket?.listen(
        _handleSocketData,
        onError: (err) {
          if (kDebugMode) debugPrint('[NativeMinicap] Socket error: $err');
          _scheduleReconnect();
        },
        onDone: () {
          if (!_isDisposed) _scheduleReconnect();
        },
        cancelOnError: true,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[NativeMinicap] Socket connect error: $e');
      _scheduleReconnect();
    }
  }

  void _handleSocketData(Uint8List chunk) {
    if (_isDisposed || !_isEnabled) return;

    _buffer.add(chunk);

    while (true) {
      final currentBytes = _buffer.toBytes();

      // 1. 解析 24 字节 Banner 头部
      if (!_bannerParsed) {
        if (currentBytes.length < 24) return;
        _bannerParsed = true;
        _buffer.clear();
        if (currentBytes.length > 24) {
          _buffer.add(currentBytes.sublist(24));
        }
        continue;
      }

      // 2. 解析 4 字节 Frame Size
      if (_targetFrameSize == 0) {
        if (currentBytes.length < 4) return;
        final bd = ByteData.sublistView(Uint8List.fromList(currentBytes.sublist(0, 4)));
        _targetFrameSize = bd.getUint32(0, Endian.little);
        _buffer.clear();
        if (currentBytes.length > 4) {
          _buffer.add(currentBytes.sublist(4));
        }
        continue;
      }

      // 3. 读取完整 Frame 数据
      if (currentBytes.length < _targetFrameSize) {
        return;
      }

      final frameData = Uint8List.fromList(currentBytes.sublist(0, _targetFrameSize));
      if (!_streamController.isClosed && !_isDisposed) {
        _streamController.add(frameData);
      }

      final remaining = currentBytes.length - _targetFrameSize;
      _buffer.clear();
      if (remaining > 0) {
        _buffer.add(currentBytes.sublist(_targetFrameSize));
      }
      _targetFrameSize = 0;
    }
  }

  void _scheduleReconnect() {
    _socketSubscription?.cancel();
    _socketSubscription = null;
    _socket?.destroy();
    _socket = null;
    _state = StreamState.disconnected;
    notifyListeners();

    if (!_isDisposed) {
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(const Duration(seconds: 2), () {
        if (!_isDisposed && _state != StreamState.streaming) {
          _startNativeMinicapPipeline();
        }
      });
    }
  }

  @override
  void setStreamEnabled(bool enabled) {
    if (_isEnabled == enabled) return;
    _isEnabled = enabled;
    _state = enabled ? StreamState.streaming : StreamState.paused;
    notifyListeners();
  }

  @override
  void requestResolution(int width, int height) {}

  @override
  void triggerImmediateRefresh() {}

  @override
  void stopStream() {
    _reconnectTimer?.cancel();
    _socketSubscription?.cancel();
    _socketSubscription = null;
    _socket?.destroy();
    _socket = null;
    _serverProcess?.kill();
    _serverProcess = null;
    _state = StreamState.disconnected;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _reconnectTimer?.cancel();
    _socketSubscription?.cancel();
    _socket?.destroy();
    _serverProcess?.kill();
    _streamController.close();
    super.dispose();
  }
}
