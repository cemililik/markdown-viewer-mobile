import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/features/observability/application/observability_providers.dart';
import 'package:markdown_viewer/features/observability/data/consent_store_impl.dart';
import 'package:markdown_viewer/features/observability/domain/repositories/consent_store.dart';
import 'package:markdown_viewer/features/settings/application/settings_providers.dart';
import 'package:markdown_viewer/features/settings/data/settings_store_impl.dart';
import 'package:markdown_viewer/features/settings/domain/repositories/settings_store.dart';
import 'package:markdown_viewer/features/settings/presentation/screens/settings_screen.dart';
import 'package:markdown_viewer/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'semantics_audit.dart';

void main() {
  late SettingsStore store;
  late ConsentStore consentStore;
  late AppLocalizations l10n;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    store = SettingsStoreImpl(prefs);
    consentStore = ConsentStoreImpl(prefs);
  });

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  Widget harness() {
    return ProviderScope(
      overrides: [
        settingsStoreProvider.overrideWithValue(store),
        consentStoreProvider.overrideWithValue(consentStore),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsScreen(),
      ),
    );
  }

  testWidgets('should section headers carry isHeader semantics', (
    tester,
  ) async {
    await withSemanticsAudit(tester, () async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      final expectedHeaders = [
        l10n.settingsThemeTitle,
        l10n.settingsLanguageTitle,
        l10n.settingsReadingTitle,
        l10n.settingsDisplayTitle,
      ];
      for (final title in expectedHeaders) {
        final label = find.text(title);
        if (label.evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            label,
            240,
            scrollable: find.byType(Scrollable).first,
          );
        }
        expect(
          tester.getSemantics(find.bySemanticsLabel(title)),
          matchesSemantics(label: title, isHeader: true),
          reason: 'Settings section "$title" must remain a semantic header.',
        );
      }
      expectEveryTapTargetLabeled(tester);
      expectTapTargetsAtLeast(tester);
    });
  });
}
