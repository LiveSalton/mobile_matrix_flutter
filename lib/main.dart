import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'views/control/device_control_page.dart';

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

  @override
  void initState() {
    super.initState();
    _themeController.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    _themeController.removeListener(_onThemeChanged);
    _themeController.dispose();
    super.dispose();
  }

  void _onThemeChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mobile Matrix',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.buildTheme(_themeController.currentTheme),
      home: DeviceControlPage(themeController: _themeController),
    );
  }
}

