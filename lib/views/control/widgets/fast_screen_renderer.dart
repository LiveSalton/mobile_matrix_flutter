import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class FastScreenRenderer extends StatefulWidget {
  final Stream<Uint8List> frameStream;
  final Widget? placeholder;
  final bool showFps;

  const FastScreenRenderer({
    super.key,
    required this.frameStream,
    this.placeholder,
    this.showFps = true,
  });

  @override
  State<FastScreenRenderer> createState() => _FastScreenRendererState();
}

class _FastScreenRendererState extends State<FastScreenRenderer> {
  ui.Image? _activeImage;
  StreamSubscription<Uint8List>? _subscription;
  bool _isDecoding = false;
  Uint8List? _latestPendingBytes;
  int _streamGeneration = 0;

  final List<DateTime> _receivedFrameTimestamps = [];
  final List<DateTime> _renderedFrameTimestamps = [];
  int _receivedFps = 0;
  int _renderedFps = 0;
  int _droppedFrames = 0;
  double _lastDecodeMs = 0;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant FastScreenRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.frameStream != widget.frameStream) {
      _subscription?.cancel();
      _streamGeneration++;
      _latestPendingBytes = null;
      final old = _activeImage;
      _activeImage = null;
      _receivedFrameTimestamps.clear();
      _renderedFrameTimestamps.clear();
      _receivedFps = 0;
      _renderedFps = 0;
      _droppedFrames = 0;
      _lastDecodeMs = 0;
      old?.dispose();
      _subscribe();
    }
  }

  @override
  void dispose() {
    _streamGeneration++;
    _latestPendingBytes = null;
    _subscription?.cancel();
    _activeImage?.dispose();
    _activeImage = null;
    super.dispose();
  }

  void _subscribe() {
    final generation = _streamGeneration;
    _subscription = widget.frameStream.listen((bytes) {
      if (!mounted || generation != _streamGeneration) return;
      final now = DateTime.now();
      _recordReceivedFrame(now);
      if (_latestPendingBytes != null) {
        _droppedFrames++;
      }
      _latestPendingBytes = bytes;
      if (!_isDecoding) {
        unawaited(_decodeNextFrameIfNeeded());
      }
    });
  }

  void _recordReceivedFrame(DateTime now) {
    _receivedFrameTimestamps.add(now);
    _pruneFrameWindow(_receivedFrameTimestamps, now);
    _receivedFps = _receivedFrameTimestamps.length;
  }

  void _recordRenderedFrame(DateTime now) {
    _renderedFrameTimestamps.add(now);
    _pruneFrameWindow(_renderedFrameTimestamps, now);
    _renderedFps = _renderedFrameTimestamps.length;
  }

  void _pruneFrameWindow(List<DateTime> timestamps, DateTime now) {
    timestamps.removeWhere(
      (timestamp) => now.difference(timestamp).inMilliseconds > 1000,
    );
  }

  Future<void> _decodeNextFrameIfNeeded() async {
    if (_latestPendingBytes == null || !mounted) return;

    _isDecoding = true;
    final generation = _streamGeneration;
    final bytesToDecode = _latestPendingBytes!;
    _latestPendingBytes = null;
    final startTime = DateTime.now();
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;

    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(bytesToDecode);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      codec = await descriptor.instantiateCodec();
      final frameInfo = await codec.getNextFrame();
      final newImage = frameInfo.image;

      if (!mounted || generation != _streamGeneration) {
        newImage.dispose();
        return;
      }

      final renderTime = DateTime.now();
      final frameCost =
          renderTime.difference(startTime).inMicroseconds / 1000.0;
      _recordRenderedFrame(renderTime);
      _lastDecodeMs = frameCost;

      final oldImage = _activeImage;
      setState(() {
        _activeImage = newImage;
      });
      oldImage?.dispose();
    } catch (_) {
      // 忽略异常损坏帧
    } finally {
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
      _isDecoding = false;
      if (_latestPendingBytes != null && mounted) {
        unawaited(_decodeNextFrameIfNeeded());
      }
    }
  }

  Color _getFpsColor(int fps) {
    if (fps >= 45) {
      return const Color(0xFF00D591); // 绿色
    } else if (fps >= 25) {
      return const Color(0xFFFF9124); // 黄色
    } else {
      return const Color(0xFFEF4444); // 红色
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 核心 Canvas 硬件直画或 Placeholder
        Positioned.fill(
          child: _activeImage != null
              ? RepaintBoundary(
                  child: CustomPaint(
                    painter: _ImageDirectPainter(image: _activeImage!),
                  ),
                )
              : (widget.placeholder ?? const SizedBox.shrink()),
        ),

        // 屏幕左上角实时 FPS 检测 HUD (始终显示)
        if (widget.showFps)
          Positioned(
            top: 10,
            left: 10,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xCC000000),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _getFpsColor(_renderedFps).withValues(alpha: 0.8),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _getFpsColor(_renderedFps).withValues(alpha: 0.35),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _getFpsColor(_renderedFps),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'IN $_receivedFps · OUT $_renderedFps · DROP $_droppedFrames',
                      style: TextStyle(
                        color: _getFpsColor(_renderedFps),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                    if (_lastDecodeMs > 0) ...[
                      const SizedBox(width: 6),
                      Text(
                        '· ${_lastDecodeMs.toStringAsFixed(1)}ms',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 10,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ImageDirectPainter extends CustomPainter {
  final ui.Image image;
  static final Paint _paint = Paint()
    ..isAntiAlias = false
    ..filterQuality = FilterQuality.low;

  _ImageDirectPainter({required this.image});

  @override
  void paint(Canvas canvas, Size size) {
    final src = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final dst = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawImageRect(image, src, dst, _paint);
  }

  @override
  bool shouldRepaint(covariant _ImageDirectPainter oldDelegate) {
    return oldDelegate.image != image;
  }
}
