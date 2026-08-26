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

  static String joinPath(String parent, String child) {
    if (parent.isEmpty || parent == '/') {
      return '/${child.replaceFirst('/', '')}';
    }
    return '${parent.replaceFirst(RegExp(r'/+$'), '')}/$child';
  }
}
