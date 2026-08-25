import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_matrix/models/device_tool_models.dart';
import 'package:mobile_matrix/services/device_tool_parsers.dart';
import 'package:mobile_matrix/services/device_tools_service.dart';

void main() {
  test('parses adb directory rows into navigable file entries', () {
    const output = '''
drwxr-xr-x 2 shell shell 4096 2026-08-25 10:00 Pictures
-rw-r--r-- 1 shell shell 128 2026-08-25 10:01 hello.txt
''';

    final entries = DeviceToolParsers.parseDirectoryListing(output, '/sdcard');

    expect(entries, hasLength(2));
    expect(entries.first, isA<DeviceFileEntry>());
    expect(entries.first.name, 'Pictures');
    expect(entries.first.isDirectory, isTrue);
    expect(entries.first.path, '/sdcard/Pictures');
    expect(entries.last.size, 128);
  });

  test('parses selected device properties without requiring every key', () {
    const output = '''
[ro.product.model]: [Pixel 9]
[ro.product.manufacturer]: [Google]
[ro.build.version.release]: [15]
''';

    final properties = DeviceToolParsers.parseProperties(output);

    expect(properties['ro.product.model'], 'Pixel 9');
    expect(properties['ro.build.version.release'], '15');
    expect(properties['missing'], isNull);
  });

  test('accepts only tcp ports in the valid range', () {
    expect(DeviceToolsService.validatePort('1'), 1);
    expect(DeviceToolsService.validatePort('65535'), 65535);
    expect(DeviceToolsService.validatePort('0'), isNull);
    expect(DeviceToolsService.validatePort('65536'), isNull);
    expect(DeviceToolsService.validatePort('abc'), isNull);
  });
}
