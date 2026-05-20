import 'package:flutter/material.dart';

const Color kSeedColor = Color(0xFF1976D2);
const Color kSurfaceColor = Color(0xFFFAF8F4);

ThemeData buildLightTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: kSeedColor,
    brightness: Brightness.light,
  ).copyWith(surface: kSurfaceColor);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: kSurfaceColor,
  );
}
