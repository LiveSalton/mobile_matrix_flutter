import 'dart:async';
import 'package:flutter/foundation.dart';
import 'adb_service.dart';
import 'stf_lite_runtime_service.dart';

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

/// Device control backed by the local STF Lite session instead of the legacy
/// STF Web Socket and fixed port.
class StfLiteDeviceControlService extends ChangeNotifier
    implements IDeviceControlService {
  final String serial;
  final StfLiteRuntimeService runtime;

  String _clipboardContent = '';
  final List<String> _commandHistory = <String>[];
  Future<void> _controlQueue = Future<void>.value();
  bool _isDisposed = false;

  StfLiteDeviceControlService({required this.serial, required this.runtime}) {
    // Warm the persistent control channel before the first pointer event.
    unawaited(runtime.ensureControlChannel(serial));
  }

  List<String> get commandHistory => List.unmodifiable(_commandHistory);
  String get clipboardContent => _clipboardContent;

  Future<bool> _enqueueControl(Map<String, dynamic> payload) {
    if (_isDisposed) return Future<bool>.value(false);
    final next = _controlQueue.then<bool>((_) async {
      final isHighFrequency =
          payload['type'] == 'touchMove' || payload['type'] == 'touchCommit';
      if (kDebugMode && !isHighFrequency) {
        debugPrint(
          '[StfLiteControl:$serial] request '
          'type=${payload['type']} '
          'action=${payload['action'] ?? '-'} '
          'contact=${payload['contact'] ?? '-'} '
          'x=${payload['x'] ?? '-'} '
          'y=${payload['y'] ?? '-'}',
        );
      }
      final success = await runtime.sendControl(serial, payload);
      if (kDebugMode && !isHighFrequency) {
        debugPrint(
          '[StfLiteControl:$serial] response '
          'type=${payload['type']} success=$success',
        );
      }
      return success;
    });
    _controlQueue = next.then<void>((_) {}).catchError((Object error) {
      if (kDebugMode) {
        debugPrint('[StfLiteControl:$serial] control failed: $error');
      }
    });
    return next;
  }

  void _sendControl(Map<String, dynamic> payload) {
    unawaited(
      _enqueueControl(payload).catchError((Object error) {
        if (kDebugMode) {
          debugPrint('[StfLiteControl:$serial] control failed: $error');
        }
        return false;
      }),
    );
  }

  @override
  void touchDown({
    required int contact,
    required double xP,
    required double yP,
    double pressure = 0.5,
  }) {
    _sendControl(<String, dynamic>{'type': 'gestureStart'});
    _sendControl(<String, dynamic>{
      'type': 'touchDown',
      'contact': contact,
      'x': xP,
      'y': yP,
      'pressure': pressure,
    });
  }

  @override
  void touchMove({
    required int contact,
    required double xP,
    required double yP,
    double pressure = 0.5,
  }) {
    _sendControl(<String, dynamic>{
      'type': 'touchMove',
      'contact': contact,
      'x': xP,
      'y': yP,
      'pressure': pressure,
    });
  }

  @override
  Future<void> touchUp({required int contact}) async {
    await _enqueueControl(<String, dynamic>{
      'type': 'touchUp',
      'contact': contact,
    });
    await _enqueueControl(<String, dynamic>{'type': 'touchCommit'});
    await _enqueueControl(<String, dynamic>{'type': 'gestureStop'});
  }

  @override
  void touchCommit() {
    _sendControl(<String, dynamic>{'type': 'touchCommit'});
  }

  @override
  void rawKeyDown(String keyName) {
    _sendControl(<String, dynamic>{
      'type': 'key',
      'action': 'down',
      'key': keyName,
    });
  }

  @override
  void rawKeyUp(String keyName) {
    _sendControl(<String, dynamic>{
      'type': 'key',
      'action': 'up',
      'key': keyName,
    });
  }

  @override
  void rawKeyPress(String keyName) {
    _sendControl(<String, dynamic>{
      'type': 'key',
      'action': 'press',
      'key': keyName,
    });
  }

  @override
  void keyPress(DeviceKeyAction key) {
    _sendControl(<String, dynamic>{
      'type': 'key',
      'action': 'press',
      'key': androidKeyCodeForAction(key),
    });
  }

  @override
  Future<bool> typeText(String text) => pasteText(text);

  @override
  Future<bool> pasteText(String text) async {
    if (_isDisposed || text.isEmpty) return false;
    final clipboardSet = await runtime.setClipboard(serial, text);
    if (!clipboardSet) return false;
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final pasted = await _enqueueControl(<String, dynamic>{
      'type': 'key',
      'action': 'press',
      'key': 279,
    });
    if (pasted) {
      _clipboardContent = text;
      notifyListeners();
    }
    return pasted;
  }

  @override
  Future<String?> getClipboard() async => _clipboardContent;

  @override
  Future<String> executeShell(String command) async {
    _commandHistory.add(command);
    notifyListeners();
    return AdbService.executeShell(serial, command);
  }

  @override
  void setRotation(int rotation) {
    _sendControl(<String, dynamic>{
      'type': 'rotation',
      'rotation': (rotation ~/ 90).clamp(0, 3),
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
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
