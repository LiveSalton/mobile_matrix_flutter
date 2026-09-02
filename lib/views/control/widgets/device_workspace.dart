import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/l10n.dart';
import '../../../models/device_model.dart';
import '../../../models/device_tool_models.dart';
import '../../../models/screen_fps_stats.dart';
import '../../../services/device_control_service.dart';
import '../../../services/device_tool_parsers.dart';
import '../../../services/device_tools_service.dart';
import '../../../services/screen_capture_service.dart';
import '../../../services/screen_stream_service.dart';
import '../../../theme/app_theme.dart';

class DeviceWorkspace extends StatefulWidget {
  final DeviceModel device;
  final IDeviceControlService controlService;
  final DeviceToolsService toolsService;
  final IScreenStreamService streamService;
  final ValueListenable<ScreenFpsStats> fpsStats;
  final VoidCallback onToggleRotation;
  final VoidCallback onToggleScreenVisibility;
  final bool isScreenVisible;

  const DeviceWorkspace({
    super.key,
    required this.device,
    required this.controlService,
    required this.toolsService,
    required this.streamService,
    required this.fpsStats,
    required this.onToggleRotation,
    required this.onToggleScreenVisibility,
    required this.isScreenVisible,
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
  static const _dashboardWideBreakpoint = 640.0;

  L10n get _strings => L10n.current;

  List<_ToolEntry> _tools(L10n strings) => [
    _ToolEntry(
      DeviceToolKind.dashboard,
      strings.dashboard,
      Icons.dashboard_outlined,
    ),
    _ToolEntry(DeviceToolKind.logs, strings.logs, Icons.article_outlined),
    _ToolEntry(
      DeviceToolKind.automation,
      strings.automation,
      Icons.tune_rounded,
    ),
    _ToolEntry(
      DeviceToolKind.explorer,
      strings.file_management,
      Icons.folder_open_outlined,
    ),
    _ToolEntry(
      DeviceToolKind.advanced,
      strings.advanced_features,
      Icons.extension_outlined,
    ),
    _ToolEntry(
      DeviceToolKind.info,
      strings.device_info,
      Icons.info_outline_rounded,
    ),
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
  Timer? _monitorTimer;
  DeviceMonitorSnapshot? _monitorSnapshot;
  final List<double> _cpuHistory = [];
  final List<double> _memoryHistory = [];
  final List<double> _networkHistory = [];
  var _monitorGeneration = 0;

  DeviceToolKind _selectedTool = DeviceToolKind.dashboard;
  DeviceInfoSnapshot? _info;
  String _explorerMessage = '';
  String _portMessage = '';
  bool _isExecutingShell = false;
  bool _isLoading = false;
  bool _isLogcatRunning = false;
  bool _isExplorerLoading = false;
  bool _isCopyingScreenshot = false;
  bool _wifiEnabled = true;
  bool _bluetoothEnabled = true;
  bool _isWifiUpdating = false;
  bool _isBluetoothUpdating = false;
  bool _isMonitorEnabled = false;
  bool _isMonitorLoading = false;
  bool _isDiscoveringRemoteDebug = false;
  String _remoteDebugMessage = '';

  @override
  void initState() {
    super.initState();
    _subscribeLogcat();
  }

  @override
  void didUpdateWidget(covariant DeviceWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    final serviceChanged = !identical(
      oldWidget.toolsService,
      widget.toolsService,
    );
    final deviceChanged = oldWidget.device.serial != widget.device.serial;
    if (serviceChanged || deviceChanged) {
      _logSubscription?.cancel();
      _subscribeLogcat();
      _stopMonitorPolling();
      _monitorGeneration++;
      _monitorSnapshot = null;
      _cpuHistory.clear();
      _memoryHistory.clear();
      _networkHistory.clear();
      _isMonitorLoading = false;
      _remoteDebugMessage = '';
      widget.toolsService.resetMonitorBaseline();
      if (_isMonitorEnabled) _startMonitorPolling();
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

  void _handleMonitorToggle(bool enabled) {
    _stopMonitorPolling();
    _monitorGeneration++;
    widget.toolsService.resetMonitorBaseline();
    setState(() {
      _isMonitorEnabled = enabled;
      _isMonitorLoading = false;
      _monitorSnapshot = null;
      _cpuHistory.clear();
      _memoryHistory.clear();
      _networkHistory.clear();
    });
    if (enabled) _startMonitorPolling();
  }

  void _startMonitorPolling() {
    if (!mounted || !_isMonitorEnabled) return;
    _stopMonitorPolling();
    unawaited(_refreshMonitor());
    _monitorTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(_refreshMonitor()),
    );
  }

  void _stopMonitorPolling() {
    _monitorTimer?.cancel();
    _monitorTimer = null;
  }

  Future<void> _refreshMonitor() async {
    if (!mounted || !_isMonitorEnabled || _isMonitorLoading) return;
    final generation = _monitorGeneration;
    setState(() => _isMonitorLoading = true);

    try {
      final snapshot = await widget.toolsService.readMonitorSnapshot();
      if (!mounted || generation != _monitorGeneration || !_isMonitorEnabled) {
        return;
      }
      setState(() {
        _monitorSnapshot = snapshot;
        _appendMonitorPoint(_cpuHistory, snapshot.cpuPercent, divisor: 100);
        _appendMonitorPoint(
          _memoryHistory,
          snapshot.memoryPercent,
          divisor: 100,
        );
        _appendMonitorPoint(
          _networkHistory,
          snapshot.networkBytesPerSecond,
          clampToUnit: false,
        );
      });
    } finally {
      if (mounted && generation == _monitorGeneration) {
        setState(() => _isMonitorLoading = false);
      }
    }
  }

  void _appendMonitorPoint(
    List<double> history,
    double? value, {
    double divisor = 1,
    bool clampToUnit = true,
  }) {
    if (value == null || !value.isFinite) return;
    final point = value / divisor;
    history.add(clampToUnit ? point.clamp(0.0, 1.0).toDouble() : point);
    if (history.length > 20) history.removeAt(0);
  }

  List<double> _normalizedNetworkHistory() {
    var maximum = 1.0;
    for (final value in _networkHistory) {
      if (value > maximum) maximum = value;
    }
    return List<double>.unmodifiable(
      _networkHistory.map((value) => value / maximum),
    );
  }

  String _formatMonitorPercent(double? value) {
    if (value == null) return '--';
    return '${value.toStringAsFixed(0)}%';
  }

  String _formatMonitorRate(double? bytesPerSecond) {
    if (bytesPerSecond == null) return '--';
    if (bytesPerSecond >= 1024 * 1024) {
      return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
    if (bytesPerSecond >= 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${bytesPerSecond.toStringAsFixed(0)} B/s';
  }

  @override
  void dispose() {
    _stopMonitorPolling();
    _monitorGeneration++;
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
    _appendTerminalLog(_strings.commit_text_log(text));
  }

  Future<void> _handleSetClipboard() async {
    final text = _clipboardController.text;
    if (text.isEmpty) return;
    final pasted = await widget.controlService.pasteText(text);
    if (pasted) widget.streamService.triggerImmediateRefresh();
    _appendTerminalLog(_strings.clipboard_set_log(text));
  }

  Future<void> _handlePasteFromComputer() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) {
      _showMessage(_strings.computer_clipboard_empty);
      return;
    }
    _clipboardController.text = text;
    final pasted = await widget.controlService.pasteText(text);
    if (pasted) widget.streamService.triggerImmediateRefresh();
    _appendTerminalLog(_strings.pasted_clipboard_log(text));
    _showMessage(
      pasted
          ? _strings.clipboard_pasted_to_device
          : _strings.clipboard_paste_failed,
    );
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
    _showResult(
      result,
      successMessage: _strings.third_party_apps_loaded(_packages.length),
    );
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

  Future<void> _handleDiscoverRemoteDebug() async {
    if (_isDiscoveringRemoteDebug) return;
    setState(() {
      _isDiscoveringRemoteDebug = true;
      _remoteDebugMessage = '';
    });

    try {
      final info = await widget.toolsService.discoverRemoteDebugInfo();
      if (!mounted) return;
      if (info.ipAddress != null && info.port != null) {
        _remoteAddressController.text = info.endpoint;
      } else {
        _remoteAddressController.clear();
      }
      final selectedName = info.selectedDeviceName ?? _strings.unknown_device;
      setState(() {
        _remoteDebugMessage =
            info.error ??
            _strings.remote_debug_discovered(
              info.connectedDeviceCount,
              selectedName,
              info.endpoint,
            );
      });
      _showMessage(_remoteDebugMessage);
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _remoteDebugMessage = _strings.remote_debug_read_failed(error),
      );
      _showMessage(_remoteDebugMessage);
    } finally {
      if (mounted) setState(() => _isDiscoveringRemoteDebug = false);
    }
  }

  Future<void> _handleStartLogcat() async {
    await widget.toolsService.startLogcat(filter: _logFilterController.text);
    if (mounted) setState(() => _isLogcatRunning = true);
    _showMessage(_strings.logcat_started);
  }

  Future<void> _handleStopLogcat() async {
    await widget.toolsService.stopLogcat();
    if (mounted) setState(() => _isLogcatRunning = false);
    _showMessage(_strings.logcat_stopped);
  }

  Future<void> _handleCopyLogs() async {
    final text = _filteredLogs.join('\n');
    if (text.isEmpty) {
      _showMessage(_strings.no_logs_to_copy);
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    _showMessage(_strings.logs_copied);
  }

  Future<void> _handleCopyScreenshot() async {
    if (_isCopyingScreenshot) {
      debugPrint('[SCREEN-CAPTURE] ignored duplicate click');
      return;
    }
    debugPrint(
      '[SCREEN-CAPTURE] button pressed serial=${widget.device.serial}',
    );
    setState(() => _isCopyingScreenshot = true);
    try {
      await ScreenCaptureService(
        serial: widget.device.serial,
      ).copyScreenshotToClipboard();
      debugPrint(
        '[SCREEN-CAPTURE] button completed serial=${widget.device.serial}',
      );
      if (mounted) _showMessage(_strings.screenshot_copied);
    } catch (error, stackTrace) {
      debugPrint(
        '[SCREEN-CAPTURE] button failed '
        'serial=${widget.device.serial} error=$error',
      );
      debugPrintStack(label: '[SCREEN-CAPTURE] stack', stackTrace: stackTrace);
      if (mounted) _showMessage('$error');
    } finally {
      if (mounted) setState(() => _isCopyingScreenshot = false);
    }
  }

  Future<void> _handleRingerMode(DeviceRingerMode mode) async {
    _showResult(await widget.toolsService.setRingerMode(mode));
  }

  Future<void> _handleWifi(bool enabled) async {
    if (_isWifiUpdating) return;
    setState(() => _isWifiUpdating = true);
    try {
      final result = await widget.toolsService.setWifiEnabled(enabled);
      if (result.success && mounted) setState(() => _wifiEnabled = enabled);
      _showResult(result);
    } finally {
      if (mounted) setState(() => _isWifiUpdating = false);
    }
  }

  Future<void> _handleBluetooth(bool enabled) async {
    if (_isBluetoothUpdating) return;
    setState(() => _isBluetoothUpdating = true);
    try {
      final result = await widget.toolsService.setBluetoothEnabled(enabled);
      if (result.success && mounted) {
        setState(() => _bluetoothEnabled = enabled);
      }
      _showResult(result);
    } finally {
      if (mounted) setState(() => _isBluetoothUpdating = false);
    }
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
          ? _strings.file_count(_files.length)
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
      _showMessage(_strings.local_destination_required);
      return;
    }
    _showResult(
      await widget.toolsService.pullFile(entry.path, destination),
      successMessage: _strings.file_pulled(destination),
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
    final strings = _strings;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.restart_device),
        content: Text(strings.restart_confirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(strings.restart),
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
    final strings = L10n.of(context);
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF090D16).withValues(alpha: 0.95),
        border: Border(
          bottom: BorderSide(color: tokens.outline.withValues(alpha: 0.65)),
        ),
      ),
      child: Row(
        children: [
          // 设备型号药丸徽标
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: tokens.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: tokens.primary.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.smartphone_rounded,
                    size: 14,
                    color: tokens.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.device.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // 物理分辨率胶囊
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: tokens.bgSecondary.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: tokens.outline.withValues(alpha: 0.4)),
            ),
            child: Text(
              '${widget.device.display.width}×${widget.device.display.height}',
              style: TextStyle(
                color: tokens.textSecondary,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 8),

          // FPS 位于分辨率之后，作为左侧信息的最后一项
          ValueListenableBuilder<ScreenFpsStats>(
            valueListenable: widget.fpsStats,
            builder: (context, stats, _) => _buildFpsIndicator(stats, tokens),
          ),
          const Spacer(),

          // 横屏、显隐和复制截屏放在同一组
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: tokens.bgSecondary.withValues(alpha: 0.46),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: tokens.outline.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildInfoActionButton(
                  tooltip: widget.device.display.isLandscape
                      ? strings.switch_to_portrait
                      : strings.switch_to_landscape,
                  icon: widget.device.display.isLandscape
                      ? Icons.stay_current_landscape_rounded
                      : Icons.stay_current_portrait_rounded,
                  color: tokens.primary,
                  onPressed: widget.onToggleRotation,
                ),
                _buildInfoActionButton(
                  tooltip: _wifiEnabled
                      ? strings.disable_wifi
                      : strings.enable_wifi,
                  icon: _wifiEnabled
                      ? Icons.wifi_rounded
                      : Icons.wifi_off_rounded,
                  color: _wifiEnabled ? tokens.primary : tokens.textSecondary,
                  onPressed: _isWifiUpdating
                      ? null
                      : () => _handleWifi(!_wifiEnabled),
                ),
                _buildInfoActionButton(
                  tooltip: _bluetoothEnabled
                      ? strings.disable_bluetooth
                      : strings.enable_bluetooth,
                  icon: _bluetoothEnabled
                      ? Icons.bluetooth_rounded
                      : Icons.bluetooth_disabled_rounded,
                  color: _bluetoothEnabled
                      ? tokens.primary
                      : tokens.textSecondary,
                  onPressed: _isBluetoothUpdating
                      ? null
                      : () => _handleBluetooth(!_bluetoothEnabled),
                ),
                _buildInfoActionButton(
                  tooltip: widget.isScreenVisible
                      ? strings.hide_screen
                      : strings.show_screen,
                  icon: widget.isScreenVisible
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                  color: widget.isScreenVisible
                      ? tokens.primary
                      : tokens.textSecondary,
                  onPressed: widget.onToggleScreenVisibility,
                ),
                _buildInfoActionButton(
                  tooltip: strings.copy_screenshot,
                  icon: Icons.content_copy_outlined,
                  color: tokens.primary,
                  onPressed: _isCopyingScreenshot
                      ? null
                      : _handleCopyScreenshot,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoActionButton({
    required String tooltip,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: 17),
        style: IconButton.styleFrom(
          foregroundColor: color,
          padding: const EdgeInsets.all(6),
          minimumSize: const Size(32, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        ),
      ),
    );
  }

  Color _getFpsColor(int fps, AppColorTokens tokens) {
    if (fps >= 45) return const Color(0xFF00D591);
    if (fps >= 25) return tokens.warning;
    return tokens.danger;
  }

  Widget _buildFpsIndicator(ScreenFpsStats stats, AppColorTokens tokens) {
    final color = _getFpsColor(stats.rendered, tokens);
    return SizedBox(
      width: 76,
      height: 28,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
            const SizedBox(width: 5),
            Text(
              '${stats.rendered} FPS',
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigation(BuildContext context) {
    final tokens = context.tokens;
    final strings = L10n.of(context);
    final tools = _tools(strings);
    return Container(
      color: const Color(0xFF080C14),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: ListView.separated(
        itemCount: tools.length,
        separatorBuilder: (_, _) => const SizedBox(height: 4),
        itemBuilder: (context, index) {
          final entry = tools[index];
          final selected = entry.kind == _selectedTool;
          return Tooltip(
            message: entry.label,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _selectedTool = entry.kind),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? tokens.primary.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected
                        ? tokens.primary.withValues(alpha: 0.55)
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      entry.icon,
                      size: 16,
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
      DeviceToolKind.automation => _buildAutomation(context),
      DeviceToolKind.explorer => _buildExplorer(context),
      DeviceToolKind.advanced => _buildAdvanced(context),
      DeviceToolKind.info => _buildInfo(context),
    };
  }

  Widget _buildDashboard(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _dashboardWideBreakpoint;

        if (!isWide) {
          return _toolScroll(context, [
            _buildQuickControlDeck(context),
            _buildSystemMonitorCard(context),
            _buildUrlLauncherCard(context),
            _buildSmartInputCard(context),
            _buildClipboardCard(context),
            _buildShellCard(context),
            _buildAppManagementCard(context),
            _buildRemoteDebugCard(context),
          ]);
        }

        return _toolScroll(context, [_buildDashboardColumns(context)]);
      },
    );
  }

  Widget _buildDashboardColumns(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildQuickControlDeck(context),
              const SizedBox(height: 14),
              _buildUrlLauncherCard(context),
              const SizedBox(height: 14),
              _buildSmartInputCard(context),
              const SizedBox(height: 14),
              _buildAppManagementCard(context),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSystemMonitorCard(context),
              const SizedBox(height: 14),
              _buildClipboardCard(context),
              const SizedBox(height: 14),
              _buildShellCard(context),
              const SizedBox(height: 14),
              _buildRemoteDebugCard(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickControlDeck(BuildContext context) {
    final tokens = context.tokens;
    final strings = L10n.of(context);

    return _buildModernCard(
      context: context,
      title: strings.quick_control,
      subtitle: strings.hardware_controls,
      icon: Icons.tune_rounded,
      accentColor: tokens.primary,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = 8.0;
          final buttonSize = math.min(
            88.0,
            math.max(0.0, (constraints.maxWidth - gap * 3) / 4),
          );
          return SizedBox(
            height: buttonSize,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SizedBox(
                  width: buttonSize,
                  height: buttonSize,
                  child: _buildTactileButton(
                    tooltip: strings.power,
                    icon: Icons.power_settings_new_rounded,
                    color: tokens.danger,
                    onPressed: () =>
                        widget.controlService.keyPress(DeviceKeyAction.power),
                  ),
                ),
                SizedBox(
                  width: buttonSize,
                  height: buttonSize,
                  child: _buildTactileButton(
                    tooltip: strings.volume_up,
                    icon: Icons.volume_up_rounded,
                    color: tokens.primary,
                    onPressed: () => widget.controlService.keyPress(
                      DeviceKeyAction.volumeUp,
                    ),
                  ),
                ),
                SizedBox(
                  width: buttonSize,
                  height: buttonSize,
                  child: _buildTactileButton(
                    tooltip: strings.volume_down,
                    icon: Icons.volume_down_rounded,
                    color: tokens.primary,
                    onPressed: () => widget.controlService.keyPress(
                      DeviceKeyAction.volumeDown,
                    ),
                  ),
                ),
                SizedBox(
                  width: buttonSize,
                  height: buttonSize,
                  child: _buildTactileButton(
                    tooltip: strings.rotate_screen,
                    icon: Icons.screen_rotation_rounded,
                    color: const Color(0xFF00D591),
                    onPressed: widget.onToggleRotation,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSystemMonitorCard(BuildContext context) {
    final tokens = context.tokens;
    final strings = L10n.of(context);
    final snapshot = _monitorSnapshot;
    final networkPoints = _normalizedNetworkHistory();

    return SizedBox(
      height: 232,
      child: _buildModernCard(
        context: context,
        title: strings.system_monitor,
        subtitle: _isMonitorEnabled
            ? (_isMonitorLoading
                  ? strings.monitor_reading
                  : strings.monitor_sampling)
            : strings.monitor_disabled,
        icon: Icons.show_chart_rounded,
        accentColor: const Color(0xFF00D591),
        headerTrailing: Tooltip(
          message: _isMonitorEnabled
              ? strings.close_system_monitor
              : strings.open_system_monitor,
          child: Semantics(
            label: strings.system_monitor_accessibility,
            toggled: _isMonitorEnabled,
            child: Switch(
              value: _isMonitorEnabled,
              onChanged: _handleMonitorToggle,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              activeThumbColor: const Color(0xFF00D591),
              activeTrackColor: const Color(0xFF00D591).withValues(alpha: 0.28),
              inactiveThumbColor: tokens.textSecondary,
              inactiveTrackColor: tokens.outline.withValues(alpha: 0.35),
            ),
          ),
        ),
        child: Column(
          children: [
            _buildMonitorRow(
              context: context,
              label: strings.cpu,
              value: _formatMonitorPercent(snapshot?.cpuPercent),
              color: const Color(0xFF00D591),
              dataPoints: List<double>.unmodifiable(_cpuHistory),
            ),
            const SizedBox(height: 12),
            _buildMonitorRow(
              context: context,
              label: strings.memory,
              value: _formatMonitorPercent(snapshot?.memoryPercent),
              color: tokens.primary,
              dataPoints: List<double>.unmodifiable(_memoryHistory),
            ),
            const SizedBox(height: 12),
            _buildMonitorRow(
              context: context,
              label: strings.network,
              value: _formatMonitorRate(snapshot?.networkBytesPerSecond),
              color: tokens.warning,
              dataPoints: networkPoints,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonitorRow({
    required BuildContext context,
    required String label,
    required String value,
    required Color color,
    required List<double> dataPoints,
  }) {
    final tokens = context.tokens;
    return Row(
      children: [
        SizedBox(
          width: 58,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: tokens.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF060910),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: tokens.outline.withValues(alpha: 0.3)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: CustomPaint(
                painter: _SparklinePainter(color: color, points: dataPoints),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUrlLauncherCard(BuildContext context) {
    final tokens = context.tokens;
    final strings = L10n.of(context);

    return _buildModernCard(
      context: context,
      title: strings.url_deeplink_launcher,
      subtitle: strings.url_deeplink_subtitle,
      icon: Icons.language_rounded,
      accentColor: tokens.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  context,
                  _urlController,
                  strings.url_deeplink_hint,
                  onSubmitted: (_) => _handleOpenUrl(),
                ),
              ),
              const SizedBox(width: 8),
              _buildCompactButton(
                context,
                strings.open,
                Icons.open_in_new_rounded,
                _handleOpenUrl,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildPresetBadge(
                context,
                Icons.download_rounded,
                strings.downloaded,
                'https://github.com',
              ),
              _buildPresetBadge(
                context,
                Icons.apps_rounded,
                strings.apps,
                'market://details?id=com.tencent.mm',
              ),
              _buildPresetBadge(
                context,
                Icons.menu_book_rounded,
                strings.books,
                'https://m.bilibili.com',
              ),
              _buildPresetBadge(
                context,
                Icons.check_circle_outline_rounded,
                strings.store,
                'https://www.baidu.com',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPresetBadge(
    BuildContext context,
    IconData icon,
    String label,
    String url,
  ) {
    final tokens = context.tokens;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () {
        _urlController.text = url;
        _handleOpenUrl();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF101726),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: tokens.primary.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: tokens.primary),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmartInputCard(BuildContext context) {
    final tokens = context.tokens;
    final strings = L10n.of(context);

    return _buildModernCard(
      context: context,
      title: strings.smart_input_hub,
      subtitle: strings.smart_input_subtitle,
      icon: Icons.keyboard_alt_outlined,
      accentColor: const Color(0xFF00D591),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 文本输入框与发送
          _buildInputActionRow(
            context,
            _typeInputController,
            strings.realtime_text_hint,
            strings.send,
            _handleSendText,
          ),
          const SizedBox(height: 10),

          // 方案 B 核心：大面积翡翠绿发光【一键粘贴电脑剪贴板】按钮
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _handlePasteFromComputer,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF00D591).withValues(alpha: 0.16),
                    const Color(0xFF00B578).withValues(alpha: 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF00D591).withValues(alpha: 0.65),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00D591).withValues(alpha: 0.15),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.content_paste_rounded,
                    size: 16,
                    color: Color(0xFF00D591),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      strings.paste_computer_clipboard,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF00D591),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 常用快捷短语列表
          Text(
            strings.common_test_phrases,
            style: TextStyle(
              color: tokens.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          _buildPhraseSnippetRow(context, strings.sample_phone),
          const SizedBox(height: 4),
          _buildPhraseSnippetRow(context, strings.sample_email),
          const SizedBox(height: 4),
          _buildPhraseSnippetRow(context, strings.sample_greeting),
        ],
      ),
    );
  }

  Widget _buildPhraseSnippetRow(BuildContext context, String phrase) {
    final tokens = context.tokens;
    final strings = L10n.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1019),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: tokens.outline.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '"$phrase"',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ),
          InkWell(
            onTap: () {
              widget.controlService.typeText(phrase);
              widget.streamService.triggerImmediateRefresh();
              _appendTerminalLog(strings.injected_phrase_log(phrase));
            },
            child: Icon(Icons.send_rounded, size: 13, color: tokens.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildClipboardCard(BuildContext context) {
    final strings = L10n.of(context);
    return _buildModernCard(
      context: context,
      title: strings.advanced_clipboard_hub,
      subtitle: strings.clipboard_subtitle,
      icon: Icons.content_paste_rounded,
      accentColor: const Color(0xFF00D591),
      child: _buildClipboardControls(context),
    );
  }

  Widget _buildShellCard(BuildContext context) {
    final tokens = context.tokens;
    final strings = L10n.of(context);
    return _buildModernCard(
      context: context,
      title: strings.adb_shell_title,
      subtitle: strings.adb_shell_subtitle,
      icon: Icons.terminal_rounded,
      accentColor: tokens.primary,
      child: _buildShellControls(context),
    );
  }

  Widget _buildAppManagementCard(BuildContext context) {
    final tokens = context.tokens;
    final strings = L10n.of(context);
    return _buildModernCard(
      context: context,
      title: strings.app_management_title,
      subtitle: strings.app_management_subtitle,
      icon: Icons.apps_outlined,
      accentColor: tokens.primary,
      child: _buildAppManagement(context),
    );
  }

  Widget _buildRemoteDebugCard(BuildContext context) {
    final tokens = context.tokens;
    final strings = L10n.of(context);
    return _buildModernCard(
      context: context,
      title: strings.remote_debug_title,
      subtitle: strings.remote_debug_subtitle,
      icon: Icons.wifi_tethering_outlined,
      accentColor: tokens.warning,
      child: _buildRemoteDebug(context),
    );
  }

  Widget _buildModernCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    Widget? headerTrailing,
    required Widget child,
  }) {
    final tokens = context.tokens;
    final trailing = headerTrailing;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B1019), Color(0xFF0E1524)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.outline.withValues(alpha: 0.75)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                ),
                child: Icon(icon, size: 15, color: accentColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.textSecondary.withValues(alpha: 0.8),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing],
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildTactileButton({
    required String tooltip,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 350),
      child: SizedBox.expand(
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF161F30), Color(0xFF0F1726)],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.42)),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Semantics(
              button: true,
              label: tooltip,
              child: Center(child: Icon(icon, size: 26, color: color)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogs(BuildContext context) {
    final tokens = context.tokens;
    final strings = L10n.of(context);
    final logs = _filteredLogs;
    return _toolScroll(context, [
      _buildCard(
        context,
        strings.logcat_logs,
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
                  _isLogcatRunning ? strings.stop : strings.start,
                  _isLogcatRunning
                      ? Icons.stop_circle_outlined
                      : Icons.play_circle_outline,
                  _isLogcatRunning ? _handleStopLogcat : _handleStartLogcat,
                ),
                _buildCompactButton(
                  context,
                  strings.clear,
                  Icons.delete_sweep_outlined,
                  () => setState(() => _logLines.clear()),
                ),
                _buildCompactButton(
                  context,
                  strings.copy,
                  Icons.copy_outlined,
                  _handleCopyLogs,
                ),
                SizedBox(
                  width: 220,
                  child: _buildTextField(
                    context,
                    _logFilterController,
                    strings.filter_keywords,
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
                      strings.logcat_waiting,
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

  Widget _buildAutomation(BuildContext context) {
    final strings = L10n.of(context);
    return _toolScroll(context, [
      _buildCard(
        context,
        strings.device_settings,
        Icons.tune_rounded,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              children: [
                _buildCompactButton(
                  context,
                  strings.silent,
                  Icons.volume_off_outlined,
                  () => _handleRingerMode(DeviceRingerMode.silent),
                ),
                _buildCompactButton(
                  context,
                  strings.vibrate,
                  Icons.vibration_outlined,
                  () => _handleRingerMode(DeviceRingerMode.vibrate),
                ),
                _buildCompactButton(
                  context,
                  strings.ring,
                  Icons.notifications_active_outlined,
                  () => _handleRingerMode(DeviceRingerMode.normal),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildCompactButton(
              context,
              strings.clear_bluetooth_bonds,
              Icons.bluetooth_disabled_outlined,
              () async =>
                  _showResult(await widget.toolsService.clearBluetoothBonds()),
            ),
          ],
        ),
      ),
      _buildCard(
        context,
        strings.store_account,
        Icons.account_circle_outlined,
        Column(
          children: [
            _buildTextField(context, _accountController, strings.account_name),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildCompactButton(
                  context,
                  strings.view_accounts,
                  Icons.visibility_outlined,
                  () async =>
                      _showResult(await widget.toolsService.getStoreAccounts()),
                ),
                _buildCompactButton(
                  context,
                  strings.check,
                  Icons.search_rounded,
                  _handleAccountCheck,
                ),
                _buildCompactButton(
                  context,
                  strings.remove,
                  Icons.person_remove_outlined,
                  _handleAccountRemove,
                ),
                _buildCompactButton(
                  context,
                  strings.add_account,
                  Icons.person_add_outlined,
                  () async =>
                      _showResult(await widget.toolsService.addStoreAccount()),
                ),
                _buildCompactButton(
                  context,
                  strings.open_app_store,
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
    final strings = L10n.of(context);
    return _toolScroll(context, [
      _buildCard(
        context,
        strings.file_browser,
        Icons.folder_open_outlined,
        Column(
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: strings.parent_directory,
                  onPressed: _handleExplorerUp,
                  icon: const Icon(Icons.arrow_upward_rounded),
                ),
                Expanded(
                  child: _buildTextField(
                    context,
                    _explorerPathController,
                    strings.device_path,
                    onSubmitted: (_) => _handleListDirectory(),
                  ),
                ),
                const SizedBox(width: 8),
                _buildCompactButton(
                  context,
                  strings.enter,
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
                    ? strings.device_path_hint
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
                        strings.no_directory_content,
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
                            file.isDirectory
                                ? strings.directory
                                : strings.file_size_bytes(file.size),
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
                                  tooltip: strings.pull_file,
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
              strings.local_file_pull_path,
            ),
          ],
        ),
      ),
    ]);
  }

  Widget _buildAdvanced(BuildContext context) {
    final strings = L10n.of(context);
    return _toolScroll(context, [
      _buildCard(
        context,
        strings.special_keys,
        Icons.keyboard_command_key_outlined,
        _buildAdvancedKeys(context),
      ),
      _buildCard(
        context,
        strings.port_forwarding,
        Icons.compare_arrows_outlined,
        Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    context,
                    _hostPortController,
                    strings.local_port,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTextField(
                    context,
                    _devicePortController,
                    strings.device_port,
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
                  strings.create,
                  Icons.add_link_rounded,
                  _handleCreateForward,
                ),
                _buildCompactButton(
                  context,
                  strings.remove,
                  Icons.link_off_rounded,
                  _handleRemoveForward,
                ),
                _buildCompactButton(
                  context,
                  strings.view,
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
        strings.device_maintenance,
        Icons.build_outlined,
        _buildCompactButton(
          context,
          strings.restart_device,
          Icons.restart_alt_rounded,
          _handleReboot,
        ),
      ),
    ]);
  }

  Widget _buildInfo(BuildContext context) {
    final strings = L10n.of(context);
    if (_info == null && !_isLoading) {
      return _toolScroll(context, [
        _buildCard(
          context,
          strings.device_info,
          Icons.info_outline_rounded,
          _buildCompactButton(
            context,
            strings.read_device_info,
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
        strings.device_info,
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
                      strings.refresh,
                      Icons.refresh_rounded,
                      _handleLoadInfo,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildInfoGroup(context, strings.hardware, {
                    strings.manufacturer:
                        info?.value('manufacturer') ?? strings.unknown,
                    strings.model: info?.value('model') ?? strings.unknown,
                    strings.product: info?.value('product') ?? strings.unknown,
                    strings.serial_number:
                        info?.value('serial') ?? widget.device.serial,
                  }),
                  _buildInfoGroup(context, strings.platform, {
                    strings.android: info?.value('android') ?? strings.unknown,
                    strings.sdk: info?.value('sdk') ?? strings.unknown,
                    strings.abi: info?.value('abi') ?? strings.unknown,
                  }),
                  _buildInfoGroup(context, strings.display, {
                    strings.resolution:
                        info?.value('display') ?? strings.unknown,
                    strings.density: info?.value('density') ?? strings.unknown,
                    'FPS': widget.device.display.fps.toStringAsFixed(0),
                  }),
                  _buildInfoGroup(context, strings.battery, {
                    strings.battery_level:
                        info?.value('batteryLevel') == strings.unknown
                        ? strings.unknown
                        : '${info?.value('batteryLevel')}%',
                    strings.battery_status:
                        info?.value('batteryStatus') ?? strings.unknown,
                    strings.temperature:
                        info?.value('batteryTemperature') == strings.unknown
                        ? strings.unknown
                        : '${info?.value('batteryTemperature')} / 10 °C',
                  }),
                  _buildInfoGroup(context, strings.network_sim, {
                    strings.ip: info?.value('network') ?? strings.unknown,
                    strings.carrier: info?.value('carrier') ?? strings.unknown,
                    strings.sim_country:
                        info?.value('simCountry') ?? strings.unknown,
                    strings.imei: info?.value('imei') ?? strings.unknown,
                  }),
                  _buildInfoGroup(context, strings.cpu_memory, {
                    strings.cpu: info?.value('cpuName') ?? strings.unknown,
                    strings.core_count:
                        info?.value('cpuCores') ?? strings.unknown,
                    strings.memory: info?.value('memory') ?? strings.unknown,
                    strings.storage: info?.value('storage') ?? strings.unknown,
                  }),
                ],
              ),
      ),
    ]);
  }

  Widget _buildAdvancedKeys(BuildContext context) {
    final strings = L10n.of(context);
    final actions = <(String, IconData, DeviceKeyAction)>[
      (strings.camera, Icons.camera_alt_outlined, DeviceKeyAction.camera),
      (strings.search, Icons.search_rounded, DeviceKeyAction.search),
      (
        strings.switch_input_method,
        Icons.language_rounded,
        DeviceKeyAction.switchCharset,
      ),
      (strings.silent, Icons.volume_off_outlined, DeviceKeyAction.mute),
      (
        strings.back,
        Icons.skip_previous_rounded,
        DeviceKeyAction.mediaPrevious,
      ),
      (
        strings.play_pause,
        Icons.play_arrow_rounded,
        DeviceKeyAction.mediaPlayPause,
      ),
      (strings.stop, Icons.stop_rounded, DeviceKeyAction.mediaStop),
      (strings.next, Icons.skip_next_rounded, DeviceKeyAction.mediaNext),
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
    final strings = L10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(context, _apkPathController, strings.apk_path_hint),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            _buildCompactButton(
              context,
              strings.install_apk,
              Icons.file_download_outlined,
              _handleInstallApk,
            ),
            _buildCompactButton(
              context,
              strings.read_apps,
              Icons.refresh_rounded,
              _handleListPackages,
            ),
            _buildCompactButton(
              context,
              strings.system_settings,
              Icons.settings_outlined,
              () async => _showResult(await widget.toolsService.openSettings()),
            ),
            _buildCompactButton(
              context,
              strings.developer_settings,
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
              child: _buildTextField(
                context,
                _packageController,
                strings.package_name_hint,
              ),
            ),
            const SizedBox(width: 8),
            _buildCompactButton(
              context,
              strings.uninstall,
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
    final strings = L10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(
          context,
          _remoteAddressController,
          strings.remote_address_hint,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildCompactButton(
              context,
              _isDiscoveringRemoteDebug
                  ? strings.reading
                  : strings.read_local_device,
              Icons.devices_other_outlined,
              _isDiscoveringRemoteDebug ? null : _handleDiscoverRemoteDebug,
            ),
            _buildCompactButton(
              context,
              strings.connect,
              Icons.link_rounded,
              _handleRemoteDebug,
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildStatusText(
          context,
          _remoteDebugMessage.isEmpty
              ? strings.remote_debug_hint
              : _remoteDebugMessage,
        ),
      ],
    );
  }

  Widget _buildClipboardControls(BuildContext context) {
    final strings = L10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(
          context,
          _clipboardController,
          strings.clipboard_text_hint,
          maxLines: 2,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildCompactButton(
              context,
              strings.paste_computer_clipboard,
              Icons.paste_rounded,
              _handlePasteFromComputer,
            ),
            _buildCompactButton(
              context,
              strings.read_phone,
              Icons.download_rounded,
              _handleGetClipboard,
            ),
            _buildCompactButton(
              context,
              strings.write_phone,
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
    final strings = L10n.of(context);
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
              strings.system_version,
            ),
            _buildCommandChip(context, 'wm size', strings.screen_resolution),
            _buildCommandChip(context, 'ip addr show', strings.network_ip),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                context,
                _shellInputController,
                strings.shell_command_hint,
                onSubmitted: (_) => _handleExecuteShell(),
              ),
            ),
            const SizedBox(width: 8),
            _buildCompactButton(
              context,
              strings.execute,
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
                  strings.shell_waiting,
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
      padding: const EdgeInsets.all(18),
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surfaceElevated.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.outline.withValues(alpha: 0.82)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: tokens.primary.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 16, color: tokens.primary),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
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
        fillColor: tokens.bgSecondary.withValues(alpha: 0.72),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 11,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: tokens.outline.withValues(alpha: 0.9)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: tokens.outline.withValues(alpha: 0.9)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: tokens.primary, width: 1.4),
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
        side: BorderSide(color: tokens.outline.withValues(alpha: 0.92)),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        minimumSize: const Size(0, 42),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        overlayColor: tokens.highlight.withValues(alpha: 0.22),
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

class _SparklinePainter extends CustomPainter {
  final Color color;
  final List<double> points;

  _SparklinePainter({required this.color, required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final path = Path();
    final fillPath = Path();
    final widthStep = size.width / (points.length - 1);

    for (var i = 0; i < points.length; i++) {
      final x = i * widthStep;
      final clamped = points[i].clamp(0.0, 1.0);
      final y = size.height - (clamped * (size.height - 4) + 2);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    final strokePaint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.color != color ||
        !listEquals(oldDelegate.points, points);
  }
}
