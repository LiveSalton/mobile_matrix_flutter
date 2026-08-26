import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/device_tool_models.dart';
import 'adb_service.dart';
import 'device_tool_parsers.dart';

class DeviceToolsService extends ChangeNotifier {
  final String serial;
  Process? _logcatProcess;
  StreamController<String>? _logController;
  DeviceCpuTimes? _previousCpuTimes;
  int? _previousNetworkBytes;
  DateTime? _previousMonitorAt;
  bool _isDisposed = false;

  DeviceToolsService({required this.serial});

  Stream<String> get logLines =>
      (_logController ??= StreamController<String>.broadcast()).stream;

  static int? validatePort(String value) {
    final port = int.tryParse(value.trim());
    if (port == null || port < 1 || port > 65535) return null;
    return port;
  }

  static String? validateRemoteAddress(String value) {
    final address = value.trim();
    if (address.isEmpty) return '请输入远程调试地址';
    final separator = address.lastIndexOf(':');
    if (separator <= 0 || separator == address.length - 1) {
      return '地址格式应为 主机:端口';
    }
    if (validatePort(address.substring(separator + 1)) == null) {
      return '远程调试端口无效';
    }
    return null;
  }

  static String? normalizeUrl(String value) {
    final url = value.trim();
    if (url.isEmpty) return null;
    if (RegExp(r'^[a-z][a-z0-9+.-]*://', caseSensitive: false).hasMatch(url)) {
      return url;
    }
    return 'http://$url';
  }

  Future<DeviceToolResult> runShell(String command) async {
    if (command.trim().isEmpty) {
      return const DeviceToolResult.failure('命令不能为空');
    }
    final output = await AdbService.executeShell(serial, command);
    return _resultFromShellOutput(output);
  }

  Future<DeviceToolResult> listDirectory(String path) async {
    final cleanPath = path.trim().isEmpty ? '/sdcard' : path.trim();
    final result = await runShell('ls -la ${_quoteShell(cleanPath)}');
    if (!result.success) return result;
    final entries = DeviceToolParsers.parseDirectoryListing(
      result.output,
      cleanPath,
    );
    if (entries.isEmpty && result.output.trim().isNotEmpty) {
      return DeviceToolResult.ok(result.output);
    }
    return DeviceToolResult.ok(result.output);
  }

  Future<DeviceToolResult> installApk(String localPath) async {
    if (localPath.trim().isEmpty) {
      return const DeviceToolResult.failure('请输入 APK 路径');
    }
    return AdbService.installApk(serial, localPath.trim());
  }

  Future<DeviceToolResult> pullFile(String remotePath, String localPath) async {
    if (remotePath.trim().isEmpty || localPath.trim().isEmpty) {
      return const DeviceToolResult.failure('设备路径和本地目标路径不能为空');
    }
    return AdbService.pullFile(serial, remotePath.trim(), localPath.trim());
  }

  Future<DeviceToolResult> uninstallPackage(String packageName) async {
    final packageId = packageName.trim();
    if (packageId.isEmpty) {
      return const DeviceToolResult.failure('请输入应用包名');
    }
    return runShell('pm uninstall ${_quoteShell(packageId)}');
  }

  Future<DeviceToolResult> listPackages() {
    return runShell('pm list packages -3');
  }

  Future<DeviceToolResult> setRingerMode(DeviceRingerMode mode) {
    final value = switch (mode) {
      DeviceRingerMode.silent => 0,
      DeviceRingerMode.vibrate => 1,
      DeviceRingerMode.normal => 2,
    };
    return runShell('cmd audio set-ringer-mode $value');
  }

  Future<DeviceToolResult> setWifiEnabled(bool enabled) {
    return runShell('svc wifi ${enabled ? 'enable' : 'disable'}');
  }

  Future<DeviceToolResult> setBluetoothEnabled(bool enabled) {
    return runShell('svc bluetooth ${enabled ? 'enable' : 'disable'}');
  }

  Future<DeviceToolResult> clearBluetoothBonds() {
    return runShell('cmd bluetooth_manager unpair-all');
  }

  Future<DeviceToolResult> openAppStore() {
    return runShell(
      'am start -a android.intent.action.VIEW -d market://details?id=com.android.vending',
    );
  }

  Future<DeviceToolResult> openUrl(String value) async {
    final url = normalizeUrl(value);
    if (url == null) return const DeviceToolResult.failure('请输入网址');
    return runShell(
      'am start -a android.intent.action.VIEW -d ${_quoteShell(url)}',
    );
  }

  Future<DeviceToolResult> openSettings() {
    return runShell('am start -a android.settings.SETTINGS');
  }

  Future<DeviceToolResult> openDeveloperOptions() {
    return runShell(
      'am start -a android.settings.APPLICATION_DEVELOPMENT_SETTINGS',
    );
  }

  Future<DeviceToolResult> addStoreAccount() {
    return runShell('am start -a android.settings.ADD_ACCOUNT_SETTINGS');
  }

  Future<DeviceToolResult> getStoreAccounts() {
    return runShell('dumpsys account');
  }

  Future<DeviceToolResult> checkStoreAccount(String account) async {
    if (account.trim().isEmpty) {
      return const DeviceToolResult.failure('请输入要检查的账号');
    }
    final result = await runShell('dumpsys account');
    if (!result.success) return result;
    final found = result.output.toLowerCase().contains(
      account.trim().toLowerCase(),
    );
    return DeviceToolResult.ok(
      found ? '已找到账号：${account.trim()}' : '未找到账号：${account.trim()}',
    );
  }

  Future<DeviceToolResult> removeStoreAccount(String account) async {
    if (account.trim().isEmpty) {
      return const DeviceToolResult.failure('请输入要移除的账号');
    }
    return runShell(
      'cmd account remove-account ${_quoteShell(account.trim())}',
    );
  }

  Future<DeviceToolResult> enableRemoteDebug(String address) async {
    final validation = validateRemoteAddress(address);
    if (validation != null) return DeviceToolResult.failure(validation);
    return AdbService.executeHostCommand(['connect', address.trim()]);
  }

  Future<DeviceToolResult> createPortForward(
    String hostPort,
    String devicePort,
  ) async {
    final host = validatePort(hostPort);
    final device = validatePort(devicePort);
    if (host == null || device == null) {
      return const DeviceToolResult.failure('本地端口和设备端口必须为 1-65535');
    }
    return AdbService.executeHostCommand([
      '-s',
      serial,
      'forward',
      'tcp:$host',
      'tcp:$device',
    ]);
  }

  Future<DeviceToolResult> removePortForward(String hostPort) async {
    final host = validatePort(hostPort);
    if (host == null) return const DeviceToolResult.failure('本地端口无效');
    return AdbService.executeHostCommand([
      '-s',
      serial,
      'forward',
      '--remove',
      'tcp:$host',
    ]);
  }

  Future<DeviceToolResult> testPortForward() {
    return AdbService.executeHostCommand(['-s', serial, 'forward', '--list']);
  }

  Future<DeviceToolResult> reboot() {
    return runShell('reboot');
  }

  Future<DeviceToolResult> loadInfo() async {
    final responses = await Future.wait([
      AdbService.executeShell(serial, 'getprop'),
      AdbService.executeShell(serial, 'dumpsys battery'),
      AdbService.executeShell(serial, 'wm size'),
      AdbService.executeShell(serial, 'wm density'),
      AdbService.executeShell(serial, 'ip route'),
      AdbService.executeShell(serial, 'cat /proc/cpuinfo'),
      AdbService.executeShell(serial, 'cat /proc/meminfo'),
      AdbService.executeShell(serial, 'df -h /data'),
    ]);

    final values = DeviceToolParsers.parseProperties(responses[0]);
    _put(values, 'manufacturer', values['ro.product.manufacturer']);
    _put(values, 'model', values['ro.product.model']);
    _put(values, 'product', values['ro.product.name']);
    _put(values, 'serial', values['ro.serialno'] ?? serial);
    _put(values, 'android', values['ro.build.version.release']);
    _put(values, 'sdk', values['ro.build.version.sdk']);
    _put(values, 'abi', values['ro.product.cpu.abi']);
    _put(values, 'density', _firstMatch(responses[3], r'(\d+)'));
    _put(values, 'display', _firstMatch(responses[2], r'(\d+x\d+)'));
    _put(values, 'network', _firstMatch(responses[4], r'src\s+(\S+)'));
    _put(values, 'batteryLevel', _firstMatch(responses[1], r'level:\s*(\d+)'));
    _put(
      values,
      'batteryStatus',
      _firstMatch(responses[1], r'status:\s*(\d+)'),
    );
    _put(
      values,
      'batteryTemperature',
      _firstMatch(responses[1], r'temperature:\s*(\d+)'),
    );
    _put(
      values,
      'cpuName',
      _firstMatch(responses[5], r'model name\s*:\s*(.+)'),
    );
    _put(
      values,
      'cpuCores',
      RegExp(
        r'^processor\s*:',
        multiLine: true,
      ).allMatches(responses[5]).length.toString(),
    );
    _put(values, 'memory', _firstMatch(responses[6], r'MemTotal:\s*(.+)'));
    _put(values, 'storage', _firstMatch(responses[7], r'/data\s*$'));
    _put(values, 'carrier', values['gsm.operator.alpha']);
    _put(values, 'simCountry', values['gsm.sim.operator.iso-country']);
    _put(values, 'imei', values['ro.ril.oem.imei']);

    return DeviceToolResult.ok(_encodeInfo(values));
  }

  Future<DeviceInfoSnapshot> readInfoSnapshot() async {
    final result = await loadInfo();
    if (!result.success) {
      return DeviceInfoSnapshot(values: {'error': result.message});
    }
    return DeviceInfoSnapshot(values: _decodeInfo(result.output));
  }

  void resetMonitorBaseline() {
    _previousCpuTimes = null;
    _previousNetworkBytes = null;
    _previousMonitorAt = null;
  }

  Future<DeviceMonitorSnapshot> readMonitorSnapshot() async {
    final capturedAt = DateTime.now();
    if (_isDisposed) {
      return DeviceMonitorSnapshot(
        cpuPercent: null,
        memoryPercent: null,
        networkBytesPerSecond: null,
        capturedAt: capturedAt,
      );
    }

    final responses = await Future.wait([
      AdbService.executeShell(serial, 'cat /proc/stat'),
      AdbService.executeShell(serial, 'cat /proc/meminfo'),
      AdbService.executeShell(serial, 'cat /proc/net/dev'),
    ]);
    if (_isDisposed) {
      return DeviceMonitorSnapshot(
        cpuPercent: null,
        memoryPercent: null,
        networkBytesPerSecond: null,
        capturedAt: capturedAt,
      );
    }

    final cpuTimes = DeviceToolParsers.parseCpuTimes(responses[0]);
    final memoryPercent = DeviceToolParsers.parseMemoryUsagePercent(
      responses[1],
    );
    final networkBytes = DeviceToolParsers.parseNetworkBytes(responses[2]);

    double? cpuPercent;
    final previousCpuTimes = _previousCpuTimes;
    if (cpuTimes != null && previousCpuTimes != null) {
      final totalDelta = cpuTimes.total - previousCpuTimes.total;
      final idleDelta = cpuTimes.idle - previousCpuTimes.idle;
      if (totalDelta > 0 && idleDelta >= 0) {
        cpuPercent = ((totalDelta - idleDelta) / totalDelta * 100)
            .clamp(0.0, 100.0)
            .toDouble();
      }
    }

    double? networkBytesPerSecond;
    final previousNetworkBytes = _previousNetworkBytes;
    final previousMonitorAt = _previousMonitorAt;
    if (networkBytes != null &&
        previousNetworkBytes != null &&
        previousMonitorAt != null) {
      final elapsedSeconds =
          capturedAt.difference(previousMonitorAt).inMicroseconds / 1000000;
      final byteDelta = networkBytes - previousNetworkBytes;
      if (elapsedSeconds > 0 && byteDelta >= 0) {
        networkBytesPerSecond = byteDelta / elapsedSeconds;
      }
    }

    if (cpuTimes != null) _previousCpuTimes = cpuTimes;
    if (networkBytes != null) {
      _previousNetworkBytes = networkBytes;
      _previousMonitorAt = capturedAt;
    }

    return DeviceMonitorSnapshot(
      cpuPercent: cpuPercent,
      memoryPercent: memoryPercent,
      networkBytesPerSecond: networkBytesPerSecond,
      capturedAt: capturedAt,
    );
  }

  Future<void> startLogcat({String? filter}) async {
    await stopLogcat();
    final process = await AdbService.startLogcat(serial);
    if (process == null) {
      _logController?.add('无法启动 logcat');
      return;
    }
    _logcatProcess = process;
    final controller = _logController ??= StreamController<String>.broadcast();
    process.stdout
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .listen(
          controller.add,
          onError: controller.addError,
          onDone: () {
            if (identical(_logcatProcess, process)) _logcatProcess = null;
          },
        );
    process.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .listen((line) => controller.add('[stderr] $line'));
    if (filter != null && filter.trim().isNotEmpty) {
      controller.add('logcat 已启动，过滤条件由界面应用：${filter.trim()}');
    }
  }

  Future<void> stopLogcat() async {
    final process = _logcatProcess;
    _logcatProcess = null;
    process?.kill(ProcessSignal.sigterm);
    if (process != null) {
      await process.exitCode.timeout(
        const Duration(seconds: 2),
        onTimeout: () => -1,
      );
    }
  }

  DeviceToolResult _resultFromShellOutput(String output) {
    final trimmed = output.trimLeft();
    if (trimmed.startsWith('Error') ||
        trimmed.startsWith('Execution Exception')) {
      return DeviceToolResult.failure(trimmed);
    }
    return DeviceToolResult.ok(output);
  }

  static String _quoteShell(String value) =>
      "'${value.replaceAll("'", "'\\''")}'";

  static void _put(Map<String, String> values, String key, String? value) {
    if (value != null && value.trim().isNotEmpty) values[key] = value.trim();
  }

  static String? _firstMatch(String value, String pattern) {
    final match = RegExp(pattern, multiLine: true).firstMatch(value);
    return match?.groupCount == 0 ? match?.group(0) : match?.group(1);
  }

  static String _encodeInfo(Map<String, String> values) => values.entries
      .map(
        (entry) =>
            '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value)}',
      )
      .join('&');

  static Map<String, String> _decodeInfo(String value) {
    final result = <String, String>{};
    for (final pair in value.split('&')) {
      if (pair.isEmpty) continue;
      final separator = pair.indexOf('=');
      if (separator <= 0) continue;
      result[Uri.decodeComponent(pair.substring(0, separator))] =
          Uri.decodeComponent(pair.substring(separator + 1));
    }
    return result;
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    unawaited(stopLogcat());
    final controller = _logController;
    _logController = null;
    unawaited(controller?.close() ?? Future<void>.value());
    super.dispose();
  }
}
