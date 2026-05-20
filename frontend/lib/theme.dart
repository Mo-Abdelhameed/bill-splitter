import 'package:flutter/material.dart';

/// Royal-blue accent — the design spec's #1F5FBE, used across every primary
/// surface in the prototype (`specs/001-bill-split-flow/ui/`).
const Color seedColor = Color(0xFF1F5FBE);

/// All custom design tokens that don't have a natural home on [ColorScheme]
/// or [TextTheme]. Lives as a ThemeExtension so any widget can read them via
/// `Theme.of(context).extension<BillSplitTokens>()`.
@immutable
class BillSplitTokens extends ThemeExtension<BillSplitTokens> {
  final Color bg;
  final Color surface;
  final Color surfaceLow;
  final Color surfaceHigh;
  final Color outline;
  final Color outlineSoft;
  final Color onSurface;
  final Color onMuted;
  final Color onDim;
  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color tertiary;
  final Color danger;
  final Color dangerContainer;
  final Color success;
  final Color warn;
  final Color warnSurface;
  final Color warnBorder;
  final double radius;
  final double radiusSm;
  final double radiusXs;

  const BillSplitTokens({
    required this.bg,
    required this.surface,
    required this.surfaceLow,
    required this.surfaceHigh,
    required this.outline,
    required this.outlineSoft,
    required this.onSurface,
    required this.onMuted,
    required this.onDim,
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.tertiary,
    required this.danger,
    required this.dangerContainer,
    required this.success,
    required this.warn,
    required this.warnSurface,
    required this.warnBorder,
    required this.radius,
    required this.radiusSm,
    required this.radiusXs,
  });

  static const BillSplitTokens light = BillSplitTokens(
    bg: Color(0xFFFAF8F4),
    surface: Color(0xFFFFFFFE),
    surfaceLow: Color(0xFFF4F1EA),
    surfaceHigh: Color(0xFFFEFCF7),
    outline: Color(0xFFD9D4C9),
    outlineSoft: Color(0xFFECE7DC),
    onSurface: Color(0xFF1A1A17),
    onMuted: Color(0xFF5E5B53),
    onDim: Color(0xFF8C8779),
    primary: seedColor,
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFD7E5FB),
    onPrimaryContainer: Color(0xFF0E2A57),
    tertiary: Color(0xFF7A5AF8),
    danger: Color(0xFFB3261E),
    dangerContainer: Color(0xFFF9DEDC),
    success: Color(0xFF1F7A4C),
    warn: Color(0xFF9C6A12),
    warnSurface: Color(0xFFFFF4E5),
    warnBorder: Color(0xFFF2C181),
    radius: 16,
    radiusSm: 10,
    radiusXs: 6,
  );

  /// Dark-mode counterpart. Roles are inverted (bg becomes warm near-black,
  /// onSurface becomes warm near-white) and accent colors are slightly
  /// lightened for legible contrast against the dark surfaces.
  static const BillSplitTokens dark = BillSplitTokens(
    bg: Color(0xFF14130F),
    surface: Color(0xFF1E1D19),
    surfaceLow: Color(0xFF0F0E0A),
    surfaceHigh: Color(0xFF28261F),
    outline: Color(0xFF44423B),
    outlineSoft: Color(0xFF2E2C25),
    onSurface: Color(0xFFFAF8F4),
    onMuted: Color(0xFFB8B3A6),
    onDim: Color(0xFF847F73),
    primary: Color(0xFF7AA7E8),
    onPrimary: Color(0xFF06122B),
    primaryContainer: Color(0xFF173264),
    onPrimaryContainer: Color(0xFFD7E5FB),
    tertiary: Color(0xFFA89AF7),
    danger: Color(0xFFF2B8B5),
    dangerContainer: Color(0xFF5C1A1A),
    success: Color(0xFF5FCB9C),
    warn: Color(0xFFE0B57A),
    warnSurface: Color(0xFF3E2D14),
    warnBorder: Color(0xFF6A5424),
    radius: 16,
    radiusSm: 10,
    radiusXs: 6,
  );

  @override
  BillSplitTokens copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceLow,
    Color? surfaceHigh,
    Color? outline,
    Color? outlineSoft,
    Color? onSurface,
    Color? onMuted,
    Color? onDim,
    Color? primary,
    Color? onPrimary,
    Color? primaryContainer,
    Color? onPrimaryContainer,
    Color? tertiary,
    Color? danger,
    Color? dangerContainer,
    Color? success,
    Color? warn,
    Color? warnSurface,
    Color? warnBorder,
    double? radius,
    double? radiusSm,
    double? radiusXs,
  }) {
    return BillSplitTokens(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceLow: surfaceLow ?? this.surfaceLow,
      surfaceHigh: surfaceHigh ?? this.surfaceHigh,
      outline: outline ?? this.outline,
      outlineSoft: outlineSoft ?? this.outlineSoft,
      onSurface: onSurface ?? this.onSurface,
      onMuted: onMuted ?? this.onMuted,
      onDim: onDim ?? this.onDim,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      primaryContainer: primaryContainer ?? this.primaryContainer,
      onPrimaryContainer: onPrimaryContainer ?? this.onPrimaryContainer,
      tertiary: tertiary ?? this.tertiary,
      danger: danger ?? this.danger,
      dangerContainer: dangerContainer ?? this.dangerContainer,
      success: success ?? this.success,
      warn: warn ?? this.warn,
      warnSurface: warnSurface ?? this.warnSurface,
      warnBorder: warnBorder ?? this.warnBorder,
      radius: radius ?? this.radius,
      radiusSm: radiusSm ?? this.radiusSm,
      radiusXs: radiusXs ?? this.radiusXs,
    );
  }

  @override
  BillSplitTokens lerp(ThemeExtension<BillSplitTokens>? other, double t) {
    if (other is! BillSplitTokens) return this;
    return BillSplitTokens(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceLow: Color.lerp(surfaceLow, other.surfaceLow, t)!,
      surfaceHigh: Color.lerp(surfaceHigh, other.surfaceHigh, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      outlineSoft: Color.lerp(outlineSoft, other.outlineSoft, t)!,
      onSurface: Color.lerp(onSurface, other.onSurface, t)!,
      onMuted: Color.lerp(onMuted, other.onMuted, t)!,
      onDim: Color.lerp(onDim, other.onDim, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      primaryContainer:
          Color.lerp(primaryContainer, other.primaryContainer, t)!,
      onPrimaryContainer:
          Color.lerp(onPrimaryContainer, other.onPrimaryContainer, t)!,
      tertiary: Color.lerp(tertiary, other.tertiary, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerContainer: Color.lerp(dangerContainer, other.dangerContainer, t)!,
      success: Color.lerp(success, other.success, t)!,
      warn: Color.lerp(warn, other.warn, t)!,
      warnSurface: Color.lerp(warnSurface, other.warnSurface, t)!,
      warnBorder: Color.lerp(warnBorder, other.warnBorder, t)!,
      radius: radius,
      radiusSm: radiusSm,
      radiusXs: radiusXs,
    );
  }
}

/// Extension to make `Theme.of(context).tokens` work without callers having
/// to reach into `extension<BillSplitTokens>()` every time.
extension BillSplitTokensX on ThemeData {
  BillSplitTokens get tokens =>
      extension<BillSplitTokens>() ?? BillSplitTokens.light;
}

ColorScheme _schemeFor(Brightness brightness, BillSplitTokens t) {
  final base = ColorScheme.fromSeed(seedColor: seedColor, brightness: brightness);
  return base.copyWith(
    surface: t.bg,
    surfaceContainerLow: t.surfaceLow,
    surfaceContainerHigh: t.surfaceHigh,
    primary: t.primary,
    onPrimary: t.onPrimary,
    primaryContainer: t.primaryContainer,
    onPrimaryContainer: t.onPrimaryContainer,
    onSurface: t.onSurface,
    onSurfaceVariant: t.onMuted,
    outline: t.outline,
    outlineVariant: t.outlineSoft,
    error: t.danger,
    errorContainer: t.dangerContainer,
  );
}

ColorScheme _lightScheme = _schemeFor(Brightness.light, BillSplitTokens.light);
ColorScheme _darkScheme = _schemeFor(Brightness.dark, BillSplitTokens.dark);

/// Font family names. The design spec uses Geist + Instrument Serif. Until
/// we bundle the font assets, these fall back to the system family — Inter
/// or San Francisco on iOS, Roboto on Android — which still reads cleanly
/// with the rest of the token system.
const String _fontDisplay = 'serif'; // Instrument Serif when bundled
const String _fontUi = 'sans-serif'; // Inter / Geist when bundled

TextTheme _textTheme(ColorScheme scheme) {
  final base = ThemeData(colorScheme: scheme, useMaterial3: true).textTheme;
  return base.copyWith(
    displayLarge: base.displayLarge?.copyWith(
      fontFamily: _fontDisplay,
      fontWeight: FontWeight.w400,
      fontSize: 42,
      height: 1.04,
      letterSpacing: -0.4,
    ),
    displayMedium: base.displayMedium?.copyWith(
      fontFamily: _fontDisplay,
      fontWeight: FontWeight.w400,
      fontSize: 34,
      height: 1.04,
      letterSpacing: -0.4,
    ),
    displaySmall: base.displaySmall?.copyWith(
      fontFamily: _fontDisplay,
      fontWeight: FontWeight.w400,
      fontSize: 28,
      height: 1.06,
      letterSpacing: -0.3,
    ),
    headlineMedium: base.headlineMedium?.copyWith(
      fontFamily: _fontDisplay,
      fontWeight: FontWeight.w400,
      fontSize: 26,
      letterSpacing: -0.2,
    ),
    titleMedium: base.titleMedium?.copyWith(
      fontFamily: _fontUi,
      fontWeight: FontWeight.w600,
    ),
    titleSmall: base.titleSmall?.copyWith(
      fontFamily: _fontUi,
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: base.bodyLarge?.copyWith(fontFamily: _fontUi),
    bodyMedium: base.bodyMedium?.copyWith(fontFamily: _fontUi),
    bodySmall: base.bodySmall?.copyWith(fontFamily: _fontUi),
    labelLarge: base.labelLarge?.copyWith(
      fontFamily: _fontUi,
      fontWeight: FontWeight.w600,
    ),
  );
}

/// Build a [ThemeData] from a token set + a derived color scheme. Both
/// `lightTheme` and `darkTheme` go through this so every widget pulls its
/// colors from the right brightness variant.
ThemeData _buildTheme(BillSplitTokens t, ColorScheme scheme) {
  final isDark = scheme.brightness == Brightness.dark;
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: t.bg,
    canvasColor: t.bg,
    textTheme: _textTheme(scheme),
    appBarTheme: AppBarTheme(
      backgroundColor: t.bg,
      foregroundColor: t.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: _fontUi,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        color: t.onSurface,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: t.primary,
        foregroundColor: t.onPrimary,
        disabledBackgroundColor:
            isDark ? const Color(0xFF2A2924) : const Color(0xFFE6E2D7),
        disabledForegroundColor:
            isDark ? const Color(0xFF6E6A60) : const Color(0xFFA6A294),
        minimumSize: const Size.fromHeight(48),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(
          fontFamily: _fontUi,
          fontSize: 15.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: t.primary,
        minimumSize: const Size.fromHeight(48),
        side: BorderSide(color: t.outline),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(
          fontFamily: _fontUi,
          fontSize: 15.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: t.primary,
        textStyle: const TextStyle(
          fontFamily: _fontUi,
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: false,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(t.radius),
        borderSide: BorderSide(color: t.outlineSoft),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(t.radius),
        borderSide: BorderSide(color: t.outlineSoft),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(t.radius),
        borderSide: BorderSide(color: t.primary, width: 1.5),
      ),
      hintStyle: TextStyle(fontFamily: _fontUi, color: t.onDim),
      labelStyle: TextStyle(fontFamily: _fontUi, color: t.onMuted),
    ),
    cardTheme: CardThemeData(
      color: t.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(t.radius),
        side: BorderSide(color: t.outlineSoft),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: t.surface,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        fontFamily: _fontUi,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: t.onSurface,
      ),
      contentTextStyle: TextStyle(
        fontFamily: _fontUi,
        fontSize: 14,
        color: t.onSurface,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: t.bg,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: t.bg,
    ),
    checkboxTheme: CheckboxThemeData(
      side: BorderSide(color: t.outline),
      fillColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.selected)) return t.primary;
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(t.onPrimary),
    ),
    iconTheme: IconThemeData(color: t.onSurface),
    dividerColor: t.outlineSoft,
    extensions: <ThemeExtension<dynamic>>[t],
  );
}

final ThemeData lightTheme = _buildTheme(BillSplitTokens.light, _lightScheme);
final ThemeData darkTheme = _buildTheme(BillSplitTokens.dark, _darkScheme);
