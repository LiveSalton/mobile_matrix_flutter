import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../models/device_model.dart';
import '../../../services/stf_web_session_service.dart';
import '../../../theme/app_theme.dart';

class StfWebViewStage extends StatefulWidget {
  final DeviceModel device;
  final VoidCallback? onFallback;

  const StfWebViewStage({super.key, required this.device, this.onFallback});

  @override
  State<StfWebViewStage> createState() => _StfWebViewStageState();
}

class _StfWebViewStageState extends State<StfWebViewStage> {
  late final WebViewController _controller;
  StfWebSessionService? _session;
  String? _loadedSerial;
  int _loadGeneration = 0;

  StfWebSessionService get _webSession => _session ??= StfWebSessionService();

  @override
  void initState() {
    super.initState();
    _webSession;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: _handlePageStarted,
          onPageFinished: _handlePageFinished,
          onHttpError: _handleHttpError,
          onWebResourceError: _handleWebResourceError,
          onNavigationRequest: _handleNavigationRequest,
        ),
      )
      ..addJavaScriptChannel(
        'FlutterStfBridge',
        onMessageReceived: _handleJavaScriptMessage,
      );
    unawaited(_loadDevice(widget.device.serial));
  }

  @override
  void didUpdateWidget(covariant StfWebViewStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.device.serial != widget.device.serial) {
      unawaited(_loadDevice(widget.device.serial));
    }
  }

  @override
  void dispose() {
    _loadGeneration++;
    _session?.cancelPendingChecks();
    _session?.dispose();
    super.dispose();
  }

  Future<void> _loadDevice(String serial) async {
    final generation = ++_loadGeneration;
    _loadedSerial = null;
    final available = await _webSession.checkHealth();
    if (!mounted || generation != _loadGeneration || !available) return;

    final uri = _webSession.deviceUri(serial);
    _webSession.markLoading();
    _loadedSerial = serial;
    if (kDebugMode) {
      debugPrint('[StfWebView:$serial] Loading $uri');
    }
    await _controller.loadRequest(uri);
  }

  void _handlePageStarted(String url) {
    _webSession.markLoading();
    if (kDebugMode) {
      debugPrint('[StfWebView:${widget.device.serial}] Page started $url');
    }
  }

  Future<void> _handlePageFinished(String url) async {
    if (!mounted || _loadedSerial != widget.device.serial) return;
    _webSession.markLoaded();
    await _installErrorBridge();
    if (kDebugMode) {
      debugPrint('[StfWebView:${widget.device.serial}] Page loaded $url');
    }
  }

  void _handleHttpError(HttpResponseError error) {
    _webSession.markError(
      'STF Web HTTP 错误 ${error.response?.statusCode ?? ''}: $error',
    );
  }

  void _handleWebResourceError(WebResourceError error) {
    if (error.isForMainFrame != true) return;
    _webSession.markError(
      'STF Web 加载失败 ${error.errorCode}: ${error.description}',
    );
  }

  NavigationDecision _handleNavigationRequest(NavigationRequest request) {
    final uri = Uri.tryParse(request.url);
    if (uri != null && _webSession.isAllowedNavigation(uri)) {
      return NavigationDecision.navigate;
    }
    _webSession.markError('已阻止 WebView 外部导航：${request.url}');
    return NavigationDecision.prevent;
  }

  void _handleJavaScriptMessage(JavaScriptMessage message) {
    _webSession.markError('STF Web JavaScript 错误：${message.message}');
  }

  Future<void> _installErrorBridge() async {
    const script = '''
(function() {
  if (window.__flutterStfBridgeInstalled) return;
  window.__flutterStfBridgeInstalled = true;
  window.addEventListener('error', function(event) {
    FlutterStfBridge.postMessage(event.message || 'window error');
  });
  window.addEventListener('unhandledrejection', function(event) {
    FlutterStfBridge.postMessage(String(event.reason || 'unhandled rejection'));
  });
})();
''';
    try {
      await _controller.runJavaScript(script);
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[StfWebView:${widget.device.serial}] Bridge failed: $error',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return AnimatedBuilder(
      animation: _webSession,
      builder: (context, _) {
        final isError = _webSession.state == StfWebSessionState.error;
        return Container(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              WebViewWidget(controller: _controller),
              if (isError) _buildErrorOverlay(context, tokens),
              if (!isError && _webSession.state != StfWebSessionState.loaded)
                _buildLoadingOverlay(context, tokens),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadingOverlay(BuildContext context, AppColorTokens tokens) {
    return ColoredBox(
      color: const Color(0xE60B1220),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: tokens.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '正在加载 STF Web 手机控制…',
              style: TextStyle(color: tokens.textPrimary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorOverlay(BuildContext context, AppColorTokens tokens) {
    return ColoredBox(
      color: const Color(0xF20B1220),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.web_asset_off_rounded, color: tokens.danger, size: 36),
              const SizedBox(height: 12),
              Text(
                _webSession.errorMessage ?? 'STF Web 页面不可用',
                textAlign: TextAlign.center,
                style: TextStyle(color: tokens.textPrimary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                children: [
                  ElevatedButton.icon(
                    onPressed: () =>
                        unawaited(_loadDevice(widget.device.serial)),
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('重试 Web 控制'),
                  ),
                  if (widget.onFallback != null)
                    OutlinedButton.icon(
                      onPressed: widget.onFallback,
                      icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                      label: const Text('使用原生控制'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
