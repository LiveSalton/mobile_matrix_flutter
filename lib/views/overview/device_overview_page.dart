import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../services/device_session.dart';
import '../../services/device_session_manager.dart';
import '../../theme/app_theme.dart';
import '../control/device_control_page.dart';
import '../control/widgets/app_header.dart';
import 'widgets/device_preview_card.dart';

int deviceOverviewColumnCount(double width) {
  if (width >= 1024) return 4;
  if (width >= 960) return 3;
  if (width >= 640) return 2;
  return 1;
}

const _overviewHorizontalPadding = 12.0;
const _overviewCardGap = 8.0;

class DeviceOverviewPage extends StatefulWidget {
  final ThemeController themeController;
  final DeviceSessionManager sessionManager;

  const DeviceOverviewPage({
    super.key,
    required this.themeController,
    required this.sessionManager,
  });

  @override
  State<DeviceOverviewPage> createState() => _DeviceOverviewPageState();
}

class _DeviceOverviewPageState extends State<DeviceOverviewPage> {
  @override
  void initState() {
    super.initState();
    widget.sessionManager.addListener(_handleManagerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(widget.sessionManager.start());
    });
  }

  @override
  void dispose() {
    widget.sessionManager.removeListener(_handleManagerChanged);
    super.dispose();
  }

  void _handleManagerChanged() {
    if (mounted) setState(() {});
  }

  void _openConsole(BuildContext context, String serial) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DeviceControlPage(
          themeController: widget.themeController,
          sessionManager: widget.sessionManager,
          initialSerial: serial,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final strings = L10n.of(context);
    final sessions = widget.sessionManager.sessions;
    final currentDevice = sessions.isEmpty ? null : sessions.first.device;

    return Scaffold(
      backgroundColor: tokens.bg,
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              currentDevice: currentDevice,
              currentTheme: widget.themeController.currentTheme,
              availableDevices: sessions
                  .map((session) => session.device)
                  .toList(growable: false),
              onDeviceSelected: (device) =>
                  _openConsole(context, device.serial),
              onRefreshDevices: widget.sessionManager.refresh,
              onToggleTheme: widget.themeController.toggleTheme,
              isScanning: widget.sessionManager.isScanning,
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final columns = deviceOverviewColumnCount(
                    constraints.maxWidth,
                  );
                  return CustomScrollView(
                    key: const ValueKey('device-overview-scroll'),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                        sliver: SliverToBoxAdapter(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Text(
                                  strings.device_overview,
                                  style: TextStyle(
                                    color: tokens.textPrimary,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Text(
                                strings.connected_devices(sessions.length),
                                style: TextStyle(
                                  color: tokens.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (sessions.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _buildEmptyState(context),
                        )
                      else
                        _buildPreviewRows(
                          context,
                          sessions,
                          columns,
                          constraints.maxWidth,
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewRows(
    BuildContext context,
    List<DeviceSession> sessions,
    int columns,
    double viewportWidth,
  ) {
    final contentWidth = math
        .max(0.0, viewportWidth - (_overviewHorizontalPadding * 2))
        .toDouble();
    final cardWidth = math
        .max(1.0, (contentWidth - (_overviewCardGap * (columns - 1))) / columns)
        .toDouble();
    final rowCount = (sessions.length + columns - 1) ~/ columns;

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        _overviewHorizontalPadding,
        0,
        _overviewHorizontalPadding,
        _overviewHorizontalPadding,
      ),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, rowIndex) {
          final rowStart = rowIndex * columns;
          final rowSessions = sessions
              .skip(rowStart)
              .take(columns)
              .toList(growable: false);
          final previewScreenWidth = devicePreviewScreenWidthForCardWidth(
            cardWidth,
          );
          final previewStageHeight = devicePreviewStageHeightForSessions(
            rowSessions,
            previewScreenWidth,
          );

          final rowChildren = <Widget>[];
          for (var columnIndex = 0; columnIndex < columns; columnIndex++) {
            if (columnIndex > 0) {
              rowChildren.add(const SizedBox(width: _overviewCardGap));
            }

            if (columnIndex < rowSessions.length) {
              final session = rowSessions[columnIndex];
              rowChildren.add(
                Expanded(
                  child: DevicePreviewCard(
                    key: ValueKey('device-preview-${session.serial}'),
                    session: session,
                    previewStageHeight: previewStageHeight,
                    previewScreenWidth: previewScreenWidth,
                    onOpenConsole: () => _openConsole(context, session.serial),
                  ),
                ),
              );
            } else {
              rowChildren.add(const Expanded(child: SizedBox.shrink()));
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: rowIndex == rowCount - 1 ? 0 : _overviewCardGap,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: rowChildren,
            ),
          );
        }, childCount: rowCount),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final tokens = context.tokens;
    final strings = L10n.of(context);
    final message = widget.sessionManager.errorMessage;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.phone_android_outlined,
              size: 52,
              color: tokens.primary.withValues(alpha: 0.55),
            ),
            const SizedBox(height: 16),
            Text(
              strings.no_usb_device,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (message != null && message.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: tokens.danger, fontSize: 12),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: widget.sessionManager.isScanning
                  ? null
                  : widget.sessionManager.refresh,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(strings.rescan_adb_devices),
            ),
          ],
        ),
      ),
    );
  }
}
