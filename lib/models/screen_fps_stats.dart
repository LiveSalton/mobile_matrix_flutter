/// Rendering metrics for one device screen stream.
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
