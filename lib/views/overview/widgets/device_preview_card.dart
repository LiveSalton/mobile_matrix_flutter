import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../models/device_model.dart';
import '../../../services/device_session.dart';
import '../../../theme/app_theme.dart';
import '../../control/widgets/device_screen_stage.dart';

const devicePreviewNavigationBarHeight = 32.0;

double devicePreviewScreenWidthForCardWidth(double cardWidth) {
  if (cardWidth <= 0) return 0;
  return (cardWidth * 0.92).clamp(140.0, 400.0).toDouble();
}

double devicePreviewScreenHeightAtWidth(DeviceModel device, double width) {
  final display = device.display;
  if (width <= 0 || display.width <= 0 || display.height <= 0) return 0;

  final screenAspectRatio = display.isLandscape
      ? display.height / display.width
      : display.width / display.height;
  return width / screenAspectRatio;
}

double devicePreviewStageHeightForSessions(
  Iterable<DeviceSession> sessions,
  double screenWidth,
) {
  var maxScreenHeight = 0.0;
  for (final session in sessions) {
    maxScreenHeight = math.max(
      maxScreenHeight,
      devicePreviewScreenHeightAtWidth(session.device, screenWidth),
    );
  }
  return maxScreenHeight + devicePreviewNavigationBarHeight;
}

class DevicePreviewCard extends StatelessWidget {
  final DeviceSession session;
  final VoidCallback onOpenConsole;
  final double previewStageHeight;
  final double previewScreenWidth;

  const DevicePreviewCard({
    super.key,
    required this.session,
    required this.onOpenConsole,
    required this.previewStageHeight,
    required this.previewScreenWidth,
  });

  Color _stateColor(AppColorTokens tokens) {
    return switch (session.state) {
      DeviceSessionState.ready => tokens.success,
      DeviceSessionState.connecting => tokens.warning,
      DeviceSessionState.error => tokens.danger,
      DeviceSessionState.disconnected => tokens.textSecondary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final strings = L10n.of(context);
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: session,
        builder: (context, _) {
          final stateColor = _stateColor(tokens);
          return Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: tokens.outline, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                SizedBox(
                  height: 76,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 12, 10),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: stateColor.withValues(alpha: 0.13),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: stateColor.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Icon(
                            Icons.phone_android_rounded,
                            size: 18,
                            color: stateColor,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                session.device.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: tokens.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${session.device.display.width}×${session.device.display.height}',
                                style: TextStyle(
                                  color: tokens.textSecondary,
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                        Tooltip(
                          message: strings.enter_console,
                          child: IconButton(
                            key: ValueKey('open-console-${session.serial}'),
                            onPressed: onOpenConsole,
                            icon: Icon(
                              Icons.open_in_new_rounded,
                              size: 18,
                              color: tokens.primary,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  height: previewStageHeight,
                  width: double.infinity,
                  child: DeviceScreenStage(
                    device: session.device,
                    controlService: session.controlService,
                    streamService: session.streamService,
                    fpsStatsNotifier: session.fpsStats,
                    // The bridge is local to this card and only receives focus
                    // after its own screen is pressed, so keyboard input stays
                    // scoped to the device the user is operating.
                    keyboardEnabled: true,
                    showBottomNavigation: true,
                    screenAlignment: Alignment.bottomCenter,
                    maxScreenWidth: previewScreenWidth,
                    navigationBarHeight: devicePreviewNavigationBarHeight,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
