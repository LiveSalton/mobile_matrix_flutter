import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_matrix/services/device_control_service.dart';

void main() {
  test('maps Web advanced keys to Android key codes', () {
    expect(androidKeyCodeForAction(DeviceKeyAction.camera), 27);
    expect(androidKeyCodeForAction(DeviceKeyAction.search), 84);
    expect(androidKeyCodeForAction(DeviceKeyAction.switchCharset), 95);
    expect(androidKeyCodeForAction(DeviceKeyAction.mute), 91);
    expect(androidKeyCodeForAction(DeviceKeyAction.mediaPlayPause), 85);
    expect(androidKeyCodeForAction(DeviceKeyAction.dpadRight), 22);
  });
}
