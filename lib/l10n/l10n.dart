// GENERATED CODE - DO NOT MODIFY BY HAND
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'intl/messages_all.dart';

// **************************************************************************
// Generator: Flutter Intl IDE plugin
// Made by Localizely
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, lines_longer_than_80_chars
// ignore_for_file: join_return_with_assignment, prefer_final_in_for_each
// ignore_for_file: avoid_redundant_argument_values, avoid_escaping_inner_quotes

class L10n {
  L10n();

  static L10n? _current;

  static L10n get current {
    assert(
      _current != null,
      'No instance of L10n was loaded. Try to initialize the L10n delegate before accessing L10n.current.',
    );
    return _current!;
  }

  static const AppLocalizationDelegate delegate = AppLocalizationDelegate();

  static Future<L10n> load(Locale locale) {
    final name = (locale.countryCode?.isEmpty ?? false)
        ? locale.languageCode
        : locale.toString();
    final localeName = Intl.canonicalizedLocale(name);
    return initializeMessages(localeName).then((_) {
      Intl.defaultLocale = localeName;
      final instance = L10n();
      L10n._current = instance;

      return instance;
    });
  }

  static L10n of(BuildContext context) {
    final instance = L10n.maybeOf(context);
    assert(
      instance != null,
      'No instance of L10n present in the widget tree. Did you add L10n.delegate in localizationsDelegates?',
    );
    return instance!;
  }

  static L10n? maybeOf(BuildContext context) {
    return Localizations.of<L10n>(context, L10n);
  }

  /// `Mobile Matrix`
  String get app_name {
    return Intl.message('Mobile Matrix', name: 'app_name', desc: '', args: []);
  }

  /// `仪表盘`
  String get dashboard {
    return Intl.message('仪表盘', name: 'dashboard', desc: '', args: []);
  }

  /// `日志`
  String get logs {
    return Intl.message('日志', name: 'logs', desc: '', args: []);
  }

  /// `截屏`
  String get screenshots {
    return Intl.message('截屏', name: 'screenshots', desc: '', args: []);
  }

  /// `自动化`
  String get automation {
    return Intl.message('自动化', name: 'automation', desc: '', args: []);
  }

  /// `文件管理`
  String get file_management {
    return Intl.message('文件管理', name: 'file_management', desc: '', args: []);
  }

  /// `高级功能`
  String get advanced_features {
    return Intl.message('高级功能', name: 'advanced_features', desc: '', args: []);
  }

  /// `设备信息`
  String get device_info {
    return Intl.message('设备信息', name: 'device_info', desc: '', args: []);
  }

  /// `电脑剪贴板当前为空`
  String get computer_clipboard_empty {
    return Intl.message(
      '电脑剪贴板当前为空',
      name: 'computer_clipboard_empty',
      desc: '',
      args: [],
    );
  }

  /// `已将电脑剪贴板内容注入手机`
  String get clipboard_pasted_to_device {
    return Intl.message(
      '已将电脑剪贴板内容注入手机',
      name: 'clipboard_pasted_to_device',
      desc: '',
      args: [],
    );
  }

  /// `注入手机失败`
  String get clipboard_paste_failed {
    return Intl.message(
      '注入手机失败',
      name: 'clipboard_paste_failed',
      desc: '',
      args: [],
    );
  }

  /// `已读取 {count} 个第三方应用`
  String third_party_apps_loaded(Object count) {
    return Intl.message(
      '已读取 $count 个第三方应用',
      name: 'third_party_apps_loaded',
      desc: '',
      args: [count],
    );
  }

  /// `未知设备`
  String get unknown_device {
    return Intl.message('未知设备', name: 'unknown_device', desc: '', args: []);
  }

  /// `已发现 {count} 台设备，已为 {device} 配置 {endpoint}`
  String remote_debug_discovered(Object count, Object device, Object endpoint) {
    return Intl.message(
      '已发现 $count 台设备，已为 $device 配置 $endpoint',
      name: 'remote_debug_discovered',
      desc: '',
      args: [count, device, endpoint],
    );
  }

  /// `读取本机设备失败：{error}`
  String remote_debug_read_failed(Object error) {
    return Intl.message(
      '读取本机设备失败：$error',
      name: 'remote_debug_read_failed',
      desc: '',
      args: [error],
    );
  }

  /// `logcat 已启动`
  String get logcat_started {
    return Intl.message(
      'logcat 已启动',
      name: 'logcat_started',
      desc: '',
      args: [],
    );
  }

  /// `logcat 已停止`
  String get logcat_stopped {
    return Intl.message(
      'logcat 已停止',
      name: 'logcat_stopped',
      desc: '',
      args: [],
    );
  }

  /// `当前没有可复制的日志`
  String get no_logs_to_copy {
    return Intl.message(
      '当前没有可复制的日志',
      name: 'no_logs_to_copy',
      desc: '',
      args: [],
    );
  }

  /// `日志已复制到剪贴板`
  String get logs_copied {
    return Intl.message('日志已复制到剪贴板', name: 'logs_copied', desc: '', args: []);
  }

  /// `已复制 PNG 到系统图片剪贴板`
  String get screenshot_copied {
    return Intl.message(
      '已复制 PNG 到系统图片剪贴板',
      name: 'screenshot_copied',
      desc: '',
      args: [],
    );
  }

  /// `{count} 个项目`
  String file_count(Object count) {
    return Intl.message(
      '$count 个项目',
      name: 'file_count',
      desc: '',
      args: [count],
    );
  }

  /// `请先填写本地目标路径`
  String get local_destination_required {
    return Intl.message(
      '请先填写本地目标路径',
      name: 'local_destination_required',
      desc: '',
      args: [],
    );
  }

  /// `文件已拉取到 {destination}`
  String file_pulled(Object destination) {
    return Intl.message(
      '文件已拉取到 $destination',
      name: 'file_pulled',
      desc: '',
      args: [destination],
    );
  }

  /// `重启设备`
  String get restart_device {
    return Intl.message('重启设备', name: 'restart_device', desc: '', args: []);
  }

  /// `确定要重启当前设备吗？`
  String get restart_confirmation {
    return Intl.message(
      '确定要重启当前设备吗？',
      name: 'restart_confirmation',
      desc: '',
      args: [],
    );
  }

  /// `取消`
  String get cancel {
    return Intl.message('取消', name: 'cancel', desc: '', args: []);
  }

  /// `重启`
  String get restart {
    return Intl.message('重启', name: 'restart', desc: '', args: []);
  }

  /// `切换为竖屏 (0°)`
  String get switch_to_portrait {
    return Intl.message(
      '切换为竖屏 (0°)',
      name: 'switch_to_portrait',
      desc: '',
      args: [],
    );
  }

  /// `切换为横屏 (90°)`
  String get switch_to_landscape {
    return Intl.message(
      '切换为横屏 (90°)',
      name: 'switch_to_landscape',
      desc: '',
      args: [],
    );
  }

  /// `隐藏屏幕`
  String get hide_screen {
    return Intl.message('隐藏屏幕', name: 'hide_screen', desc: '', args: []);
  }

  /// `显示屏幕`
  String get show_screen {
    return Intl.message('显示屏幕', name: 'show_screen', desc: '', args: []);
  }

  /// `复制截屏`
  String get copy_screenshot {
    return Intl.message('复制截屏', name: 'copy_screenshot', desc: '', args: []);
  }

  /// `快捷控制`
  String get quick_control {
    return Intl.message('快捷控制', name: 'quick_control', desc: '', args: []);
  }

  /// `硬件按键与屏幕操作`
  String get hardware_controls {
    return Intl.message(
      '硬件按键与屏幕操作',
      name: 'hardware_controls',
      desc: '',
      args: [],
    );
  }

  /// `Power`
  String get power {
    return Intl.message('Power', name: 'power', desc: '', args: []);
  }

  /// `Volume Up`
  String get volume_up {
    return Intl.message('Volume Up', name: 'volume_up', desc: '', args: []);
  }

  /// `Volume Down`
  String get volume_down {
    return Intl.message('Volume Down', name: 'volume_down', desc: '', args: []);
  }

  /// `Rotate Screen`
  String get rotate_screen {
    return Intl.message(
      'Rotate Screen',
      name: 'rotate_screen',
      desc: '',
      args: [],
    );
  }

  /// `实时系统监控`
  String get system_monitor {
    return Intl.message('实时系统监控', name: 'system_monitor', desc: '', args: []);
  }

  /// `每 5 秒采样 · CPU、内存与网络`
  String get monitor_sampling {
    return Intl.message(
      '每 5 秒采样 · CPU、内存与网络',
      name: 'monitor_sampling',
      desc: '',
      args: [],
    );
  }

  /// `每 5 秒采样 · 正在读取设备数据`
  String get monitor_reading {
    return Intl.message(
      '每 5 秒采样 · 正在读取设备数据',
      name: 'monitor_reading',
      desc: '',
      args: [],
    );
  }

  /// `监控已关闭 · 按需开启以降低设备性能影响`
  String get monitor_disabled {
    return Intl.message(
      '监控已关闭 · 按需开启以降低设备性能影响',
      name: 'monitor_disabled',
      desc: '',
      args: [],
    );
  }

  /// `关闭系统监控`
  String get close_system_monitor {
    return Intl.message(
      '关闭系统监控',
      name: 'close_system_monitor',
      desc: '',
      args: [],
    );
  }

  /// `开启系统监控`
  String get open_system_monitor {
    return Intl.message(
      '开启系统监控',
      name: 'open_system_monitor',
      desc: '',
      args: [],
    );
  }

  /// `实时系统监控`
  String get system_monitor_accessibility {
    return Intl.message(
      '实时系统监控',
      name: 'system_monitor_accessibility',
      desc: '',
      args: [],
    );
  }

  /// `CPU`
  String get cpu {
    return Intl.message('CPU', name: 'cpu', desc: '', args: []);
  }

  /// `内存`
  String get memory {
    return Intl.message('内存', name: 'memory', desc: '', args: []);
  }

  /// `网络`
  String get network {
    return Intl.message('网络', name: 'network', desc: '', args: []);
  }

  /// `URL 与 DeepLink 启动器`
  String get url_deeplink_launcher {
    return Intl.message(
      'URL 与 DeepLink 启动器',
      name: 'url_deeplink_launcher',
      desc: '',
      args: [],
    );
  }

  /// `快速在真机浏览器中打开网页或 DeepLink`
  String get url_deeplink_subtitle {
    return Intl.message(
      '快速在真机浏览器中打开网页或 DeepLink',
      name: 'url_deeplink_subtitle',
      desc: '',
      args: [],
    );
  }

  /// `输入网址或 DeepLink...`
  String get url_deeplink_hint {
    return Intl.message(
      '输入网址或 DeepLink...',
      name: 'url_deeplink_hint',
      desc: '',
      args: [],
    );
  }

  /// `打开`
  String get open {
    return Intl.message('打开', name: 'open', desc: '', args: []);
  }

  /// `已下载`
  String get downloaded {
    return Intl.message('已下载', name: 'downloaded', desc: '', args: []);
  }

  /// `应用`
  String get apps {
    return Intl.message('应用', name: 'apps', desc: '', args: []);
  }

  /// `书籍`
  String get books {
    return Intl.message('书籍', name: 'books', desc: '', args: []);
  }

  /// `商店`
  String get store {
    return Intl.message('商店', name: 'store', desc: '', args: []);
  }

  /// `智能输入中心`
  String get smart_input_hub {
    return Intl.message('智能输入中心', name: 'smart_input_hub', desc: '', args: []);
  }

  /// `实时同步文本注入与快捷短语枢纽`
  String get smart_input_subtitle {
    return Intl.message(
      '实时同步文本注入与快捷短语枢纽',
      name: 'smart_input_subtitle',
      desc: '',
      args: [],
    );
  }

  /// `实时同步文本注入...`
  String get realtime_text_hint {
    return Intl.message(
      '实时同步文本注入...',
      name: 'realtime_text_hint',
      desc: '',
      args: [],
    );
  }

  /// `发送`
  String get send {
    return Intl.message('发送', name: 'send', desc: '', args: []);
  }

  /// `粘贴电脑剪贴板`
  String get paste_computer_clipboard {
    return Intl.message(
      '粘贴电脑剪贴板',
      name: 'paste_computer_clipboard',
      desc: '',
      args: [],
    );
  }

  /// `常用测试短语：`
  String get common_test_phrases {
    return Intl.message(
      '常用测试短语：',
      name: 'common_test_phrases',
      desc: '',
      args: [],
    );
  }

  /// `13800000000`
  String get sample_phone {
    return Intl.message(
      '13800000000',
      name: 'sample_phone',
      desc: '',
      args: [],
    );
  }

  /// `test@example.com`
  String get sample_email {
    return Intl.message(
      'test@example.com',
      name: 'sample_email',
      desc: '',
      args: [],
    );
  }

  /// `Hello, 世界！🎉`
  String get sample_greeting {
    return Intl.message(
      'Hello, 世界！🎉',
      name: 'sample_greeting',
      desc: '',
      args: [],
    );
  }

  /// `高级剪贴板中心`
  String get advanced_clipboard_hub {
    return Intl.message(
      '高级剪贴板中心',
      name: 'advanced_clipboard_hub',
      desc: '',
      args: [],
    );
  }

  /// `宿主机电脑与真机剪贴板双向极速同步`
  String get clipboard_subtitle {
    return Intl.message(
      '宿主机电脑与真机剪贴板双向极速同步',
      name: 'clipboard_subtitle',
      desc: '',
      args: [],
    );
  }

  /// `剪贴板文本`
  String get clipboard_text_hint {
    return Intl.message(
      '剪贴板文本',
      name: 'clipboard_text_hint',
      desc: '',
      args: [],
    );
  }

  /// `读取手机`
  String get read_phone {
    return Intl.message('读取手机', name: 'read_phone', desc: '', args: []);
  }

  /// `写入手机`
  String get write_phone {
    return Intl.message('写入手机', name: 'write_phone', desc: '', args: []);
  }

  /// `ADB Shell 极速控制台（终端）`
  String get adb_shell_title {
    return Intl.message(
      'ADB Shell 极速控制台（终端）',
      name: 'adb_shell_title',
      desc: '',
      args: [],
    );
  }

  /// `直接在真机执行 Linux / Android 命令行`
  String get adb_shell_subtitle {
    return Intl.message(
      '直接在真机执行 Linux / Android 命令行',
      name: 'adb_shell_subtitle',
      desc: '',
      args: [],
    );
  }

  /// `系统版本`
  String get system_version {
    return Intl.message('系统版本', name: 'system_version', desc: '', args: []);
  }

  /// `屏幕分辨率`
  String get screen_resolution {
    return Intl.message('屏幕分辨率', name: 'screen_resolution', desc: '', args: []);
  }

  /// `网络 IP`
  String get network_ip {
    return Intl.message('网络 IP', name: 'network_ip', desc: '', args: []);
  }

  /// `输入 Shell 命令`
  String get shell_command_hint {
    return Intl.message(
      '输入 Shell 命令',
      name: 'shell_command_hint',
      desc: '',
      args: [],
    );
  }

  /// `执行`
  String get execute {
    return Intl.message('执行', name: 'execute', desc: '', args: []);
  }

  /// `# 等待执行命令...`
  String get shell_waiting {
    return Intl.message(
      '# 等待执行命令...',
      name: 'shell_waiting',
      desc: '',
      args: [],
    );
  }

  /// `应用管理与安装（应用包管理）`
  String get app_management_title {
    return Intl.message(
      '应用管理与安装（应用包管理）',
      name: 'app_management_title',
      desc: '',
      args: [],
    );
  }

  /// `安装 APK、读取已装应用、打开系统开发者选项`
  String get app_management_subtitle {
    return Intl.message(
      '安装 APK、读取已装应用、打开系统开发者选项',
      name: 'app_management_subtitle',
      desc: '',
      args: [],
    );
  }

  /// `本地 APK 路径`
  String get apk_path_hint {
    return Intl.message('本地 APK 路径', name: 'apk_path_hint', desc: '', args: []);
  }

  /// `安装 APK`
  String get install_apk {
    return Intl.message('安装 APK', name: 'install_apk', desc: '', args: []);
  }

  /// `读取应用`
  String get read_apps {
    return Intl.message('读取应用', name: 'read_apps', desc: '', args: []);
  }

  /// `系统设置`
  String get system_settings {
    return Intl.message('系统设置', name: 'system_settings', desc: '', args: []);
  }

  /// `开发者设置`
  String get developer_settings {
    return Intl.message(
      '开发者设置',
      name: 'developer_settings',
      desc: '',
      args: [],
    );
  }

  /// `应用包名`
  String get package_name_hint {
    return Intl.message('应用包名', name: 'package_name_hint', desc: '', args: []);
  }

  /// `卸载`
  String get uninstall {
    return Intl.message('卸载', name: 'uninstall', desc: '', args: []);
  }

  /// `ADB 远程网络调试（无线 ADB）`
  String get remote_debug_title {
    return Intl.message(
      'ADB 远程网络调试（无线 ADB）',
      name: 'remote_debug_title',
      desc: '',
      args: [],
    );
  }

  /// `配置 TCP/IP 端口，支持免 USB 无线投屏控制`
  String get remote_debug_subtitle {
    return Intl.message(
      '配置 TCP/IP 端口，支持免 USB 无线投屏控制',
      name: 'remote_debug_subtitle',
      desc: '',
      args: [],
    );
  }

  /// `设备地址，例如 192.168.1.8:36997`
  String get remote_address_hint {
    return Intl.message(
      '设备地址，例如 192.168.1.8:36997',
      name: 'remote_address_hint',
      desc: '',
      args: [],
    );
  }

  /// `读取中...`
  String get reading {
    return Intl.message('读取中...', name: 'reading', desc: '', args: []);
  }

  /// `读取本机设备`
  String get read_local_device {
    return Intl.message(
      '读取本机设备',
      name: 'read_local_device',
      desc: '',
      args: [],
    );
  }

  /// `连接`
  String get connect {
    return Intl.message('连接', name: 'connect', desc: '', args: []);
  }

  /// `读取本机设备后自动识别无线 ADB 连接端口；连接后可在设备选择器中使用。`
  String get remote_debug_hint {
    return Intl.message(
      '读取本机设备后自动识别无线 ADB 连接端口；连接后可在设备选择器中使用。',
      name: 'remote_debug_hint',
      desc: '',
      args: [],
    );
  }

  /// `Logcat 日志`
  String get logcat_logs {
    return Intl.message('Logcat 日志', name: 'logcat_logs', desc: '', args: []);
  }

  /// `启动`
  String get start {
    return Intl.message('启动', name: 'start', desc: '', args: []);
  }

  /// `停止`
  String get stop {
    return Intl.message('停止', name: 'stop', desc: '', args: []);
  }

  /// `清空`
  String get clear {
    return Intl.message('清空', name: 'clear', desc: '', args: []);
  }

  /// `复制`
  String get copy {
    return Intl.message('复制', name: 'copy', desc: '', args: []);
  }

  /// `过滤关键词`
  String get filter_keywords {
    return Intl.message('过滤关键词', name: 'filter_keywords', desc: '', args: []);
  }

  /// `# 启动 logcat 后显示设备日志`
  String get logcat_waiting {
    return Intl.message(
      '# 启动 logcat 后显示设备日志',
      name: 'logcat_waiting',
      desc: '',
      args: [],
    );
  }

  /// `设备截图`
  String get device_screenshot {
    return Intl.message('设备截图', name: 'device_screenshot', desc: '', args: []);
  }

  /// `复制截屏到系统图片剪贴板`
  String get screenshot_copy_tooltip {
    return Intl.message(
      '复制截屏到系统图片剪贴板',
      name: 'screenshot_copy_tooltip',
      desc: '',
      args: [],
    );
  }

  /// `截取当前设备画面并复制到粘贴板，不保存桌面文件。`
  String get screenshot_status {
    return Intl.message(
      '截取当前设备画面并复制到粘贴板，不保存桌面文件。',
      name: 'screenshot_status',
      desc: '',
      args: [],
    );
  }

  /// `设备设置`
  String get device_settings {
    return Intl.message('设备设置', name: 'device_settings', desc: '', args: []);
  }

  /// `静音`
  String get silent {
    return Intl.message('静音', name: 'silent', desc: '', args: []);
  }

  /// `振动`
  String get vibrate {
    return Intl.message('振动', name: 'vibrate', desc: '', args: []);
  }

  /// `响铃`
  String get ring {
    return Intl.message('响铃', name: 'ring', desc: '', args: []);
  }

  /// `Wi‑Fi`
  String get wifi {
    return Intl.message('Wi‑Fi', name: 'wifi', desc: '', args: []);
  }

  /// `蓝牙`
  String get bluetooth {
    return Intl.message('蓝牙', name: 'bluetooth', desc: '', args: []);
  }

  /// `清理蓝牙配对设备`
  String get clear_bluetooth_bonds {
    return Intl.message(
      '清理蓝牙配对设备',
      name: 'clear_bluetooth_bonds',
      desc: '',
      args: [],
    );
  }

  /// `应用商店账号`
  String get store_account {
    return Intl.message('应用商店账号', name: 'store_account', desc: '', args: []);
  }

  /// `账号名称`
  String get account_name {
    return Intl.message('账号名称', name: 'account_name', desc: '', args: []);
  }

  /// `查看账号`
  String get view_accounts {
    return Intl.message('查看账号', name: 'view_accounts', desc: '', args: []);
  }

  /// `检查`
  String get check {
    return Intl.message('检查', name: 'check', desc: '', args: []);
  }

  /// `移除`
  String get remove {
    return Intl.message('移除', name: 'remove', desc: '', args: []);
  }

  /// `添加账号`
  String get add_account {
    return Intl.message('添加账号', name: 'add_account', desc: '', args: []);
  }

  /// `打开应用商店`
  String get open_app_store {
    return Intl.message('打开应用商店', name: 'open_app_store', desc: '', args: []);
  }

  /// `文件浏览器`
  String get file_browser {
    return Intl.message('文件浏览器', name: 'file_browser', desc: '', args: []);
  }

  /// `上级目录`
  String get parent_directory {
    return Intl.message('上级目录', name: 'parent_directory', desc: '', args: []);
  }

  /// `设备路径`
  String get device_path {
    return Intl.message('设备路径', name: 'device_path', desc: '', args: []);
  }

  /// `进入`
  String get enter {
    return Intl.message('进入', name: 'enter', desc: '', args: []);
  }

  /// `输入 /sdcard 或其他设备路径`
  String get device_path_hint {
    return Intl.message(
      '输入 /sdcard 或其他设备路径',
      name: 'device_path_hint',
      desc: '',
      args: [],
    );
  }

  /// `暂无目录内容`
  String get no_directory_content {
    return Intl.message(
      '暂无目录内容',
      name: 'no_directory_content',
      desc: '',
      args: [],
    );
  }

  /// `目录`
  String get directory {
    return Intl.message('目录', name: 'directory', desc: '', args: []);
  }

  /// `{size} B`
  String file_size_bytes(Object size) {
    return Intl.message(
      '$size B',
      name: 'file_size_bytes',
      desc: '',
      args: [size],
    );
  }

  /// `拉取文件`
  String get pull_file {
    return Intl.message('拉取文件', name: 'pull_file', desc: '', args: []);
  }

  /// `文件拉取目标路径（本地）`
  String get local_file_pull_path {
    return Intl.message(
      '文件拉取目标路径（本地）',
      name: 'local_file_pull_path',
      desc: '',
      args: [],
    );
  }

  /// `特殊按键`
  String get special_keys {
    return Intl.message('特殊按键', name: 'special_keys', desc: '', args: []);
  }

  /// `端口转发`
  String get port_forwarding {
    return Intl.message('端口转发', name: 'port_forwarding', desc: '', args: []);
  }

  /// `本地端口`
  String get local_port {
    return Intl.message('本地端口', name: 'local_port', desc: '', args: []);
  }

  /// `设备端口`
  String get device_port {
    return Intl.message('设备端口', name: 'device_port', desc: '', args: []);
  }

  /// `创建`
  String get create {
    return Intl.message('创建', name: 'create', desc: '', args: []);
  }

  /// `查看`
  String get view {
    return Intl.message('查看', name: 'view', desc: '', args: []);
  }

  /// `设备维护`
  String get device_maintenance {
    return Intl.message('设备维护', name: 'device_maintenance', desc: '', args: []);
  }

  /// `读取设备信息`
  String get read_device_info {
    return Intl.message('读取设备信息', name: 'read_device_info', desc: '', args: []);
  }

  /// `刷新`
  String get refresh {
    return Intl.message('刷新', name: 'refresh', desc: '', args: []);
  }

  /// `硬件`
  String get hardware {
    return Intl.message('硬件', name: 'hardware', desc: '', args: []);
  }

  /// `制造商`
  String get manufacturer {
    return Intl.message('制造商', name: 'manufacturer', desc: '', args: []);
  }

  /// `型号`
  String get model {
    return Intl.message('型号', name: 'model', desc: '', args: []);
  }

  /// `产品`
  String get product {
    return Intl.message('产品', name: 'product', desc: '', args: []);
  }

  /// `序列号`
  String get serial_number {
    return Intl.message('序列号', name: 'serial_number', desc: '', args: []);
  }

  /// `平台`
  String get platform {
    return Intl.message('平台', name: 'platform', desc: '', args: []);
  }

  /// `Android`
  String get android {
    return Intl.message('Android', name: 'android', desc: '', args: []);
  }

  /// `SDK`
  String get sdk {
    return Intl.message('SDK', name: 'sdk', desc: '', args: []);
  }

  /// `ABI`
  String get abi {
    return Intl.message('ABI', name: 'abi', desc: '', args: []);
  }

  /// `显示`
  String get display {
    return Intl.message('显示', name: 'display', desc: '', args: []);
  }

  /// `分辨率`
  String get resolution {
    return Intl.message('分辨率', name: 'resolution', desc: '', args: []);
  }

  /// `密度`
  String get density {
    return Intl.message('密度', name: 'density', desc: '', args: []);
  }

  /// `电池`
  String get battery {
    return Intl.message('电池', name: 'battery', desc: '', args: []);
  }

  /// `电量`
  String get battery_level {
    return Intl.message('电量', name: 'battery_level', desc: '', args: []);
  }

  /// `状态`
  String get battery_status {
    return Intl.message('状态', name: 'battery_status', desc: '', args: []);
  }

  /// `温度`
  String get temperature {
    return Intl.message('温度', name: 'temperature', desc: '', args: []);
  }

  /// `网络 / SIM`
  String get network_sim {
    return Intl.message('网络 / SIM', name: 'network_sim', desc: '', args: []);
  }

  /// `IP`
  String get ip {
    return Intl.message('IP', name: 'ip', desc: '', args: []);
  }

  /// `运营商`
  String get carrier {
    return Intl.message('运营商', name: 'carrier', desc: '', args: []);
  }

  /// `SIM 国家`
  String get sim_country {
    return Intl.message('SIM 国家', name: 'sim_country', desc: '', args: []);
  }

  /// `IMEI`
  String get imei {
    return Intl.message('IMEI', name: 'imei', desc: '', args: []);
  }

  /// `CPU / 内存`
  String get cpu_memory {
    return Intl.message('CPU / 内存', name: 'cpu_memory', desc: '', args: []);
  }

  /// `核心数`
  String get core_count {
    return Intl.message('核心数', name: 'core_count', desc: '', args: []);
  }

  /// `存储`
  String get storage {
    return Intl.message('存储', name: 'storage', desc: '', args: []);
  }

  /// `未知`
  String get unknown {
    return Intl.message('未知', name: 'unknown', desc: '', args: []);
  }

  /// `相机`
  String get camera {
    return Intl.message('相机', name: 'camera', desc: '', args: []);
  }

  /// `搜索`
  String get search {
    return Intl.message('搜索', name: 'search', desc: '', args: []);
  }

  /// `切换输入法`
  String get switch_input_method {
    return Intl.message(
      '切换输入法',
      name: 'switch_input_method',
      desc: '',
      args: [],
    );
  }

  /// `后退`
  String get back {
    return Intl.message('后退', name: 'back', desc: '', args: []);
  }

  /// `播放/暂停`
  String get play_pause {
    return Intl.message('播放/暂停', name: 'play_pause', desc: '', args: []);
  }

  /// `前进`
  String get next {
    return Intl.message('前进', name: 'next', desc: '', args: []);
  }

  /// `提交文本："{text}"`
  String commit_text_log(Object text) {
    return Intl.message(
      '提交文本："$text"',
      name: 'commit_text_log',
      desc: '',
      args: [text],
    );
  }

  /// `写入剪贴板："{text}"`
  String clipboard_set_log(Object text) {
    return Intl.message(
      '写入剪贴板："$text"',
      name: 'clipboard_set_log',
      desc: '',
      args: [text],
    );
  }

  /// `从电脑剪贴板粘贴："{text}"`
  String pasted_clipboard_log(Object text) {
    return Intl.message(
      '从电脑剪贴板粘贴："$text"',
      name: 'pasted_clipboard_log',
      desc: '',
      args: [text],
    );
  }

  /// `注入短语："{phrase}"`
  String injected_phrase_log(Object phrase) {
    return Intl.message(
      '注入短语："$phrase"',
      name: 'injected_phrase_log',
      desc: '',
      args: [phrase],
    );
  }

  /// `已连接 · 可控制`
  String get device_connected_controllable {
    return Intl.message(
      '已连接 · 可控制',
      name: 'device_connected_controllable',
      desc: '',
      args: [],
    );
  }

  /// `正在控制 (ADB)`
  String get device_controlling {
    return Intl.message(
      '正在控制 (ADB)',
      name: 'device_controlling',
      desc: '',
      args: [],
    );
  }

  /// `设备正被占用`
  String get device_busy {
    return Intl.message('设备正被占用', name: 'device_busy', desc: '', args: []);
  }

  /// `连接已断开`
  String get device_disconnected {
    return Intl.message(
      '连接已断开',
      name: 'device_disconnected',
      desc: '',
      args: [],
    );
  }

  /// `未授权 (请在手机勾选信任)`
  String get device_unauthorized {
    return Intl.message(
      '未授权 (请在手机勾选信任)',
      name: 'device_unauthorized',
      desc: '',
      args: [],
    );
  }

  /// `切换设备`
  String get switch_device {
    return Intl.message('切换设备', name: 'switch_device', desc: '', args: []);
  }

  /// `未检测到 USB 真机连接`
  String get no_usb_device {
    return Intl.message(
      '未检测到 USB 真机连接',
      name: 'no_usb_device',
      desc: '',
      args: [],
    );
  }

  /// `重新扫描 ADB 真机设备`
  String get rescan_adb_devices {
    return Intl.message(
      '重新扫描 ADB 真机设备',
      name: 'rescan_adb_devices',
      desc: '',
      args: [],
    );
  }

  /// `切换流光主题 (液态蓝 / 玫瑰流光)`
  String get toggle_theme {
    return Intl.message(
      '切换流光主题 (液态蓝 / 玫瑰流光)',
      name: 'toggle_theme',
      desc: '',
      args: [],
    );
  }

  /// `STF Lite 运行时资源未配置，请配置 sidecar 与资源目录`
  String get stf_lite_runtime_unavailable {
    return Intl.message(
      'STF Lite 运行时资源未配置，请配置 sidecar 与资源目录',
      name: 'stf_lite_runtime_unavailable',
      desc: '',
      args: [],
    );
  }

  /// `STF Lite 运行时尚未就绪`
  String get stf_lite_runtime_not_ready {
    return Intl.message(
      'STF Lite 运行时尚未就绪',
      name: 'stf_lite_runtime_not_ready',
      desc: '',
      args: [],
    );
  }

  /// `STF Lite 运行时启动失败：{error}`
  String stf_lite_runtime_start_failed(Object error) {
    return Intl.message(
      'STF Lite 运行时启动失败：$error',
      name: 'stf_lite_runtime_start_failed',
      desc: '',
      args: [error],
    );
  }

  /// `STF Lite sidecar 已退出`
  String get stf_lite_sidecar_exited {
    return Intl.message(
      'STF Lite sidecar 已退出',
      name: 'stf_lite_sidecar_exited',
      desc: '',
      args: [],
    );
  }

  /// `等待 STF 屏幕首帧...`
  String get stf_lite_screen_waiting {
    return Intl.message(
      '等待 STF 屏幕首帧...',
      name: 'stf_lite_screen_waiting',
      desc: '',
      args: [],
    );
  }

  /// `STF 屏幕流已暂停`
  String get stf_lite_screen_paused {
    return Intl.message(
      'STF 屏幕流已暂停',
      name: 'stf_lite_screen_paused',
      desc: '',
      args: [],
    );
  }

  /// `STF 屏幕服务不可用`
  String get stf_lite_screen_service_unavailable {
    return Intl.message(
      'STF 屏幕服务不可用',
      name: 'stf_lite_screen_service_unavailable',
      desc: '',
      args: [],
    );
  }

  /// `STF 屏幕连接已断开`
  String get stf_lite_screen_disconnected {
    return Intl.message(
      'STF 屏幕连接已断开',
      name: 'stf_lite_screen_disconnected',
      desc: '',
      args: [],
    );
  }

  /// `正在连接 STF 屏幕流...`
  String get stf_lite_screen_connecting {
    return Intl.message(
      '正在连接 STF 屏幕流...',
      name: 'stf_lite_screen_connecting',
      desc: '',
      args: [],
    );
  }

  /// `未找到 STF Lite 屏幕会话，正在重试`
  String get stf_lite_screen_session_missing {
    return Intl.message(
      '未找到 STF Lite 屏幕会话，正在重试',
      name: 'stf_lite_screen_session_missing',
      desc: '',
      args: [],
    );
  }

  /// `STF Lite 屏幕连接异常，正在重试`
  String get stf_lite_screen_connection_error {
    return Intl.message(
      'STF Lite 屏幕连接异常，正在重试',
      name: 'stf_lite_screen_connection_error',
      desc: '',
      args: [],
    );
  }

  /// `STF Lite 屏幕连接中断，正在重试`
  String get stf_lite_screen_interrupted {
    return Intl.message(
      'STF Lite 屏幕连接中断，正在重试',
      name: 'stf_lite_screen_interrupted',
      desc: '',
      args: [],
    );
  }

  /// `STF Lite 屏幕连接已关闭，正在重试`
  String get stf_lite_screen_closed {
    return Intl.message(
      'STF Lite 屏幕连接已关闭，正在重试',
      name: 'stf_lite_screen_closed',
      desc: '',
      args: [],
    );
  }

  /// `STF Lite 屏幕连接已断开，正在重新解析服务`
  String get stf_lite_screen_reconnecting {
    return Intl.message(
      'STF Lite 屏幕连接已断开，正在重新解析服务',
      name: 'stf_lite_screen_reconnecting',
      desc: '',
      args: [],
    );
  }
}

class AppLocalizationDelegate extends LocalizationsDelegate<L10n> {
  const AppLocalizationDelegate();

  List<Locale> get supportedLocales {
    return const <Locale>[
      Locale.fromSubtags(languageCode: 'zh'),
      Locale.fromSubtags(languageCode: 'en'),
    ];
  }

  @override
  bool isSupported(Locale locale) => _isSupported(locale);
  @override
  Future<L10n> load(Locale locale) => L10n.load(locale);
  @override
  bool shouldReload(AppLocalizationDelegate old) => false;

  bool _isSupported(Locale locale) {
    for (var supportedLocale in supportedLocales) {
      if (supportedLocale.languageCode == locale.languageCode) {
        return true;
      }
    }
    return false;
  }
}
