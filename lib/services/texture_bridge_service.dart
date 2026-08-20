import 'dart:async';
import 'package:flutter/services.dart';

class TextureBridgeService {
  static const MethodChannel _channel = MethodChannel('com.matrix.video_texture');

  static Future<int?> createTexture({required int width, required int height}) async {
    try {
      final res = await _channel.invokeMethod<int>('createTexture', {
        'width': width,
        'height': height,
      });
      return res;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> updateFrame({
    required int textureId,
    required Uint8List bgraData,
    required int width,
    required int height,
  }) async {
    try {
      final res = await _channel.invokeMethod<bool>('updateFrame', {
        'textureId': textureId,
        'data': bgraData,
        'width': width,
        'height': height,
      });
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> disposeTexture(int textureId) async {
    try {
      await _channel.invokeMethod('disposeTexture', {
        'textureId': textureId,
      });
    } catch (_) {}
  }
}
