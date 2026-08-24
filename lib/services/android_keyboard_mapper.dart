import 'package:flutter/services.dart';

/// Maps Flutter desktop keys to the Android key names accepted by STF.
///
/// STF's Socket.IO key payload is a string (for example `a`, `enter`, or
/// `switch_charset`). The STF device service resolves those names to Android
/// KeyCodes before injecting them, which is the same wire format used by the
/// Web console.
abstract final class AndroidKeyboardMapper {
  /// STF resolves this name to Android KEYCODE_SWITCH_CHARSET (95).
  static const String switchCharset = 'switch_charset';

  static String? keyNameFor(KeyEvent event) {
    return _physicalKeyNames[event.physicalKey] ??
        _logicalKeyNames[event.logicalKey];
  }

  static bool isCharsetSwitch(KeyEvent event) {
    final physicalKey = event.physicalKey;
    final logicalKey = event.logicalKey;
    return physicalKey == PhysicalKeyboardKey.convert ||
        physicalKey == PhysicalKeyboardKey.nonConvert ||
        physicalKey == PhysicalKeyboardKey.kanaMode ||
        physicalKey == PhysicalKeyboardKey.lang1 ||
        physicalKey == PhysicalKeyboardKey.lang2 ||
        logicalKey == LogicalKeyboardKey.alphanumeric ||
        logicalKey == LogicalKeyboardKey.convert ||
        logicalKey == LogicalKeyboardKey.nonConvert ||
        logicalKey == LogicalKeyboardKey.kanaMode ||
        logicalKey == LogicalKeyboardKey.kanjiMode ||
        logicalKey == LogicalKeyboardKey.lang1 ||
        logicalKey == LogicalKeyboardKey.lang2;
  }

  static final Map<PhysicalKeyboardKey, String> _physicalKeyNames = {
    PhysicalKeyboardKey.keyA: 'a',
    PhysicalKeyboardKey.keyB: 'b',
    PhysicalKeyboardKey.keyC: 'c',
    PhysicalKeyboardKey.keyD: 'd',
    PhysicalKeyboardKey.keyE: 'e',
    PhysicalKeyboardKey.keyF: 'f',
    PhysicalKeyboardKey.keyG: 'g',
    PhysicalKeyboardKey.keyH: 'h',
    PhysicalKeyboardKey.keyI: 'i',
    PhysicalKeyboardKey.keyJ: 'j',
    PhysicalKeyboardKey.keyK: 'k',
    PhysicalKeyboardKey.keyL: 'l',
    PhysicalKeyboardKey.keyM: 'm',
    PhysicalKeyboardKey.keyN: 'n',
    PhysicalKeyboardKey.keyO: 'o',
    PhysicalKeyboardKey.keyP: 'p',
    PhysicalKeyboardKey.keyQ: 'q',
    PhysicalKeyboardKey.keyR: 'r',
    PhysicalKeyboardKey.keyS: 's',
    PhysicalKeyboardKey.keyT: 't',
    PhysicalKeyboardKey.keyU: 'u',
    PhysicalKeyboardKey.keyV: 'v',
    PhysicalKeyboardKey.keyW: 'w',
    PhysicalKeyboardKey.keyX: 'x',
    PhysicalKeyboardKey.keyY: 'y',
    PhysicalKeyboardKey.keyZ: 'z',
    PhysicalKeyboardKey.digit1: '1',
    PhysicalKeyboardKey.digit2: '2',
    PhysicalKeyboardKey.digit3: '3',
    PhysicalKeyboardKey.digit4: '4',
    PhysicalKeyboardKey.digit5: '5',
    PhysicalKeyboardKey.digit6: '6',
    PhysicalKeyboardKey.digit7: '7',
    PhysicalKeyboardKey.digit8: '8',
    PhysicalKeyboardKey.digit9: '9',
    PhysicalKeyboardKey.digit0: '0',
    PhysicalKeyboardKey.enter: 'enter',
    PhysicalKeyboardKey.numpadEnter: 'numpad_enter',
    PhysicalKeyboardKey.escape: 'escape',
    PhysicalKeyboardKey.backspace: 'del',
    PhysicalKeyboardKey.tab: 'tab',
    PhysicalKeyboardKey.space: 'space',
    PhysicalKeyboardKey.minus: 'minus',
    PhysicalKeyboardKey.equal: 'equals',
    PhysicalKeyboardKey.bracketLeft: 'left_bracket',
    PhysicalKeyboardKey.bracketRight: 'right_bracket',
    PhysicalKeyboardKey.backslash: 'backslash',
    PhysicalKeyboardKey.semicolon: 'semicolon',
    PhysicalKeyboardKey.quote: 'apostrophe',
    PhysicalKeyboardKey.backquote: 'grave',
    PhysicalKeyboardKey.comma: 'comma',
    PhysicalKeyboardKey.period: 'period',
    PhysicalKeyboardKey.slash: 'slash',
    PhysicalKeyboardKey.capsLock: 'caps_lock',
    PhysicalKeyboardKey.arrowUp: 'dpad_up',
    PhysicalKeyboardKey.arrowDown: 'dpad_down',
    PhysicalKeyboardKey.arrowLeft: 'dpad_left',
    PhysicalKeyboardKey.arrowRight: 'dpad_right',
    PhysicalKeyboardKey.home: 'move_home',
    PhysicalKeyboardKey.end: 'move_end',
    PhysicalKeyboardKey.pageUp: 'page_up',
    PhysicalKeyboardKey.pageDown: 'page_down',
    PhysicalKeyboardKey.delete: 'forward_del',
    PhysicalKeyboardKey.shiftLeft: 'shift_left',
    PhysicalKeyboardKey.shiftRight: 'shift_right',
    PhysicalKeyboardKey.controlLeft: 'ctrl_left',
    PhysicalKeyboardKey.controlRight: 'ctrl_right',
    PhysicalKeyboardKey.altLeft: 'alt_left',
    PhysicalKeyboardKey.altRight: 'alt_right',
    PhysicalKeyboardKey.metaLeft: 'meta_left',
    PhysicalKeyboardKey.metaRight: 'meta_right',
    PhysicalKeyboardKey.numpad0: 'numpad_0',
    PhysicalKeyboardKey.numpad1: 'numpad_1',
    PhysicalKeyboardKey.numpad2: 'numpad_2',
    PhysicalKeyboardKey.numpad3: 'numpad_3',
    PhysicalKeyboardKey.numpad4: 'numpad_4',
    PhysicalKeyboardKey.numpad5: 'numpad_5',
    PhysicalKeyboardKey.numpad6: 'numpad_6',
    PhysicalKeyboardKey.numpad7: 'numpad_7',
    PhysicalKeyboardKey.numpad8: 'numpad_8',
    PhysicalKeyboardKey.numpad9: 'numpad_9',
    PhysicalKeyboardKey.numpadDivide: 'numpad_divide',
    PhysicalKeyboardKey.numpadMultiply: 'numpad_multiply',
    PhysicalKeyboardKey.numpadSubtract: 'numpad_subtract',
    PhysicalKeyboardKey.numpadAdd: 'numpad_add',
    PhysicalKeyboardKey.numpadDecimal: 'numpad_dot',
  };

  static final Map<LogicalKeyboardKey, String> _logicalKeyNames = {
    LogicalKeyboardKey.enter: 'enter',
    LogicalKeyboardKey.numpadEnter: 'numpad_enter',
    LogicalKeyboardKey.escape: 'escape',
    LogicalKeyboardKey.backspace: 'del',
    LogicalKeyboardKey.tab: 'tab',
    LogicalKeyboardKey.space: 'space',
    LogicalKeyboardKey.arrowUp: 'dpad_up',
    LogicalKeyboardKey.arrowDown: 'dpad_down',
    LogicalKeyboardKey.arrowLeft: 'dpad_left',
    LogicalKeyboardKey.arrowRight: 'dpad_right',
    LogicalKeyboardKey.home: 'move_home',
    LogicalKeyboardKey.end: 'move_end',
    LogicalKeyboardKey.pageUp: 'page_up',
    LogicalKeyboardKey.pageDown: 'page_down',
    LogicalKeyboardKey.delete: 'forward_del',
    LogicalKeyboardKey.shiftLeft: 'shift_left',
    LogicalKeyboardKey.shiftRight: 'shift_right',
    LogicalKeyboardKey.controlLeft: 'ctrl_left',
    LogicalKeyboardKey.controlRight: 'ctrl_right',
    LogicalKeyboardKey.altLeft: 'alt_left',
    LogicalKeyboardKey.altRight: 'alt_right',
    LogicalKeyboardKey.metaLeft: 'meta_left',
    LogicalKeyboardKey.metaRight: 'meta_right',
  };
}
