/// The three raw-key actions understood by the STF Lite control protocol.
enum DeviceKeyInputAction { down, up, press }

extension DeviceKeyInputActionWireName on DeviceKeyInputAction {
  String get wireName => name;
}

/// Modifier state captured from Flutter's physical keyboard at dispatch time.
///
/// This model intentionally contains no UI or process concerns so the same
/// event contract can be used by the real and mock control services.
class DeviceKeyModifiers {
  final bool shift;
  final bool ctrl;
  final bool alt;
  final bool meta;
  final bool sym;
  final bool function;
  final bool capsLock;
  final bool scrollLock;
  final bool numLock;

  const DeviceKeyModifiers({
    this.shift = false,
    this.ctrl = false,
    this.alt = false,
    this.meta = false,
    this.sym = false,
    this.function = false,
    this.capsLock = false,
    this.scrollLock = false,
    this.numLock = false,
  });

  static const none = DeviceKeyModifiers();

  Map<String, bool> toJson() => <String, bool>{
    'shift': shift,
    'ctrl': ctrl,
    'alt': alt,
    'meta': meta,
    'sym': sym,
    'function': function,
    'capsLock': capsLock,
    'scrollLock': scrollLock,
    'numLock': numLock,
  };
}

class DeviceKeyEvent {
  final String serial;
  final DeviceKeyInputAction action;
  final String canonicalKey;
  final DeviceKeyModifiers modifiers;

  const DeviceKeyEvent({
    required this.serial,
    required this.action,
    required this.canonicalKey,
    this.modifiers = DeviceKeyModifiers.none,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
    'type': 'key',
    'action': action.wireName,
    'key': canonicalKey,
    'modifiers': modifiers.toJson(),
  };
}
