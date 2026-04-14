import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown_viewer/app/router.dart';
import 'package:markdown_viewer/app/theme.dart';
import 'package:markdown_viewer/features/settings/application/settings_providers.dart';
import 'package:markdown_viewer/features/settings/domain/app_theme_mode.dart';
import 'package:markdown_viewer/l10n/generated/app_localizations.dart';

class MarkdownViewerApp extends ConsumerWidget {
  const MarkdownViewerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    // Watching the settings controllers directly (instead of using
    // `ref.select` for a narrower rebuild) is intentional: a
    // theme-mode or locale change must rebuild the entire
    // MaterialApp to swap ThemeData / Localizations, and this is
    // literally the top of the widget tree — there is nothing above
    // us to save work for.
    final appThemeMode = ref.watch(themeModeControllerProvider);
    final appLocale = ref.watch(localeControllerProvider);

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        // Sepia forces ThemeMode.light with a custom warm-parchment
        // ThemeData that ignores the dynamic palette. All other modes
        // map 1:1 to the corresponding Flutter ThemeMode value.
        final ThemeData lightTheme;
        final ThemeMode flutterThemeMode;
        switch (appThemeMode) {
          case AppThemeMode.sepia:
            lightTheme = AppTheme.sepia();
            flutterThemeMode = ThemeMode.light;
          case AppThemeMode.light:
            lightTheme = AppTheme.light(lightDynamic);
            flutterThemeMode = ThemeMode.light;
          case AppThemeMode.dark:
            lightTheme = AppTheme.light(lightDynamic);
            flutterThemeMode = ThemeMode.dark;
          case AppThemeMode.system:
            lightTheme = AppTheme.light(lightDynamic);
            flutterThemeMode = ThemeMode.system;
        }

        return MaterialApp.router(
          onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
          theme: lightTheme,
          darkTheme: AppTheme.dark(darkDynamic),
          themeMode: flutterThemeMode,
          // `null` means "follow the OS language list"; MaterialApp
          // then runs its built-in delegate chain against the
          // supported locales from [AppLocalizations].
          locale: appLocale.locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
