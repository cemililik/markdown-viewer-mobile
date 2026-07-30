import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/features/observability/application/observability_providers.dart';
import 'package:markdown_viewer/features/observability/data/consent_store_impl.dart';
import 'package:markdown_viewer/features/settings/application/settings_providers.dart';
import 'package:markdown_viewer/features/settings/data/settings_store_impl.dart';
import 'package:markdown_viewer/features/settings/domain/app_locale.dart';
import 'package:markdown_viewer/features/settings/domain/app_theme_mode.dart';
import 'package:markdown_viewer/features/settings/presentation/screens/settings_screen.dart';
import 'package:markdown_viewer/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppLocalizations en;
  late AppLocalizations tr;

  setUpAll(() async {
    en = await AppLocalizations.delegate.load(const Locale('en'));
    tr = await AppLocalizations.delegate.load(const Locale('tr'));
  });

  Future<Widget> buildHarness({Locale locale = const Locale('en')}) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final store = SettingsStoreImpl(prefs);
    return ProviderScope(
      overrides: [
        settingsStoreProvider.overrideWithValue(store),
        consentStoreProvider.overrideWithValue(ConsentStoreImpl(prefs)),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(useMaterial3: true),
        home: const SettingsScreen(),
      ),
    );
  }

  group('SettingsScreen', () {
    testWidgets(
      'should render four theme segments and three language segments in English when the widget is exercised',
      (tester) async {
        await tester.pumpWidget(await buildHarness());
        await tester.pumpAndSettle();

        expect(find.bySemanticsLabel(en.settingsThemeTitle), findsOneWidget);
        // "System" is the label for BOTH the theme "System" segment
        // and the language "System" segment — they share the same
        // copy after the l10n shortening. Expect two matches.
        expect(find.bySemanticsLabel(en.settingsThemeSystem), findsNWidgets(2));
        expect(find.bySemanticsLabel(en.settingsThemeLight), findsOneWidget);
        expect(find.bySemanticsLabel(en.settingsThemeDark), findsOneWidget);
        expect(find.bySemanticsLabel(en.settingsThemeSepia), findsOneWidget);

        expect(find.bySemanticsLabel(en.settingsLanguageTitle), findsOneWidget);
        expect(
          find.bySemanticsLabel(en.settingsLanguageEnglish),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(en.settingsLanguageTurkish),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'should update the ThemeModeController state when a theme radio is tapped',
      (tester) async {
        await tester.pumpWidget(await buildHarness());
        await tester.pumpAndSettle();

        await tester.tap(find.bySemanticsLabel(en.settingsThemeDark));
        await tester.pumpAndSettle();

        final element = tester.element(find.byType(SettingsScreen));
        final container = ProviderScope.containerOf(element);
        expect(container.read(themeModeControllerProvider), AppThemeMode.dark);
      },
    );

    testWidgets(
      'should update the LocaleController state when a language radio is tapped',
      (tester) async {
        await tester.pumpWidget(await buildHarness());
        await tester.pumpAndSettle();

        await tester.tap(find.bySemanticsLabel(en.settingsLanguageTurkish));
        await tester.pumpAndSettle();

        final element = tester.element(find.byType(SettingsScreen));
        final container = ProviderScope.containerOf(element);
        expect(container.read(localeControllerProvider), AppLocale.turkish);
      },
    );

    testWidgets(
      'should render Turkish copy under the tr locale when the widget is exercised',
      (tester) async {
        await tester.pumpWidget(await buildHarness(locale: const Locale('tr')));
        await tester.pumpAndSettle();

        expect(find.bySemanticsLabel(tr.settingsThemeTitle), findsOneWidget);
        expect(find.bySemanticsLabel(tr.settingsLanguageTitle), findsOneWidget);
        expect(
          find.bySemanticsLabel(tr.settingsLanguageTurkish),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(tr.settingsLanguageEnglish),
          findsOneWidget,
        );
      },
    );
  });
}
