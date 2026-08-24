import 'package:flutter/material.dart';

import '../../models/device_model.dart';
import '../../services/adb_service.dart';
import '../../theme/app_theme.dart';
import 'widgets/stf_webview_stage.dart';

class DeviceControlPage extends StatefulWidget {
  final ThemeController themeController;

  const DeviceControlPage({super.key, required this.themeController});

  @override
  State<DeviceControlPage> createState() => _DeviceControlPageState();
}

class _DeviceControlPageState extends State<DeviceControlPage> {
  bool _isScanning = false;
  String _adbPathInfo = '';
  String? _scanErrorInfo;
  List<DeviceModel> _devices = [];

  @override
  void initState() {
    super.initState();
    _scanAdbDevices();
  }

  Future<void> _scanAdbDevices() async {
    setState(() {
      _isScanning = true;
      _scanErrorInfo = null;
    });

    try {
      final adbPath = await AdbService.resolveAdbPath();
      final realDevices = await AdbService.getConnectedDevices();

      if (!mounted) return;
      setState(() {
        _adbPathInfo = adbPath;
        _devices = realDevices;
        _scanErrorInfo = AdbService.lastError;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _scanErrorInfo = '检测异常: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Scaffold(
      backgroundColor: tokens.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: _devices.isEmpty
                  ? _buildEmptyState(context)
                  : _buildDeviceWall(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final tokens = context.tokens;

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(bottom: BorderSide(color: tokens.outline)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: tokens.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: tokens.primary, width: 1.2),
            ),
            child: Icon(
              Icons.grid_view_rounded,
              size: 16,
              color: tokens.primary,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Mobile Matrix',
            style: TextStyle(
              color: tokens.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 24),
          Container(
            height: 20,
            width: 1,
            color: tokens.outline.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 16),
          Icon(Icons.devices_rounded, size: 17, color: tokens.textSecondary),
          const SizedBox(width: 6),
          Text(
            '已连接 ${_devices.length} 台手机',
            style: TextStyle(color: tokens.textSecondary, fontSize: 13),
          ),
          if (_isScanning) ...[
            const SizedBox(width: 10),
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: tokens.primary,
              ),
            ),
          ],
          const Spacer(),
          IconButton(
            tooltip: '重新扫描已连接手机',
            onPressed: _isScanning ? null : _scanAdbDevices,
            icon: Icon(
              Icons.refresh_rounded,
              size: 19,
              color: _isScanning
                  ? tokens.textSecondary.withValues(alpha: 0.4)
                  : tokens.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            height: 20,
            width: 1,
            color: tokens.outline.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: '切换流光主题 (液态蓝 / 玫瑰流光)',
            onPressed: widget.themeController.toggleTheme,
            icon: Icon(Icons.palette_outlined, size: 20, color: tokens.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceWall(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1200
            ? 3
            : constraints.maxWidth >= 760
            ? 2
            : 1;

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            mainAxisExtent: 560,
          ),
          itemCount: _devices.length,
          itemBuilder: (context, index) {
            final device = _devices[index];
            return _buildDeviceCard(context, device, index);
          },
        );
      },
    );
  }

  Widget _buildDeviceCard(BuildContext context, DeviceModel device, int order) {
    final tokens = context.tokens;

    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.outline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tokens.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    '${order + 1}',
                    style: TextStyle(
                      color: tokens.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  Icons.phone_android_rounded,
                  size: 18,
                  color: tokens.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tokens.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${device.model} · ${device.serial}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tokens.textSecondary,
                          fontSize: 10,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildStatusBadge(context, device.status),
              ],
            ),
          ),
          Divider(height: 1, color: tokens.outline),
          Expanded(
            child: StfWebViewStage(
              key: ValueKey<String>('stf-web-${device.serial}'),
              device: device,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(
    BuildContext context,
    DeviceConnectionStatus status,
  ) {
    final tokens = context.tokens;
    final (color, label) = switch (status) {
      DeviceConnectionStatus.available => (tokens.success, '可控制'),
      DeviceConnectionStatus.using => (tokens.success, '控制中'),
      DeviceConnectionStatus.busy => (tokens.warning, '已占用'),
      DeviceConnectionStatus.disconnected => (tokens.danger, '已断开'),
      DeviceConnectionStatus.unauthorized => (tokens.danger, '未授权'),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: color, fontSize: 10)),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final tokens = context.tokens;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.phone_android_rounded,
            size: 52,
            color: tokens.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '请通过 USB 连接 Android 手机',
            style: TextStyle(
              color: tokens.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '开启【开发者选项】与【USB 调试】后点击重新扫描',
            style: TextStyle(color: tokens.textSecondary, fontSize: 12),
          ),
          if (_adbPathInfo.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'ADB: $_adbPathInfo',
              style: TextStyle(
                color: tokens.textSecondary.withValues(alpha: 0.6),
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ],
          if (_scanErrorInfo != null) ...[
            const SizedBox(height: 8),
            Text(
              _scanErrorInfo!,
              textAlign: TextAlign.center,
              style: TextStyle(color: tokens.danger, fontSize: 11),
            ),
          ],
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _isScanning ? null : _scanAdbDevices,
            icon: _isScanning
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('重新检测设备'),
          ),
        ],
      ),
    );
  }
}
