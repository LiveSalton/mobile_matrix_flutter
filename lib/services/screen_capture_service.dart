import 'package:super_clipboard/super_clipboard.dart';

import 'adb_service.dart';

class ScreenCaptureService {
  final String serial;

  ScreenCaptureService({required this.serial});

  Future<void> copyScreenshotToClipboard() async {
    final bytes = await AdbService.captureScreen(serial);
    if (bytes == null || bytes.isEmpty) {
      throw StateError('截取屏幕失败，请检查设备连接');
    }

    final clipboard = SystemClipboard.instance;
    if (clipboard == null) {
      throw StateError('当前系统不支持图片剪贴板');
    }

    final item = DataWriterItem(suggestedName: 'MobileMatrixScreenshot.png');
    item.add(Formats.png(bytes));
    await clipboard.write([item]);
  }
}
