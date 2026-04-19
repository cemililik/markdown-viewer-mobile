import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown_viewer/app/router.dart';
import 'package:markdown_viewer/app/theme.dart';
import 'package:markdown_viewer/core/logging/logger.dart';
import 'package:markdown_viewer/features/file_open/application/incoming_file_provider.dart';
import 'package:markdown_viewer/features/settings/application/settings_providers.dart';
import 'package:markdown_viewer/features/settings/domain/app_theme_mode.dart';
import 'package:markdown_viewer/l10n/generated/app_localizations.dart';

/// Key for the root [ScaffoldMessenger] so a stream error delivered
/// from outside a build context (the `ref.listen` in
/// [MarkdownViewerApp.build]) can still surface a localised snackbar
/// to the user.
///
/// Paired with `MaterialApp.router(scaffoldMessengerKey: …)` below.
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Picks the locale to display when the user has left the language
/// preference on "Follow system" (i.e. `MaterialApp.locale` is null).
///
/// Rule, per product requirement:
/// - If any of the OS's preferred locales is Turkish → show Turkish.
/// - Otherwise (including English as the OS primary, or a completely
///   unsupported OS primary like German / Spanish / Japanese) → show
///   English.
///
/// Iterating the full [preferredLocales] list rather than looking at
/// `.first` respects multi-locale users: e.g. an OS list of
/// `[de, tr, en]` (a German expat who speaks Turkish) still lands on
/// Turkish because it's the first of the user's preferences that we
/// can actually render, instead of bouncing straight to the English
/// fallback after failing to match `de`.
///
/// This callback is NOT invoked when the user has explicitly picked
/// `AppLocale.english` or `AppLocale.turkish` in settings —
/// `MaterialApp.locale` is non-null in that case and Flutter bypasses
/// the resolution callback entirely.
Locale resolveSystemLocale(
  List<Locale>? preferredLocales,
  Iterable<Locale> supportedLocales,
) {
  const english = Locale('en');
  const turkish = Locale('tr');
  if (preferredLocales == null || preferredLocales.isEmpty) {
    return english;
  }
  for (final locale in preferredLocales) {
    if (locale.languageCode == 'tr') return turkish;
    if (locale.languageCode == 'en') return english;
  }
  return english;
}

class MarkdownViewerApp extends ConsumerWidget {
  const MarkdownViewerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    // Navigate to the viewer whenever the OS hands us a file to open
    // (Android share-intent / ACTION_VIEW, iOS "Open In" from Files).
    // ref.listen fires synchronously on the first emission if the
    // provider already has a value (cold-start buffered path), and on
    // every subsequent emission for warm-start opens.
    //
    // The stream error branch is surfaced through the logger so a
    // platform-side failure (oversized file, missing permission) is
    // traceable — `.whenData` alone would drop the error on the
    // floor.
    ref.listen<AsyncValue<String>>(incomingFileProvider, (_, next) {
      next.when(
        data: (path) => router.go(ViewerRoute.location(path)),
        loading: () {},
        error: (error, stackTrace) {
          ref
              .read(appLoggerProvider)
              .e(
                'incomingFileProvider stream error',
                error: error,
                stackTrace: stackTrace,
              );
          // Map the typed PlatformException codes emitted by
          // `FileOpenChannel` on either platform (e.g. FILE_TOO_LARGE)
          // to a localised snackbar so the share-sheet tap actually
          // tells the user why nothing opened. The messenger's own
          // context sits *inside* the MaterialApp so
          // `AppLocalizations.of(...)` resolves cleanly (pulling
          // localisations from the outer build context would null-
          // deref because MarkdownViewerApp is the PARENT of
          // MaterialApp).
          // Reference: code-review CR-20260419-034.
          if (error is PlatformException) {
            final messengerState = rootScaffoldMessengerKey.currentState;
            final messengerContext = rootScaffoldMessengerKey.currentContext;
            if (messengerState == null || messengerContext == null) return;
            final l10n = AppLocalizations.of(messengerContext);
            final message = switch (error.code) {
              'FILE_TOO_LARGE' => l10n.fileOpenTooLarge,
              _ => null,
            };
            if (message != null) {
              messengerState
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(message)));
            }
          }
        },
      );
    });

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
          scaffoldMessengerKey: rootScaffoldMessengerKey,
          onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
          theme: lightTheme,
          darkTheme: AppTheme.dark(darkDynamic),
          themeMode: flutterThemeMode,
          // `null` means "follow the OS language list"; MaterialApp
          // then runs the [localeListResolutionCallback] below against
          // the supported locales from [AppLocalizations].
          locale: appLocale.locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          localeListResolutionCallback: resolveSystemLocale,
          routerConfig: router,
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
