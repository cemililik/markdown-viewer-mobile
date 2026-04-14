import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/features/settings/application/settings_providers.dart';
import 'package:markdown_viewer/features/settings/data/settings_store.dart';
import 'package:markdown_viewer/features/settings/presentation/screens/settings_screen.dart';
import 'package:markdown_viewer/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SettingsStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    store = SettingsStore(prefs);
  });

  Widget harness() {
    return ProviderScope(
      overrides: [settingsStoreProvider.overrideWithValue(store)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SettingsScreen(),
      ),
    );
  }

  testWidgets('section headers carry isHeader semantics', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    // Every _SectionHeader wraps its Text in Semantics(header: true).
    // Find all such Semantics widgets in the tree to confirm at least
    // one section header is present.
    final headerWidgets = find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.header == true,
    );

    expect(
      headerWidgets,
      findsWidgets,
      reason:
          'SettingsScreen must have at least one node flagged isHeader so '
          'screen readers can jump between sections by heading.',
    );
  });
}
