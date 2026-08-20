import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:socket_io_client/socket_io_client.dart' as io;

/// Sends touch events through the same Socket.IO -> STF -> minitouch path used
/// by the Web console.
class StfTouchService {
  final String serial;
  final Uri stfBaseUri;

  io.Socket? _socket;
  String? _channel;
  Future<void>? _connectFuture;
  final List<_PendingTouchEvent> _pendingEvents = <_PendingTouchEvent>[];
  // STF's touch SeqQueue has a fixed size of 100 and drops larger sequence
  // numbers. Keep the same 0..99 cycle as the Web console.
  int _sequence = -1;
  bool _isDisposed = false;

  StfTouchService({required this.serial, Uri? stfBaseUri})
    : stfBaseUri = stfBaseUri ?? Uri.parse('http://127.0.0.1:7100') {
    unawaited(_ensureConnected());
  }

  void touchDown({
    required int contact,
    required double xP,
    required double yP,
    double pressure = 0.5,
  }) {
    if (!(_socket?.connected ?? false)) {
      _pendingEvents.clear();
    }
    _enqueue('input.gestureStart');
    _enqueue('input.touchDown', <String, Object>{
      'contact': contact,
      'x': xP.clamp(0.0, 1.0),
      'y': yP.clamp(0.0, 1.0),
      'pressure': pressure.clamp(0.0, 1.0),
    });
  }

  void touchMove({
    required int contact,
    required double xP,
    required double yP,
    double pressure = 0.5,
  }) {
    _enqueue('input.touchMove', <String, Object>{
      'contact': contact,
      'x': xP.clamp(0.0, 1.0),
      'y': yP.clamp(0.0, 1.0),
      'pressure': pressure.clamp(0.0, 1.0),
    });
  }

  Future<void> touchUp({required int contact}) async {
    _enqueue('input.touchUp', <String, Object>{'contact': contact});
    _enqueue('input.touchCommit');
    _enqueue('input.gestureStop');
    await _ensureConnected();
  }

  void touchCommit() {
    _enqueue('input.touchCommit');
  }

  void _enqueue(String name, [Map<String, Object>? values]) {
    if (_isDisposed) return;

    _sequence = (_sequence + 1) % 100;
    final data = <String, Object>{'seq': _sequence, ...?values};
    final event = _PendingTouchEvent(name, data);
    final socket = _socket;
    final channel = _channel;
    if (socket != null && socket.connected && channel != null) {
      socket.emit(name, <Object>[channel, data]);
      return;
    }

    _pendingEvents.add(event);
    unawaited(_ensureConnected());
  }

  Future<void> _ensureConnected() {
    if (_isDisposed || (_socket?.connected ?? false)) {
      return Future<void>.value();
    }
    return _connectFuture ??= _connect().whenComplete(() {
      _connectFuture = null;
    });
  }

  Future<void> _connect() async {
    try {
      final endpoint = await _resolveEndpoint();
      if (_isDisposed) return;

      _channel = endpoint.channel;
      final previousSocket = _socket;
      if (previousSocket != null) {
        previousSocket.dispose();
      }

      final connected = Completer<void>();
      final socket = io.io(
        endpoint.websocketUrl,
        io.OptionBuilder()
            .setTransports(<String>['websocket'])
            .setExtraHeaders(<String, String>{
              HttpHeaders.cookieHeader: endpoint.cookieHeader,
            })
            .enableForceNewConnection()
            .enableReconnection()
            .setReconnectionDelay(300)
            .setReconnectionDelayMax(1200)
            .setTimeout(2500)
            .disableAutoConnect()
            .build(),
      );
      _socket = socket;

      socket.onConnect((_) {
        if (!connected.isCompleted) connected.complete();
        _flushPendingEvents();
        _debugLog('[StfTouch:$serial] Connected');
      });
      socket.onConnectError((error) {
        if (!connected.isCompleted) {
          connected.completeError(
            StateError('STF touch connection failed: $error'),
          );
        }
      });
      socket.onDisconnect((_) {
        if (!_isDisposed) _debugLog('[StfTouch:$serial] Disconnected');
      });
      socket.connect();

      await connected.future.timeout(const Duration(seconds: 3));
    } catch (error) {
      if (!_isDisposed) _debugLog('[StfTouch:$serial] Setup failed: $error');
    }
  }

  void _flushPendingEvents() {
    final socket = _socket;
    final channel = _channel;
    if (_isDisposed ||
        socket == null ||
        !socket.connected ||
        channel == null ||
        _pendingEvents.isEmpty) {
      return;
    }

    final events = List<_PendingTouchEvent>.of(_pendingEvents);
    _pendingEvents.clear();
    for (final event in events) {
      socket.emit(event.name, <Object>[channel, event.data]);
    }
  }

  Future<_StfEndpoint> _resolveEndpoint() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
    final cookies = <String, Cookie>{};

    try {
      await _getText(client, stfBaseUri, cookies);

      final stateScript = await _getText(
        client,
        stfBaseUri.resolve('/app/api/v1/state.js'),
        cookies,
      );
      final stateStart = stateScript.indexOf('{');
      final stateEnd = stateScript.lastIndexOf('}');
      if (stateStart == -1 || stateEnd <= stateStart) {
        throw const FormatException('Invalid STF state response');
      }
      final state =
          jsonDecode(stateScript.substring(stateStart, stateEnd + 1))
              as Map<String, dynamic>;
      final config = state['config'] as Map<String, dynamic>?;
      final websocketUrl = config?['websocketUrl'] as String?;
      if (websocketUrl == null || websocketUrl.isEmpty) {
        throw const FormatException('STF websocket URL is missing');
      }

      final devicesBody = await _getText(
        client,
        stfBaseUri.resolve('/api/v1/devices'),
        cookies,
      );
      final devicesResponse = jsonDecode(devicesBody) as Map<String, dynamic>;
      final devices = devicesResponse['devices'] as List<dynamic>?;
      final device = devices?.cast<Map<String, dynamic>>().firstWhere(
        (item) => item['serial'] == serial && item['present'] == true,
        orElse: () => <String, dynamic>{},
      );
      final channel = device?['channel'] as String?;
      if (channel == null || channel.isEmpty) {
        throw StateError('STF channel is missing for $serial');
      }

      return _StfEndpoint(
        websocketUrl: websocketUrl,
        channel: channel,
        cookieHeader: cookies.values
            .map((cookie) => '${cookie.name}=${cookie.value}')
            .join('; '),
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<String> _getText(
    HttpClient client,
    Uri uri,
    Map<String, Cookie> cookies,
  ) async {
    final request = await client.getUrl(uri);
    request.cookies.addAll(cookies.values);
    final response = await request.close().timeout(const Duration(seconds: 3));
    for (final cookie in response.cookies) {
      cookies[cookie.name] = cookie;
    }
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'STF request failed with HTTP ${response.statusCode}',
        uri: uri,
      );
    }
    return body;
  }

  void dispose() {
    _isDisposed = true;
    _pendingEvents.clear();
    _socket?.dispose();
    _socket = null;
  }
}

void _debugLog(String message) {
  if (!const bool.fromEnvironment('dart.vm.product')) {
    stderr.writeln(message);
  }
}

class _PendingTouchEvent {
  final String name;
  final Map<String, Object> data;

  const _PendingTouchEvent(this.name, this.data);
}

class _StfEndpoint {
  final String websocketUrl;
  final String channel;
  final String cookieHeader;

  const _StfEndpoint({
    required this.websocketUrl,
    required this.channel,
    required this.cookieHeader,
  });
}
