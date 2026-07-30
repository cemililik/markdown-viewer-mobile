import 'dart:io';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';
import 'package:markdown_viewer/app/theme.dart';
import 'package:markdown_viewer/core/errors/failure.dart';
import 'package:markdown_viewer/features/library/application/content_search_provider.dart';
import 'package:markdown_viewer/features/library/application/library_folders_provider.dart';
import 'package:markdown_viewer/features/library/application/recent_documents_provider.dart';
import 'package:markdown_viewer/features/library/domain/entities/library_folder.dart';
import 'package:markdown_viewer/features/library/domain/entities/recent_document.dart';
import 'package:markdown_viewer/features/library/domain/repositories/library_folders_store.dart';
import 'package:markdown_viewer/features/library/domain/repositories/recent_documents_store.dart';
import 'package:markdown_viewer/features/library/domain/services/folder_enumerator.dart';
import 'package:markdown_viewer/features/library/domain/services/library_content_search.dart';
import 'package:markdown_viewer/features/library/presentation/screens/library_screen.dart';
import 'package:markdown_viewer/features/observability/application/observability_providers.dart';
import 'package:markdown_viewer/features/observability/data/consent_store_impl.dart';
import 'package:markdown_viewer/features/onboarding/application/onboarding_providers.dart';
import 'package:markdown_viewer/features/onboarding/domain/repositories/onboarding_store.dart';
import 'package:markdown_viewer/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:markdown_viewer/features/repo_sync/application/repo_sync_providers.dart';
import 'package:markdown_viewer/features/repo_sync/data/services/pat_store.dart';
import 'package:markdown_viewer/features/repo_sync/domain/entities/synced_repo.dart';
import 'package:markdown_viewer/features/repo_sync/presentation/screens/repo_sync_screen.dart';
import 'package:markdown_viewer/features/settings/application/settings_providers.dart';
import 'package:markdown_viewer/features/settings/data/settings_store_impl.dart';
import 'package:markdown_viewer/features/settings/presentation/screens/settings_screen.dart';
import 'package:markdown_viewer/features/viewer/application/document_repository_provider.dart';
import 'package:markdown_viewer/features/viewer/application/reading_position_store_provider.dart';
import 'package:markdown_viewer/features/viewer/domain/entities/document.dart';
import 'package:markdown_viewer/features/viewer/domain/entities/reading_position.dart';
import 'package:markdown_viewer/features/viewer/domain/repositories/document_repository.dart';
import 'package:markdown_viewer/features/viewer/domain/repositories/reading_position_store.dart';
import 'package:markdown_viewer/features/viewer/presentation/screens/diagram_fullscreen_screen.dart';
import 'package:markdown_viewer/features/viewer/presentation/screens/viewer_screen.dart';
import 'package:markdown_viewer/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../_helpers/golden_harness.dart';

void main() {
  late SharedPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'settings.bookmarkHintSeen': true,
    });
    preferences = await SharedPreferences.getInstance();
    FlutterSecureStorage.setMockInitialValues(<String, String>{});

    final originalInterval =
        VisibilityDetectorController.instance.updateInterval;
    final originalLeakSettings = LeakTesting.settings;
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    LeakTesting.settings = originalLeakSettings.withIgnored(
      classes: const ['ImageStreamCompleterHandle', '_LiveImage'],
    );
    addTearDown(() {
      VisibilityDetectorController.instance.updateInterval = originalInterval;
      LeakTesting.settings = originalLeakSettings;
    });
  });

  goldenTest(
    'should render the LibraryScreen empty state across locale and scale',
    fileName: 'library_empty',
    pumpBeforeTest: goldenPumpBeforeTest,
    pumpWidget: goldenPumpWidget,
    builder:
        () => GoldenTestGroup(
          children: standardGoldenScenarios(
            builder:
                (locale, textScaler, brightness) => _libraryHarness(
                  preferences,
                  locale: locale,
                  textScaler: textScaler,
                  brightness: brightness,
                ),
          ),
        ),
  );

  goldenTest(
    'should render the ViewerScreen error state across locale and scale',
    fileName: 'viewer_error',
    pumpBeforeTest: goldenPumpBeforeTest,
    pumpWidget: goldenPumpWidget,
    builder:
        () => GoldenTestGroup(
          children: standardGoldenScenarios(
            builder:
                (locale, textScaler, brightness) => goldenAppHarness(
                  locale: locale,
                  textScaler: textScaler,
                  brightness: brightness,
                  home: ProviderScope(
                    overrides: [
                      documentRepositoryProvider.overrideWithValue(
                        const _FailingDocumentRepository(),
                      ),
                      readingPositionStoreProvider.overrideWithValue(
                        _PositionStore(),
                      ),
                      settingsStoreProvider.overrideWithValue(
                        SettingsStoreImpl(preferences),
                      ),
                      recentDocumentsStoreProvider.overrideWithValue(
                        _RecentStore(),
                      ),
                    ],
                    child: const ViewerScreen(
                      documentId: DocumentId('/tmp/missing.md'),
                    ),
                  ),
                ),
          ),
        ),
  );

  goldenTest(
    'should render the SettingsScreen across locale and scale',
    fileName: 'settings',
    pumpBeforeTest: goldenPumpBeforeTest,
    pumpWidget: goldenPumpWidget,
    builder:
        () => GoldenTestGroup(
          children: standardGoldenScenarios(
            builder:
                (locale, textScaler, brightness) => goldenAppHarness(
                  locale: locale,
                  textScaler: textScaler,
                  brightness: brightness,
                  home: ProviderScope(
                    overrides: [
                      settingsStoreProvider.overrideWithValue(
                        SettingsStoreImpl(preferences),
                      ),
                      consentStoreProvider.overrideWithValue(
                        ConsentStoreImpl(preferences),
                      ),
                    ],
                    child: const SettingsScreen(),
                  ),
                ),
          ),
        ),
  );

  goldenTest(
    'should render the OnboardingScreen across locale and scale',
    fileName: 'onboarding',
    pumpBeforeTest: goldenPumpBeforeTest,
    pumpWidget: goldenPumpWidget,
    builder:
        () => GoldenTestGroup(
          children: standardGoldenScenarios(
            builder:
                (locale, textScaler, brightness) => goldenAppHarness(
                  locale: locale,
                  textScaler: textScaler,
                  brightness: brightness,
                  home: ProviderScope(
                    overrides: [
                      onboardingStoreProvider.overrideWithValue(
                        _OnboardingStore(),
                      ),
                    ],
                    child: const OnboardingScreen(),
                  ),
                ),
          ),
        ),
  );

  goldenTest(
    'should render the RepoSyncScreen across locale and scale',
    fileName: 'repo_sync',
    pumpBeforeTest: goldenPumpBeforeTest,
    pumpWidget: goldenPumpWidget,
    builder:
        () => GoldenTestGroup(
          children: standardGoldenScenarios(
            builder:
                (locale, textScaler, brightness) => goldenAppHarness(
                  locale: locale,
                  textScaler: textScaler,
                  brightness: brightness,
                  home: ProviderScope(
                    overrides: [
                      patStoreProvider.overrideWithValue(
                        const PatStore(FlutterSecureStorage()),
                      ),
                      syncedReposProvider.overrideWith(
                        (_) async => const <SyncedRepo>[],
                      ),
                    ],
                    child: const RepoSyncScreen(
                      initialUrl: 'https://github.com/example/docs',
                    ),
                  ),
                ),
          ),
        ),
  );

  goldenTest(
    'should render the DiagramFullscreenScreen across locale and scale',
    fileName: 'diagram_fullscreen',
    pumpBeforeTest: goldenPumpBeforeTest,
    pumpWidget: goldenPumpWidget,
    builder:
        () => GoldenTestGroup(
          children: standardGoldenScenarios(
            builder:
                (locale, textScaler, brightness) => goldenAppHarness(
                  locale: locale,
                  textScaler: textScaler,
                  brightness: brightness,
                  home: DiagramFullscreenScreen(
                    args: DiagramFullscreenArgs(
                      pngBytes:
                          File(
                            'android/app/src/main/res/drawable-xxhdpi/'
                            'splash.png',
                          ).readAsBytesSync(),
                      width: 240,
                      height: 120,
                    ),
                  ),
                ),
          ),
        ),
  );
}

Widget _libraryHarness(
  SharedPreferences preferences, {
  required Locale locale,
  required TextScaler textScaler,
  required Brightness brightness,
}) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const LibraryScreen()),
      GoRoute(path: '/settings', builder: (_, _) => const SizedBox.shrink()),
      GoRoute(path: '/sync', builder: (_, _) => const SizedBox.shrink()),
    ],
  );
  addTearDown(router.dispose);

  return SizedBox(
    width: kGoldenViewport.width,
    height: kGoldenViewport.height,
    child: ProviderScope(
      overrides: [
        recentDocumentsStoreProvider.overrideWithValue(_RecentStore()),
        libraryFoldersStoreProvider.overrideWithValue(const _FoldersStore()),
        folderEnumeratorProvider.overrideWithValue(const _FolderEnumerator()),
        libraryContentSearchProvider.overrideWithValue(const _ContentSearch()),
        syncedReposProvider.overrideWith((_) async => const <SyncedRepo>[]),
        consentStoreProvider.overrideWithValue(ConsentStoreImpl(preferences)),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme:
            brightness == Brightness.dark
                ? AppTheme.dark(null)
                : AppTheme.light(null),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        debugShowCheckedModeBanner: false,
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: textScaler, disableAnimations: true),
              child: child!,
            ),
      ),
    ),
  );
}

final class _FailingDocumentRepository implements DocumentRepository {
  const _FailingDocumentRepository();

  @override
  Future<Document> load(DocumentId path) async {
    throw const FileNotFoundFailure(message: 'missing');
  }
}

final class _PositionStore implements ReadingPositionStore {
  @override
  ReadingPosition? read(DocumentId documentId) => null;

  @override
  Future<void> write(ReadingPosition position) async {}

  @override
  Future<void> clear(DocumentId documentId) async {}
}

final class _RecentStore implements RecentDocumentsStore {
  List<RecentDocument> _documents = const <RecentDocument>[];

  @override
  List<RecentDocument> read() => List.unmodifiable(_documents);

  @override
  Future<void> write(List<RecentDocument> documents) async {
    _documents = List.of(documents);
  }
}

final class _FoldersStore implements LibraryFoldersStore {
  const _FoldersStore();

  @override
  List<LibraryFolder> read() => const <LibraryFolder>[];

  @override
  Future<void> write(List<LibraryFolder> folders) async {}
}

final class _FolderEnumerator implements FolderEnumerator {
  const _FolderEnumerator();

  @override
  Future<List<FolderEntry>> enumerate(
    LibraryFolder folder, {
    String? subPath,
  }) async => const <FolderEntry>[];

  @override
  Future<List<FolderFileEntry>> enumerateRecursive(
    LibraryFolder folder,
  ) async => const <FolderFileEntry>[];
}

final class _ContentSearch implements LibraryContentSearch {
  const _ContentSearch();

  @override
  Future<List<ContentSearchMatch>> search({
    required String query,
    required List<RecentDocument> recents,
    required List<LibraryFolder> folders,
    required List<SyncedRepo> syncedRepos,
    required String recentsSourceLabel,
    required String Function(LibraryFolder folder) folderSourceLabelBuilder,
    required String Function(SyncedRepo repo) syncedRepoSourceLabelBuilder,
  }) async => const <ContentSearchMatch>[];
}

final class _OnboardingStore implements OnboardingStore {
  @override
  int readSeenVersion() => 0;

  @override
  Future<void> writeSeenVersion(int version) async {}
}
