import 'dart:math';
import 'package:flutter/material.dart';

class NormalizedPoint {
  final double xP;
  final double yP;

  const NormalizedPoint({required this.xP, required this.yP});

  @override
  String toString() => 'NormalizedPoint(xP: ${xP.toStringAsFixed(4)}, yP: ${yP.toStringAsFixed(4)})';
}

class ScaledDimension {
  final double width;
  final double height;

  const ScaledDimension({required this.width, required this.height});
}

class ScalingCoordinator {
  final int realWidth;
  final int realHeight;

  ScalingCoordinator({
    required this.realWidth,
    required this.realHeight,
  }) : assert(realWidth > 0 && realHeight > 0);

  double get realRatio => realWidth / realHeight;

  /// 计算屏幕在容器中居中且保持长宽比时的渲染矩形 Rect
  Rect calculateRenderRect(Size containerSize, int rotation) {
    if (containerSize.width <= 0 || containerSize.height <= 0) {
      return Rect.zero;
    }

    final isLandscape = (rotation == 90 || rotation == 270);
    final targetAspect = isLandscape ? (1.0 / realRatio) : realRatio;
    final containerAspect = containerSize.width / containerSize.height;

    double renderW;
    double renderH;

    if (containerAspect > targetAspect) {
      // 容器更宽，高度贴满，两侧有黑边
      renderH = containerSize.height;
      renderW = renderH * targetAspect;
    } else {
      // 容器更高，宽度贴满，上下有黑边
      renderW = containerSize.width;
      renderH = renderW / targetAspect;
    }

    final offsetX = (containerSize.width - renderW) / 2.0;
    final offsetY = (containerSize.height - renderH) / 2.0;

    return Rect.fromLTWH(offsetX, offsetY, renderW, renderH);
  }

  /// 将视口相对像素坐标转换为 Android 设备上的归一化坐标 (0.0 ~ 1.0)
  NormalizedPoint mapToDeviceCoords({
    required double boundingW,
    required double boundingH,
    required double relX,
    required double relY,
    required int rotation,
  }) {
    if (boundingW <= 0 || boundingH <= 0) {
      return const NormalizedPoint(xP: 0.0, yP: 0.0);
    }

    double w;
    double h;
    double x;
    double y;

    switch (rotation) {
      case 90:
        w = boundingH;
        h = boundingW;
        x = boundingH - relY;
        y = relX;
        break;
      case 180:
        w = boundingW;
        h = boundingH;
        x = boundingW - relX;
        y = boundingH - relY;
        break;
      case 270:
        w = boundingH;
        h = boundingW;
        x = relY;
        y = boundingW - relX;
        break;
      case 0:
      default:
        w = boundingW;
        h = boundingH;
        x = relX;
        y = relY;
        break;
    }

    final ratio = w / h;
    double scaledValue;

    if (realRatio > ratio) {
      scaledValue = w / realRatio;
      y -= (h - scaledValue) / 2.0;
      h = scaledValue;
    } else {
      scaledValue = h * realRatio;
      x -= (w - scaledValue) / 2.0;
      w = scaledValue;
    }

    // 夹取在 0.0 ~ 1.0 范围内
    final clampedX = max(0.0, min(1.0, x / w));
    final clampedY = max(0.0, min(1.0, y / h));

    return NormalizedPoint(xP: clampedX, yP: clampedY);
  }
}
