import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_matrix/services/device_tools_service.dart';

void main() {
  test('rejects blank remote debug address before touching adb', () {
    expect(DeviceToolsService.validateRemoteAddress(''), '请输入远程调试地址');
    expect(
      DeviceToolsService.validateRemoteAddress('192.168.1.8:5555'),
      isNull,
    );
  });

  test('normalizes navigation URLs before opening them on the device', () {
    expect(
      DeviceToolsService.normalizeUrl('example.com'),
      'http://example.com',
    );
    expect(
      DeviceToolsService.normalizeUrl('https://example.com'),
      'https://example.com',
    );
    expect(DeviceToolsService.normalizeUrl(''), isNull);
  });
}
