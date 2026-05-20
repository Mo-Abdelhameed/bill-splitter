import 'package:flutter/material.dart';

/// Design tokens for Bill Splitter — Material 3 seeded off royal blue, warm
/// off-white surface, hairline outlines.
class AppTokens {
  // Colors
  static const Color bg = Color(0xFFFAF8F4);
  static const Color surface = Color(0xFFFFFFFE);
  static const Color surfaceLow = Color(0xFFF4F1EA);
  static const Color surfaceHigh = Color(0xFFFEFCF7);
  static const Color outline = Color(0xFFD9D4C9);
  static const Color outlineSoft = Color(0xFFECE7DC);
  static const Color onSurface = Color(0xFF1A1A17);
  static const Color onMuted = Color(0xFF5E5B53);
  static const Color onDim = Color(0xFF8C8779);
  static const Color primary = Color(0xFF1F5FBE);
  static const Color primaryContainer = Color(0xFFD7E5FB);
  static const Color onPrimaryContainer = Color(0xFF0E2A57);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color danger = Color(0xFFB3261E);
  static const Color dangerContainer = Color(0xFFF9DEDC);
  static const Color warnBg = Color(0xFFFFF4E5);
  static const Color warnFg = Color(0xFF7A4B11);
  static const Color warnBorder = Color(0xFFF2C181);

  // Warm-tone palette for person avatars (matches the design).
  static const List<Color> personPalette = [
    Color(0xFFC7693A),
    Color(0xFF7A8C5C),
    Color(0xFFB25E73),
    Color(0xFFC39A3A),
    Color(0xFF7B6FB0),
    Color(0xFF5E7A85),
  ];

  // Radii
  static const double radius = 16;
  static const double radiusSm = 10;
  static const double radiusXs = 6;
  static const double radiusPill = 999;
}

ThemeData buildLightTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppTokens.primary,
    brightness: Brightness.light,
  ).copyWith(
    surface: AppTokens.surface,
    onSurface: AppTokens.onSurface,
    surfaceContainerLowest: AppTokens.bg,
    surfaceContainerLow: AppTokens.surfaceLow,
    primary: AppTokens.primary,
    onPrimary: AppTokens.onPrimary,
    primaryContainer: AppTokens.primaryContainer,
    onPrimaryContainer: AppTokens.onPrimaryContainer,
    outline: AppTokens.outline,
    outlineVariant: AppTokens.outlineSoft,
    error: AppTokens.danger,
    errorContainer: AppTokens.dangerContainer,
  );

  // Use a serif for display (Instrument Serif fallback chain), system UI font
  // elsewhere. Real Instrument Serif requires font assets — using the system
  // serif keeps the spirit without a font shipment.
  const displayFamily = 'Georgia';

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppTokens.bg,
    canvasColor: AppTokens.bg,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppTokens.bg,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppTokens.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppTokens.onSurface,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
      ),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontFamily: displayFamily, fontWeight: FontWeight.w400, fontSize: 34, height: 1.04, letterSpacing: -0.4, color: AppTokens.onSurface),
      displayMedium: TextStyle(fontFamily: displayFamily, fontWeight: FontWeight.w400, fontSize: 28, height: 1.05, letterSpacing: -0.3, color: AppTokens.onSurface),
      displaySmall: TextStyle(fontFamily: displayFamily, fontWeight: FontWeight.w400, fontSize: 24, height: 1.1, letterSpacing: -0.2, color: AppTokens.onSurface),
      titleMedium: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: AppTokens.onSurface),
      titleSmall: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppTokens.onSurface),
      bodyLarge: TextStyle(fontSize: 16, color: AppTokens.onSurface),
      bodyMedium: TextStyle(fontSize: 14, color: AppTokens.onSurface),
      bodySmall: TextStyle(fontSize: 13, color: AppTokens.onMuted),
      labelLarge: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppTokens.onSurface),
      labelSmall: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, letterSpacing: 1.4, color: AppTokens.onDim),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: false,
      isDense: true,
      contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 0),
      border: UnderlineInputBorder(borderSide: BorderSide(color: AppTokens.outlineSoft)),
      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTokens.outlineSoft)),
      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTokens.primary, width: 1.5)),
    ),
  );
}
