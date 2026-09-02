// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a zh locale. All the
// messages from the main program should be duplicated here with the same
// function name.

// Ignore issues from commonly used lints in this file.
// ignore_for_file:unnecessary_brace_in_string_interps, unnecessary_new
// ignore_for_file:prefer_single_quotes,comment_references, directives_ordering
// ignore_for_file:annotate_overrides,prefer_generic_function_type_aliases
// ignore_for_file:unused_import, file_names, avoid_escaping_inner_quotes
// ignore_for_file:unnecessary_string_interpolations, unnecessary_string_escapes

import 'package:intl/intl.dart';
import 'package:intl/message_lookup_by_library.dart';

final messages = new MessageLookup();

typedef String MessageIfAbsent(String messageStr, List<dynamic> args);

class MessageLookup extends MessageLookupByLibrary {
  String get localeName => 'zh';

  static String m0(text) => "写入剪贴板：\"${text}\"";

  static String m1(text) => "提交文本：\"${text}\"";

  static String m2(count) => "已连接 ${count} 台设备";

  static String m3(count) => "${count} 个项目";

  static String m4(destination) => "文件已拉取到 ${destination}";

  static String m5(size) => "${size} B";

  static String m6(phrase) => "注入短语：\"${phrase}\"";

  static String m7(text) => "从电脑剪贴板粘贴：\"${text}\"";

  static String m8(count, device, endpoint) =>
      "已发现 ${count} 台设备，已为 ${device} 配置 ${endpoint}";

  static String m9(error) => "读取本机设备失败：${error}";

  static String m10(error) => "STF Lite 运行时启动失败：${error}";

  static String m11(count) => "已读取 ${count} 个第三方应用";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "abi": MessageLookupByLibrary.simpleMessage("ABI"),
    "account_name": MessageLookupByLibrary.simpleMessage("账号名称"),
    "adb_shell_subtitle": MessageLookupByLibrary.simpleMessage(
      "直接在真机执行 Linux / Android 命令行",
    ),
    "adb_shell_title": MessageLookupByLibrary.simpleMessage(
      "ADB Shell 极速控制台（终端）",
    ),
    "add_account": MessageLookupByLibrary.simpleMessage("添加账号"),
    "advanced_clipboard_hub": MessageLookupByLibrary.simpleMessage("高级剪贴板中心"),
    "advanced_features": MessageLookupByLibrary.simpleMessage("高级功能"),
    "android": MessageLookupByLibrary.simpleMessage("Android"),
    "apk_path_hint": MessageLookupByLibrary.simpleMessage("本地 APK 路径"),
    "app_management_subtitle": MessageLookupByLibrary.simpleMessage(
      "安装 APK、读取已装应用、打开系统开发者选项",
    ),
    "app_management_title": MessageLookupByLibrary.simpleMessage(
      "应用管理与安装（应用包管理）",
    ),
    "app_name": MessageLookupByLibrary.simpleMessage("Mobile Matrix"),
    "apps": MessageLookupByLibrary.simpleMessage("应用"),
    "automation": MessageLookupByLibrary.simpleMessage("自动化"),
    "back": MessageLookupByLibrary.simpleMessage("后退"),
    "back_to_overview": MessageLookupByLibrary.simpleMessage("返回设备总览"),
    "battery": MessageLookupByLibrary.simpleMessage("电池"),
    "battery_level": MessageLookupByLibrary.simpleMessage("电量"),
    "battery_status": MessageLookupByLibrary.simpleMessage("状态"),
    "books": MessageLookupByLibrary.simpleMessage("书籍"),
    "camera": MessageLookupByLibrary.simpleMessage("相机"),
    "cancel": MessageLookupByLibrary.simpleMessage("取消"),
    "carrier": MessageLookupByLibrary.simpleMessage("运营商"),
    "check": MessageLookupByLibrary.simpleMessage("检查"),
    "clear": MessageLookupByLibrary.simpleMessage("清空"),
    "clear_bluetooth_bonds": MessageLookupByLibrary.simpleMessage("清理蓝牙配对设备"),
    "clipboard_paste_failed": MessageLookupByLibrary.simpleMessage("注入手机失败"),
    "clipboard_pasted_to_device": MessageLookupByLibrary.simpleMessage(
      "已将电脑剪贴板内容注入手机",
    ),
    "clipboard_set_log": m0,
    "clipboard_subtitle": MessageLookupByLibrary.simpleMessage(
      "宿主机电脑与真机剪贴板双向极速同步",
    ),
    "clipboard_text_hint": MessageLookupByLibrary.simpleMessage("剪贴板文本"),
    "close_system_monitor": MessageLookupByLibrary.simpleMessage("关闭系统监控"),
    "commit_text_log": m1,
    "common_test_phrases": MessageLookupByLibrary.simpleMessage("常用测试短语："),
    "computer_clipboard_empty": MessageLookupByLibrary.simpleMessage(
      "电脑剪贴板当前为空",
    ),
    "connect": MessageLookupByLibrary.simpleMessage("连接"),
    "connected_devices": m2,
    "copy": MessageLookupByLibrary.simpleMessage("复制"),
    "copy_screenshot": MessageLookupByLibrary.simpleMessage("复制截屏"),
    "core_count": MessageLookupByLibrary.simpleMessage("核心数"),
    "cpu": MessageLookupByLibrary.simpleMessage("CPU"),
    "cpu_memory": MessageLookupByLibrary.simpleMessage("CPU / 内存"),
    "create": MessageLookupByLibrary.simpleMessage("创建"),
    "dashboard": MessageLookupByLibrary.simpleMessage("仪表盘"),
    "density": MessageLookupByLibrary.simpleMessage("密度"),
    "developer_settings": MessageLookupByLibrary.simpleMessage("开发者设置"),
    "device_busy": MessageLookupByLibrary.simpleMessage("设备正被占用"),
    "device_connected_controllable": MessageLookupByLibrary.simpleMessage(
      "已连接 · 可控制",
    ),
    "device_controlling": MessageLookupByLibrary.simpleMessage("正在控制 (ADB)"),
    "device_disconnected": MessageLookupByLibrary.simpleMessage("连接已断开"),
    "device_info": MessageLookupByLibrary.simpleMessage("设备信息"),
    "device_maintenance": MessageLookupByLibrary.simpleMessage("设备维护"),
    "device_overview": MessageLookupByLibrary.simpleMessage("设备总览"),
    "device_path": MessageLookupByLibrary.simpleMessage("设备路径"),
    "device_path_hint": MessageLookupByLibrary.simpleMessage(
      "输入 /sdcard 或其他设备路径",
    ),
    "device_port": MessageLookupByLibrary.simpleMessage("设备端口"),
    "device_settings": MessageLookupByLibrary.simpleMessage("设备设置"),
    "device_unauthorized": MessageLookupByLibrary.simpleMessage(
      "未授权 (请在手机勾选信任)",
    ),
    "directory": MessageLookupByLibrary.simpleMessage("目录"),
    "disable_bluetooth": MessageLookupByLibrary.simpleMessage("关闭蓝牙"),
    "disable_wifi": MessageLookupByLibrary.simpleMessage("关闭 Wi‑Fi"),
    "display": MessageLookupByLibrary.simpleMessage("显示"),
    "downloaded": MessageLookupByLibrary.simpleMessage("已下载"),
    "enable_bluetooth": MessageLookupByLibrary.simpleMessage("开启蓝牙"),
    "enable_wifi": MessageLookupByLibrary.simpleMessage("开启 Wi‑Fi"),
    "enter": MessageLookupByLibrary.simpleMessage("进入"),
    "enter_console": MessageLookupByLibrary.simpleMessage("进入控制台"),
    "execute": MessageLookupByLibrary.simpleMessage("执行"),
    "file_browser": MessageLookupByLibrary.simpleMessage("文件浏览器"),
    "file_count": m3,
    "file_management": MessageLookupByLibrary.simpleMessage("文件管理"),
    "file_pulled": m4,
    "file_size_bytes": m5,
    "filter_keywords": MessageLookupByLibrary.simpleMessage("过滤关键词"),
    "hardware": MessageLookupByLibrary.simpleMessage("硬件"),
    "hardware_controls": MessageLookupByLibrary.simpleMessage("硬件按键与屏幕操作"),
    "hide_screen": MessageLookupByLibrary.simpleMessage("隐藏屏幕"),
    "imei": MessageLookupByLibrary.simpleMessage("IMEI"),
    "injected_phrase_log": m6,
    "install_apk": MessageLookupByLibrary.simpleMessage("安装 APK"),
    "ip": MessageLookupByLibrary.simpleMessage("IP"),
    "local_destination_required": MessageLookupByLibrary.simpleMessage(
      "请先填写本地目标路径",
    ),
    "local_file_pull_path": MessageLookupByLibrary.simpleMessage(
      "文件拉取目标路径（本地）",
    ),
    "local_port": MessageLookupByLibrary.simpleMessage("本地端口"),
    "logcat_logs": MessageLookupByLibrary.simpleMessage("Logcat 日志"),
    "logcat_started": MessageLookupByLibrary.simpleMessage("logcat 已启动"),
    "logcat_stopped": MessageLookupByLibrary.simpleMessage("logcat 已停止"),
    "logcat_waiting": MessageLookupByLibrary.simpleMessage(
      "# 启动 logcat 后显示设备日志",
    ),
    "logs": MessageLookupByLibrary.simpleMessage("日志"),
    "logs_copied": MessageLookupByLibrary.simpleMessage("日志已复制到剪贴板"),
    "manufacturer": MessageLookupByLibrary.simpleMessage("制造商"),
    "memory": MessageLookupByLibrary.simpleMessage("内存"),
    "model": MessageLookupByLibrary.simpleMessage("型号"),
    "monitor_disabled": MessageLookupByLibrary.simpleMessage(
      "监控已关闭 · 按需开启以降低设备性能影响",
    ),
    "monitor_reading": MessageLookupByLibrary.simpleMessage(
      "每 5 秒采样 · 正在读取设备数据",
    ),
    "monitor_sampling": MessageLookupByLibrary.simpleMessage(
      "每 5 秒采样 · CPU、内存与网络",
    ),
    "network": MessageLookupByLibrary.simpleMessage("网络"),
    "network_ip": MessageLookupByLibrary.simpleMessage("网络 IP"),
    "network_sim": MessageLookupByLibrary.simpleMessage("网络 / SIM"),
    "next": MessageLookupByLibrary.simpleMessage("前进"),
    "no_directory_content": MessageLookupByLibrary.simpleMessage("暂无目录内容"),
    "no_logs_to_copy": MessageLookupByLibrary.simpleMessage("当前没有可复制的日志"),
    "no_usb_device": MessageLookupByLibrary.simpleMessage("未检测到 USB 真机连接"),
    "open": MessageLookupByLibrary.simpleMessage("打开"),
    "open_app_store": MessageLookupByLibrary.simpleMessage("打开应用商店"),
    "open_system_monitor": MessageLookupByLibrary.simpleMessage("开启系统监控"),
    "package_name_hint": MessageLookupByLibrary.simpleMessage("应用包名"),
    "parent_directory": MessageLookupByLibrary.simpleMessage("上级目录"),
    "paste_computer_clipboard": MessageLookupByLibrary.simpleMessage("粘贴电脑剪贴板"),
    "pasted_clipboard_log": m7,
    "platform": MessageLookupByLibrary.simpleMessage("平台"),
    "play_pause": MessageLookupByLibrary.simpleMessage("播放/暂停"),
    "port_forwarding": MessageLookupByLibrary.simpleMessage("端口转发"),
    "power": MessageLookupByLibrary.simpleMessage("Power"),
    "product": MessageLookupByLibrary.simpleMessage("产品"),
    "pull_file": MessageLookupByLibrary.simpleMessage("拉取文件"),
    "quick_control": MessageLookupByLibrary.simpleMessage("快捷控制"),
    "read_apps": MessageLookupByLibrary.simpleMessage("读取应用"),
    "read_device_info": MessageLookupByLibrary.simpleMessage("读取设备信息"),
    "read_local_device": MessageLookupByLibrary.simpleMessage("读取本机设备"),
    "read_phone": MessageLookupByLibrary.simpleMessage("读取手机"),
    "reading": MessageLookupByLibrary.simpleMessage("读取中..."),
    "realtime_text_hint": MessageLookupByLibrary.simpleMessage("实时同步文本注入..."),
    "refresh": MessageLookupByLibrary.simpleMessage("刷新"),
    "remote_address_hint": MessageLookupByLibrary.simpleMessage(
      "设备地址，例如 192.168.1.8:36997",
    ),
    "remote_debug_discovered": m8,
    "remote_debug_hint": MessageLookupByLibrary.simpleMessage(
      "读取本机设备后自动识别无线 ADB 连接端口；连接后可在设备选择器中使用。",
    ),
    "remote_debug_read_failed": m9,
    "remote_debug_subtitle": MessageLookupByLibrary.simpleMessage(
      "配置 TCP/IP 端口，支持免 USB 无线投屏控制",
    ),
    "remote_debug_title": MessageLookupByLibrary.simpleMessage(
      "ADB 远程网络调试（无线 ADB）",
    ),
    "remove": MessageLookupByLibrary.simpleMessage("移除"),
    "rescan_adb_devices": MessageLookupByLibrary.simpleMessage("重新扫描 ADB 真机设备"),
    "resolution": MessageLookupByLibrary.simpleMessage("分辨率"),
    "restart": MessageLookupByLibrary.simpleMessage("重启"),
    "restart_confirmation": MessageLookupByLibrary.simpleMessage("确定要重启当前设备吗？"),
    "restart_device": MessageLookupByLibrary.simpleMessage("重启设备"),
    "ring": MessageLookupByLibrary.simpleMessage("响铃"),
    "rotate_screen": MessageLookupByLibrary.simpleMessage("Rotate Screen"),
    "sample_email": MessageLookupByLibrary.simpleMessage("test@example.com"),
    "sample_greeting": MessageLookupByLibrary.simpleMessage("Hello, 世界！🎉"),
    "sample_phone": MessageLookupByLibrary.simpleMessage("13800000000"),
    "screen_resolution": MessageLookupByLibrary.simpleMessage("屏幕分辨率"),
    "screenshot_copied": MessageLookupByLibrary.simpleMessage(
      "已复制 PNG 到系统图片剪贴板",
    ),
    "sdk": MessageLookupByLibrary.simpleMessage("SDK"),
    "search": MessageLookupByLibrary.simpleMessage("搜索"),
    "send": MessageLookupByLibrary.simpleMessage("发送"),
    "serial_number": MessageLookupByLibrary.simpleMessage("序列号"),
    "shell_command_hint": MessageLookupByLibrary.simpleMessage("输入 Shell 命令"),
    "shell_waiting": MessageLookupByLibrary.simpleMessage("# 等待执行命令..."),
    "show_screen": MessageLookupByLibrary.simpleMessage("显示屏幕"),
    "silent": MessageLookupByLibrary.simpleMessage("静音"),
    "sim_country": MessageLookupByLibrary.simpleMessage("SIM 国家"),
    "smart_input_hub": MessageLookupByLibrary.simpleMessage("智能输入中心"),
    "smart_input_subtitle": MessageLookupByLibrary.simpleMessage(
      "实时同步文本注入与快捷短语枢纽",
    ),
    "special_keys": MessageLookupByLibrary.simpleMessage("特殊按键"),
    "start": MessageLookupByLibrary.simpleMessage("启动"),
    "stf_lite_runtime_not_ready": MessageLookupByLibrary.simpleMessage(
      "STF Lite 运行时尚未就绪",
    ),
    "stf_lite_runtime_start_failed": m10,
    "stf_lite_runtime_unavailable": MessageLookupByLibrary.simpleMessage(
      "STF Lite 运行时资源未配置，请配置 sidecar 与资源目录",
    ),
    "stf_lite_screen_closed": MessageLookupByLibrary.simpleMessage(
      "STF Lite 屏幕连接已关闭，正在重试",
    ),
    "stf_lite_screen_connecting": MessageLookupByLibrary.simpleMessage(
      "正在连接 STF 屏幕流...",
    ),
    "stf_lite_screen_connection_error": MessageLookupByLibrary.simpleMessage(
      "STF Lite 屏幕连接异常，正在重试",
    ),
    "stf_lite_screen_disconnected": MessageLookupByLibrary.simpleMessage(
      "STF 屏幕连接已断开",
    ),
    "stf_lite_screen_interrupted": MessageLookupByLibrary.simpleMessage(
      "STF Lite 屏幕连接中断，正在重试",
    ),
    "stf_lite_screen_paused": MessageLookupByLibrary.simpleMessage(
      "STF 屏幕流已暂停",
    ),
    "stf_lite_screen_reconnecting": MessageLookupByLibrary.simpleMessage(
      "STF Lite 屏幕连接已断开，正在重新解析服务",
    ),
    "stf_lite_screen_service_unavailable": MessageLookupByLibrary.simpleMessage(
      "STF 屏幕服务不可用",
    ),
    "stf_lite_screen_session_missing": MessageLookupByLibrary.simpleMessage(
      "未找到 STF Lite 屏幕会话，正在重试",
    ),
    "stf_lite_screen_waiting": MessageLookupByLibrary.simpleMessage(
      "等待 STF 屏幕首帧...",
    ),
    "stf_lite_sidecar_exited": MessageLookupByLibrary.simpleMessage(
      "STF Lite sidecar 已退出",
    ),
    "stop": MessageLookupByLibrary.simpleMessage("停止"),
    "storage": MessageLookupByLibrary.simpleMessage("存储"),
    "store": MessageLookupByLibrary.simpleMessage("商店"),
    "store_account": MessageLookupByLibrary.simpleMessage("应用商店账号"),
    "switch_device": MessageLookupByLibrary.simpleMessage("切换设备"),
    "switch_input_method": MessageLookupByLibrary.simpleMessage("切换输入法"),
    "switch_to_landscape": MessageLookupByLibrary.simpleMessage("切换为横屏 (90°)"),
    "switch_to_portrait": MessageLookupByLibrary.simpleMessage("切换为竖屏 (0°)"),
    "system_monitor": MessageLookupByLibrary.simpleMessage("实时系统监控"),
    "system_monitor_accessibility": MessageLookupByLibrary.simpleMessage(
      "实时系统监控",
    ),
    "system_settings": MessageLookupByLibrary.simpleMessage("系统设置"),
    "system_version": MessageLookupByLibrary.simpleMessage("系统版本"),
    "temperature": MessageLookupByLibrary.simpleMessage("温度"),
    "third_party_apps_loaded": m11,
    "toggle_theme": MessageLookupByLibrary.simpleMessage("切换流光主题 (液态蓝 / 玫瑰流光)"),
    "uninstall": MessageLookupByLibrary.simpleMessage("卸载"),
    "unknown": MessageLookupByLibrary.simpleMessage("未知"),
    "unknown_device": MessageLookupByLibrary.simpleMessage("未知设备"),
    "url_deeplink_hint": MessageLookupByLibrary.simpleMessage(
      "输入网址或 DeepLink...",
    ),
    "url_deeplink_launcher": MessageLookupByLibrary.simpleMessage(
      "URL 与 DeepLink 启动器",
    ),
    "url_deeplink_subtitle": MessageLookupByLibrary.simpleMessage(
      "快速在真机浏览器中打开网页或 DeepLink",
    ),
    "vibrate": MessageLookupByLibrary.simpleMessage("振动"),
    "view": MessageLookupByLibrary.simpleMessage("查看"),
    "view_accounts": MessageLookupByLibrary.simpleMessage("查看账号"),
    "volume_down": MessageLookupByLibrary.simpleMessage("Volume Down"),
    "volume_up": MessageLookupByLibrary.simpleMessage("Volume Up"),
    "write_phone": MessageLookupByLibrary.simpleMessage("写入手机"),
  };
}
