import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_matrix/models/screen_fps_stats.dart';

void main() {
  test('starts with a stable empty FPS value', () {
    expect(ScreenFpsStats.empty.received, 0);
    expect(ScreenFpsStats.empty.rendered, 0);
    expect(ScreenFpsStats.empty.dropped, 0);
  });
}
