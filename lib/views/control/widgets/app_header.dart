import 'package:flutter/material.dart';
import '../../../models/device_model.dart';
import '../../../theme/app_theme.dart';

enum AppHeaderMode { full, brandOnly, controlsOnly }

class AppHeader extends StatelessWidget {
  final DeviceModel? currentDevice;
  final AppThemeType currentTheme;
  final List<DeviceModel> availableDevices;
  final ValueChanged<DeviceModel> onDeviceSelected;
  final VoidCallback onRefreshDevices;
  final VoidCallback onToggleTheme;
  final VoidCallback onToggleRotation;
  final VoidCallback onToggleScreenVisibility;
  final bool isScreenVisible;
  final bool isScanning;
  final AppHeaderMode mode;

  const AppHeader({
    super.key,
    required this.currentDevice,
    required this.currentTheme,
    required this.availableDevices,
    required this.onDeviceSelected,
    required this.onRefreshDevices,
    required this.onToggleTheme,
    required this.onToggleRotation,
    required this.onToggleScreenVisibility,
    required this.isScreenVisible,
    this.isScanning = false,
    this.mode = AppHeaderMode.full,
  });

  Color _getStatusColor(DeviceConnectionStatus status, AppColorTokens tokens) {
    switch (status) {
      case DeviceConnectionStatus.available:
      case DeviceConnectionStatus.using:
        return tokens.success;
      case DeviceConnectionStatus.busy:
        return tokens.warning;
      case DeviceConnectionStatus.disconnected:
      case DeviceConnectionStatus.unauthorized:
        return tokens.danger;
    }
  }

  String _getStatusText(DeviceConnectionStatus status) {
    switch (status) {
      case DeviceConnectionStatus.available:
        return '已连接 · 可控制';
      case DeviceConnectionStatus.using:
        return '正在控制 (ADB)';
      case DeviceConnectionStatus.busy:
        return '设备正被占用';
      case DeviceConnectionStatus.disconnected:
        return '连接已断开';
      case DeviceConnectionStatus.unauthorized:
        return '未授权 (请在手机勾选信任)';
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final logoAsset = currentTheme == AppThemeType.roseGlow
        ? 'assets/branding/mobile-matrix-128-rose.png'
        : 'assets/branding/mobile-matrix-128.png';
    final showBrand = mode != AppHeaderMode.controlsOnly;
    final showControls = mode != AppHeaderMode.brandOnly;

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(bottom: BorderSide(color: tokens.outline, width: 1)),
      ),
      child: Row(
        children: [
          if (showBrand) ...[
            // 品牌 Logo & 名称
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: tokens.primary, width: 1.2),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(logoAsset, fit: BoxFit.cover),
                ),
                const SizedBox(width: 10),
                Text(
                  'Mobile Matrix',
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),

            if (mode == AppHeaderMode.full) ...[
              const SizedBox(width: 24),
              Container(
                height: 20,
                width: 1,
                color: tokens.outline.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 24),
            ],
          ],

          if (showControls) ...[
            // 设备选择下拉与状态
            if (availableDevices.isNotEmpty && currentDevice != null)
              PopupMenuButton<DeviceModel>(
                tooltip: '切换设备',
                offset: const Offset(0, 42),
                color: tokens.bgSecondary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: tokens.outline),
                ),
                onSelected: onDeviceSelected,
                itemBuilder: (context) {
                  return availableDevices.map((dev) {
                    final isSelected = dev.serial == currentDevice!.serial;
                    return PopupMenuItem<DeviceModel>(
                      value: dev,
                      child: Row(
                        children: [
                          Icon(
                            Icons.phone_android_rounded,
                            size: 18,
                            color: isSelected
                                ? tokens.primary
                                : tokens.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              dev.displayName,
                              style: TextStyle(
                                color: isSelected
                                    ? tokens.primary
                                    : tokens.textPrimary,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _getStatusColor(dev.status, tokens),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.bgSecondary,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: tokens.outline),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.phone_android_rounded,
                        size: 16,
                        color: tokens.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        currentDevice!.displayName,
                        style: TextStyle(
                          color: tokens.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _getStatusColor(currentDevice!.status, tokens),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _getStatusText(currentDevice!.status),
                        style: TextStyle(
                          color: tokens.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_drop_down,
                        size: 18,
                        color: tokens.textSecondary,
                      ),
                    ],
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: tokens.bgSecondary,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: tokens.outline),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.phonelink_erase_rounded,
                      size: 16,
                      color: tokens.warning,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '未检测到 USB 真机连接',
                      style: TextStyle(
                        color: tokens.warning,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(width: 10),

            // 刷新设备扫描按钮
            IconButton(
              tooltip: '重新扫描 ADB 真机设备',
              icon: isScanning
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: tokens.primary,
                      ),
                    )
                  : Icon(
                      Icons.refresh_rounded,
                      size: 18,
                      color: tokens.textSecondary,
                    ),
              onPressed: isScanning ? null : onRefreshDevices,
            ),

            const Spacer(),

            // 屏幕旋转按钮
            if (currentDevice != null)
              IconButton(
                tooltip: currentDevice!.display.isLandscape
                    ? '切换为竖屏 (0°)'
                    : '切换为横屏 (90°)',
                icon: Icon(
                  currentDevice!.display.isLandscape
                      ? Icons.stay_current_landscape_rounded
                      : Icons.stay_current_portrait_rounded,
                  size: 20,
                  color: tokens.textSecondary,
                ),
                onPressed: onToggleRotation,
              ),

            // 屏幕显隐控制
            IconButton(
              tooltip: isScreenVisible ? '隐藏屏幕' : '显示屏幕',
              icon: Icon(
                isScreenVisible
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
                size: 20,
                color: isScreenVisible ? tokens.primary : tokens.textSecondary,
              ),
              onPressed: onToggleScreenVisibility,
            ),

            const SizedBox(width: 8),
            Container(
              height: 20,
              width: 1,
              color: tokens.outline.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 8),

            // 主题切换按钮
            IconButton(
              tooltip: '切换流光主题 (液态蓝 / 玫瑰流光)',
              icon: Icon(
                Icons.palette_outlined,
                size: 20,
                color: tokens.primary,
              ),
              onPressed: onToggleTheme,
            ),
          ],

          if (!showControls) const Spacer(),
        ],
      ),
    );
  }
}
