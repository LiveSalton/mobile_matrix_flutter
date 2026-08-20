import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/device_model.dart';
import '../../../services/device_control_service.dart';
import '../../../services/screen_stream_service.dart';
import '../../../theme/app_theme.dart';

enum WorkspaceMode { batchExecution, deviceTools }

class DeviceWorkspace extends StatefulWidget {
  final DeviceModel device;
  final IDeviceControlService controlService;
  final IScreenStreamService streamService;

  const DeviceWorkspace({
    super.key,
    required this.device,
    required this.controlService,
    required this.streamService,
  });

  @override
  State<DeviceWorkspace> createState() => _DeviceWorkspaceState();
}

class _DeviceWorkspaceState extends State<DeviceWorkspace> {
  WorkspaceMode _currentMode = WorkspaceMode.deviceTools;

  // 剪贴板
  final TextEditingController _clipboardController = TextEditingController();
  // 打字输入
  final TextEditingController _typeInputController = TextEditingController();
  // Shell 命令
  final TextEditingController _shellInputController = TextEditingController();
  final List<String> _terminalLogs = [];
  bool _isExecutingShell = false;

  @override
  void dispose() {
    _clipboardController.dispose();
    _typeInputController.dispose();
    _shellInputController.dispose();
    super.dispose();
  }

  Future<void> _handleSendText() async {
    final text = _typeInputController.text;
    if (text.isEmpty) return;
    final sent = await widget.controlService.typeText(text);
    if (sent) {
      widget.streamService.triggerImmediateRefresh();
    }
    _typeInputController.clear();
    _appendLog('Commit Text: "$text"');
  }

  Future<void> _handleSetClipboard() async {
    final text = _clipboardController.text;
    if (text.isEmpty) return;
    final pasted = await widget.controlService.pasteText(text);
    if (pasted) {
      widget.streamService.triggerImmediateRefresh();
    }
    _appendLog('Clipboard Set: "$text"');
  }

  Future<void> _handlePasteFromComputer() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text != null && text.isNotEmpty) {
      _clipboardController.text = text;
      final pasted = await widget.controlService.pasteText(text);
      if (pasted) {
        widget.streamService.triggerImmediateRefresh();
      }
      _appendLog('Pasted from Mac Clipboard: "$text"');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已成功将电脑剪贴板内容注入手机！'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('电脑剪贴板当前为空'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }

  Future<void> _handleGetClipboard() async {
    final text = await widget.controlService.getClipboard();
    if (text != null) {
      _clipboardController.text = text;
      _appendLog('Clipboard Fetched: "$text"');
    }
  }

  Future<void> _handleExecuteShell([String? customCmd]) async {
    final cmd = (customCmd ?? _shellInputController.text).trim();
    if (cmd.isEmpty) return;

    setState(() {
      _isExecutingShell = true;
    });

    _appendLog('\$ $cmd');
    final res = await widget.controlService.executeShell(cmd);
    _appendLog(res.trimRight());

    setState(() {
      _isExecutingShell = false;
    });
    _shellInputController.clear();
  }

  void _appendLog(String line) {
    setState(() {
      _terminalLogs.add(line);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Container(
      color: tokens.bg,
      child: Column(
        children: [
          // 顶部工作区模式切换
          _buildModeTabBar(context),

          // 核心内容区
          Expanded(
            child: _currentMode == WorkspaceMode.deviceTools
                ? _buildToolsDashboard(context)
                : _buildBatchExecutionWizard(context),
          ),
        ],
      ),
    );
  }

  Widget _buildModeTabBar(BuildContext context) {
    final tokens = context.tokens;

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(bottom: BorderSide(color: tokens.outline, width: 1)),
      ),
      child: Row(
        children: [
          _buildModeTabButton(
            title: '设备工具箱',
            icon: Icons.build_circle_outlined,
            mode: WorkspaceMode.deviceTools,
            tokens: tokens,
          ),
          const SizedBox(width: 8),
          _buildModeTabButton(
            title: '群控执行向导',
            icon: Icons.layers_outlined,
            mode: WorkspaceMode.batchExecution,
            tokens: tokens,
          ),
        ],
      ),
    );
  }

  Widget _buildModeTabButton({
    required String title,
    required IconData icon,
    required WorkspaceMode mode,
    required AppColorTokens tokens,
  }) {
    final isSelected = _currentMode == mode;

    return InkWell(
      onTap: () {
        setState(() {
          _currentMode = mode;
        });
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? tokens.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? tokens.primary : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? tokens.primary : tokens.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? tokens.primary : tokens.textSecondary,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolsDashboard(BuildContext context) {
    final tokens = context.tokens;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 快捷物理硬件按键
        _buildCard(
          context: context,
          title: '硬件物理按键',
          icon: Icons.power_settings_new_rounded,
          child: Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  context: context,
                  label: '电源键',
                  icon: Icons.power_settings_new_rounded,
                  onPressed: () =>
                      widget.controlService.keyPress(DeviceKeyAction.power),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionButton(
                  context: context,
                  label: '音量 +',
                  icon: Icons.volume_up_rounded,
                  onPressed: () =>
                      widget.controlService.keyPress(DeviceKeyAction.volumeUp),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionButton(
                  context: context,
                  label: '音量 -',
                  icon: Icons.volume_down_rounded,
                  onPressed: () => widget.controlService.keyPress(
                    DeviceKeyAction.volumeDown,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 文本快速注入 (Type Input)
        _buildCard(
          context: context,
          title: '输入法文本注入',
          icon: Icons.keyboard_alt_outlined,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _typeInputController,
                  style: TextStyle(color: tokens.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: '输入要发送到真机的内容...',
                    hintStyle: TextStyle(
                      color: tokens.textSecondary.withValues(alpha: 0.5),
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    filled: true,
                    fillColor: tokens.bgSecondary,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: tokens.outline),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: tokens.outline),
                    ),
                  ),
                  onSubmitted: (_) => _handleSendText(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: tokens.primary,
                  foregroundColor: tokens.textPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                icon: const Icon(Icons.send_rounded, size: 16),
                label: const Text('发送'),
                onPressed: _handleSendText,
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 剪贴板双向同步
        _buildCard(
          context: context,
          title: '剪贴板双向同步',
          icon: Icons.content_paste_rounded,
          child: Column(
            children: [
              TextField(
                controller: _clipboardController,
                maxLines: 2,
                style: TextStyle(color: tokens.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: '剪贴板文本...',
                  hintStyle: TextStyle(
                    color: tokens.textSecondary.withValues(alpha: 0.5),
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.all(10),
                  filled: true,
                  fillColor: tokens.bgSecondary,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: tokens.outline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: tokens.outline),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: tokens.primary.withValues(alpha: 0.5),
                      ),
                      backgroundColor: tokens.primary.withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    icon: Icon(
                      Icons.paste_rounded,
                      size: 16,
                      color: tokens.primary,
                    ),
                    label: Text(
                      '📋 粘贴电脑剪贴板到手机',
                      style: TextStyle(
                        color: tokens.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: _handlePasteFromComputer,
                  ),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: tokens.outline),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        icon: Icon(
                          Icons.download_rounded,
                          size: 16,
                          color: tokens.textSecondary,
                        ),
                        label: Text(
                          '读取手机',
                          style: TextStyle(
                            color: tokens.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        onPressed: _handleGetClipboard,
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: tokens.primary,
                          foregroundColor: tokens.textPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        icon: const Icon(Icons.upload_rounded, size: 16),
                        label: const Text(
                          '写入手机',
                          style: TextStyle(fontSize: 12),
                        ),
                        onPressed: _handleSetClipboard,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ADB Shell 终端控制台
        _buildCard(
          context: context,
          title: 'ADB Shell 终端控制台',
          icon: Icons.terminal_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 快捷常用命令 Chip
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildCommandChip(
                    'getprop ro.build.version.release',
                    '获取系统版本',
                  ),
                  _buildCommandChip('wm size', '获取屏幕物理分辨率'),
                  _buildCommandChip('ip addr show', '查看网络 IP'),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _shellInputController,
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                      decoration: InputDecoration(
                        hintText: '输入 Shell 命令...',
                        hintStyle: TextStyle(
                          color: tokens.textSecondary.withValues(alpha: 0.5),
                        ),
                        prefixText: '\$ ',
                        prefixStyle: TextStyle(
                          color: tokens.primary,
                          fontWeight: FontWeight.bold,
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        filled: true,
                        fillColor: tokens.bgSecondary,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: tokens.outline),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: tokens.outline),
                        ),
                      ),
                      onSubmitted: (_) => _handleExecuteShell(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tokens.primary,
                      foregroundColor: tokens.textPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    onPressed: _isExecutingShell
                        ? null
                        : () => _handleExecuteShell(),
                    child: _isExecutingShell
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('执行', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // 终端控制台输出框
              Container(
                height: 140,
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF070B0E),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: tokens.outline.withValues(alpha: 0.4),
                  ),
                ),
                child: _terminalLogs.isEmpty
                    ? Text(
                        '# 等待执行命令...\n',
                        style: TextStyle(
                          color: tokens.textSecondary.withValues(alpha: 0.5),
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      )
                    : ListView.builder(
                        itemCount: _terminalLogs.length,
                        itemBuilder: (context, index) {
                          final log = _terminalLogs[index];
                          final isCommand = log.startsWith('\$');
                          return Text(
                            log,
                            style: TextStyle(
                              color: isCommand
                                  ? tokens.primary
                                  : tokens.textSecondary,
                              fontSize: 11,
                              fontFamily: 'monospace',
                              height: 1.4,
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCommandChip(String command, String label) {
    final tokens = context.tokens;
    return ActionChip(
      label: Text(
        label,
        style: TextStyle(color: tokens.textPrimary, fontSize: 11),
      ),
      backgroundColor: tokens.bgSecondary,
      side: BorderSide(color: tokens.outline),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      onPressed: () => _handleExecuteShell(command),
    );
  }

  Widget _buildBatchExecutionWizard(BuildContext context) {
    final tokens = context.tokens;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildCard(
          context: context,
          title: '群控执行向导',
          icon: Icons.layers_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStepItem(
                stepNum: '1',
                title: '选择执行设备',
                desc:
                    '当前已指定: ${widget.device.displayName} (${widget.device.serial})',
                isActive: true,
                tokens: tokens,
              ),
              const SizedBox(height: 12),
              _buildStepItem(
                stepNum: '2',
                title: '配置群控操作任务',
                desc: '支持批量触控录制回放、APK 安装、Shell 脚本批量下发',
                isActive: false,
                tokens: tokens,
              ),
              const SizedBox(height: 12),
              _buildStepItem(
                stepNum: '3',
                title: '确认并监控执行',
                desc: '执行引擎准备就绪，待任务接入',
                isActive: false,
                tokens: tokens,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepItem({
    required String stepNum,
    required String title,
    required String desc,
    required bool isActive,
    required AppColorTokens tokens,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? tokens.primary : tokens.bgSecondary,
            border: Border.all(
              color: isActive ? tokens.primary : tokens.outline,
            ),
          ),
          child: Center(
            child: Text(
              stepNum,
              style: TextStyle(
                color: isActive ? tokens.textPrimary : tokens.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isActive ? tokens.textPrimary : tokens.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(color: tokens.textSecondary, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    final tokens = context.tokens;

    return Container(
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
              Icon(icon, size: 16, color: tokens.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
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

  Widget _buildActionButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    final tokens = context.tokens;

    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: tokens.textPrimary,
        side: BorderSide(color: tokens.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: const EdgeInsets.symmetric(vertical: 10),
      ),
      icon: Icon(icon, size: 16, color: tokens.primary),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: onPressed,
    );
  }
}
