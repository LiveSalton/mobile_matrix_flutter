import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/l10n.dart';
import 'services/device_session_manager.dart';
import 'theme/app_theme.dart';
import 'views/overview/device_overview_page.dart';

void main() {
  runApp(const MobileMatrixApp());
}

class MobileMatrixApp extends StatefulWidget {
  const MobileMatrixApp({super.key});

  @override
  State<MobileMatrixApp> createState() => _MobileMatrixAppState();
}

class _MobileMatrixAppState extends State<MobileMatrixApp> {
  final ThemeController _themeController = ThemeController();
  final DeviceSessionManager _sessionManager = DeviceSessionManager();

  @override
  void initState() {
    super.initState();
    _themeController.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    _themeController.removeListener(_onThemeChanged);
    _themeController.dispose();
    _sessionManager.dispose();
    super.dispose();
  }

  void _onThemeChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => L10n.of(context).app_name,
      localizationsDelegates: const [
        L10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('zh')],
      locale: const Locale('zh'),
      theme: AppTheme.buildTheme(_themeController.currentTheme),
      home: DeviceOverviewPage(
        themeController: _themeController,
        sessionManager: _sessionManager,
      ),
    );
  }
}
