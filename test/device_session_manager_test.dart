import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_matrix/models/device_model.dart';
import 'package:mobile_matrix/services/device_session.dart';
import 'package:mobile_matrix/services/device_session_manager.dart';
import 'package:mobile_matrix/services/screen_stream_service.dart';
import 'package:mobile_matrix/services/stf_lite_runtime_service.dart';

class _FakeRuntime extends StfLiteRuntimeService {
  @override
  bool get isAvailable => true;

  @override
  Future<bool> start() async => true;

  @override
  Future<List<StfLiteSessionInfo>> getSessions() async => const [];

  @override
  Future<bool> ensureControlChannel(String serial) async => true;

  @override
  Future<bool> sendControl(String serial, Map<String, dynamic> payload) async =>
      true;
}

DeviceModel _device(String serial) {
  return DeviceModel(
    serial: serial,
    name: serial,
    model: serial,
    manufacturer: 'Test',
    sdkVersion: '35',
    status: DeviceConnectionStatus.using,
    display: const DeviceDisplayInfo(width: 1080, height: 2400),
  );
}

void main() {
  test('reuses sessions by serial and removes after two misses', () async {
    var devices = <DeviceModel>[_device('a'), _device('b')];
    final runtime = _FakeRuntime();
    var builds = 0;
    final manager = DeviceSessionManager(
      runtime: runtime,
      readDevices: () async => devices,
      buildSession: (device, runtime) {
        builds += 1;
        return DeviceSession(
          device: device,
          runtime: runtime,
          streamService: MockScreenStreamService(streamUrl: device.serial),
        );
      },
    );

    await manager.refresh();
    final firstA = manager.sessionFor('a');
    expect(manager.sessions, hasLength(2));
    expect(builds, 2);

    await manager.refresh();
    expect(manager.sessionFor('a'), same(firstA));
    expect(builds, 2);

    devices = <DeviceModel>[_device('a')];
    await manager.refresh();
    expect(manager.sessionFor('b'), isNotNull);
    await manager.refresh();
    expect(manager.sessionFor('b'), isNull);
    expect(manager.sessions, hasLength(1));
    manager.dispose();
  });
}
