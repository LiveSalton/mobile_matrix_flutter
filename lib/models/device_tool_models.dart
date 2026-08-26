import 'dart:typed_data';

enum DeviceToolKind {
  dashboard,
  logs,
  screenshots,
  automation,
  explorer,
  advanced,
  info,
}

enum DeviceRingerMode { silent, vibrate, normal }

class DeviceToolResult {
  final bool success;
  final String output;
  final String? error;

  const DeviceToolResult({required this.success, this.output = '', this.error});

  const DeviceToolResult.ok([String output = ''])
    : this(success: true, output: output);

  const DeviceToolResult.failure(String message, {String output = ''})
    : this(success: false, output: output, error: message);

  String get message => success ? output.trim() : (error ?? output).trim();
}

class DeviceFileEntry {
  final String name;
  final String path;
  final bool isDirectory;
  final int size;
  final String modified;

  const DeviceFileEntry({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.size = 0,
    this.modified = '',
  });
}

class DeviceInfoSnapshot {
  final Map<String, String> values;
  final DateTime capturedAt;

  DeviceInfoSnapshot({
    required Map<String, String> values,
    DateTime? capturedAt,
  }) : values = Map.unmodifiable(values),
       capturedAt = capturedAt ?? DateTime.now();

  String value(String key, [String fallback = '未知']) {
    final result = values[key]?.trim();
    return result == null || result.isEmpty ? fallback : result;
  }
}

class DeviceCpuTimes {
  final int total;
  final int idle;

  const DeviceCpuTimes({required this.total, required this.idle});
}

class DeviceMonitorSnapshot {
  final double? cpuPercent;
  final double? memoryPercent;
  final double? networkBytesPerSecond;
  final DateTime capturedAt;

  const DeviceMonitorSnapshot({
    required this.cpuPercent,
    required this.memoryPercent,
    required this.networkBytesPerSecond,
    required this.capturedAt,
  });
}

class DevicePortForward {
  final int hostPort;
  final int devicePort;

  const DevicePortForward({required this.hostPort, required this.devicePort});
}

class DeviceScreenshotResult {
  final Uint8List bytes;
  final DateTime capturedAt;

  DeviceScreenshotResult(this.bytes, {DateTime? capturedAt})
    : capturedAt = capturedAt ?? DateTime.now();
}
