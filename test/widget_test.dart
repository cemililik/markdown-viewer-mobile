import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/app/app.dart';
import 'package:markdown_viewer/features/library/application/library_folders_provider.dart';
import 'package:markdown_viewer/features/library/application/recent_documents_provider.dart';
import 'package:markdown_viewer/features/library/data/repositories/library_folders_store_impl.dart';
import 'package:markdown_viewer/features/library/data/repositories/recent_documents_store_impl.dart';
import 'package:markdown_viewer/features/library/data/services/folder_enumerator_impl.dart';
import 'package:markdown_viewer/features/observability/application/observability_providers.dart';
import 'package:markdown_viewer/features/observability/data/consent_store.dart';
import 'package:markdown_viewer/features/onboarding/application/onboarding_providers.dart';
import 'package:markdown_viewer/features/onboarding/data/onboarding_store.dart';
import 'package:markdown_viewer/features/settings/application/settings_providers.dart';
import 'package:markdown_viewer/features/settings/data/settings_store.dart';
import 'package:markdown_viewer/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('MarkdownViewerApp', () {
    testWidgets('should boot and render the library empty state', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'onboarding.seenVersion': currentOnboardingVersion,
      });
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsStoreProvider.overrideWithValue(SettingsStore(prefs)),
            recentDocumentsStoreProvider.overrideWithValue(
              RecentDocumentsStoreImpl(prefs),
            ),
            libraryFoldersStoreProvider.overrideWithValue(
              LibraryFoldersStoreImpl(prefs),
            ),
            folderEnumeratorProvider.overrideWithValue(
              const FolderEnumeratorImpl(),
            ),
            onboardingStoreProvider.overrideWithValue(OnboardingStore(prefs)),
            consentStoreProvider.overrideWithValue(ConsentStore(prefs)),
          ],
          child: const MarkdownViewerApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Load the English localizations so the test matches the ARB
      // values by key instead of coupling the assertions to a
      // specific English string — a key rename or a locale change
      // would otherwise surface as a mystery test failure. See the
      // testing-standards rule: "Never use `find.text` for strings
      // that will be localized."
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
      expect(find.text(l10n.navLibrary), findsOneWidget);
      expect(find.text(l10n.libraryEmptyTitle), findsOneWidget);
    });
  });
}
