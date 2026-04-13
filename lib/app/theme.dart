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
      // rather than a mode-inverting flash. Floating behaviour keeps
      // the snackbar visually separate from the back-to-top FAB and
      // respects bottom safe-area padding.
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        contentTextStyle: TextStyle(color: scheme.onSurface),
        actionTextColor: scheme.primary,
        closeIconColor: scheme.onSurface,
        behavior: SnackBarBehavior.floating,
        elevation: 3,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        insetPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      ),
    );
  }
}
