import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class ScreenFpsStats {
  final int received;
  final int rendered;
  final int dropped;
  final double lastDecodeMs;

  const ScreenFpsStats({
    this.received = 0,
    this.rendered = 0,
    this.dropped = 0,
    this.lastDecodeMs = 0,
  });

  static const empty = ScreenFpsStats();
}

class FastScreenRenderer extends StatefulWidget {
  final Stream<Uint8List> frameStream;
  final int rotation;
  final Widget? placeholder;
  final ValueChanged<ScreenFpsStats>? onFpsChanged;

  const FastScreenRenderer({
    super.key,
    required this.frameStream,
    this.rotation = 0,
    this.placeholder,
    this.onFpsChanged,
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
      widget.onFpsChanged?.call(
        ScreenFpsStats(
          received: _receivedFps,
          rendered: _renderedFps,
          dropped: _droppedFrames,
          lastDecodeMs: _lastDecodeMs,
        ),
      );

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

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 核心 Canvas 硬件直画或 Placeholder
        Positioned.fill(
          child: _activeImage != null
              ? RepaintBoundary(
                  child: CustomPaint(
                    painter: _ImageDirectPainter(
                      image: _activeImage!,
                      rotation: widget.rotation,
                    ),
                  ),
                )
              : (widget.placeholder ?? const SizedBox.shrink()),
        ),
      ],
    );
  }
}

class _ImageDirectPainter extends CustomPainter {
  final ui.Image image;
  final int? rotation;
  static final Paint _paint = Paint()
    ..isAntiAlias = false
    ..filterQuality = FilterQuality.low;

  _ImageDirectPainter({required this.image, required this.rotation});

  @override
  void paint(Canvas canvas, Size size) {
    final src = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    if (size.isEmpty || image.width == 0 || image.height == 0) return;

    final normalizedRotation = (((rotation ?? 0) % 360) + 360) % 360;
    final shouldRotateSource =
        (normalizedRotation == 90 || normalizedRotation == 270) !=
        (image.width >= image.height);
    final sourceAspect = shouldRotateSource
        ? image.height / image.width
        : image.width / image.height;
    final destinationAspect = size.width / size.height;
    final destination = destinationAspect > sourceAspect
        ? Rect.fromLTWH(
            (size.width - size.height * sourceAspect) / 2,
            0,
            size.height * sourceAspect,
            size.height,
          )
        : Rect.fromLTWH(
            0,
            (size.height - size.width / sourceAspect) / 2,
            size.width,
            size.width / sourceAspect,
          );

    if (!shouldRotateSource) {
      canvas.drawImageRect(image, src, destination, _paint);
      return;
    }

    canvas.save();
    canvas.translate(destination.center.dx, destination.center.dy);
    canvas.rotate(normalizedRotation == 270 ? -math.pi / 2 : math.pi / 2);
    final rotatedDestination = Rect.fromCenter(
      center: Offset.zero,
      width: destination.height,
      height: destination.width,
    );
    canvas.drawImageRect(image, src, rotatedDestination, _paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ImageDirectPainter oldDelegate) {
    return oldDelegate.image != image || oldDelegate.rotation != rotation;
  }
}
