import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

enum StfWebSessionState { idle, checking, ready, loading, loaded, error }

/// Owns the local STF Web session used by the embedded WebView.
class StfWebSessionService extends ChangeNotifier {
  final Uri baseUri;

  StfWebSessionState _state = StfWebSessionState.idle;
  String? _errorMessage;
  int _requestGeneration = 0;

  StfWebSessionService({Uri? baseUri})
    : baseUri = baseUri ?? Uri.parse('http://127.0.0.1:7100');

  StfWebSessionState get state => _state;
  String? get errorMessage => _errorMessage;
  bool get isReady =>
      _state == StfWebSessionState.ready ||
      _state == StfWebSessionState.loading ||
      _state == StfWebSessionState.loaded;

  Uri deviceUri(String serial) {
    return baseUri.replace(
      path: '/',
      query: null,
      fragment: '!/c/${Uri.encodeComponent(serial)}?standalone',
    );
  }

  bool isAllowedNavigation(Uri uri) {
    if (uri.scheme == 'about') return true;
    return uri.scheme == baseUri.scheme &&
        uri.host == baseUri.host &&
        uri.port == baseUri.port;
  }

  Future<bool> checkHealth() async {
    final generation = ++_requestGeneration;
    _setState(StfWebSessionState.checking);

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 2)
      ..idleTimeout = const Duration(seconds: 2);
    try {
      final request = await client
          .getUrl(baseUri.resolve('/app/api/v1/state.js'))
          .timeout(const Duration(seconds: 3));
      final response = await request.close().timeout(
        const Duration(seconds: 3),
      );
      await response.drain<void>();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'STF returned HTTP ${response.statusCode}',
          uri: baseUri,
        );
      }

      if (generation == _requestGeneration) {
        _setState(StfWebSessionState.ready);
      }
      return true;
    } catch (error) {
      if (generation == _requestGeneration) {
        _setError('STF Web 服务不可用：$error');
      }
      return false;
    } finally {
      client.close(force: true);
    }
  }

  void markLoading() {
    _setState(StfWebSessionState.loading);
  }

  void markLoaded() {
    _setState(StfWebSessionState.loaded);
  }

  void markError(String message) {
    _setError(message);
  }

  void cancelPendingChecks() {
    _requestGeneration++;
  }

  void _setState(StfWebSessionState state) {
    _state = state;
    _errorMessage = null;
    notifyListeners();
  }

  void _setError(String message) {
    _state = StfWebSessionState.error;
    _errorMessage = message;
    if (kDebugMode) {
      debugPrint('[StfWebView] $message');
    }
    notifyListeners();
  }
}
