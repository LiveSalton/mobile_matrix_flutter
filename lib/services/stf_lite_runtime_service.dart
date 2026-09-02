import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'adb_service.dart';

enum StfLiteRuntimeState { stopped, starting, ready, unavailable, error }

enum StfLiteRuntimeErrorCode {
  resourcesUnavailable,
  startupFailed,
  runtimeNotReady,
  sidecarExited,
}

class _PendingKeyRequest {
  final Completer<bool> completer = Completer<bool>();
}

class StfLiteSessionInfo {
  final String serial;
  final String model;
  final String status;
  final bool present;
  final int width;
  final int height;
  final int rotation;
  final String? screenUrl;
  final String? controlUrl;
  final String? controlStreamUrl;
  final bool clipboardAvailable;
  final String? lastError;

  const StfLiteSessionInfo({
    required this.serial,
    required this.model,
    required this.status,
    required this.present,
    required this.width,
    required this.height,
    required this.rotation,
    required this.screenUrl,
    required this.controlUrl,
    required this.controlStreamUrl,
    required this.clipboardAvailable,
    required this.lastError,
  });

  bool get isReady => present && status == 'ready';

  factory StfLiteSessionInfo.fromJson(Map<String, dynamic> json) {
    return StfLiteSessionInfo(
      serial: json['serial'] as String? ?? '',
      model: json['model'] as String? ?? '',
      status: json['status'] as String? ?? 'unknown',
      present: json['present'] as bool? ?? false,
      width: json['width'] as int? ?? 0,
      height: json['height'] as int? ?? 0,
      rotation: json['rotation'] as int? ?? 0,
      screenUrl: json['screenUrl'] as String?,
      controlUrl: json['controlUrl'] as String?,
      controlStreamUrl: json['controlStreamUrl'] as String?,
      clipboardAvailable: json['clipboard'] as bool? ?? false,
      lastError: json['lastError'] as String?,
    );
  }
}

/// Owns the development STF Lite Node sidecar and exposes only its local
/// session protocol to Flutter.
class StfLiteRuntimeService extends ChangeNotifier {
  final String? sidecarPath;
  final String? resourceDirectory;
  final String? adbPath;
  final String? nodeExecutable;

  Process? _process;
  Uri? _baseUri;
  Completer<Uri>? _readyCompleter;
  final Map<String, WebSocket> _controlSockets = <String, WebSocket>{};
  final Map<String, Future<WebSocket?>> _controlSocketConnections =
      <String, Future<WebSocket?>>{};
  final Map<String, DateTime> _controlSocketRetryAfter = <String, DateTime>{};
  final Map<String, _PendingKeyRequest> _pendingKeyRequests =
      <String, _PendingKeyRequest>{};
  int _controlRequestSequence = 0;
  StfLiteRuntimeState _state = StfLiteRuntimeState.stopped;
  String? _errorMessage;
  StfLiteRuntimeErrorCode? _errorCode;
  bool _isDisposed = false;

  StfLiteRuntimeService({
    this.sidecarPath,
    this.resourceDirectory,
    this.adbPath,
    String? nodeExecutable,
  }) : nodeExecutable =
           nodeExecutable ?? Platform.environment['MOBILE_MATRIX_NODE'];

  StfLiteRuntimeState get state => _state;
  String? get errorMessage => _errorMessage;
  StfLiteRuntimeErrorCode? get errorCode => _errorCode;
  bool get isAvailable => _state == StfLiteRuntimeState.ready;

  Future<bool> start() async {
    if (_isDisposed) return false;
    if (_state == StfLiteRuntimeState.ready && _baseUri != null) return true;
    if (_readyCompleter != null) {
      try {
        await _readyCompleter!.future.timeout(const Duration(seconds: 8));
        return _baseUri != null;
      } catch (_) {
        return false;
      }
    }

    final resolvedSidecar = await _resolveSidecarPath();
    final resolvedResources = await _resolveResourceDirectory();
    if (resolvedSidecar == null || resolvedResources == null) {
      _setState(
        StfLiteRuntimeState.unavailable,
        null,
        errorCode: StfLiteRuntimeErrorCode.resourcesUnavailable,
      );
      return false;
    }

    _setState(StfLiteRuntimeState.starting, null);
    final ready = Completer<Uri>();
    _readyCompleter = ready;
    try {
      final resolvedNode = await _resolveNodeExecutable();
      final resolvedAdb = await _resolveAdbExecutable();
      final arguments = <String>[
        resolvedSidecar,
        '--host',
        '127.0.0.1',
        '--port',
        '0',
        '--resource-dir',
        resolvedResources,
        '--adb-path',
        resolvedAdb,
      ];

      final process = await Process.start(
        resolvedNode,
        arguments,
        workingDirectory: File(resolvedSidecar).parent.parent.path,
        environment: <String, String>{...Platform.environment, 'NO_COLOR': '1'},
      );
      if (_isDisposed) {
        process.kill();
        return false;
      }
      _process = process;
      _listenStdout(process.stdout, ready);
      _listenStderr(process.stderr);
      unawaited(_observeExit(process));

      final baseUri = await ready.future.timeout(const Duration(seconds: 8));
      if (_isDisposed) return false;
      _baseUri = baseUri;
      _setState(StfLiteRuntimeState.ready, null);
      return true;
    } catch (error) {
      if (!ready.isCompleted) ready.completeError(error);
      _errorMessage = _readableError(error);
      _setState(
        StfLiteRuntimeState.error,
        _errorMessage,
        errorCode: StfLiteRuntimeErrorCode.startupFailed,
      );
      await _terminateOwnedProcess();
      return false;
    } finally {
      if (identical(_readyCompleter, ready)) _readyCompleter = null;
    }
  }

  Future<List<StfLiteSessionInfo>> getSessions() async {
    final baseUri = _baseUri;
    if (baseUri == null) return const <StfLiteSessionInfo>[];
    final response = await _request('GET', baseUri.resolve('/v1/sessions'));
    final body = jsonDecode(response) as Map<String, dynamic>;
    final sessions = body['sessions'] as List<dynamic>? ?? const <dynamic>[];
    return sessions
        .whereType<Map<String, dynamic>>()
        .map(StfLiteSessionInfo.fromJson)
        .toList(growable: false);
  }

  Future<bool> sendControl(String serial, Map<String, dynamic> payload) async {
    final isKeyEvent = payload['type'] == 'key';
    final requestPayload = isKeyEvent
        ? <String, dynamic>{
            ...payload,
            'id': payload['id'] ?? _nextControlRequestId(serial),
          }
        : payload;
    final socket = await _ensureControlSocket(serial);
    if (socket != null) {
      try {
        if (isKeyEvent) {
          return await _sendKeyOverSocket(serial, socket, requestPayload);
        }
        socket.add(jsonEncode(requestPayload));
        return true;
      } catch (error) {
        _dropControlSocket(serial, socket, error: error);
        if (isKeyEvent && error is TimeoutException) return false;
      }
    }

    // Keep the HTTP endpoint as a compatibility fallback for startup races or
    // older sidecars. Touch events use the persistent socket whenever it is
    // available, so normal pointer movement never waits for a new HTTP request.
    final response = await _request(
      'POST',
      _sessionUri(serial, 'control'),
      payload: requestPayload,
    );
    return (jsonDecode(response) as Map<String, dynamic>)['success'] == true;
  }

  String _nextControlRequestId(String serial) {
    _controlRequestSequence += 1;
    final safeSerial = serial.replaceAll(RegExp(r'[^A-Za-z0-9_.:-]'), '_');
    return 'flutter-key-$safeSerial-$_controlRequestSequence';
  }

  String _pendingKeyRequestId(String serial, String id) => '$serial\u0000$id';

  Future<bool> _sendKeyOverSocket(
    String serial,
    WebSocket socket,
    Map<String, dynamic> payload,
  ) async {
    final id = payload['id']?.toString();
    if (id == null || id.isEmpty) return false;
    final pendingId = _pendingKeyRequestId(serial, id);
    final pending = _PendingKeyRequest();
    _pendingKeyRequests[pendingId] = pending;
    try {
      socket.add(jsonEncode(payload));
      return await pending.completer.future.timeout(
        const Duration(seconds: 4),
        onTimeout: () {
          throw TimeoutException('STF Lite key event response timed out');
        },
      );
    } finally {
      _pendingKeyRequests.remove(pendingId);
    }
  }

  Future<bool> ensureControlChannel(String serial) async {
    return await _ensureControlSocket(serial) != null;
  }

  Future<WebSocket?> _ensureControlSocket(String serial) {
    final current = _controlSockets[serial];
    if (current?.readyState == WebSocket.open) {
      return Future<WebSocket?>.value(current);
    }

    final retryAfter = _controlSocketRetryAfter[serial];
    if (retryAfter != null && DateTime.now().isBefore(retryAfter)) {
      return Future<WebSocket?>.value(null);
    }

    final connecting = _controlSocketConnections[serial];
    if (connecting != null) return connecting;

    final future = _connectControlSocket(serial);
    _controlSocketConnections[serial] = future;
    return future.whenComplete(() {
      if (identical(_controlSocketConnections[serial], future)) {
        _controlSocketConnections.remove(serial);
      }
    });
  }

  Future<WebSocket?> _connectControlSocket(String serial) async {
    try {
      final socket = await WebSocket.connect(
        _sessionWebSocketUri(serial, 'control-stream').toString(),
      ).timeout(const Duration(milliseconds: 1500));
      if (_isDisposed || _state != StfLiteRuntimeState.ready) {
        await socket.close();
        return null;
      }

      socket.pingInterval = const Duration(seconds: 10);
      socket.listen(
        (event) {
          if (kDebugMode && event is String) {
            debugPrint('[StfLiteControl:$serial] sidecar message=$event');
          }
          if (event is String) {
            _resolveKeyResponse(serial, event);
          }
        },
        onError: (Object error) {
          if (kDebugMode) {
            debugPrint('[StfLiteControl:$serial] socket error=$error');
          }
          _dropControlSocket(serial, socket, error: error);
        },
        onDone: () {
          _dropControlSocket(serial, socket);
        },
        cancelOnError: true,
      );
      _controlSockets[serial] = socket;
      _controlSocketRetryAfter.remove(serial);
      if (kDebugMode) {
        debugPrint('[StfLiteControl:$serial] persistent channel connected');
      }
      return socket;
    } catch (error) {
      _controlSocketRetryAfter[serial] = DateTime.now().add(
        const Duration(seconds: 2),
      );
      if (kDebugMode) {
        debugPrint(
          '[StfLiteControl:$serial] persistent channel unavailable: $error',
        );
      }
      return null;
    }
  }

  Uri _sessionWebSocketUri(String serial, String action) {
    final baseUri = _baseUri;
    if (baseUri == null) {
      throw StateError('STF Lite runtime is not ready');
    }
    return baseUri.replace(
      scheme: baseUri.scheme == 'https' ? 'wss' : 'ws',
      path: '/v1/sessions/${Uri.encodeComponent(serial)}/$action',
      query: '',
      fragment: '',
    );
  }

  void _dropControlSocket(String serial, WebSocket socket, {Object? error}) {
    if (!identical(_controlSockets[serial], socket)) return;
    _controlSockets.remove(serial);
    _failPendingKeyRequests(serial);
    _controlSocketRetryAfter[serial] = DateTime.now().add(
      const Duration(milliseconds: 250),
    );
    if (kDebugMode && error != null) {
      debugPrint('[StfLiteControl:$serial] persistent channel closed: $error');
    }
  }

  void _resolveKeyResponse(String serial, String event) {
    Map<String, dynamic> response;
    try {
      final decoded = jsonDecode(event);
      if (decoded is! Map<String, dynamic>) return;
      response = decoded;
    } catch (_) {
      return;
    }
    if (response['type'] != 'key') return;
    final id = response['id']?.toString();
    if (id == null || id.isEmpty) return;
    final pending = _pendingKeyRequests[_pendingKeyRequestId(serial, id)];
    if (pending == null || pending.completer.isCompleted) return;
    pending.completer.complete(response['success'] == true);
  }

  void _failPendingKeyRequests(String serial) {
    final prefix = '$serial\u0000';
    final ids = _pendingKeyRequests.keys
        .where((key) => key.startsWith(prefix))
        .toList(growable: false);
    for (final id in ids) {
      final pending = _pendingKeyRequests.remove(id);
      if (pending != null && !pending.completer.isCompleted) {
        pending.completer.complete(false);
      }
    }
  }

  void _failAllPendingKeyRequests() {
    for (final pending in _pendingKeyRequests.values) {
      if (!pending.completer.isCompleted) pending.completer.complete(false);
    }
    _pendingKeyRequests.clear();
  }

  Future<bool> setClipboard(String serial, String text) async {
    final response = await _request(
      'POST',
      _sessionUri(serial, 'clipboard'),
      payload: <String, dynamic>{'text': text},
    );
    return (jsonDecode(response) as Map<String, dynamic>)['success'] == true;
  }

  Future<void> stop() async {
    final controlSockets = _controlSockets.values.toList(growable: false);
    _controlSockets.clear();
    _controlSocketConnections.clear();
    _controlSocketRetryAfter.clear();
    for (final pending in _pendingKeyRequests.values) {
      if (!pending.completer.isCompleted) pending.completer.complete(false);
    }
    _pendingKeyRequests.clear();
    for (final socket in controlSockets) {
      await socket.close();
    }
    final process = _process;
    final baseUri = _baseUri;
    _process = null;
    _baseUri = null;
    if (process == null) {
      _setState(StfLiteRuntimeState.stopped, null);
      return;
    }

    try {
      if (baseUri != null) {
        await _request('POST', baseUri.resolve('/v1/runtime/stop'));
      }
    } catch (_) {}
    process.kill(ProcessSignal.sigterm);
    _setState(StfLiteRuntimeState.stopped, null);
  }

  Uri _sessionUri(String serial, String action) {
    final baseUri = _baseUri;
    if (baseUri == null) {
      throw StateError('STF Lite runtime is not ready');
    }
    return baseUri.resolve(
      '/v1/sessions/${Uri.encodeComponent(serial)}/$action',
    );
  }

  Future<String> _request(
    String method,
    Uri uri, {
    Map<String, dynamic>? payload,
  }) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
    try {
      final request = await client.openUrl(method, uri);
      request.headers.contentType = ContentType.json;
      if (payload != null) request.write(jsonEncode(payload));
      final response = await request.close().timeout(
        const Duration(seconds: 5),
      );
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'STF Lite request failed with HTTP ${response.statusCode}: $body',
          uri: uri,
        );
      }
      return body;
    } finally {
      client.close(force: true);
    }
  }

  void _listenStdout(Stream<List<int>> output, Completer<Uri> ready) {
    output
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) {
            if (!line.startsWith('STF_LITE_READY ')) return;
            final port = int.tryParse(line.substring('STF_LITE_READY '.length));
            if (port == null || port <= 0 || ready.isCompleted) return;
            ready.complete(Uri.parse('http://127.0.0.1:$port'));
          },
          onError: (Object error, StackTrace stack) {
            if (!ready.isCompleted) ready.completeError(error, stack);
          },
        );
  }

  void _listenStderr(Stream<List<int>> output) {
    output
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) {
            if (kDebugMode) debugPrint('[StfLite] $line');
          },
          onError: (Object error, StackTrace stack) {
            if (kDebugMode) {
              debugPrint('[StfLite] sidecar stderr failed: $error');
            }
          },
        );
  }

  Future<void> _observeExit(Process process) async {
    final exitCode = await process.exitCode;
    if (_isDisposed || !identical(_process, process)) return;
    _process = null;
    _baseUri = null;
    _failAllPendingKeyRequests();
    _setState(
      StfLiteRuntimeState.error,
      'sidecar exited with code $exitCode',
      errorCode: StfLiteRuntimeErrorCode.sidecarExited,
    );
  }

  Future<void> _terminateOwnedProcess() async {
    final process = _process;
    _process = null;
    _baseUri = null;
    _failAllPendingKeyRequests();
    if (process == null) return;
    process.kill(ProcessSignal.sigterm);
    try {
      await process.exitCode.timeout(const Duration(seconds: 2));
    } catch (_) {
      process.kill(ProcessSignal.sigkill);
    }
  }

  Future<String?> _resolveSidecarPath() async {
    final configured =
        sidecarPath ?? Platform.environment['MOBILE_MATRIX_STF_LITE_SIDECAR'];
    final developmentRoot = _findDevelopmentProjectRoot();
    final candidates = <String>[
      if (configured != null && configured.trim().isNotEmpty) configured,
      _bundlePath('stf-lite/src/main.js'),
      '${Directory.current.path}/tools/stf_lite/src/main.js',
      if (developmentRoot != null)
        '${developmentRoot.path}/tools/stf_lite/src/main.js',
    ];
    for (final candidate in candidates) {
      final absolute = File(candidate).absolute.path;
      if (await File(absolute).exists()) return absolute;
    }
    return null;
  }

  Future<String> _resolveNodeExecutable() async {
    final configured = nodeExecutable;
    if (configured != null && configured.trim().isNotEmpty) {
      return configured;
    }
    final bundled = _bundlePath('stf-lite/bin/node');
    if (await File(bundled).exists()) return bundled;
    for (final candidate in const [
      '/opt/homebrew/bin/node',
      '/usr/local/bin/node',
    ]) {
      if (await File(candidate).exists()) return candidate;
    }
    return 'node';
  }

  Future<String> _resolveAdbExecutable() async {
    final configured = adbPath ?? Platform.environment['MOBILE_MATRIX_ADB'];
    if (configured != null && configured.trim().isNotEmpty) {
      return configured;
    }
    final bundled = _bundlePath('stf-lite/bin/adb');
    if (await File(bundled).exists()) return bundled;
    return AdbService.resolveAdbPath();
  }

  Future<String?> _resolveResourceDirectory() async {
    final configured =
        resourceDirectory ??
        Platform.environment['MOBILE_MATRIX_STF_LITE_RESOURCES'];
    if (configured != null && configured.trim().isNotEmpty) {
      final absolute = Directory(configured).absolute.path;
      return await Directory(absolute).exists() ? absolute : null;
    }
    final bundled = _bundlePath('stf-lite/resources');
    if (await Directory(bundled).exists()) return bundled;
    // Development-only fallback to the documented sibling reference checkout.
    // Finder-launched debug apps do not inherit the project as cwd, so locate
    // the checkout from the executable's ancestor directories as well.
    final developmentRoot = _findDevelopmentProjectRoot();
    final referenceCandidates = <Directory>[
      Directory(
        '${Directory.current.path}${Platform.pathSeparator}..${Platform.pathSeparator}mobile-matrix${Platform.pathSeparator}vendor${Platform.pathSeparator}devicefarmer-stf',
      ),
      if (developmentRoot != null)
        Directory(
          '${developmentRoot.parent.path}${Platform.pathSeparator}mobile-matrix${Platform.pathSeparator}vendor${Platform.pathSeparator}devicefarmer-stf',
        ),
    ];
    for (final reference in referenceCandidates) {
      if (await reference.exists()) return reference.absolute.path;
    }
    return null;
  }

  Directory? _findDevelopmentProjectRoot() {
    final starts = <Directory>[
      Directory.current,
      File(Platform.resolvedExecutable).parent,
    ];
    for (final start in starts) {
      var current = start.absolute;
      while (true) {
        final marker = Directory(
          '${current.path}${Platform.pathSeparator}tools${Platform.pathSeparator}stf_lite',
        );
        if (marker.existsSync()) return current;
        final parent = current.parent;
        if (parent.path == current.path) break;
        current = parent;
      }
    }
    return null;
  }

  String _bundlePath(String relativePath) {
    final executable = File(Platform.resolvedExecutable);
    final macResources = Directory(
      '${executable.parent.parent.path}${Platform.pathSeparator}Resources',
    );
    return '${macResources.path}${Platform.pathSeparator}$relativePath';
  }

  String _readableError(Object error) {
    if (error is ProcessException) return error.message;
    return error.toString().replaceFirst('Exception: ', '');
  }

  void _setState(
    StfLiteRuntimeState state,
    String? error, {
    StfLiteRuntimeErrorCode? errorCode,
  }) {
    _state = state;
    _errorMessage = error;
    _errorCode = errorCode;
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    unawaited(stop());
    super.dispose();
  }
}
