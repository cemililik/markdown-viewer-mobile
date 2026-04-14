import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';

abstract final class AppTheme {
  /// Seed color used when the platform does not provide a dynamic palette.
  ///
  /// Chosen to be readable on both light and dark surfaces and to harmonize
  /// with the app's reading-first visual identity.
  static const Color _seed = Color(0xFF3B5BDB);

  static ThemeData light(ColorScheme? dynamicScheme) {
    final scheme =
        dynamicScheme?.harmonized() ?? ColorScheme.fromSeed(seedColor: _seed);
    return _build(scheme);
  }

  static ThemeData dark(ColorScheme? dynamicScheme) {
    final scheme =
        dynamicScheme?.harmonized() ??
        ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.dark);
    return _build(scheme);
  }

  /// Warm parchment theme for extended reading sessions. Uses ink-and-paper
  /// tones derived from traditional sepia photography and aged paper — easier
  /// on the eyes than a bright white background and less disorienting than
  /// a full dark theme in a lit room.
  ///
  /// Ignores the platform dynamic colour palette intentionally: the warm
  /// tonality would be broken by arbitrary device accent colours.
  static ThemeData sepia() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFF8B6334),
      onPrimary: Color(0xFFFFF8ED),
      primaryContainer: Color(0xFFFFDDB6),
      onPrimaryContainer: Color(0xFF2B1700),
      secondary: Color(0xFF74562F),
      onSecondary: Color(0xFFFFFFFF),
      secondaryContainer: Color(0xFFFFDCB5),
      onSecondaryContainer: Color(0xFF2B1600),
      tertiary: Color(0xFF5C6428),
      onTertiary: Color(0xFFFFFFFF),
      tertiaryContainer: Color(0xFFE1EBA1),
      onTertiaryContainer: Color(0xFF1A1F00),
      error: Color(0xFFB3261E),
      onError: Color(0xFFFFFFFF),
      errorContainer: Color(0xFFF9DEDC),
      onErrorContainer: Color(0xFF410E0B),
      // Warm parchment surface hierarchy
      surface: Color(0xFFF5ECD7),
      onSurface: Color(0xFF3C2A14),
      surfaceContainerLowest: Color(0xFFFAF5EC),
      surfaceContainerLow: Color(0xFFF3EBD9),
      surfaceContainer: Color(0xFFEFE5CF),
      surfaceContainerHigh: Color(0xFFE8D9C3),
      surfaceContainerHighest: Color(0xFFE0D0BA),
      onSurfaceVariant: Color(0xFF6B4F2C),
      outline: Color(0xFF8B7355),
      outlineVariant: Color(0xFFC8B89A),
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
      inverseSurface: Color(0xFF3C2A14),
      onInverseSurface: Color(0xFFF5ECD7),
      inversePrimary: Color(0xFFFFB96C),
    );
    return _build(scheme);
  }

  static ThemeData _build(ColorScheme scheme) {
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.secondaryContainer,
      ),
      // Material 3's default snackbar uses `inverseSurface`, which
      // flips to LIGHT in dark mode — bright, harsh, and out of
      // place against the rest of the reading UI. We lock it to a
      // subtly elevated tonal surface (`surfaceContainerHigh`) in
      // both modes so snackbars feel like a quiet elevation change
      // rather than a mode-inverting flash.
      //
      // Behaviour is deliberately `fixed`, not `floating`: the
      // viewer exposes a back-to-top FAB in the bottom-right, and
      // floating snackbars snap into the same safe-area lane as
      // the FAB, producing an ugly side-by-side overlap every time
      // a snackbar shows. Fixed snackbars anchor to the very
      // bottom of the Scaffold, and the FAB renders above them —
      // the user sees a flash of notification at the edge of the
      // screen with the FAB gently covering part of it, which is
      // the reading the user asked for.
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        contentTextStyle: TextStyle(color: scheme.onSurface),
        actionTextColor: scheme.primary,
        closeIconColor: scheme.onSurface,
        behavior: SnackBarBehavior.fixed,
        elevation: 3,
      ),
      // Reading-column scrollbar: thin (4 dp), rounded, hidden by
      // default and only fading in while the reader is actually
      // scrolling. The thumb uses `outline` over a transparent
      // track so it sits as a quiet hint along the right edge
      // rather than a chrome stripe — exactly the "subtle, not
      // too obtrusive" affordance the home / viewer screens want.
      scrollbarTheme: ScrollbarThemeData(
        thumbVisibility: const WidgetStatePropertyAll(false),
        trackVisibility: const WidgetStatePropertyAll(false),
        thickness: const WidgetStatePropertyAll(4),
        radius: const Radius.circular(2),
        thumbColor: WidgetStatePropertyAll(
          scheme.outline.withValues(alpha: 0.55),
        ),
        crossAxisMargin: 2,
        mainAxisMargin: 4,
        interactive: true,
      ),
    );
  }
}
