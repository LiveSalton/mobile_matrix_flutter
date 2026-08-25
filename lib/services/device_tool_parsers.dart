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

  static String joinPath(String parent, String child) {
    if (parent.isEmpty || parent == '/') {
      return '/${child.replaceFirst('/', '')}';
    }
    return '${parent.replaceFirst(RegExp(r'/+$'), '')}/$child';
  }
}
