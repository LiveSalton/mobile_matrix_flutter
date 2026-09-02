import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_matrix/services/screen_stream_service.dart';

void main() {
  const viewport = ScreenViewport(
    logicalWidth: 280,
    logicalHeight: 520,
    devicePixelRatio: 2,
    rotation: 0,
  );

  test('preview projection caps the longest edge without changing ratio', () {
    final projection = calculateStfScreenProjection(
      viewport: viewport,
      realWidth: 1080,
      realHeight: 2400,
      maxLongestEdge: 720,
    );

    expect(projection.height, lessThanOrEqualTo(720));
    expect(projection.width / projection.height, closeTo(280 / 520, 0.01));
  });

  test('full projection keeps the uncapped profile', () {
    final projection = calculateStfScreenProjection(
      viewport: viewport,
      realWidth: 1080,
      realHeight: 2400,
    );

    expect(projection.height, greaterThan(720));
  });
}
