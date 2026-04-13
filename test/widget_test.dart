import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/app/app.dart';
import 'package:markdown_viewer/features/library/application/recent_documents_provider.dart';
import 'package:markdown_viewer/features/library/data/repositories/recent_documents_store_impl.dart';
import 'package:markdown_viewer/features/settings/application/settings_providers.dart';
import 'package:markdown_viewer/features/settings/data/settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('MarkdownViewerApp', () {
    testWidgets('should boot and render the library empty state', (
      tester,
    ) async {
      // The smoke test boots the whole app, which means the settings
      // controllers are read during `MaterialApp.router`'s build and
      // need a real-ish [SettingsStore] backing them. Use the
      // SharedPreferences in-memory mock.
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsStoreProvider.overrideWithValue(SettingsStore(prefs)),
            recentDocumentsStoreProvider.overrideWithValue(
              RecentDocumentsStoreImpl(prefs),
            ),
          ],
          child: const MarkdownViewerApp(),
        ),
      );
      await tester.pumpAndSettle();

      // The default test locale is en_US, so we should see the English copy.
      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
      expect(find.text('Library'), findsOneWidget);
      expect(find.text('No documents yet'), findsOneWidget);
    });
  });
}
