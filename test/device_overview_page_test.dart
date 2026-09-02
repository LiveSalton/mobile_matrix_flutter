import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_matrix/l10n/l10n.dart';
import 'package:mobile_matrix/models/device_model.dart';
import 'package:mobile_matrix/services/device_session.dart';
import 'package:mobile_matrix/services/device_session_manager.dart';
import 'package:mobile_matrix/services/screen_stream_service.dart';
import 'package:mobile_matrix/services/stf_lite_runtime_service.dart';
import 'package:mobile_matrix/theme/app_theme.dart';
import 'package:mobile_matrix/views/control/device_control_page.dart';
import 'package:mobile_matrix/views/overview/device_overview_page.dart';

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
  test('uses the approved overview breakpoints', () {
    expect(deviceOverviewColumnCount(1280), 4);
    expect(deviceOverviewColumnCount(960), 3);
    expect(deviceOverviewColumnCount(640), 2);
    expect(deviceOverviewColumnCount(639), 1);
  });

  testWidgets('renders serial-keyed previews and opens its console', (
    tester,
  ) async {
    final manager = DeviceSessionManager(
      runtime: _FakeRuntime(),
      readDevices: () async => [_device('serial-a')],
      buildSession: (device, runtime) => DeviceSession(
        device: device,
        runtime: runtime,
        streamService: MockScreenStreamService(streamUrl: device.serial),
      ),
    );
    final themeController = ThemeController();
    final observer = _CountingNavigatorObserver();

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: const [
          L10n.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: const [Locale('zh'), Locale('en')],
        navigatorObservers: [observer],
        theme: AppTheme.buildTheme(themeController.currentTheme),
        home: DeviceOverviewPage(
          themeController: themeController,
          sessionManager: manager,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    expect(
      find.byKey(const ValueKey('device-preview-serial-a')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('open-console-serial-a')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('open-console-serial-a')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(observer.pushes, 2);
    expect(find.byType(DeviceControlPage, skipOffstage: false), findsOneWidget);
    expect(
      find.byKey(const ValueKey('back-to-overview'), skipOffstage: false),
      findsOneWidget,
    );
    expect(manager.sessionFor('serial-a'), isNotNull);

    final backButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('back-to-overview'), skipOffstage: false),
    );
    expect(backButton.onPressed, isNotNull);
    backButton.onPressed!();
    await tester.pump(const Duration(milliseconds: 400));
    expect(observer.pops, 1);
    expect(find.byType(DeviceControlPage), findsNothing);
    manager.dispose();
    themeController.dispose();
  });
}

class _CountingNavigatorObserver extends NavigatorObserver {
  var pushes = 0;
  var pops = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes += 1;
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pops += 1;
    super.didPop(route, previousRoute);
  }
}
