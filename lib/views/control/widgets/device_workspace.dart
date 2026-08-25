import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/device_model.dart';
import '../../../models/device_tool_models.dart';
import '../../../services/device_control_service.dart';
import '../../../services/device_tool_parsers.dart';
import '../../../services/device_tools_service.dart';
import '../../../services/screen_capture_service.dart';
import '../../../services/screen_stream_service.dart';
import '../../../theme/app_theme.dart';
import 'fast_screen_renderer.dart';

class DeviceWorkspace extends StatefulWidget {
  final DeviceModel device;
  final IDeviceControlService controlService;
  final DeviceToolsService toolsService;
  final IScreenStreamService streamService;
  final ValueListenable<ScreenFpsStats> fpsStats;

  const DeviceWorkspace({
    super.key,
    required this.device,
    required this.controlService,
    required this.toolsService,
    required this.streamService,
    required this.fpsStats,
  });

  @override
  State<DeviceWorkspace> createState() => _DeviceWorkspaceState();
}

class _ToolEntry {
  final DeviceToolKind kind;
  final String label;
  final IconData icon;

  const _ToolEntry(this.kind, this.label, this.icon);
}

class _DeviceWorkspaceState extends State<DeviceWorkspace> {
  static const _tools = [
    _ToolEntry(DeviceToolKind.dashboard, 'Dashboard', Icons.dashboard_outlined),
    _ToolEntry(DeviceToolKind.logs, '日志', Icons.article_outlined),
    _ToolEntry(
      DeviceToolKind.screenshots,
      '截屏',
      Icons.screenshot_monitor_outlined,
    ),
    _ToolEntry(DeviceToolKind.automation, '自动化', Icons.tune_rounded),
    _ToolEntry(DeviceToolKind.explorer, '文件管理', Icons.folder_open_outlined),
    _ToolEntry(DeviceToolKind.advanced, '高级功能', Icons.extension_outlined),
    _ToolEntry(DeviceToolKind.info, '设备信息', Icons.info_outline_rounded),
  ];

  final TextEditingController _clipboardController = TextEditingController();
  final TextEditingController _typeInputController = TextEditingController();
  final TextEditingController _shellInputController = TextEditingController();
  final TextEditingController _apkPathController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _packageController = TextEditingController();
  final TextEditingController _remoteAddressController =
      TextEditingController();
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _explorerPathController = TextEditingController(
    text: '/sdcard',
  );
  final TextEditingController _pullDestinationController =
      TextEditingController();
  final TextEditingController _logFilterController = TextEditingController();
  final TextEditingController _hostPortController = TextEditingController();
  final TextEditingController _devicePortController = TextEditingController();

  final List<String> _terminalLogs = [];
  final List<String> _logLines = [];
  final List<String> _packages = [];
  final List<DeviceFileEntry> _files = [];
  StreamSubscription<String>? _logSubscription;

  DeviceToolKind _selectedTool = DeviceToolKind.dashboard;
  DeviceInfoSnapshot? _info;
  String _explorerMessage = '';
  String _toolMessage = '';
  String _portMessage = '';
  String _screenshotMessage = '';
  bool _isExecutingShell = false;
  bool _isLoading = false;
  bool _isLogcatRunning = false;
  bool _isExplorerLoading = false;
  bool _isCopyingScreenshot = false;
  bool _wifiEnabled = true;
  bool _bluetoothEnabled = true;

  @override
  void initState() {
    super.initState();
    _subscribeLogcat();
  }

  @override
  void didUpdateWidget(covariant DeviceWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.toolsService, widget.toolsService)) {
      _logSubscription?.cancel();
      _subscribeLogcat();
    }
  }

  void _subscribeLogcat() {
    _logSubscription = widget.toolsService.logLines.listen((line) {
      if (!mounted) return;
      setState(() {
        _logLines.add(line);
        if (_logLines.length > 2000) _logLines.removeRange(0, 500);
      });
    });
  }

  @override
  void dispose() {
    _logSubscription?.cancel();
    _clipboardController.dispose();
    _typeInputController.dispose();
    _shellInputController.dispose();
    _apkPathController.dispose();
    _urlController.dispose();
    _packageController.dispose();
    _remoteAddressController.dispose();
    _accountController.dispose();
    _explorerPathController.dispose();
    _pullDestinationController.dispose();
    _logFilterController.dispose();
    _hostPortController.dispose();
    _devicePortController.dispose();
    super.dispose();
  }

  Future<void> _handleSendText() async {
    final text = _typeInputController.text;
    if (text.isEmpty) return;
    final sent = await widget.controlService.typeText(text);
    if (sent) widget.streamService.triggerImmediateRefresh();
    _typeInputController.clear();
    _appendTerminalLog('Commit Text: "$text"');
  }

  Future<void> _handleSetClipboard() async {
    final text = _clipboardController.text;
    if (text.isEmpty) return;
    final pasted = await widget.controlService.pasteText(text);
    if (pasted) widget.streamService.triggerImmediateRefresh();
    _appendTerminalLog('Clipboard Set: "$text"');
  }

  Future<void> _handlePasteFromComputer() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) {
      _showMessage('电脑剪贴板当前为空');
      return;
    }
    _clipboardController.text = text;
    final pasted = await widget.controlService.pasteText(text);
    if (pasted) widget.streamService.triggerImmediateRefresh();
    _appendTerminalLog('Pasted from computer clipboard: "$text"');
    _showMessage(pasted ? '已将电脑剪贴板内容注入手机' : '注入手机失败');
  }

  Future<void> _handleGetClipboard() async {
    final text = await widget.controlService.getClipboard();
    if (text != null) _clipboardController.text = text;
  }

  Future<void> _handleExecuteShell([String? customCommand]) async {
    final command = (customCommand ?? _shellInputController.text).trim();
    if (command.isEmpty) return;
    setState(() => _isExecutingShell = true);
    _appendTerminalLog('\$ $command');
    final result = await widget.controlService.executeShell(command);
    _appendTerminalLog(result.trimRight());
    if (mounted) setState(() => _isExecutingShell = false);
    _shellInputController.clear();
  }

  void _appendTerminalLog(String line) {
    if (!mounted) return;
    setState(() {
      _terminalLogs.add(line);
      if (_terminalLogs.length > 500) _terminalLogs.removeAt(0);
    });
  }

  Future<void> _handleInstallApk() async {
    final result = await widget.toolsService.installApk(
      _apkPathController.text,
    );
    _showResult(result);
  }

  Future<void> _handleOpenUrl() async {
    _showResult(await widget.toolsService.openUrl(_urlController.text));
  }

  Future<void> _handleListPackages() async {
    final result = await widget.toolsService.listPackages();
    if (!mounted) return;
    setState(() {
      _packages
        ..clear()
        ..addAll(
          result.output
              .split('\n')
              .map((line) => line.replaceFirst('package:', '').trim())
              .where((line) => line.isNotEmpty),
        );
    });
    _showResult(result, successMessage: '已读取 ${_packages.length} 个第三方应用');
  }

  Future<void> _handleUninstallPackage() async {
    final result = await widget.toolsService.uninstallPackage(
      _packageController.text,
    );
    _showResult(result);
  }

  Future<void> _handleRemoteDebug() async {
    final result = await widget.toolsService.enableRemoteDebug(
      _remoteAddressController.text,
    );
    _showResult(result);
  }

  Future<void> _handleStartLogcat() async {
    await widget.toolsService.startLogcat(filter: _logFilterController.text);
    if (mounted) setState(() => _isLogcatRunning = true);
    _showMessage('logcat 已启动');
  }

  Future<void> _handleStopLogcat() async {
    await widget.toolsService.stopLogcat();
    if (mounted) setState(() => _isLogcatRunning = false);
    _showMessage('logcat 已停止');
  }

  Future<void> _handleCopyLogs() async {
    final text = _filteredLogs.join('\n');
    if (text.isEmpty) {
      _showMessage('当前没有可复制的日志');
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    _showMessage('日志已复制到剪贴板');
  }

  Future<void> _handleCopyScreenshot() async {
    if (_isCopyingScreenshot) return;
    setState(() => _isCopyingScreenshot = true);
    try {
      await ScreenCaptureService(
        serial: widget.device.serial,
      ).copyScreenshotToClipboard();
      if (mounted) setState(() => _screenshotMessage = '已复制 PNG 到系统图片剪贴板');
    } catch (error) {
      if (mounted) setState(() => _screenshotMessage = '$error');
    } finally {
      if (mounted) setState(() => _isCopyingScreenshot = false);
    }
  }

  Future<void> _handleRingerMode(DeviceRingerMode mode) async {
    _showResult(await widget.toolsService.setRingerMode(mode));
  }

  Future<void> _handleWifi(bool enabled) async {
    final result = await widget.toolsService.setWifiEnabled(enabled);
    if (result.success && mounted) setState(() => _wifiEnabled = enabled);
    _showResult(result);
  }

  Future<void> _handleBluetooth(bool enabled) async {
    final result = await widget.toolsService.setBluetoothEnabled(enabled);
    if (result.success && mounted) setState(() => _bluetoothEnabled = enabled);
    _showResult(result);
  }

  Future<void> _handleAccountCheck() async {
    _showResult(
      await widget.toolsService.checkStoreAccount(_accountController.text),
    );
  }

  Future<void> _handleAccountRemove() async {
    _showResult(
      await widget.toolsService.removeStoreAccount(_accountController.text),
    );
  }

  Future<void> _handleListDirectory([String? path]) async {
    final target = (path ?? _explorerPathController.text).trim();
    if (target.isEmpty) return;
    setState(() => _isExplorerLoading = true);
    final result = await widget.toolsService.listDirectory(target);
    if (!mounted) return;
    setState(() {
      _isExplorerLoading = false;
      _explorerPathController.text = target;
      _files
        ..clear()
        ..addAll(
          DeviceToolParsers.parseDirectoryListing(result.output, target),
        );
      _explorerMessage = result.success
          ? '${_files.length} 个项目'
          : result.message;
    });
  }

  void _handleExplorerUp() {
    final current = _explorerPathController.text.trim();
    if (current.isEmpty || current == '/') return;
    final index = current.lastIndexOf('/');
    final parent = index <= 0 ? '/' : current.substring(0, index);
    _handleListDirectory(parent);
  }

  Future<void> _handlePullFile(DeviceFileEntry entry) async {
    final destination = _pullDestinationController.text.trim();
    if (destination.isEmpty) {
      _showMessage('请先填写本地目标路径');
      return;
    }
    _showResult(
      await widget.toolsService.pullFile(entry.path, destination),
      successMessage: '文件已拉取到 $destination',
    );
  }

  Future<void> _handleCreateForward() async {
    final result = await widget.toolsService.createPortForward(
      _hostPortController.text,
      _devicePortController.text,
    );
    if (mounted) setState(() => _portMessage = result.message);
  }

  Future<void> _handleRemoveForward() async {
    final result = await widget.toolsService.removePortForward(
      _hostPortController.text,
    );
    if (mounted) setState(() => _portMessage = result.message);
  }

  Future<void> _handleTestForward() async {
    final result = await widget.toolsService.testPortForward();
    if (mounted) setState(() => _portMessage = result.message);
  }

  Future<void> _handleLoadInfo() async {
    setState(() => _isLoading = true);
    final info = await widget.toolsService.readInfoSnapshot();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _info = info;
    });
  }

  Future<void> _handleReboot() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重启设备'),
        content: const Text('确定要重启当前设备吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('重启'),
          ),
        ],
      ),
    );
    if (confirmed == true) _showResult(await widget.toolsService.reboot());
  }

  List<String> get _filteredLogs {
    final query = _logFilterController.text.trim().toLowerCase();
    if (query.isEmpty) return List.unmodifiable(_logLines);
    return _logLines
        .where((line) => line.toLowerCase().contains(query))
        .toList(growable: false);
  }

  void _showResult(DeviceToolResult result, {String? successMessage}) {
    _showMessage(
      result.success ? (successMessage ?? result.message) : result.message,
    );
  }

  void _showMessage(String message) {
    if (!mounted || message.trim().isEmpty) return;
    setState(() => _toolMessage = message.trim());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message.trim()),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      color: tokens.bg,
      child: Column(
        children: [
          _buildDeviceInfoBar(context),
          _buildModeBar(context),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final navigationWidth = constraints.maxWidth < 760
                    ? 132.0
                    : 164.0;
                return Row(
                  children: [
                    SizedBox(
                      width: navigationWidth,
                      child: _buildNavigation(context),
                    ),
                    VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: tokens.outline,
                    ),
                    Expanded(child: _buildActiveTool(context)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceInfoBar(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: tokens.bgSecondary.withValues(alpha: 0.5),
        border: Border(bottom: BorderSide(color: tokens.outline)),
      ),
      child: Row(
        children: [
          Icon(Icons.smartphone_rounded, size: 17, color: tokens.primary),
          const SizedBox(width: 8),
          Text(
            widget.device.displayName,
            style: TextStyle(
              color: tokens.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${widget.device.display.width}×${widget.device.display.height}',
            style: TextStyle(color: tokens.textSecondary, fontSize: 11),
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder<ScreenFpsStats>(
            valueListenable: widget.fpsStats,
            builder: (context, stats, _) => _buildFpsIndicator(stats, tokens),
          ),
          const Spacer(),
          Tooltip(
            message: '复制截屏',
            child: IconButton(
              tooltip: '复制截屏',
              onPressed: _isCopyingScreenshot ? null : _handleCopyScreenshot,
              icon: const Icon(Icons.content_copy_outlined, size: 17),
              style: IconButton.styleFrom(
                foregroundColor: tokens.primary,
                side: BorderSide(color: tokens.primary.withValues(alpha: 0.7)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: const EdgeInsets.all(6),
                minimumSize: const Size(32, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getFpsColor(int fps, AppColorTokens tokens) {
    if (fps >= 45) return tokens.success;
    if (fps >= 25) return tokens.warning;
    return tokens.danger;
  }

  Widget _buildFpsIndicator(ScreenFpsStats stats, AppColorTokens tokens) {
    final color = _getFpsColor(stats.rendered, tokens);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 4),
          Text(
            'FPS ${stats.rendered}',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeBar(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(bottom: BorderSide(color: tokens.outline)),
      ),
      child: Row(
        children: [
          Icon(Icons.build_circle_outlined, size: 18, color: tokens.primary),
          const SizedBox(width: 8),
          Text(
            '设备工具箱',
            style: TextStyle(
              color: tokens.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          if (_toolMessage.isNotEmpty)
            Flexible(
              child: Text(
                _toolMessage,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: tokens.textSecondary, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNavigation(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      color: tokens.surface.withValues(alpha: 0.55),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: ListView.separated(
        itemCount: _tools.length,
        separatorBuilder: (_, _) => const SizedBox(height: 4),
        itemBuilder: (context, index) {
          final entry = _tools[index];
          final selected = entry.kind == _selectedTool;
          return Tooltip(
            message: entry.label,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _selectedTool = entry.kind),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? tokens.primary.withValues(alpha: 0.18)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected ? tokens.primary : Colors.transparent,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      entry.icon,
                      size: 18,
                      color: selected ? tokens.primary : tokens.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entry.label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected
                              ? tokens.primary
                              : tokens.textSecondary,
                          fontSize: 12,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActiveTool(BuildContext context) {
    return switch (_selectedTool) {
      DeviceToolKind.dashboard => _buildDashboard(context),
      DeviceToolKind.logs => _buildLogs(context),
      DeviceToolKind.screenshots => _buildScreenshots(context),
      DeviceToolKind.automation => _buildAutomation(context),
      DeviceToolKind.explorer => _buildExplorer(context),
      DeviceToolKind.advanced => _buildAdvanced(context),
      DeviceToolKind.info => _buildInfo(context),
    };
  }

  Widget _buildDashboard(BuildContext context) {
    return _toolScroll(context, [
      _buildCard(
        context,
        '导航',
        Icons.language_outlined,
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                context,
                _urlController,
                '输入网址，例如 example.com',
                onSubmitted: (_) => _handleOpenUrl(),
              ),
            ),
            const SizedBox(width: 8),
            _buildCompactButton(
              context,
              '打开',
              Icons.open_in_new_rounded,
              _handleOpenUrl,
            ),
          ],
        ),
      ),
      _buildCard(
        context,
        '硬件物理按键',
        Icons.power_settings_new_rounded,
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildActionButton(
              context,
              '电源键',
              Icons.power_settings_new_rounded,
              () => widget.controlService.keyPress(DeviceKeyAction.power),
            ),
            _buildActionButton(
              context,
              '音量 +',
              Icons.volume_up_rounded,
              () => widget.controlService.keyPress(DeviceKeyAction.volumeUp),
            ),
            _buildActionButton(
              context,
              '音量 -',
              Icons.volume_down_rounded,
              () => widget.controlService.keyPress(DeviceKeyAction.volumeDown),
            ),
          ],
        ),
      ),
      _buildCard(
        context,
        '输入法文本注入',
        Icons.keyboard_alt_outlined,
        _buildInputActionRow(
          context,
          _typeInputController,
          '输入要发送到真机的内容...',
          '发送',
          _handleSendText,
        ),
      ),
      _buildCard(
        context,
        '剪贴板双向同步',
        Icons.content_paste_rounded,
        _buildClipboardControls(context),
      ),
      _buildCard(
        context,
        'ADB Shell 终端控制台',
        Icons.terminal_rounded,
        _buildShellControls(context),
      ),
      _buildCard(
        context,
        '应用安装与管理',
        Icons.apps_outlined,
        _buildAppManagement(context),
      ),
      _buildCard(
        context,
        'ADB 远程调试',
        Icons.wifi_tethering_outlined,
        _buildRemoteDebug(context),
      ),
    ]);
  }

  Widget _buildLogs(BuildContext context) {
    final tokens = context.tokens;
    final logs = _filteredLogs;
    return _toolScroll(context, [
      _buildCard(
        context,
        'Logcat 日志',
        Icons.article_outlined,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildCompactButton(
                  context,
                  _isLogcatRunning ? '停止' : '启动',
                  _isLogcatRunning
                      ? Icons.stop_circle_outlined
                      : Icons.play_circle_outline,
                  _isLogcatRunning ? _handleStopLogcat : _handleStartLogcat,
                ),
                _buildCompactButton(
                  context,
                  '清空',
                  Icons.delete_sweep_outlined,
                  () => setState(() => _logLines.clear()),
                ),
                _buildCompactButton(
                  context,
                  '复制',
                  Icons.copy_outlined,
                  _handleCopyLogs,
                ),
                SizedBox(
                  width: 220,
                  child: _buildTextField(
                    context,
                    _logFilterController,
                    '过滤关键词',
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 360,
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF070B0E),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: tokens.outline.withValues(alpha: 0.5),
                ),
              ),
              child: logs.isEmpty
                  ? Text(
                      '# 启动 logcat 后显示设备日志',
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    )
                  : ListView.builder(
                      itemCount: logs.length,
                      itemBuilder: (context, index) => Text(
                        logs[index],
                        style: TextStyle(
                          color: tokens.textSecondary,
                          fontSize: 11,
                          fontFamily: 'monospace',
                          height: 1.35,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    ]);
  }

  Widget _buildScreenshots(BuildContext context) {
    final tokens = context.tokens;
    return _toolScroll(context, [
      _buildCard(
        context,
        '设备截图',
        Icons.screenshot_monitor_outlined,
        Row(
          children: [
            Tooltip(
              message: '复制截屏到系统图片剪贴板',
              child: IconButton.filledTonal(
                onPressed: _handleCopyScreenshot,
                icon: const Icon(Icons.content_copy_rounded),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _screenshotMessage.isEmpty
                    ? '截取当前设备画面并复制到粘贴板，不保存桌面文件。'
                    : _screenshotMessage,
                style: TextStyle(color: tokens.textSecondary, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    ]);
  }

  Widget _buildAutomation(BuildContext context) {
    return _toolScroll(context, [
      _buildCard(
        context,
        '设备设置',
        Icons.tune_rounded,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              children: [
                _buildCompactButton(
                  context,
                  '静音',
                  Icons.volume_off_outlined,
                  () => _handleRingerMode(DeviceRingerMode.silent),
                ),
                _buildCompactButton(
                  context,
                  '振动',
                  Icons.vibration_outlined,
                  () => _handleRingerMode(DeviceRingerMode.vibrate),
                ),
                _buildCompactButton(
                  context,
                  '响铃',
                  Icons.notifications_active_outlined,
                  () => _handleRingerMode(DeviceRingerMode.normal),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Wi‑Fi'),
              value: _wifiEnabled,
              onChanged: _handleWifi,
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('蓝牙'),
              value: _bluetoothEnabled,
              onChanged: _handleBluetooth,
            ),
            _buildCompactButton(
              context,
              '清理蓝牙配对设备',
              Icons.bluetooth_disabled_outlined,
              () async =>
                  _showResult(await widget.toolsService.clearBluetoothBonds()),
            ),
          ],
        ),
      ),
      _buildCard(
        context,
        '应用商店账号',
        Icons.account_circle_outlined,
        Column(
          children: [
            _buildTextField(context, _accountController, '账号名称'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildCompactButton(
                  context,
                  '查看账号',
                  Icons.visibility_outlined,
                  () async =>
                      _showResult(await widget.toolsService.getStoreAccounts()),
                ),
                _buildCompactButton(
                  context,
                  '检查',
                  Icons.search_rounded,
                  _handleAccountCheck,
                ),
                _buildCompactButton(
                  context,
                  '移除',
                  Icons.person_remove_outlined,
                  _handleAccountRemove,
                ),
                _buildCompactButton(
                  context,
                  '添加账号',
                  Icons.person_add_outlined,
                  () async =>
                      _showResult(await widget.toolsService.addStoreAccount()),
                ),
                _buildCompactButton(
                  context,
                  '打开应用商店',
                  Icons.storefront_outlined,
                  () async =>
                      _showResult(await widget.toolsService.openAppStore()),
                ),
              ],
            ),
          ],
        ),
      ),
    ]);
  }

  Widget _buildExplorer(BuildContext context) {
    final tokens = context.tokens;
    return _toolScroll(context, [
      _buildCard(
        context,
        '文件浏览器',
        Icons.folder_open_outlined,
        Column(
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: '上级目录',
                  onPressed: _handleExplorerUp,
                  icon: const Icon(Icons.arrow_upward_rounded),
                ),
                Expanded(
                  child: _buildTextField(
                    context,
                    _explorerPathController,
                    '设备路径',
                    onSubmitted: (_) => _handleListDirectory(),
                  ),
                ),
                const SizedBox(width: 8),
                _buildCompactButton(
                  context,
                  '进入',
                  Icons.arrow_forward_rounded,
                  _handleListDirectory,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _explorerMessage.isEmpty
                    ? '输入 /sdcard 或其他设备路径'
                    : _explorerMessage,
                style: TextStyle(color: tokens.textSecondary, fontSize: 11),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 300,
              decoration: BoxDecoration(
                color: tokens.bgSecondary.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _isExplorerLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _files.isEmpty
                  ? Center(
                      child: Text(
                        '暂无目录内容',
                        style: TextStyle(
                          color: tokens.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _files.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        color: tokens.outline.withValues(alpha: 0.35),
                      ),
                      itemBuilder: (context, index) {
                        final file = _files[index];
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            file.isDirectory
                                ? Icons.folder_outlined
                                : Icons.insert_drive_file_outlined,
                            color: file.isDirectory
                                ? tokens.warning
                                : tokens.primary,
                            size: 18,
                          ),
                          title: Text(
                            file.name,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: tokens.textPrimary,
                              fontSize: 12,
                            ),
                          ),
                          subtitle: Text(
                            file.isDirectory ? '目录' : '${file.size} B',
                            style: TextStyle(
                              color: tokens.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                          onTap: file.isDirectory
                              ? () => _handleListDirectory(file.path)
                              : null,
                          trailing: file.isDirectory
                              ? null
                              : IconButton(
                                  tooltip: '拉取文件',
                                  onPressed: () => _handlePullFile(file),
                                  icon: const Icon(
                                    Icons.download_outlined,
                                    size: 18,
                                  ),
                                ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 10),
            _buildTextField(
              context,
              _pullDestinationController,
              '文件拉取目标路径（本地）',
            ),
          ],
        ),
      ),
    ]);
  }

  Widget _buildAdvanced(BuildContext context) {
    return _toolScroll(context, [
      _buildCard(
        context,
        '特殊按键',
        Icons.keyboard_command_key_outlined,
        _buildAdvancedKeys(context),
      ),
      _buildCard(
        context,
        '端口转发',
        Icons.compare_arrows_outlined,
        Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildTextField(context, _hostPortController, '本地端口'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTextField(
                    context,
                    _devicePortController,
                    '设备端口',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _buildCompactButton(
                  context,
                  '创建',
                  Icons.add_link_rounded,
                  _handleCreateForward,
                ),
                _buildCompactButton(
                  context,
                  '移除',
                  Icons.link_off_rounded,
                  _handleRemoveForward,
                ),
                _buildCompactButton(
                  context,
                  '查看',
                  Icons.list_alt_outlined,
                  _handleTestForward,
                ),
              ],
            ),
            if (_portMessage.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildStatusText(context, _portMessage),
            ],
          ],
        ),
      ),
      _buildCard(
        context,
        '设备维护',
        Icons.build_outlined,
        _buildCompactButton(
          context,
          '重启设备',
          Icons.restart_alt_rounded,
          _handleReboot,
        ),
      ),
    ]);
  }

  Widget _buildInfo(BuildContext context) {
    if (_info == null && !_isLoading) {
      return _toolScroll(context, [
        _buildCard(
          context,
          '设备信息',
          Icons.info_outline_rounded,
          _buildCompactButton(
            context,
            '读取设备信息',
            Icons.refresh_rounded,
            _handleLoadInfo,
          ),
        ),
      ]);
    }
    final info = _info;
    return _toolScroll(context, [
      _buildCard(
        context,
        '设备信息',
        Icons.info_outline_rounded,
        _isLoading
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            : Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _buildCompactButton(
                      context,
                      '刷新',
                      Icons.refresh_rounded,
                      _handleLoadInfo,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildInfoGroup(context, '硬件', {
                    '制造商': info?.value('manufacturer') ?? '未知',
                    '型号': info?.value('model') ?? '未知',
                    '产品': info?.value('product') ?? '未知',
                    '序列号': info?.value('serial') ?? widget.device.serial,
                  }),
                  _buildInfoGroup(context, '平台', {
                    'Android': info?.value('android') ?? '未知',
                    'SDK': info?.value('sdk') ?? '未知',
                    'ABI': info?.value('abi') ?? '未知',
                  }),
                  _buildInfoGroup(context, '显示', {
                    '分辨率': info?.value('display') ?? '未知',
                    '密度': info?.value('density') ?? '未知',
                    'FPS': widget.device.display.fps.toStringAsFixed(0),
                  }),
                  _buildInfoGroup(context, '电池', {
                    '电量': info?.value('batteryLevel') == '未知'
                        ? '未知'
                        : '${info?.value('batteryLevel')}%',
                    '状态': info?.value('batteryStatus') ?? '未知',
                    '温度': info?.value('batteryTemperature') == '未知'
                        ? '未知'
                        : '${info?.value('batteryTemperature')} / 10 °C',
                  }),
                  _buildInfoGroup(context, '网络 / SIM', {
                    'IP': info?.value('network') ?? '未知',
                    '运营商': info?.value('carrier') ?? '未知',
                    'SIM 国家': info?.value('simCountry') ?? '未知',
                    'IMEI': info?.value('imei') ?? '未知',
                  }),
                  _buildInfoGroup(context, 'CPU / 内存', {
                    'CPU': info?.value('cpuName') ?? '未知',
                    '核心数': info?.value('cpuCores') ?? '未知',
                    '内存': info?.value('memory') ?? '未知',
                    '存储': info?.value('storage') ?? '未知',
                  }),
                ],
              ),
      ),
    ]);
  }

  Widget _buildAdvancedKeys(BuildContext context) {
    final actions = <(String, IconData, DeviceKeyAction)>[
      ('相机', Icons.camera_alt_outlined, DeviceKeyAction.camera),
      ('搜索', Icons.search_rounded, DeviceKeyAction.search),
      ('切换输入法', Icons.language_rounded, DeviceKeyAction.switchCharset),
      ('静音', Icons.volume_off_outlined, DeviceKeyAction.mute),
      ('后退', Icons.skip_previous_rounded, DeviceKeyAction.mediaPrevious),
      ('播放/暂停', Icons.play_arrow_rounded, DeviceKeyAction.mediaPlayPause),
      ('停止', Icons.stop_rounded, DeviceKeyAction.mediaStop),
      ('前进', Icons.skip_next_rounded, DeviceKeyAction.mediaNext),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: actions
              .map(
                (entry) => _buildActionButton(
                  context,
                  entry.$1,
                  entry.$2,
                  () => widget.controlService.keyPress(entry.$3),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildIconKey(
              context,
              Icons.keyboard_arrow_up_rounded,
              DeviceKeyAction.dpadUp,
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildIconKey(
              context,
              Icons.keyboard_arrow_left_rounded,
              DeviceKeyAction.dpadLeft,
            ),
            const SizedBox(width: 8),
            _buildIconKey(
              context,
              Icons.keyboard_arrow_down_rounded,
              DeviceKeyAction.dpadDown,
            ),
            const SizedBox(width: 8),
            _buildIconKey(
              context,
              Icons.keyboard_arrow_right_rounded,
              DeviceKeyAction.dpadRight,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildIconKey(
    BuildContext context,
    IconData icon,
    DeviceKeyAction action,
  ) {
    final tokens = context.tokens;
    return IconButton.outlined(
      tooltip: action.name,
      onPressed: () => widget.controlService.keyPress(action),
      icon: Icon(icon, color: tokens.primary),
    );
  }

  Widget _buildAppManagement(BuildContext context) {
    final tokens = context.tokens;
    return Column(
      children: [
        _buildTextField(context, _apkPathController, '本地 APK 路径'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            _buildCompactButton(
              context,
              '安装 APK',
              Icons.file_download_outlined,
              _handleInstallApk,
            ),
            _buildCompactButton(
              context,
              '读取应用',
              Icons.refresh_rounded,
              _handleListPackages,
            ),
            _buildCompactButton(
              context,
              '系统设置',
              Icons.settings_outlined,
              () async => _showResult(await widget.toolsService.openSettings()),
            ),
            _buildCompactButton(
              context,
              '开发者设置',
              Icons.developer_mode_outlined,
              () async =>
                  _showResult(await widget.toolsService.openDeveloperOptions()),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildTextField(context, _packageController, '应用包名'),
            ),
            const SizedBox(width: 8),
            _buildCompactButton(
              context,
              '卸载',
              Icons.delete_outline_rounded,
              _handleUninstallPackage,
            ),
          ],
        ),
        if (_packages.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            height: 100,
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: tokens.bgSecondary,
              borderRadius: BorderRadius.circular(6),
            ),
            child: ListView(
              children: _packages
                  .map(
                    (item) => Text(
                      item,
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRemoteDebug(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                context,
                _remoteAddressController,
                '设备地址，例如 192.168.1.8:5555',
              ),
            ),
            const SizedBox(width: 8),
            _buildCompactButton(
              context,
              '连接',
              Icons.link_rounded,
              _handleRemoteDebug,
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildStatusText(context, '连接后可在设备选择器中使用 ADB 网络设备。'),
      ],
    );
  }

  Widget _buildClipboardControls(BuildContext context) {
    return Column(
      children: [
        _buildTextField(context, _clipboardController, '剪贴板文本', maxLines: 2),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildCompactButton(
              context,
              '粘贴电脑剪贴板',
              Icons.paste_rounded,
              _handlePasteFromComputer,
            ),
            _buildCompactButton(
              context,
              '读取手机',
              Icons.download_rounded,
              _handleGetClipboard,
            ),
            _buildCompactButton(
              context,
              '写入手机',
              Icons.upload_rounded,
              _handleSetClipboard,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildShellControls(BuildContext context) {
    final tokens = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _buildCommandChip(
              context,
              'getprop ro.build.version.release',
              '系统版本',
            ),
            _buildCommandChip(context, 'wm size', '屏幕分辨率'),
            _buildCommandChip(context, 'ip addr show', '网络 IP'),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                context,
                _shellInputController,
                '输入 Shell 命令',
                onSubmitted: (_) => _handleExecuteShell(),
              ),
            ),
            const SizedBox(width: 8),
            _buildCompactButton(
              context,
              '执行',
              Icons.play_arrow_rounded,
              _isExecutingShell ? null : _handleExecuteShell,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          height: 150,
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF070B0E),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: tokens.outline.withValues(alpha: 0.4)),
          ),
          child: _terminalLogs.isEmpty
              ? Text(
                  '# 等待执行命令...',
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                )
              : ListView(
                  children: _terminalLogs
                      .map(
                        (line) => Text(
                          line,
                          style: TextStyle(
                            color: line.startsWith('\$')
                                ? tokens.primary
                                : tokens.textSecondary,
                            fontSize: 11,
                            fontFamily: 'monospace',
                            height: 1.4,
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildInputActionRow(
    BuildContext context,
    TextEditingController controller,
    String hint,
    String actionLabel,
    VoidCallback onPressed,
  ) {
    return Row(
      children: [
        Expanded(
          child: _buildTextField(
            context,
            controller,
            hint,
            onSubmitted: (_) => onPressed(),
          ),
        ),
        const SizedBox(width: 8),
        _buildCompactButton(
          context,
          actionLabel,
          Icons.send_rounded,
          onPressed,
        ),
      ],
    );
  }

  Widget _toolScroll(BuildContext context, List<Widget> children) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          children[i],
        ],
      ],
    );
  }

  Widget _buildCard(
    BuildContext context,
    String title,
    IconData icon,
    Widget child,
  ) {
    final tokens = context.tokens;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: tokens.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildTextField(
    BuildContext context,
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
  }) {
    final tokens = context.tokens;
    return TextField(
      controller: controller,
      maxLines: maxLines,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: TextStyle(color: tokens.textPrimary, fontSize: 12),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: tokens.textSecondary.withValues(alpha: 0.55),
          fontSize: 12,
        ),
        isDense: true,
        filled: true,
        fillColor: tokens.bgSecondary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: BorderSide(color: tokens.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: BorderSide(color: tokens.outline),
        ),
      ),
    );
  }

  Widget _buildCompactButton(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback? onPressed,
  ) {
    final tokens = context.tokens;
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: tokens.textPrimary,
        side: BorderSide(color: tokens.outline),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 16, color: tokens.primary),
      label: Text(label, style: const TextStyle(fontSize: 11)),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback? onPressed,
  ) => _buildCompactButton(context, label, icon, onPressed);

  Widget _buildCommandChip(BuildContext context, String command, String label) {
    final tokens = context.tokens;
    return ActionChip(
      label: Text(
        label,
        style: TextStyle(color: tokens.textPrimary, fontSize: 11),
      ),
      backgroundColor: tokens.bgSecondary,
      side: BorderSide(color: tokens.outline),
      onPressed: () => _handleExecuteShell(command),
    );
  }

  Widget _buildStatusText(BuildContext context, String message) {
    final tokens = context.tokens;
    return Text(
      message,
      style: TextStyle(color: tokens.textSecondary, fontSize: 11),
    );
  }

  Widget _buildInfoGroup(
    BuildContext context,
    String title,
    Map<String, String> values,
  ) {
    final tokens = context.tokens;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tokens.bgSecondary.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: tokens.primary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          for (final entry in values.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  SizedBox(
                    width: 68,
                    child: Text(
                      entry.key,
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      entry.value,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: tokens.textPrimary, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
