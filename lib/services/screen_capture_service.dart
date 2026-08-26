import 'package:flutter/foundation.dart';
import 'package:super_clipboard/super_clipboard.dart';

import 'adb_service.dart';

class ScreenCaptureService {
  final String serial;

  ScreenCaptureService({required this.serial});

  Future<void> copyScreenshotToClipboard() async {
    debugPrint('[SCREEN-CAPTURE] start serial=$serial');
    final bytes = await AdbService.captureScreen(serial);
    debugPrint(
      '[SCREEN-CAPTURE] adb result serial=$serial '
      'bytes=${bytes?.length ?? 0}',
    );
    if (bytes == null || bytes.isEmpty) {
      throw StateError('截取屏幕失败，请检查设备连接');
    }

    final clipboard = SystemClipboard.instance;
    debugPrint(
      '[SCREEN-CAPTURE] system clipboard '
      'available=${clipboard != null}',
    );
    if (clipboard == null) {
      throw StateError('当前系统不支持图片剪贴板');
    }

    final item = DataWriterItem(suggestedName: 'MobileMatrixScreenshot.png');
    item.add(Formats.png(bytes));
    debugPrint('[SCREEN-CAPTURE] writing png to system clipboard');
    await clipboard.write([item]);
    debugPrint('[SCREEN-CAPTURE] clipboard write completed serial=$serial');
  }
}
