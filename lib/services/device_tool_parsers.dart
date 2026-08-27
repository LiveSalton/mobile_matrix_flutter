import '../models/device_tool_models.dart';

class DeviceToolParsers {
  const DeviceToolParsers._();

  static List<DeviceFileEntry> parseDirectoryListing(
    String output,
    String parentPath,
  ) {
    final entries = <DeviceFileEntry>[];
    for (final rawLine in output.split('\n')) {
      final line = rawLine.trimRight();
      if (line.isEmpty || line == 'total' || line.startsWith('total ')) {
        continue;
      }

      final match = RegExp(
        r'^([bcdlps-][rwx-]{9})\s+\d+\s+\S+\s+\S+\s+(\d+)\s+(.+)$',
      ).firstMatch(line);
      if (match == null) continue;

      final mode = match.group(1)!;
      final size = int.tryParse(match.group(2)!) ?? 0;
      final dateAndName = match.group(3)!;
      final nameMatch = RegExp(r'^\S+\s+\S+\s+(.+)$').firstMatch(dateAndName);
      if (nameMatch == null) continue;

      var name = nameMatch.group(1)!.trim();
      final linkIndex = name.indexOf(' -> ');
      if (linkIndex >= 0) name = name.substring(0, linkIndex);
      if (name == '.' || name == '..' || name.isEmpty) continue;

      entries.add(
        DeviceFileEntry(
          name: name,
          path: joinPath(parentPath, name),
          isDirectory: mode.startsWith('d'),
          size: size,
          modified: dateAndName
              .substring(0, dateAndName.length - nameMatch.group(1)!.length)
              .trim(),
        ),
      );
    }

    entries.sort((a, b) {
      if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return entries;
  }

  static Map<String, String> parseProperties(String output) {
    final values = <String, String>{};
    final pattern = RegExp(r'^\[([^\]]+)\]:\s*\[(.*)\]$');
    for (final line in output.split('\n')) {
      final match = pattern.firstMatch(line.trim());
      if (match != null) values[match.group(1)!] = match.group(2)!;
    }
    return values;
  }

  static DeviceCpuTimes? parseCpuTimes(String output) {
    for (final rawLine in output.split('\n')) {
      final line = rawLine.trim();
      if (!line.startsWith('cpu ')) continue;

      final fields = line.split(RegExp(r'\s+'));
      if (fields.length < 5) return null;

      final counters = <int>[];
      for (final value in fields.skip(1).take(8)) {
        final counter = int.tryParse(value);
        if (counter == null || counter < 0) return null;
        counters.add(counter);
      }
      if (counters.length < 4) return null;

      final total = counters.fold<int>(0, (sum, value) => sum + value);
      final idle = counters[3] + (counters.length > 4 ? counters[4] : 0);
      if (total <= 0 || idle < 0 || idle > total) return null;
      return DeviceCpuTimes(total: total, idle: idle);
    }
    return null;
  }

  static double? parseMemoryUsagePercent(String output) {
    final values = <String, int>{};
    final pattern = RegExp(r'^([A-Za-z_]+):\s+(\d+)\s*kB\s*$', multiLine: true);
    for (final match in pattern.allMatches(output)) {
      final value = int.tryParse(match.group(2)!);
      if (value != null) values[match.group(1)!] = value;
    }

    final total = values['MemTotal'];
    if (total == null || total <= 0) return null;

    final available =
        values['MemAvailable'] ??
        ((values['MemFree'] ?? 0) +
            (values['Buffers'] ?? 0) +
            (values['Cached'] ?? 0));
    final used = total - available;
    return (used / total * 100).clamp(0.0, 100.0).toDouble();
  }

  static int? parseNetworkBytes(String output) {
    var total = 0;
    var foundInterface = false;

    for (final rawLine in output.split('\n')) {
      final separator = rawLine.indexOf(':');
      if (separator <= 0) continue;

      final interfaceName = rawLine.substring(0, separator).trim();
      if (interfaceName.isEmpty || interfaceName == 'lo') continue;

      final fields = rawLine
          .substring(separator + 1)
          .trim()
          .split(RegExp(r'\s+'));
      if (fields.length < 9) continue;

      final received = int.tryParse(fields[0]);
      final transmitted = int.tryParse(fields[8]);
      if (received == null ||
          transmitted == null ||
          received < 0 ||
          transmitted < 0) {
        continue;
      }

      total += received + transmitted;
      foundInterface = true;
    }

    return foundInterface ? total : null;
  }

  static String? parseIpv4Address(String output) {
    String? firstCandidate;
    String? preferredCandidate;
    String? currentInterface;

    for (final rawLine in output.split('\n')) {
      final line = rawLine.trim();
      final interfaceMatch = RegExp(r'^\d+:\s*([^:]+):').firstMatch(line);
      if (interfaceMatch != null) {
        currentInterface = interfaceMatch.group(1);
      }

      final sourceMatch = RegExp(
        r'\bsrc\s+((?:\d{1,3}\.){3}\d{1,3})\b',
      ).firstMatch(line);
      final inetMatch = RegExp(
        r'\binet\s+((?:\d{1,3}\.){3}\d{1,3})\b',
      ).firstMatch(line);
      final candidate = sourceMatch?.group(1) ?? inetMatch?.group(1);
      if (candidate == null || !_isUsableIpv4(candidate)) continue;

      firstCandidate ??= candidate;
      final interfaceName =
          RegExp(r'\bdev\s+(\S+)').firstMatch(line)?.group(1) ??
          currentInterface;
      if (_isLanInterface(interfaceName)) preferredCandidate = candidate;
    }

    return preferredCandidate ?? firstCandidate;
  }

  static String? parseMdnsConnectEndpoint(String output, String serial) {
    const connectService = '_adb-tls-connect._tcp';
    for (final rawLine in output.split('\n')) {
      final fields = rawLine.trim().split(RegExp(r'\s+'));
      if (fields.length < 3 || fields[1] != connectService) continue;

      final endpoint = fields[2];
      final matchesDevice = fields[0].contains(serial) || endpoint == serial;
      final separator = endpoint.lastIndexOf(':');
      final port = separator > 0
          ? int.tryParse(endpoint.substring(separator + 1))
          : null;
      if (matchesDevice && port != null && port > 0 && port <= 65535) {
        return endpoint;
      }
    }
    return null;
  }

  static bool _isUsableIpv4(String value) {
    final octets = value.split('.').map(int.tryParse).toList();
    if (octets.length != 4 || octets.any((octet) => octet == null)) {
      return false;
    }
    if (octets.any((octet) => octet! < 0 || octet > 255)) return false;
    final first = octets[0]!;
    final second = octets[1]!;
    return first != 0 && first != 127 && !(first == 169 && second == 254);
  }

  static bool _isLanInterface(String? interfaceName) {
    if (interfaceName == null) return false;
    return RegExp(
      r'^(wlan|wifi|eth|en)',
      caseSensitive: false,
    ).hasMatch(interfaceName);
  }

  static String joinPath(String parent, String child) {
    if (parent.isEmpty || parent == '/') {
      return '/${child.replaceFirst('/', '')}';
    }
    return '${parent.replaceFirst(RegExp(r'/+$'), '')}/$child';
  }
}
