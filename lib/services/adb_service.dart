import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/device_model.dart';
import '../models/device_tool_models.dart';

class StfServiceClipboardClient {
  static const int _setClipboardMessageType = 9;
  static const Duration _responseTimeout = Duration(seconds: 5);

  final String serial;

  Socket? _socket;
  StreamIterator<Uint8List>? _socketReader;
  Future<void>? _connectFuture;
  int? _forwardPort;
  int _nextRequestId = 1;
  final List<int> _readBuffer = <int>[];
  bool _isDisposed = false;

  StfServiceClipboardClient({required this.serial});

  Future<bool> setText(String text) async {
    if (text.isEmpty || _isDisposed) return false;

    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        await _ensureConnected();
        final socket = _socket;
        if (socket == null) {
          throw StateError('STF service socket is unavailable');
        }

        final requestId = _takeRequestId();
        socket.add(_encodeSetClipboardFrame(requestId, text));
        await socket.flush();

        while (true) {
          final envelope = _decodeEnvelope(await _readFrame());
          if (envelope.id != requestId) continue;
          if (envelope.type != _setClipboardMessageType) {
            throw StateError('Unexpected STF response type ${envelope.type}');
          }

          final success = _decodeSetClipboardResponse(envelope.message);
          if (kDebugMode) {
            debugPrint(
              '[StfClipboard:$serial] setText chars=${text.length} '
              'success=$success',
            );
          }
          return success;
        }
      } catch (error) {
        lastError = error;
        await _resetConnection();
        if (attempt == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 150));
        }
      }
    }

    if (kDebugMode) {
      debugPrint('[StfClipboard:$serial] setText failed: $lastError');
    }
    return false;
  }

  Future<void> _ensureConnected() async {
    if (_isDisposed) {
      throw StateError('STF clipboard client is disposed');
    }
    if (_socket != null) return;

    final pending = _connectFuture ??= _connect();
    try {
      await pending;
    } finally {
      if (identical(_connectFuture, pending)) {
        _connectFuture = null;
      }
    }
  }

  Future<void> _connect() async {
    final adbPath = await AdbService.resolveAdbPath();
    await _startService(adbPath);

    final forward = await Process.run(adbPath, [
      '-s',
      serial,
      'forward',
      'tcp:0',
      'localabstract:stfservice',
    ]).timeout(const Duration(seconds: 5));
    if (forward.exitCode != 0) {
      throw StateError('ADB forward failed: ${forward.stderr}');
    }

    final port = int.tryParse(forward.stdout.toString().trim());
    if (port == null || port <= 0) {
      throw StateError('ADB forward returned invalid port: ${forward.stdout}');
    }

    _forwardPort = port;
    try {
      final socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        port,
        timeout: const Duration(seconds: 3),
      );
      if (_isDisposed) {
        socket.destroy();
        throw StateError('STF clipboard client was disposed while connecting');
      }

      socket.setOption(SocketOption.tcpNoDelay, true);
      _socket = socket;
      _socketReader = StreamIterator<Uint8List>(socket);
      if (kDebugMode) {
        debugPrint('[StfClipboard:$serial] connected on tcp:$port');
      }
    } catch (_) {
      await _removeForward(adbPath, port);
      _forwardPort = null;
      rethrow;
    }
  }

  Future<void> _startService(String adbPath) async {
    Future<ProcessResult> startWith(String command) {
      return Process.run(adbPath, [
        '-s',
        serial,
        'shell',
        'am',
        command,
        '--user',
        '0',
        '-a',
        'jp.co.cyberagent.stf.ACTION_START',
        '-n',
        'jp.co.cyberagent.stf/.Service',
      ]).timeout(const Duration(seconds: 10));
    }

    var result = await startWith('start-foreground-service');
    if (result.exitCode != 0 ||
        result.stdout.toString().trimLeft().startsWith('Error')) {
      result = await startWith('startservice');
    }
    if (result.exitCode != 0 ||
        result.stdout.toString().trimLeft().startsWith('Error')) {
      throw StateError(
        'Unable to start STF Service: ${result.stderr}${result.stdout}',
      );
    }
  }

  int _takeRequestId() {
    final id = _nextRequestId;
    _nextRequestId = (_nextRequestId % 0xFFFFFF) + 1;
    return id;
  }

  Future<Uint8List> _readFrame() async {
    while (true) {
      final frame = _tryTakeFrame();
      if (frame != null) return frame;

      final reader = _socketReader;
      if (reader == null ||
          !await reader.moveNext().timeout(_responseTimeout)) {
        throw StateError('STF service socket closed before response');
      }
      _readBuffer.addAll(reader.current);
    }
  }

  Uint8List? _tryTakeFrame() {
    var length = 0;
    var shift = 0;
    var prefixLength = 0;

    while (prefixLength < _readBuffer.length) {
      final byte = _readBuffer[prefixLength++];
      length |= (byte & 0x7F) << shift;
      if ((byte & 0x80) == 0) {
        if (_readBuffer.length - prefixLength < length) return null;
        final frame = Uint8List.fromList(
          _readBuffer.sublist(prefixLength, prefixLength + length),
        );
        _readBuffer.removeRange(0, prefixLength + length);
        return frame;
      }

      shift += 7;
      if (shift > 28) {
        throw const FormatException('Invalid STF frame length');
      }
    }
    return null;
  }

  Future<void> _resetConnection() async {
    final reader = _socketReader;
    _socketReader = null;
    _socket?.destroy();
    _socket = null;
    _readBuffer.clear();
    if (reader != null) {
      await reader.cancel();
    }

    final port = _forwardPort;
    _forwardPort = null;
    if (port != null) {
      final adbPath = await AdbService.resolveAdbPath();
      await _removeForward(adbPath, port);
    }
  }

  Future<void> _removeForward(String adbPath, int port) async {
    try {
      await Process.run(adbPath, [
        '-s',
        serial,
        'forward',
        '--remove',
        'tcp:$port',
      ]).timeout(const Duration(seconds: 3));
    } catch (_) {}
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    unawaited(_resetConnection());
  }
}

class _StfEnvelope {
  final int? id;
  final int? type;
  final Uint8List message;

  const _StfEnvelope({
    required this.id,
    required this.type,
    required this.message,
  });
}

class _ProtoReader {
  final Uint8List bytes;
  int offset = 0;

  _ProtoReader(this.bytes);

  bool get isAtEnd => offset >= bytes.length;

  int readVarint() {
    var result = 0;
    var shift = 0;
    while (offset < bytes.length && shift <= 28) {
      final byte = bytes[offset++];
      result |= (byte & 0x7F) << shift;
      if ((byte & 0x80) == 0) return result;
      shift += 7;
    }
    throw const FormatException('Invalid protobuf varint');
  }

  Uint8List readBytes() {
    final length = readVarint();
    final end = offset + length;
    if (length < 0 || end > bytes.length) {
      throw const FormatException('Invalid protobuf byte length');
    }
    final value = Uint8List.fromList(bytes.sublist(offset, end));
    offset = end;
    return value;
  }

  void skipField(int wireType) {
    switch (wireType) {
      case 0:
        readVarint();
        return;
      case 1:
        offset += 8;
        break;
      case 2:
        final length = readVarint();
        offset += length;
        break;
      case 5:
        offset += 4;
        break;
      default:
        throw FormatException('Unsupported protobuf wire type $wireType');
    }
    if (offset > bytes.length) {
      throw const FormatException('Protobuf field exceeds message length');
    }
  }
}

Uint8List _encodeSetClipboardFrame(int requestId, String text) {
  final textBytes = utf8.encode(text);
  final request = <int>[
    ..._encodeProtoVarintField(1, 1),
    ..._encodeProtoBytesField(2, textBytes),
  ];
  final envelope = <int>[
    ..._encodeProtoVarintField(1, requestId),
    ..._encodeProtoVarintField(
      2,
      StfServiceClipboardClient._setClipboardMessageType,
    ),
    ..._encodeProtoBytesField(3, request),
  ];
  return Uint8List.fromList(<int>[
    ..._encodeVarint(envelope.length),
    ...envelope,
  ]);
}

List<int> _encodeProtoVarintField(int fieldNumber, int value) {
  return <int>[..._encodeVarint(fieldNumber << 3), ..._encodeVarint(value)];
}

List<int> _encodeProtoBytesField(int fieldNumber, List<int> value) {
  return <int>[
    ..._encodeVarint((fieldNumber << 3) | 2),
    ..._encodeVarint(value.length),
    ...value,
  ];
}

List<int> _encodeVarint(int value) {
  if (value < 0) throw ArgumentError.value(value, 'value');
  final bytes = <int>[];
  var remaining = value;
  do {
    var byte = remaining & 0x7F;
    remaining >>= 7;
    if (remaining != 0) byte |= 0x80;
    bytes.add(byte);
  } while (remaining != 0);
  return bytes;
}

_StfEnvelope _decodeEnvelope(Uint8List bytes) {
  final reader = _ProtoReader(bytes);
  int? id;
  int? type;
  Uint8List? message;

  while (!reader.isAtEnd) {
    final tag = reader.readVarint();
    final fieldNumber = tag >> 3;
    final wireType = tag & 0x07;
    switch (fieldNumber) {
      case 1 when wireType == 0:
        id = reader.readVarint();
      case 2 when wireType == 0:
        type = reader.readVarint();
      case 3 when wireType == 2:
        message = reader.readBytes();
      default:
        reader.skipField(wireType);
    }
  }

  if (type == null || message == null) {
    throw const FormatException('Incomplete STF response envelope');
  }
  return _StfEnvelope(id: id, type: type, message: message);
}

bool _decodeSetClipboardResponse(Uint8List bytes) {
  final reader = _ProtoReader(bytes);
  while (!reader.isAtEnd) {
    final tag = reader.readVarint();
    final fieldNumber = tag >> 3;
    final wireType = tag & 0x07;
    if (fieldNumber == 1 && wireType == 0) {
      return reader.readVarint() != 0;
    }
    reader.skipField(wireType);
  }
  throw const FormatException('Missing STF clipboard success response');
}

class AdbInteractiveSession {
  final String serial;
  late final StfServiceClipboardClient _clipboardClient;
  Process? _process;
  Future<void>? _startFuture;
  Future<void> _commandQueue = Future<void>.value();
  bool _isDisposed = false;

  AdbInteractiveSession({required this.serial}) {
    _clipboardClient = StfServiceClipboardClient(serial: serial);
    _startFuture = _startSession();
    sendCommand(
      'am start-foreground-service -a jp.co.cyberagent.stf.ACTION_START '
      '-n jp.co.cyberagent.stf/.Service 2>/dev/null || '
      'am startservice -a jp.co.cyberagent.stf.ACTION_START '
      '-n jp.co.cyberagent.stf/.Service 2>/dev/null',
    );
  }

  Future<void> _startSession() async {
    try {
      final adbPath = await AdbService.resolveAdbPath();
      final process = await Process.start(adbPath, ['-s', serial, 'shell']);
      if (_isDisposed) {
        process.kill();
        return;
      }

      _process = process;
      // Drain shell output so a verbose Android command cannot block the
      // interactive session while the control queue is still usable.
      unawaited(process.stdout.drain<void>());
      unawaited(process.stderr.drain<void>());

      process.exitCode.then((_) {
        if (identical(_process, process)) {
          _process = null;
          _startFuture = null;
          if (!_isDisposed) {
            Future<void>.delayed(const Duration(seconds: 1), () {
              if (!_isDisposed && _process == null && _startFuture == null) {
                _startFuture = _startSession();
              }
            });
          }
        }
      });
    } catch (e) {
      _startFuture = null;
      if (kDebugMode) {
        debugPrint('[AdbInteractiveSession] Error starting session: $e');
      }
    }
  }

  Future<void> _ensureStarted() async {
    if (_isDisposed || _process != null) return;

    final pending = _startFuture ??= _startSession();
    await pending;
  }

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final next = _commandQueue.then<T>((_) => operation());
    _commandQueue = next.then<void>((_) {}).catchError((error, stack) {
      if (kDebugMode) {
        debugPrint('[AdbInteractiveSession] Command failed: $error');
      }
    });
    return next;
  }

  Future<void> _executeCommand(String command) async {
    await _ensureStarted();
    if (_isDisposed) return;

    final process = _process;
    if (process == null) {
      await AdbService.executeShell(serial, command);
      return;
    }

    try {
      process.stdin.writeln(command);
      await process.stdin.flush();
    } catch (e) {
      if (identical(_process, process)) {
        _process = null;
      }
      if (kDebugMode) {
        debugPrint(
          '[AdbInteractiveSession] Interactive command failed, falling back: $e',
        );
      }
      await AdbService.executeShell(serial, command);
    }
  }

  void sendCommand(String command) {
    unawaited(_enqueue(() => _executeCommand(command)));
  }

  Future<void> sendCommandAndWait(String command) {
    return _enqueue(() => _executeCommand(command));
  }

  void tap(int x, int y) {
    unawaited(tapAndWait(x, y));
  }

  Future<void> tapAndWait(int x, int y) {
    return sendCommandAndWait('input tap $x $y');
  }

  void longPress(int x, int y, [int duration = 600]) {
    unawaited(longPressAndWait(x, y, duration));
  }

  Future<void> longPressAndWait(int x, int y, [int duration = 600]) {
    return sendCommandAndWait('input swipe $x $y $x $y $duration');
  }

  void swipe(int x1, int y1, int x2, int y2, [int duration = 250]) {
    unawaited(swipeAndWait(x1, y1, x2, y2, duration));
  }

  Future<void> swipeAndWait(
    int x1,
    int y1,
    int x2,
    int y2, [
    int duration = 250,
  ]) {
    return sendCommandAndWait('input swipe $x1 $y1 $x2 $y2 $duration');
  }

  void keyevent(int keyCode) {
    sendCommand('input keyevent $keyCode');
  }

  void sendText(String text) {
    unawaited(pasteText(text));
  }

  Future<bool> setClipboard(String text) {
    if (text.isEmpty) return Future<bool>.value(false);
    return _enqueue(() => _clipboardClient.setText(text));
  }

  Future<bool> pasteText(String text) {
    if (text.isEmpty) return Future<bool>.value(false);

    return _enqueue(() async {
      final clipboardSet = await _clipboardClient.setText(text);
      if (!clipboardSet) return false;

      // Match STF's compound paste path: wait for Android's clipboard state to
      // settle, then issue the native paste key only after a successful service
      // response. Keeping both steps in one queue item prevents interleaving.
      await Future<void>.delayed(const Duration(milliseconds: 500));
      final output = await AdbService.executeShell(
        serial,
        'input keyevent 279',
      );
      final success =
          !output.startsWith('Error') &&
          !output.startsWith('Execution Exception');
      if (kDebugMode) {
        debugPrint(
          '[AdbInteractiveSession:$serial] paste chars=${text.length} '
          'success=$success',
        );
      }
      return success;
    });
  }

  void dispose() {
    _isDisposed = true;
    _clipboardClient.dispose();
    _process?.kill();
    _process = null;
  }
}

class AdbService {
  static String? _resolvedAdbPath;
  static String? _lastError;

  static String? get lastError => _lastError;

  static Future<String> resolveAdbPath() async {
    if (_resolvedAdbPath != null) return _resolvedAdbPath!;

    final home = Platform.environment['HOME'] ?? '';
    final candidates = [
      if (home.isNotEmpty) '$home/Library/Android/sdk/platform-tools/adb',
      if (home.isNotEmpty) '$home/Android/Sdk/platform-tools/adb',
      '/opt/homebrew/bin/adb',
      '/usr/local/bin/adb',
      'adb',
    ];

    for (final path in candidates) {
      try {
        final res = await Process.run(path, [
          'version',
        ]).timeout(const Duration(seconds: 1));
        if (res.exitCode == 0) {
          _resolvedAdbPath = path;
          return path;
        }
      } catch (_) {}
    }

    _resolvedAdbPath = 'adb';
    return 'adb';
  }

  static Future<int?> resolveDeviceScreenPort(String serial) async {
    try {
      final psRes = await Process.run('ps', [
        '-axww',
        '-o',
        'command=',
      ]).timeout(const Duration(seconds: 2));
      if (psRes.exitCode == 0) {
        final stdout = psRes.stdout.toString();
        final lines = LineSplitter.split(stdout);
        final serialArgument = RegExp(
          r'--serial(?:=|\s+)' + RegExp.escape(serial) + r'(?:\s|$)',
        );
        for (final line in lines) {
          if (line.toLowerCase().contains('stf') &&
              serialArgument.hasMatch(line)) {
            final match = RegExp(
              r'--screen-port(?:=|\s+)(\d+)',
            ).firstMatch(line);
            if (match != null) {
              final port = int.tryParse(match.group(1)!);
              if (port != null && port > 0) {
                return port;
              }
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<List<DeviceModel>> getConnectedDevices() async {
    _lastError = null;
    final adb = await resolveAdbPath();
    final List<DeviceModel> devices = [];

    try {
      final result = await Process.run(adb, [
        'devices',
        '-l',
      ]).timeout(const Duration(seconds: 3));

      if (result.exitCode != 0) {
        _lastError = 'ADB 执行错误: ${result.stderr}';
        return devices;
      }

      final lines = LineSplitter.split(result.stdout as String);
      for (final rawLine in lines) {
        final line = rawLine.trim();
        if (line.isEmpty || line.startsWith('List of devices attached')) {
          continue;
        }

        final parts = line.split(RegExp(r'\s+'));
        if (parts.length >= 2) {
          final serial = parts[0];
          final statusStr = parts[1];

          if (statusStr != 'device') continue;

          String modelName = serial;
          String manufacturer = 'Android';

          for (final token in parts.skip(2)) {
            if (token.startsWith('model:')) {
              modelName = token.substring(6);
            } else if (token.startsWith('device:')) {
              if (modelName == serial) {
                modelName = token.substring(7);
              }
            }
          }

          int width = 720;
          int height = 1612;
          int rotation = 0;

          try {
            final sizeRes = await Process.run(adb, [
              '-s',
              serial,
              'shell',
              'wm',
              'size',
            ]).timeout(const Duration(milliseconds: 1500));
            if (sizeRes.exitCode == 0) {
              final match = RegExp(
                r'(\d+)x(\d+)',
              ).firstMatch(sizeRes.stdout as String);
              if (match != null) {
                width = int.parse(match.group(1)!);
                height = int.parse(match.group(2)!);
              }
            }
          } catch (_) {}

          try {
            final rotRes = await Process.run(adb, [
              '-s',
              serial,
              'shell',
              'settings',
              'get',
              'system',
              'user_rotation',
            ]).timeout(const Duration(milliseconds: 1000));
            if (rotRes.exitCode == 0) {
              final rotVal =
                  int.tryParse((rotRes.stdout as String).trim()) ?? 0;
              rotation = (rotVal * 90) % 360;
            }
          } catch (_) {}

          try {
            final manRes = await Process.run(adb, [
              '-s',
              serial,
              'shell',
              'getprop',
              'ro.product.manufacturer',
            ]).timeout(const Duration(milliseconds: 1000));
            if (manRes.exitCode == 0) {
              final man = (manRes.stdout as String).trim();
              if (man.isNotEmpty) manufacturer = man;
            }
          } catch (_) {}

          devices.add(
            DeviceModel(
              serial: serial,
              name: modelName,
              model: modelName,
              manufacturer: manufacturer,
              sdkVersion: '14',
              status: DeviceConnectionStatus.using,
              display: DeviceDisplayInfo(
                width: width,
                height: height,
                rotation: rotation,
              ),
            ),
          );
        }
      }
    } catch (e) {
      _lastError = '扫描 ADB 异常: $e';
    }

    return devices;
  }

  static Future<Uint8List?> captureScreen(String serial) async {
    final adb = await resolveAdbPath();
    try {
      final result = await Process.run(adb, [
        '-s',
        serial,
        'exec-out',
        'screencap',
        '-p',
      ], stdoutEncoding: null).timeout(const Duration(milliseconds: 2500));

      if (result.exitCode == 0 && result.stdout is List<int>) {
        return Uint8List.fromList(result.stdout as List<int>);
      }
    } catch (_) {}
    return null;
  }

  static Future<String> executeShell(String serial, String command) async {
    final adb = await resolveAdbPath();
    try {
      final result = await Process.run(adb, [
        '-s',
        serial,
        'shell',
        command,
      ]).timeout(const Duration(seconds: 10));
      if (result.exitCode == 0) {
        return result.stdout.toString();
      } else {
        return 'Error (${result.exitCode}): ${result.stderr}';
      }
    } catch (e) {
      return 'Execution Exception: $e';
    }
  }

  static Future<DeviceToolResult> executeHostCommand(
    List<String> arguments,
  ) async {
    final adb = await resolveAdbPath();
    try {
      final result = await Process.run(
        adb,
        arguments,
      ).timeout(const Duration(seconds: 15));
      final stdout = result.stdout.toString();
      final stderr = result.stderr.toString().trim();
      if (result.exitCode == 0) {
        return DeviceToolResult.ok(stdout);
      }
      return DeviceToolResult.failure(
        stderr.isEmpty ? 'ADB 命令执行失败 (${result.exitCode})' : stderr,
        output: stdout,
      );
    } catch (error) {
      return DeviceToolResult.failure('ADB 命令执行异常: $error');
    }
  }

  static Future<DeviceToolResult> installApk(String serial, String localPath) {
    return executeHostCommand(['-s', serial, 'install', '-r', localPath]);
  }

  static Future<DeviceToolResult> pullFile(
    String serial,
    String remotePath,
    String localPath,
  ) {
    return executeHostCommand(['-s', serial, 'pull', remotePath, localPath]);
  }

  static Future<Process?> startLogcat(String serial) async {
    final adb = await resolveAdbPath();
    try {
      return await Process.start(adb, [
        '-s',
        serial,
        'logcat',
        '-v',
        'threadtime',
      ]);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> injectText(String serial, String text) async {
    if (text.isEmpty) return false;

    final clipboard = StfServiceClipboardClient(serial: serial);
    try {
      if (!await clipboard.setText(text)) return false;
      await Future<void>.delayed(const Duration(milliseconds: 500));
      final output = await executeShell(serial, 'input keyevent 279');
      return !output.startsWith('Error') &&
          !output.startsWith('Execution Exception');
    } finally {
      clipboard.dispose();
    }
  }
}
