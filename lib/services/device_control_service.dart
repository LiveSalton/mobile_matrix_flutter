import 'dart:async';
import 'package:flutter/foundation.dart';
import 'adb_service.dart';

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

  double? _downXP;
  double? _downYP;
  double? _lastXP;
  double? _lastYP;
  DateTime? _downTime;
  bool _hasMoved = false;

  String _clipboardContent = '';
  final List<String> _commandHistory = [];

  AdbDeviceControlService({
    required this.serial,
    required this.realWidth,
    required this.realHeight,
  }) {
    _session = AdbInteractiveSession(serial: serial);
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
    _downXP = xP;
    _downYP = yP;
    _lastXP = xP;
    _lastYP = yP;
    _downTime = DateTime.now();
    _hasMoved = false;
  }

  @override
  void touchMove({
    required int contact,
    required double xP,
    required double yP,
    double pressure = 0.5,
  }) {
    if (_downXP == null || _downYP == null) return;

    final startX = (_downXP! * realWidth).round();
    final startY = (_downYP! * realHeight).round();
    final currentX = (xP * realWidth).round();
    final currentY = (yP * realHeight).round();

    final deltaX = (currentX - startX).abs();
    final deltaY = (currentY - startY).abs();

    if (deltaX > 20 || deltaY > 20) {
      _hasMoved = true;
    }

    _lastXP = xP;
    _lastYP = yP;
  }

  @override
  Future<void> touchUp({required int contact}) async {
    if (_downXP == null || _downYP == null) return;

    final startX = (_downXP! * realWidth).round();
    final startY = (_downYP! * realHeight).round();
    final endX = ((_lastXP ?? _downXP!) * realWidth).round();
    final endY = ((_lastYP ?? _downYP!) * realHeight).round();

    final deltaX = (endX - startX).abs();
    final deltaY = (endY - startY).abs();

    final elapsed = _downTime != null
        ? DateTime.now().difference(_downTime!).inMilliseconds
        : 200;

    final Future<void> gesture;
    if (!_hasMoved && deltaX < 15 && deltaY < 15) {
      if (elapsed >= 450) {
        // 长按手势下发
        gesture = _session.longPressAndWait(
          startX,
          startY,
          elapsed.clamp(500, 1500).toInt(),
        );
      } else {
        // 毫秒级即时短点击
        gesture = _session.tapAndWait(startX, startY);
      }
    } else {
      // 顺畅滑动手势
      final duration = elapsed.clamp(80, 400).toInt();
      gesture = _session.swipeAndWait(startX, startY, endX, endY, duration);
    }

    // Clear the local gesture before awaiting ADB so a new pointer down cannot
    // be cleared by a slower previous swipe command.
    _downXP = null;
    _downYP = null;
    _lastXP = null;
    _lastYP = null;
    _hasMoved = false;

    await gesture;
  }

  @override
  void touchCommit() {}

  @override
  void keyPress(DeviceKeyAction key) {
    int keyCode = 3;
    switch (key) {
      case DeviceKeyAction.home:
        keyCode = 3;
        break;
      case DeviceKeyAction.back:
        keyCode = 4;
        break;
      case DeviceKeyAction.menu:
        keyCode = 82;
        break;
      case DeviceKeyAction.appSwitch:
        keyCode = 187;
        break;
      case DeviceKeyAction.power:
        keyCode = 26;
        break;
      case DeviceKeyAction.volumeUp:
        keyCode = 24;
        break;
      case DeviceKeyAction.volumeDown:
        keyCode = 25;
        break;
      case DeviceKeyAction.enter:
        keyCode = 66;
        break;
      case DeviceKeyAction.delete:
        keyCode = 67;
        break;
      case DeviceKeyAction.tab:
        keyCode = 61;
        break;
      case DeviceKeyAction.escape:
        keyCode = 111;
        break;
      case DeviceKeyAction.dpadUp:
        keyCode = 19;
        break;
      case DeviceKeyAction.dpadDown:
        keyCode = 20;
        break;
      case DeviceKeyAction.dpadLeft:
        keyCode = 21;
        break;
      case DeviceKeyAction.dpadRight:
        keyCode = 22;
        break;
    }
    _session.keyevent(keyCode);
  }

  @override
  Future<bool> typeText(String text) async {
    return pasteText(text);
  }

  @override
  Future<bool> pasteText(String text) async {
    if (text.isEmpty) return false;
    _clipboardContent = text;
    await _session.pasteText(text);
    notifyListeners();
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
