import 'package:flutter/material.dart';

enum AppThemeType {
  defaultTheme,
  roseGlow,
}

@immutable
class AppColorTokens extends ThemeExtension<AppColorTokens> {
  const AppColorTokens({
    required this.bg,
    required this.bgSecondary,
    required this.surface,
    required this.surfaceElevated,
    required this.outline,
    required this.primary,
    required this.highlight,
    required this.metalEdge,
    required this.textPrimary,
    required this.textSecondary,
    required this.success,
    required this.warning,
    required this.danger,
    required this.disabled,
    required this.scrimSoft,
    required this.scrimStrong,
  });

  final Color bg;
  final Color bgSecondary;
  final Color surface;
  final Color surfaceElevated;
  final Color outline;
  final Color primary;
  final Color highlight;
  final Color metalEdge;
  final Color textPrimary;
  final Color textSecondary;
  final Color success;
  final Color warning;
  final Color danger;
  final Color disabled;
  final Color scrimSoft;
  final Color scrimStrong;

  static const defaultTokens = AppColorTokens(
    bg: Color(0xFF0B1014),
    bgSecondary: Color(0xFF212329),
    surface: Color(0x80101827),
    surfaceElevated: Color(0xA0101827),
    outline: Color(0x4D1286D9),
    primary: Color(0xFF1286D9),
    highlight: Color(0x33B8DFFF),
    metalEdge: Color(0x661286D9),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFB4B8C5),
    success: Color(0xFF00D591),
    warning: Color(0xFFFF9124),
    danger: Color(0xFFEF4444),
    disabled: Color(0xFF64748B),
    scrimSoft: Color(0x47000000),
    scrimStrong: Color(0xB8000000),
  );

  static const roseGlowTokens = AppColorTokens(
    bg: Color(0xFF140F16),
    bgSecondary: Color(0xFF2A2029),
    surface: Color(0x801E1422),
    surfaceElevated: Color(0xA028192D),
    outline: Color(0x59E56A9A),
    primary: Color(0xFFE56A9A),
    highlight: Color(0x33FFD5E4),
    metalEdge: Color(0x66E56A9A),
    textPrimary: Color(0xFFFFF8FB),
    textSecondary: Color(0xFFD1BEC9),
    success: Color(0xFF00D591),
    warning: Color(0xFFFF9124),
    danger: Color(0xFFEF4444),
    disabled: Color(0xFF64748B),
    scrimSoft: Color(0x47000000),
    scrimStrong: Color(0xB8000000),
  );

  @override
  AppColorTokens copyWith({
    Color? bg,
    Color? bgSecondary,
    Color? surface,
    Color? surfaceElevated,
    Color? outline,
    Color? primary,
    Color? highlight,
    Color? metalEdge,
    Color? textPrimary,
    Color? textSecondary,
    Color? success,
    Color? warning,
    Color? danger,
    Color? disabled,
    Color? scrimSoft,
    Color? scrimStrong,
  }) {
    return AppColorTokens(
      bg: bg ?? this.bg,
      bgSecondary: bgSecondary ?? this.bgSecondary,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      outline: outline ?? this.outline,
      primary: primary ?? this.primary,
      highlight: highlight ?? this.highlight,
      metalEdge: metalEdge ?? this.metalEdge,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      disabled: disabled ?? this.disabled,
      scrimSoft: scrimSoft ?? this.scrimSoft,
      scrimStrong: scrimStrong ?? this.scrimStrong,
    );
  }

  @override
  AppColorTokens lerp(ThemeExtension<AppColorTokens>? other, double t) {
    if (other is! AppColorTokens) {
      return this;
    }
    return AppColorTokens(
      bg: Color.lerp(bg, other.bg, t)!,
      bgSecondary: Color.lerp(bgSecondary, other.bgSecondary, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      highlight: Color.lerp(highlight, other.highlight, t)!,
      metalEdge: Color.lerp(metalEdge, other.metalEdge, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      disabled: Color.lerp(disabled, other.disabled, t)!,
      scrimSoft: Color.lerp(scrimSoft, other.scrimSoft, t)!,
      scrimStrong: Color.lerp(scrimStrong, other.scrimStrong, t)!,
    );
  }
}

extension AppThemeContext on BuildContext {
  AppColorTokens get tokens {
    return Theme.of(this).extension<AppColorTokens>() ?? AppColorTokens.defaultTokens;
  }
}

class AppTheme {
  static ThemeData buildTheme(AppThemeType type) {
    final tokens = type == AppThemeType.roseGlow
        ? AppColorTokens.roseGlowTokens
        : AppColorTokens.defaultTokens;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: tokens.bg,
      colorScheme: ColorScheme.dark(
        primary: tokens.primary,
        surface: tokens.surface,
        onSurface: tokens.textPrimary,
      ),
      extensions: [tokens],
      fontFamily: 'Inter',
    );
  }
}

class ThemeController extends ChangeNotifier {
  AppThemeType _currentTheme = AppThemeType.defaultTheme;

  AppThemeType get currentTheme => _currentTheme;

  void setTheme(AppThemeType type) {
    if (_currentTheme != type) {
      _currentTheme = type;
      notifyListeners();
    }
  }

  void toggleTheme() {
    _currentTheme = _currentTheme == AppThemeType.defaultTheme
        ? AppThemeType.roseGlow
        : AppThemeType.defaultTheme;
    notifyListeners();
  }
}
