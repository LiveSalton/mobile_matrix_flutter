// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a en locale. All the
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
  String get localeName => 'en';

  static String m0(text) => "Set clipboard: \"${text}\"";

  static String m1(text) => "Commit text: \"${text}\"";

  static String m2(count) => "${count} items";

  static String m3(destination) => "File pulled to ${destination}";

  static String m4(size) => "${size} B";

  static String m5(phrase) => "Injected phrase: \"${phrase}\"";

  static String m6(text) => "Pasted from computer clipboard: \"${text}\"";

  static String m7(count, device, endpoint) =>
      "Found ${count} devices; configured ${device} with ${endpoint}";

  static String m8(error) => "Failed to read local devices: ${error}";

  static String m9(error) => "STF Lite runtime failed to start: ${error}";

  static String m10(count) => "Loaded ${count} third-party apps";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "abi": MessageLookupByLibrary.simpleMessage("ABI"),
    "account_name": MessageLookupByLibrary.simpleMessage("Account name"),
    "adb_shell_subtitle": MessageLookupByLibrary.simpleMessage(
      "Run Linux / Android commands directly on the device",
    ),
    "adb_shell_title": MessageLookupByLibrary.simpleMessage(
      "ADB Shell Fast Console (Terminal)",
    ),
    "add_account": MessageLookupByLibrary.simpleMessage("Add account"),
    "advanced_clipboard_hub": MessageLookupByLibrary.simpleMessage(
      "Advanced Clipboard Hub",
    ),
    "advanced_features": MessageLookupByLibrary.simpleMessage("Advanced"),
    "android": MessageLookupByLibrary.simpleMessage("Android"),
    "apk_path_hint": MessageLookupByLibrary.simpleMessage("Local APK path"),
    "app_management_subtitle": MessageLookupByLibrary.simpleMessage(
      "Install APKs, list installed apps and open developer settings",
    ),
    "app_management_title": MessageLookupByLibrary.simpleMessage(
      "App Management and Installation (Package Manager)",
    ),
    "app_name": MessageLookupByLibrary.simpleMessage("Mobile Matrix"),
    "apps": MessageLookupByLibrary.simpleMessage("Apps"),
    "automation": MessageLookupByLibrary.simpleMessage("Automation"),
    "back": MessageLookupByLibrary.simpleMessage("Back"),
    "battery": MessageLookupByLibrary.simpleMessage("Battery"),
    "battery_level": MessageLookupByLibrary.simpleMessage("Battery level"),
    "battery_status": MessageLookupByLibrary.simpleMessage("Status"),
    "books": MessageLookupByLibrary.simpleMessage("Books"),
    "camera": MessageLookupByLibrary.simpleMessage("Camera"),
    "cancel": MessageLookupByLibrary.simpleMessage("Cancel"),
    "carrier": MessageLookupByLibrary.simpleMessage("Carrier"),
    "check": MessageLookupByLibrary.simpleMessage("Check"),
    "clear": MessageLookupByLibrary.simpleMessage("Clear"),
    "clear_bluetooth_bonds": MessageLookupByLibrary.simpleMessage(
      "Clear Bluetooth pairings",
    ),
    "clipboard_paste_failed": MessageLookupByLibrary.simpleMessage(
      "Failed to inject content into the phone",
    ),
    "clipboard_pasted_to_device": MessageLookupByLibrary.simpleMessage(
      "Computer clipboard content injected into the phone",
    ),
    "clipboard_set_log": m0,
    "clipboard_subtitle": MessageLookupByLibrary.simpleMessage(
      "Fast two-way sync between computer and device clipboards",
    ),
    "clipboard_text_hint": MessageLookupByLibrary.simpleMessage(
      "Clipboard text",
    ),
    "close_system_monitor": MessageLookupByLibrary.simpleMessage(
      "Turn off system monitor",
    ),
    "commit_text_log": m1,
    "common_test_phrases": MessageLookupByLibrary.simpleMessage(
      "Common test phrases:",
    ),
    "computer_clipboard_empty": MessageLookupByLibrary.simpleMessage(
      "The computer clipboard is empty",
    ),
    "connect": MessageLookupByLibrary.simpleMessage("Connect"),
    "copy": MessageLookupByLibrary.simpleMessage("Copy"),
    "copy_screenshot": MessageLookupByLibrary.simpleMessage("Copy screenshot"),
    "core_count": MessageLookupByLibrary.simpleMessage("Core count"),
    "cpu": MessageLookupByLibrary.simpleMessage("CPU"),
    "cpu_memory": MessageLookupByLibrary.simpleMessage("CPU / Memory"),
    "create": MessageLookupByLibrary.simpleMessage("Create"),
    "dashboard": MessageLookupByLibrary.simpleMessage("Dashboard"),
    "density": MessageLookupByLibrary.simpleMessage("Density"),
    "developer_settings": MessageLookupByLibrary.simpleMessage(
      "Developer Settings",
    ),
    "device_busy": MessageLookupByLibrary.simpleMessage("Device is busy"),
    "device_connected_controllable": MessageLookupByLibrary.simpleMessage(
      "Connected · Controllable",
    ),
    "device_controlling": MessageLookupByLibrary.simpleMessage(
      "Controlling (ADB)",
    ),
    "device_disconnected": MessageLookupByLibrary.simpleMessage(
      "Connection disconnected",
    ),
    "device_info": MessageLookupByLibrary.simpleMessage("Device Info"),
    "device_maintenance": MessageLookupByLibrary.simpleMessage(
      "Device Maintenance",
    ),
    "device_path": MessageLookupByLibrary.simpleMessage("Device path"),
    "device_path_hint": MessageLookupByLibrary.simpleMessage(
      "Enter /sdcard or another device path",
    ),
    "device_port": MessageLookupByLibrary.simpleMessage("Device port"),
    "device_settings": MessageLookupByLibrary.simpleMessage("Device Settings"),
    "device_unauthorized": MessageLookupByLibrary.simpleMessage(
      "Unauthorized (approve trust on the phone)",
    ),
    "directory": MessageLookupByLibrary.simpleMessage("Directory"),
    "disable_bluetooth": MessageLookupByLibrary.simpleMessage(
      "Disable Bluetooth",
    ),
    "disable_wifi": MessageLookupByLibrary.simpleMessage("Disable Wi‑Fi"),
    "display": MessageLookupByLibrary.simpleMessage("Display"),
    "downloaded": MessageLookupByLibrary.simpleMessage("Downloaded"),
    "enable_bluetooth": MessageLookupByLibrary.simpleMessage(
      "Enable Bluetooth",
    ),
    "enable_wifi": MessageLookupByLibrary.simpleMessage("Enable Wi‑Fi"),
    "enter": MessageLookupByLibrary.simpleMessage("Enter"),
    "execute": MessageLookupByLibrary.simpleMessage("Execute"),
    "file_browser": MessageLookupByLibrary.simpleMessage("File Browser"),
    "file_count": m2,
    "file_management": MessageLookupByLibrary.simpleMessage("File Management"),
    "file_pulled": m3,
    "file_size_bytes": m4,
    "filter_keywords": MessageLookupByLibrary.simpleMessage("Filter keywords"),
    "hardware": MessageLookupByLibrary.simpleMessage("Hardware"),
    "hardware_controls": MessageLookupByLibrary.simpleMessage(
      "Hardware keys and screen actions",
    ),
    "hide_screen": MessageLookupByLibrary.simpleMessage("Hide screen"),
    "imei": MessageLookupByLibrary.simpleMessage("IMEI"),
    "injected_phrase_log": m5,
    "install_apk": MessageLookupByLibrary.simpleMessage("Install APK"),
    "ip": MessageLookupByLibrary.simpleMessage("IP"),
    "local_destination_required": MessageLookupByLibrary.simpleMessage(
      "Enter a local destination path first",
    ),
    "local_file_pull_path": MessageLookupByLibrary.simpleMessage(
      "Local destination path for pulled files",
    ),
    "local_port": MessageLookupByLibrary.simpleMessage("Local port"),
    "logcat_logs": MessageLookupByLibrary.simpleMessage("Logcat Logs"),
    "logcat_started": MessageLookupByLibrary.simpleMessage("logcat started"),
    "logcat_stopped": MessageLookupByLibrary.simpleMessage("logcat stopped"),
    "logcat_waiting": MessageLookupByLibrary.simpleMessage(
      "# Start logcat to display device logs",
    ),
    "logs": MessageLookupByLibrary.simpleMessage("Logs"),
    "logs_copied": MessageLookupByLibrary.simpleMessage(
      "Logs copied to the clipboard",
    ),
    "manufacturer": MessageLookupByLibrary.simpleMessage("Manufacturer"),
    "memory": MessageLookupByLibrary.simpleMessage("Memory"),
    "model": MessageLookupByLibrary.simpleMessage("Model"),
    "monitor_disabled": MessageLookupByLibrary.simpleMessage(
      "Monitoring is off · Enable it when needed to reduce device impact",
    ),
    "monitor_reading": MessageLookupByLibrary.simpleMessage(
      "Sampling every 5 seconds · Reading device data",
    ),
    "monitor_sampling": MessageLookupByLibrary.simpleMessage(
      "Sampling every 5 seconds · CPU, memory and network",
    ),
    "network": MessageLookupByLibrary.simpleMessage("Network"),
    "network_ip": MessageLookupByLibrary.simpleMessage("Network IP"),
    "network_sim": MessageLookupByLibrary.simpleMessage("Network / SIM"),
    "next": MessageLookupByLibrary.simpleMessage("Next"),
    "no_directory_content": MessageLookupByLibrary.simpleMessage(
      "No directory contents",
    ),
    "no_logs_to_copy": MessageLookupByLibrary.simpleMessage(
      "There are no logs to copy",
    ),
    "no_usb_device": MessageLookupByLibrary.simpleMessage(
      "No connected USB device detected",
    ),
    "open": MessageLookupByLibrary.simpleMessage("Open"),
    "open_app_store": MessageLookupByLibrary.simpleMessage("Open app store"),
    "open_system_monitor": MessageLookupByLibrary.simpleMessage(
      "Turn on system monitor",
    ),
    "package_name_hint": MessageLookupByLibrary.simpleMessage("Package name"),
    "parent_directory": MessageLookupByLibrary.simpleMessage(
      "Parent directory",
    ),
    "paste_computer_clipboard": MessageLookupByLibrary.simpleMessage(
      "Paste computer clipboard",
    ),
    "pasted_clipboard_log": m6,
    "platform": MessageLookupByLibrary.simpleMessage("Platform"),
    "play_pause": MessageLookupByLibrary.simpleMessage("Play/Pause"),
    "port_forwarding": MessageLookupByLibrary.simpleMessage("Port Forwarding"),
    "power": MessageLookupByLibrary.simpleMessage("Power"),
    "product": MessageLookupByLibrary.simpleMessage("Product"),
    "pull_file": MessageLookupByLibrary.simpleMessage("Pull file"),
    "quick_control": MessageLookupByLibrary.simpleMessage("Quick Control"),
    "read_apps": MessageLookupByLibrary.simpleMessage("List apps"),
    "read_device_info": MessageLookupByLibrary.simpleMessage(
      "Read device info",
    ),
    "read_local_device": MessageLookupByLibrary.simpleMessage(
      "Read local devices",
    ),
    "read_phone": MessageLookupByLibrary.simpleMessage("Read phone"),
    "reading": MessageLookupByLibrary.simpleMessage("Reading..."),
    "realtime_text_hint": MessageLookupByLibrary.simpleMessage(
      "Real-time text injection...",
    ),
    "refresh": MessageLookupByLibrary.simpleMessage("Refresh"),
    "remote_address_hint": MessageLookupByLibrary.simpleMessage(
      "Device address, e.g. 192.168.1.8:36997",
    ),
    "remote_debug_discovered": m7,
    "remote_debug_hint": MessageLookupByLibrary.simpleMessage(
      "Read local devices to detect the wireless ADB port; connect to use it in the device selector.",
    ),
    "remote_debug_read_failed": m8,
    "remote_debug_subtitle": MessageLookupByLibrary.simpleMessage(
      "Configure a TCP/IP port for wireless screen control",
    ),
    "remote_debug_title": MessageLookupByLibrary.simpleMessage(
      "ADB Remote Network Debugging (Wireless ADB)",
    ),
    "remove": MessageLookupByLibrary.simpleMessage("Remove"),
    "rescan_adb_devices": MessageLookupByLibrary.simpleMessage(
      "Rescan connected ADB devices",
    ),
    "resolution": MessageLookupByLibrary.simpleMessage("Resolution"),
    "restart": MessageLookupByLibrary.simpleMessage("Restart"),
    "restart_confirmation": MessageLookupByLibrary.simpleMessage(
      "Restart the current device?",
    ),
    "restart_device": MessageLookupByLibrary.simpleMessage("Restart device"),
    "ring": MessageLookupByLibrary.simpleMessage("Ring"),
    "rotate_screen": MessageLookupByLibrary.simpleMessage("Rotate Screen"),
    "sample_email": MessageLookupByLibrary.simpleMessage("test@example.com"),
    "sample_greeting": MessageLookupByLibrary.simpleMessage("Hello, world! 🎉"),
    "sample_phone": MessageLookupByLibrary.simpleMessage("13800000000"),
    "screen_resolution": MessageLookupByLibrary.simpleMessage(
      "Screen Resolution",
    ),
    "screenshot_copied": MessageLookupByLibrary.simpleMessage(
      "PNG copied to the system image clipboard",
    ),
    "sdk": MessageLookupByLibrary.simpleMessage("SDK"),
    "search": MessageLookupByLibrary.simpleMessage("Search"),
    "send": MessageLookupByLibrary.simpleMessage("Send"),
    "serial_number": MessageLookupByLibrary.simpleMessage("Serial number"),
    "shell_command_hint": MessageLookupByLibrary.simpleMessage(
      "Enter Shell command",
    ),
    "shell_waiting": MessageLookupByLibrary.simpleMessage(
      "# Waiting for a command...",
    ),
    "show_screen": MessageLookupByLibrary.simpleMessage("Show screen"),
    "silent": MessageLookupByLibrary.simpleMessage("Silent"),
    "sim_country": MessageLookupByLibrary.simpleMessage("SIM country"),
    "smart_input_hub": MessageLookupByLibrary.simpleMessage("Smart Input Hub"),
    "smart_input_subtitle": MessageLookupByLibrary.simpleMessage(
      "Real-time text injection and phrase shortcuts",
    ),
    "special_keys": MessageLookupByLibrary.simpleMessage("Special Keys"),
    "start": MessageLookupByLibrary.simpleMessage("Start"),
    "stf_lite_runtime_not_ready": MessageLookupByLibrary.simpleMessage(
      "STF Lite runtime is not ready",
    ),
    "stf_lite_runtime_start_failed": m9,
    "stf_lite_runtime_unavailable": MessageLookupByLibrary.simpleMessage(
      "STF Lite runtime resources are not configured; set the sidecar and resource directory",
    ),
    "stf_lite_screen_closed": MessageLookupByLibrary.simpleMessage(
      "STF Lite screen connection closed; retrying",
    ),
    "stf_lite_screen_connecting": MessageLookupByLibrary.simpleMessage(
      "Connecting to the STF screen stream...",
    ),
    "stf_lite_screen_connection_error": MessageLookupByLibrary.simpleMessage(
      "STF Lite screen connection error; retrying",
    ),
    "stf_lite_screen_disconnected": MessageLookupByLibrary.simpleMessage(
      "STF screen connection disconnected",
    ),
    "stf_lite_screen_interrupted": MessageLookupByLibrary.simpleMessage(
      "STF Lite screen connection interrupted; retrying",
    ),
    "stf_lite_screen_paused": MessageLookupByLibrary.simpleMessage(
      "STF screen stream paused",
    ),
    "stf_lite_screen_reconnecting": MessageLookupByLibrary.simpleMessage(
      "STF Lite screen connection lost; resolving the service again",
    ),
    "stf_lite_screen_service_unavailable": MessageLookupByLibrary.simpleMessage(
      "STF screen service unavailable",
    ),
    "stf_lite_screen_session_missing": MessageLookupByLibrary.simpleMessage(
      "STF Lite screen session not found; retrying",
    ),
    "stf_lite_screen_waiting": MessageLookupByLibrary.simpleMessage(
      "Waiting for the first STF screen frame...",
    ),
    "stf_lite_sidecar_exited": MessageLookupByLibrary.simpleMessage(
      "STF Lite sidecar exited",
    ),
    "stop": MessageLookupByLibrary.simpleMessage("Stop"),
    "storage": MessageLookupByLibrary.simpleMessage("Storage"),
    "store": MessageLookupByLibrary.simpleMessage("Store"),
    "store_account": MessageLookupByLibrary.simpleMessage("App Store Account"),
    "switch_device": MessageLookupByLibrary.simpleMessage("Switch device"),
    "switch_input_method": MessageLookupByLibrary.simpleMessage(
      "Switch input method",
    ),
    "switch_to_landscape": MessageLookupByLibrary.simpleMessage(
      "Switch to landscape (90°)",
    ),
    "switch_to_portrait": MessageLookupByLibrary.simpleMessage(
      "Switch to portrait (0°)",
    ),
    "system_monitor": MessageLookupByLibrary.simpleMessage(
      "Real-time System Monitor",
    ),
    "system_monitor_accessibility": MessageLookupByLibrary.simpleMessage(
      "Real-time system monitor",
    ),
    "system_settings": MessageLookupByLibrary.simpleMessage("System Settings"),
    "system_version": MessageLookupByLibrary.simpleMessage("System Version"),
    "temperature": MessageLookupByLibrary.simpleMessage("Temperature"),
    "third_party_apps_loaded": m10,
    "toggle_theme": MessageLookupByLibrary.simpleMessage(
      "Switch theme (Liquid Blue / Rose Glow)",
    ),
    "uninstall": MessageLookupByLibrary.simpleMessage("Uninstall"),
    "unknown": MessageLookupByLibrary.simpleMessage("Unknown"),
    "unknown_device": MessageLookupByLibrary.simpleMessage("Unknown device"),
    "url_deeplink_hint": MessageLookupByLibrary.simpleMessage(
      "Enter a URL or DeepLink...",
    ),
    "url_deeplink_launcher": MessageLookupByLibrary.simpleMessage(
      "URL and DeepLink Launcher",
    ),
    "url_deeplink_subtitle": MessageLookupByLibrary.simpleMessage(
      "Open a web page or DeepLink in the device browser",
    ),
    "vibrate": MessageLookupByLibrary.simpleMessage("Vibrate"),
    "view": MessageLookupByLibrary.simpleMessage("View"),
    "view_accounts": MessageLookupByLibrary.simpleMessage("View accounts"),
    "volume_down": MessageLookupByLibrary.simpleMessage("Volume Down"),
    "volume_up": MessageLookupByLibrary.simpleMessage("Volume Up"),
    "write_phone": MessageLookupByLibrary.simpleMessage("Write to phone"),
  };
}
