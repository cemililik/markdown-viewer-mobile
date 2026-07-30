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
/// The first OS preference whose language is present in [supportedLocales]
/// wins. English remains the product fallback when the OS list is empty or
/// unsupported; if a future build deliberately omits English, the first
/// supported locale becomes the safe fallback.
///
/// This callback is NOT invoked when the user has explicitly picked
/// `AppLocale.english` or `AppLocale.turkish` in settings —
/// `MaterialApp.locale` is non-null in that case and Flutter bypasses
/// the resolution callback entirely.
Locale resolveSystemLocale(
  List<Locale>? preferredLocales,
  Iterable<Locale> supportedLocales,
) {
  final supported = supportedLocales.toList(growable: false);
  if (supported.isEmpty) {
    return const Locale('en');
  }
  final fallback = supported.firstWhere(
    (locale) => locale.languageCode == 'en',
    orElse: () => supported.first,
  );
  if (preferredLocales == null || preferredLocales.isEmpty) {
    return fallback;
  }
  for (final preferred in preferredLocales) {
    for (final candidate in supported) {
      if (candidate.languageCode == preferred.languageCode) {
        return candidate;
      }
    }
  }
  return fallback;
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
