import 'dart:io';

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

    if (Platform.isMacOS) {
      await _copyPngToMacOsPasteboard(bytes);
      return;
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

  Future<void> _copyPngToMacOsPasteboard(Uint8List bytes) async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'mobile_matrix_screenshot_',
    );
    final imageFile = File('${tempDirectory.path}/capture.png');

    try {
      await imageFile.writeAsBytes(bytes, flush: true);
      final path = _escapeAppleScriptString(imageFile.path);
      final result = await Process.run('/usr/bin/osascript', [
        '-e',
        'set the clipboard to (read POSIX file "$path" as «class PNGf»)',
      ]).timeout(const Duration(seconds: 5));

      if (result.exitCode != 0) {
        throw StateError('macOS 图片剪贴板写入失败: ${result.stderr}'.trim());
      }

      final verification = await Process.run('/usr/bin/osascript', [
        '-e',
        'clipboard info',
      ]).timeout(const Duration(seconds: 5));
      final clipboardInfo = verification.stdout.toString();
      final containsPng =
          verification.exitCode == 0 && clipboardInfo.contains('PNGf');
      debugPrint(
        '[SCREEN-CAPTURE] macOS pasteboard verified '
        'serial=$serial containsPng=$containsPng',
      );
      if (!containsPng) {
        throw StateError('截图已生成，但未检测到系统图片剪贴板内容');
      }

      debugPrint(
        '[SCREEN-CAPTURE] macOS pasteboard write completed '
        'serial=$serial bytes=${bytes.length}',
      );
    } finally {
      await tempDirectory.delete(recursive: true);
      debugPrint('[SCREEN-CAPTURE] temporary png removed');
    }
  }

  String _escapeAppleScriptString(String value) {
    return value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
  }
}
