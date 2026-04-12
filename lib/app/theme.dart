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
    );
  }
}
