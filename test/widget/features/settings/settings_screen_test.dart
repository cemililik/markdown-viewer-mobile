import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/features/observability/application/observability_providers.dart';
import 'package:markdown_viewer/features/observability/data/consent_store.dart';
import 'package:markdown_viewer/features/settings/application/settings_providers.dart';
import 'package:markdown_viewer/features/settings/data/settings_store.dart';
import 'package:markdown_viewer/features/settings/domain/app_locale.dart';
import 'package:markdown_viewer/features/settings/domain/app_theme_mode.dart';
import 'package:markdown_viewer/features/settings/presentation/screens/settings_screen.dart';
import 'package:markdown_viewer/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<Widget> buildHarness({Locale locale = const Locale('en')}) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final store = SettingsStore(prefs);
    return ProviderScope(
      overrides: [
        settingsStoreProvider.overrideWithValue(store),
        consentStoreProvider.overrideWithValue(ConsentStore(prefs)),
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
      'renders four theme segments and three language segments in English',
      (tester) async {
        await tester.pumpWidget(await buildHarness());
        await tester.pumpAndSettle();

        expect(find.text('Theme'), findsOneWidget);
        expect(find.text('System'), findsOneWidget);
        expect(find.text('Light'), findsOneWidget);
        expect(find.text('Dark'), findsOneWidget);
        expect(find.text('Sepia'), findsOneWidget);

        expect(find.text('Language'), findsOneWidget);
        expect(find.text('System default'), findsOneWidget);
        expect(find.text('English'), findsOneWidget);
        expect(find.text('Turkish'), findsOneWidget);
      },
    );

    testWidgets('tapping a theme radio updates the ThemeModeController state', (
      tester,
    ) async {
      await tester.pumpWidget(await buildHarness());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(SettingsScreen));
      final container = ProviderScope.containerOf(element);
      expect(container.read(themeModeControllerProvider), AppThemeMode.dark);
    });

    testWidgets('tapping a language radio updates the LocaleController state', (
      tester,
    ) async {
      await tester.pumpWidget(await buildHarness());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Turkish'));
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(SettingsScreen));
      final container = ProviderScope.containerOf(element);
      expect(container.read(localeControllerProvider), AppLocale.turkish);
    });

    testWidgets('renders Turkish copy under the tr locale', (tester) async {
      await tester.pumpWidget(await buildHarness(locale: const Locale('tr')));
      await tester.pumpAndSettle();

      expect(find.text('Tema'), findsOneWidget);
      expect(find.text('Dil'), findsOneWidget);
      expect(find.text('Türkçe'), findsOneWidget);
      expect(find.text('İngilizce'), findsOneWidget);
    });
  });
}
