import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/device_model.dart';

class AdbInteractiveSession {
  final String serial;
  Process? _process;
  Future<void>? _startFuture;
  Future<void> _commandQueue = Future<void>.value();
  bool _isDisposed = false;

  AdbInteractiveSession({required this.serial}) {
    _startFuture = _startSession();
    sendCommand(
      'am start-foreground-service -a jp.co.cyberagent.stf.ACTION_START '
      '-n jp.co.cyberagent.stf/.Service 2>/dev/null || '
      'am startservice -a jp.co.cyberagent.stf.ACTION_START '
      '-n jp.co.cyberagent.stf/.Service 2>/dev/null',
    );
  }

  Future<void> _startSession() async {
    try {
      final adbPath = await AdbService.resolveAdbPath();
      final process = await Process.start(adbPath, ['-s', serial, 'shell']);
      if (_isDisposed) {
        process.kill();
        return;
      }

      _process = process;
      // Drain shell output so a verbose Android command cannot block the
      // interactive session while the control queue is still usable.
      unawaited(process.stdout.drain<void>());
      unawaited(process.stderr.drain<void>());

      process.exitCode.then((_) {
        if (identical(_process, process)) {
          _process = null;
          _startFuture = null;
          if (!_isDisposed) {
            Future<void>.delayed(const Duration(seconds: 1), () {
              if (!_isDisposed && _process == null && _startFuture == null) {
                _startFuture = _startSession();
              }
            });
          }
        }
      });
    } catch (e) {
      _startFuture = null;
      if (kDebugMode) {
        debugPrint('[AdbInteractiveSession] Error starting session: $e');
      }
    }
  }

  Future<void> _ensureStarted() async {
    if (_isDisposed || _process != null) return;

    final pending = _startFuture ??= _startSession();
    await pending;
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final next = _commandQueue.then((_) => operation());
    _commandQueue = next.catchError((error, stack) {
      if (kDebugMode) {
        debugPrint('[AdbInteractiveSession] Command failed: $error');
      }
    });
    return next;
  }

  Future<void> _executeCommand(String command) async {
    await _ensureStarted();
    if (_isDisposed) return;

    final process = _process;
    if (process == null) {
      await AdbService.executeShell(serial, command);
      return;
    }

    try {
      process.stdin.writeln(command);
      await process.stdin.flush();
    } catch (e) {
      if (identical(_process, process)) {
        _process = null;
      }
      if (kDebugMode) {
        debugPrint(
          '[AdbInteractiveSession] Interactive command failed, falling back: $e',
        );
      }
      await AdbService.executeShell(serial, command);
    }
  }

  void sendCommand(String command) {
    unawaited(_enqueue(() => _executeCommand(command)));
  }

  Future<void> sendCommandAndWait(String command) {
    return _enqueue(() => _executeCommand(command));
  }

  void tap(int x, int y) {
    unawaited(tapAndWait(x, y));
  }

  Future<void> tapAndWait(int x, int y) {
    return sendCommandAndWait('input tap $x $y');
  }

  void longPress(int x, int y, [int duration = 600]) {
    unawaited(longPressAndWait(x, y, duration));
  }

  Future<void> longPressAndWait(int x, int y, [int duration = 600]) {
    return sendCommandAndWait('input swipe $x $y $x $y $duration');
  }

  void swipe(int x1, int y1, int x2, int y2, [int duration = 250]) {
    unawaited(swipeAndWait(x1, y1, x2, y2, duration));
  }

  Future<void> swipeAndWait(
    int x1,
    int y1,
    int x2,
    int y2, [
    int duration = 250,
  ]) {
    return sendCommandAndWait('input swipe $x1 $y1 $x2 $y2 $duration');
  }

  void keyevent(int keyCode) {
    sendCommand('input keyevent $keyCode');
  }

  void sendText(String text) {
    unawaited(pasteText(text));
  }

  void setClipboard(String text) {
    if (text.isEmpty) return;
    final escaped = text.replaceAll("'", "'\\''");
    sendCommand(
      "am broadcast -a jp.co.cyberagent.stf.ACTION_SET_CLIPBOARD --es text '$escaped'",
    );
  }

  Future<void> pasteText(String text) {
    if (text.isEmpty) return Future<void>.value();

    final escaped = text.replaceAll("'", "'\\''");
    return _enqueue(() async {
      await _executeCommand(
        "am broadcast -a jp.co.cyberagent.stf.ACTION_SET_CLIPBOARD --es text '$escaped'",
      );
      // The Android clipboard receiver is asynchronous. Keep the broadcast
      // and paste event in one queue item so concurrent keystrokes cannot
      // interleave and paste the wrong value.
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await _executeCommand('input keyevent 279');
    });
  }

  void dispose() {
    _isDisposed = true;
    _process?.kill();
    _process = null;
  }
}

class AdbService {
  static String? _resolvedAdbPath;
  static String? _lastError;

  static String? get lastError => _lastError;

  static Future<String> resolveAdbPath() async {
    if (_resolvedAdbPath != null) return _resolvedAdbPath!;

    final home = Platform.environment['HOME'] ?? '';
    final candidates = [
      if (home.isNotEmpty) '$home/Library/Android/sdk/platform-tools/adb',
      if (home.isNotEmpty) '$home/Android/Sdk/platform-tools/adb',
      '/opt/homebrew/bin/adb',
      '/usr/local/bin/adb',
      'adb',
    ];

    for (final path in candidates) {
      try {
        final res = await Process.run(path, [
          'version',
        ]).timeout(const Duration(seconds: 1));
        if (res.exitCode == 0) {
          _resolvedAdbPath = path;
          return path;
        }
      } catch (_) {}
    }

    _resolvedAdbPath = 'adb';
    return 'adb';
  }

  static Future<int?> resolveDeviceScreenPort(String serial) async {
    try {
      final psRes = await Process.run('ps', [
        'aux',
      ]).timeout(const Duration(seconds: 2));
      if (psRes.exitCode == 0) {
        final stdout = psRes.stdout.toString();
        final lines = LineSplitter.split(stdout);
        for (final line in lines) {
          if (line.contains('stf') &&
              line.contains('device') &&
              line.contains(serial)) {
            final match = RegExp(r'--screen-port\s+(\d+)').firstMatch(line);
            if (match != null) {
              final port = int.tryParse(match.group(1)!);
              if (port != null && port > 0) {
                return port;
              }
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<List<DeviceModel>> getConnectedDevices() async {
    _lastError = null;
    final adb = await resolveAdbPath();
    final List<DeviceModel> devices = [];

    try {
      final result = await Process.run(adb, [
        'devices',
        '-l',
      ]).timeout(const Duration(seconds: 3));

      if (result.exitCode != 0) {
        _lastError = 'ADB 执行错误: ${result.stderr}';
        return devices;
      }

      final lines = LineSplitter.split(result.stdout as String);
      for (final rawLine in lines) {
        final line = rawLine.trim();
        if (line.isEmpty || line.startsWith('List of devices attached')) {
          continue;
        }

        final parts = line.split(RegExp(r'\s+'));
        if (parts.length >= 2) {
          final serial = parts[0];
          final statusStr = parts[1];

          if (statusStr != 'device') continue;

          String modelName = serial;
          String manufacturer = 'Android';

          for (final token in parts.skip(2)) {
            if (token.startsWith('model:')) {
              modelName = token.substring(6);
            } else if (token.startsWith('device:')) {
              if (modelName == serial) {
                modelName = token.substring(7);
              }
            }
          }

          int width = 720;
          int height = 1612;
          int rotation = 0;

          try {
            final sizeRes = await Process.run(adb, [
              '-s',
              serial,
              'shell',
              'wm',
              'size',
            ]).timeout(const Duration(milliseconds: 1500));
            if (sizeRes.exitCode == 0) {
              final match = RegExp(
                r'(\d+)x(\d+)',
              ).firstMatch(sizeRes.stdout as String);
              if (match != null) {
                width = int.parse(match.group(1)!);
                height = int.parse(match.group(2)!);
              }
            }
          } catch (_) {}

          try {
            final rotRes = await Process.run(adb, [
              '-s',
              serial,
              'shell',
              'settings',
              'get',
              'system',
              'user_rotation',
            ]).timeout(const Duration(milliseconds: 1000));
            if (rotRes.exitCode == 0) {
              final rotVal =
                  int.tryParse((rotRes.stdout as String).trim()) ?? 0;
              rotation = (rotVal * 90) % 360;
            }
          } catch (_) {}

          try {
            final manRes = await Process.run(adb, [
              '-s',
              serial,
              'shell',
              'getprop',
              'ro.product.manufacturer',
            ]).timeout(const Duration(milliseconds: 1000));
            if (manRes.exitCode == 0) {
              final man = (manRes.stdout as String).trim();
              if (man.isNotEmpty) manufacturer = man;
            }
          } catch (_) {}

          devices.add(
            DeviceModel(
              serial: serial,
              name: modelName,
              model: modelName,
              manufacturer: manufacturer,
              sdkVersion: '14',
              status: DeviceConnectionStatus.using,
              display: DeviceDisplayInfo(
                width: width,
                height: height,
                rotation: rotation,
              ),
            ),
          );
        }
      }
    } catch (e) {
      _lastError = '扫描 ADB 异常: $e';
    }

    return devices;
  }

  static Future<Uint8List?> captureScreen(String serial) async {
    final adb = await resolveAdbPath();
    try {
      final result = await Process.run(adb, [
        '-s',
        serial,
        'exec-out',
        'screencap',
        '-p',
      ]).timeout(const Duration(milliseconds: 2500));

      if (result.exitCode == 0 && result.stdout is List<int>) {
        return Uint8List.fromList(result.stdout as List<int>);
      }
    } catch (_) {}
    return null;
  }

  static Future<String> executeShell(String serial, String command) async {
    final adb = await resolveAdbPath();
    try {
      final result = await Process.run(adb, [
        '-s',
        serial,
        'shell',
        command,
      ]).timeout(const Duration(seconds: 10));
      if (result.exitCode == 0) {
        return result.stdout.toString();
      } else {
        return 'Error (${result.exitCode}): ${result.stderr}';
      }
    } catch (e) {
      return 'Execution Exception: $e';
    }
  }

  static Future<void> injectText(String serial, String text) async {
    if (text.isEmpty) return;
    final escaped = text.replaceAll("'", "'\\''");
    await executeShell(
      serial,
      "am broadcast -a jp.co.cyberagent.stf.ACTION_SET_CLIPBOARD --es text '$escaped'",
    );
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await executeShell(serial, 'input keyevent 279');
  }
}
