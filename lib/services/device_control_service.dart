import 'dart:async';
import 'package:flutter/foundation.dart';
import 'adb_service.dart';
import 'stf_touch_service.dart';

enum DeviceKeyAction {
  home,
  back,
  menu,
  appSwitch,
  power,
  volumeUp,
  volumeDown,
  enter,
  delete,
  tab,
  escape,
  dpadUp,
  dpadDown,
  dpadLeft,
  dpadRight,
  camera,
  switchCharset,
  search,
  mute,
  mediaRewind,
  mediaPrevious,
  mediaPlayPause,
  mediaStop,
  mediaNext,
  mediaFastForward,
}

int androidKeyCodeForAction(DeviceKeyAction key) {
  return switch (key) {
    DeviceKeyAction.home => 3,
    DeviceKeyAction.back => 4,
    DeviceKeyAction.menu => 82,
    DeviceKeyAction.appSwitch => 187,
    DeviceKeyAction.power => 26,
    DeviceKeyAction.volumeUp => 24,
    DeviceKeyAction.volumeDown => 25,
    DeviceKeyAction.enter => 66,
    DeviceKeyAction.delete => 67,
    DeviceKeyAction.tab => 61,
    DeviceKeyAction.escape => 111,
    DeviceKeyAction.dpadUp => 19,
    DeviceKeyAction.dpadDown => 20,
    DeviceKeyAction.dpadLeft => 21,
    DeviceKeyAction.dpadRight => 22,
    DeviceKeyAction.camera => 27,
    DeviceKeyAction.switchCharset => 95,
    DeviceKeyAction.search => 84,
    DeviceKeyAction.mute => 91,
    DeviceKeyAction.mediaRewind => 89,
    DeviceKeyAction.mediaPrevious => 88,
    DeviceKeyAction.mediaPlayPause => 85,
    DeviceKeyAction.mediaStop => 86,
    DeviceKeyAction.mediaNext => 87,
    DeviceKeyAction.mediaFastForward => 90,
  };
}

abstract class IDeviceControlService {
  void touchDown({
    required int contact,
    required double xP,
    required double yP,
    double pressure = 0.5,
  });
  void touchMove({
    required int contact,
    required double xP,
    required double yP,
    double pressure = 0.5,
  });
  Future<void> touchUp({required int contact});
  void touchCommit();
  void rawKeyDown(String keyName);
  void rawKeyUp(String keyName);
  void rawKeyPress(String keyName);
  void keyPress(DeviceKeyAction key);
  Future<bool> typeText(String text);
  Future<bool> pasteText(String text);
  Future<String?> getClipboard();
  Future<String> executeShell(String command);
  void setRotation(int rotation);
  void dispose();
}

class AdbDeviceControlService extends ChangeNotifier
    implements IDeviceControlService {
  final String serial;
  final int realWidth;
  final int realHeight;
  late final AdbInteractiveSession _session;
  late final StfTouchService _touchService;

  String _clipboardContent = '';
  final List<String> _commandHistory = [];

  AdbDeviceControlService({
    required this.serial,
    required this.realWidth,
    required this.realHeight,
  }) {
    _session = AdbInteractiveSession(serial: serial);
    _touchService = StfTouchService(serial: serial);
  }

  List<String> get commandHistory => List.unmodifiable(_commandHistory);
  String get clipboardContent => _clipboardContent;

  @override
  void touchDown({
    required int contact,
    required double xP,
    required double yP,
    double pressure = 0.5,
  }) {
    _touchService.touchDown(
      contact: contact,
      xP: xP,
      yP: yP,
      pressure: pressure,
    );
  }

  @override
  void touchMove({
    required int contact,
    required double xP,
    required double yP,
    double pressure = 0.5,
  }) {
    _touchService.touchMove(
      contact: contact,
      xP: xP,
      yP: yP,
      pressure: pressure,
    );
  }

  @override
  Future<void> touchUp({required int contact}) {
    return _touchService.touchUp(contact: contact);
  }

  @override
  void touchCommit() {
    _touchService.touchCommit();
  }

  @override
  void rawKeyDown(String keyName) {
    _touchService.keyDown(keyName);
  }

  @override
  void rawKeyUp(String keyName) {
    _touchService.keyUp(keyName);
  }

  @override
  void rawKeyPress(String keyName) {
    _touchService.keyPress(keyName);
  }

  @override
  void keyPress(DeviceKeyAction key) {
    _session.keyevent(androidKeyCodeForAction(key));
  }

  @override
  Future<bool> typeText(String text) async {
    return pasteText(text);
  }

  @override
  Future<bool> pasteText(String text) async {
    if (text.isEmpty) return false;
    final pasted = await _session.pasteText(text);
    if (!pasted) {
      if (kDebugMode) {
        debugPrint('[AdbInput:$serial] paste failed chars=${text.length}');
      }
      return false;
    }

    _clipboardContent = text;
    notifyListeners();
    if (kDebugMode) {
      debugPrint('[AdbInput:$serial] paste completed chars=${text.length}');
    }
    return true;
  }

  @override
  Future<String?> getClipboard() async {
    return _clipboardContent;
  }

  @override
  Future<String> executeShell(String command) async {
    _commandHistory.add(command);
    notifyListeners();
    final res = await AdbService.executeShell(serial, command);
    return res;
  }

  @override
  void setRotation(int rotation) {
    _session.sendCommand(
      'settings put system user_rotation ${(rotation ~/ 90)}',
    );
  }

  @override
  void dispose() {
    _touchService.dispose();
    _session.dispose();
    super.dispose();
  }
}

class MockDeviceControlService extends ChangeNotifier
    implements IDeviceControlService {
  final String serial;
  int _seq = 0;
  String _clipboardContent = '';
  final List<String> _commandHistory = [];

  MockDeviceControlService({required this.serial});

  int get _nextSeq => ++_seq;
  List<String> get commandHistory => List.unmodifiable(_commandHistory);
  String get clipboardContent => _clipboardContent;

  void _logAction(String action) {
    if (kDebugMode) {
      debugPrint('[ControlService:$serial] $action');
    }
  }

  @override
  void touchDown({
    required int contact,
    required double xP,
    required double yP,
    double pressure = 0.5,
  }) {
    _logAction(
      'touchDown seq=$_nextSeq contact=$contact xP=${xP.toStringAsFixed(3)} yP=${yP.toStringAsFixed(3)}',
    );
  }

  @override
  void touchMove({
    required int contact,
    required double xP,
    required double yP,
    double pressure = 0.5,
  }) {
    _logAction(
      'touchMove seq=$_nextSeq contact=$contact xP=${xP.toStringAsFixed(3)} yP=${yP.toStringAsFixed(3)}',
    );
  }

  @override
  Future<void> touchUp({required int contact}) async {
    _logAction('touchUp seq=$_nextSeq contact=$contact');
    return Future<void>.value();
  }

  @override
  void touchCommit() {
    _logAction('touchCommit seq=$_nextSeq');
  }

  @override
  void rawKeyDown(String keyName) {
    _logAction('rawKeyDown: $keyName');
  }

  @override
  void rawKeyUp(String keyName) {
    _logAction('rawKeyUp: $keyName');
  }

  @override
  void rawKeyPress(String keyName) {
    _logAction('rawKeyPress: $keyName');
  }

  @override
  void keyPress(DeviceKeyAction key) {
    _logAction('keyPress: ${key.name}');
  }

  @override
  Future<bool> typeText(String text) async {
    _logAction('typeText: "$text"');
    return true;
  }

  @override
  Future<bool> pasteText(String text) async {
    _clipboardContent = text;
    _logAction('pasteText: "$text"');
    notifyListeners();
    return true;
  }

  @override
  Future<String?> getClipboard() async {
    _logAction('getClipboard -> "$_clipboardContent"');
    return _clipboardContent;
  }

  @override
  Future<String> executeShell(String command) async {
    _commandHistory.add(command);
    _logAction('executeShell: "$command"');
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 120));
    if (command.trim() == 'getprop ro.build.version.release') {
      return '14\n';
    } else if (command.trim() == 'wm size') {
      return 'Physical size: 1080x2400\n';
    } else if (command.trim() == 'ip addr show') {
      return '1: lo: <LOOPBACK,UP> mtu 65536 qdisc noqueue\n    inet 127.0.0.1/8 scope host lo\n2: wlan0: <BROADCAST,MULTICAST,UP> mtu 1500\n    inet 192.168.1.108/24 brd 192.168.1.255 scope global wlan0\n';
    }
    return 'Execution success: [${command.trim()}]\n';
  }

  @override
  void setRotation(int rotation) {
    _logAction('setRotation: $rotation°');
  }
}
