import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

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
  late Uint8List diagramPng;

  setUpAll(() async {
    diagramPng = await _buildDiagramFixture();
  });

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
    'should render the LibraryScreen empty state across locale, theme, and scale when captured',
    fileName: 'library_empty',
    tags: const ['golden'],
    pumpBeforeTest: goldenPumpBeforeTest,
    pumpWidget: goldenPumpWidget,
    builder:
        () => GoldenTestGroup(
          children: standardGoldenScenarios(
            builder:
                (locale, textScaler, appTheme) => _libraryHarness(
                  preferences,
                  locale: locale,
                  textScaler: textScaler,
                  appTheme: appTheme,
                ),
          ),
        ),
  );

  goldenTest(
    'should render the ViewerScreen error state across locale, theme, and scale when captured',
    fileName: 'viewer_error',
    tags: const ['golden'],
    pumpBeforeTest: goldenPumpBeforeTest,
    pumpWidget: goldenPumpWidget,
    builder:
        () => GoldenTestGroup(
          children: standardGoldenScenarios(
            builder:
                (locale, textScaler, appTheme) => goldenAppHarness(
                  locale: locale,
                  textScaler: textScaler,
                  appTheme: appTheme,
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
    'should render the ViewerScreen loading state across locale, theme, and scale when captured',
    fileName: 'viewer_loading',
    tags: const ['golden'],
    pumpBeforeTest: _goldenPumpPendingState,
    pumpWidget: goldenPumpWidget,
    builder:
        () => GoldenTestGroup(
          children: standardGoldenScenarios(
            builder:
                (locale, textScaler, appTheme) => goldenAppHarness(
                  locale: locale,
                  textScaler: textScaler,
                  appTheme: appTheme,
                  home: ProviderScope(
                    overrides: [
                      documentRepositoryProvider.overrideWithValue(
                        _PendingDocumentRepository(),
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
                      documentId: DocumentId('/tmp/loading.md'),
                    ),
                  ),
                ),
          ),
        ),
  );

  goldenTest(
    'should render the SettingsScreen across locale, theme, and scale when captured',
    fileName: 'settings',
    tags: const ['golden'],
    pumpBeforeTest: goldenPumpBeforeTest,
    pumpWidget: goldenPumpWidget,
    builder:
        () => GoldenTestGroup(
          children: standardGoldenScenarios(
            builder:
                (locale, textScaler, appTheme) => goldenAppHarness(
                  locale: locale,
                  textScaler: textScaler,
                  appTheme: appTheme,
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
    'should render the OnboardingScreen across locale, theme, and scale when captured',
    fileName: 'onboarding',
    tags: const ['golden'],
    pumpBeforeTest: goldenPumpBeforeTest,
    pumpWidget: goldenPumpWidget,
    builder:
        () => GoldenTestGroup(
          children: standardGoldenScenarios(
            builder:
                (locale, textScaler, appTheme) => goldenAppHarness(
                  locale: locale,
                  textScaler: textScaler,
                  appTheme: appTheme,
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
    'should render the RepoSyncScreen across locale, theme, and scale when captured',
    fileName: 'repo_sync',
    tags: const ['golden'],
    pumpBeforeTest: goldenPumpBeforeTest,
    pumpWidget: goldenPumpWidget,
    builder:
        () => GoldenTestGroup(
          children: standardGoldenScenarios(
            builder:
                (locale, textScaler, appTheme) => goldenAppHarness(
                  locale: locale,
                  textScaler: textScaler,
                  appTheme: appTheme,
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
    'should render the DiagramFullscreenScreen across locale, theme, and scale when captured',
    fileName: 'diagram_fullscreen',
    tags: const ['golden'],
    pumpBeforeTest: goldenPumpBeforeTestWithImages,
    pumpWidget: goldenPumpWidget,
    builder:
        () => GoldenTestGroup(
          children: standardGoldenScenarios(
            builder:
                (locale, textScaler, appTheme) => goldenAppHarness(
                  locale: locale,
                  textScaler: textScaler,
                  appTheme: appTheme,
                  home: DiagramFullscreenScreen(
                    args: DiagramFullscreenArgs(
                      pngBytes: diagramPng,
                      width: 1400,
                      height: 900,
                    ),
                  ),
                ),
          ),
        ),
  );

  goldenTest(
    'should render transformed diagram chrome across locale, theme, and scale when captured',
    fileName: 'diagram_fullscreen_transformed',
    tags: const ['golden'],
    pumpBeforeTest: _goldenPumpTransformedDiagram,
    pumpWidget: goldenPumpWidget,
    builder:
        () => GoldenTestGroup(
          children: standardGoldenScenarios(
            builder:
                (locale, textScaler, appTheme) => goldenAppHarness(
                  locale: locale,
                  textScaler: textScaler,
                  appTheme: appTheme,
                  home: DiagramFullscreenScreen(
                    args: DiagramFullscreenArgs(
                      pngBytes: diagramPng,
                      width: 1400,
                      height: 900,
                    ),
                  ),
                ),
          ),
        ),
  );
}

Future<void> _goldenPumpPendingState(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _goldenPumpTransformedDiagram(WidgetTester tester) async {
  await goldenPumpBeforeTestWithImages(tester);
  for (final viewer in tester.widgetList<InteractiveViewer>(
    find.byType(InteractiveViewer),
  )) {
    final controller = viewer.transformationController;
    if (controller == null) continue;
    final transform =
        Matrix4.identity()
          ..setEntry(0, 0, 2.4)
          ..setEntry(1, 1, 2.4)
          ..setEntry(0, 3, -180)
          ..setEntry(1, 3, -120);
    controller.value = transform;
  }
  await tester.pump();
}

Future<Uint8List> _buildDiagramFixture() async {
  const width = 1400;
  const height = 900;
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final background = Paint()..color = const Color(0xFFF4F7FB);
  final connector =
      Paint()
        ..color = const Color(0xFF53657D)
        ..strokeWidth = 10
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
  final nodeFill =
      Paint()
        ..color = const Color(0xFFFFFFFF)
        ..style = PaintingStyle.fill;
  final nodeBorder =
      Paint()
        ..color = const Color(0xFF335A7D)
        ..strokeWidth = 8
        ..style = PaintingStyle.stroke;
  final nodeAccent =
      Paint()
        ..color = const Color(0xFF77B7E5)
        ..style = PaintingStyle.fill;

  canvas.drawRect(const Rect.fromLTWH(0, 0, 1400, 900), background);

  final connectors =
      Path()
        ..moveTo(280, 450)
        ..lineTo(420, 450)
        ..moveTo(660, 450)
        ..lineTo(820, 450)
        ..moveTo(1060, 450)
        ..lineTo(1180, 450)
        ..moveTo(540, 360)
        ..lineTo(540, 190)
        ..moveTo(540, 540)
        ..lineTo(540, 710);
  canvas.drawPath(connectors, connector);

  for (final arrow in const [
    [Offset(420, 450), Offset(385, 425), Offset(385, 475)],
    [Offset(820, 450), Offset(785, 425), Offset(785, 475)],
    [Offset(1180, 450), Offset(1145, 425), Offset(1145, 475)],
    [Offset(540, 190), Offset(515, 225), Offset(565, 225)],
    [Offset(540, 710), Offset(515, 675), Offset(565, 675)],
  ]) {
    final path =
        Path()
          ..moveTo(arrow[0].dx, arrow[0].dy)
          ..lineTo(arrow[1].dx, arrow[1].dy)
          ..lineTo(arrow[2].dx, arrow[2].dy)
          ..close();
    canvas.drawPath(path, connector..style = PaintingStyle.fill);
    connector.style = PaintingStyle.stroke;
  }

  for (final rect in const [
    Rect.fromLTWH(40, 360, 240, 180),
    Rect.fromLTWH(420, 20, 240, 170),
    Rect.fromLTWH(420, 360, 240, 180),
    Rect.fromLTWH(420, 710, 240, 170),
    Rect.fromLTWH(820, 350, 240, 200),
    Rect.fromLTWH(1180, 365, 180, 170),
  ]) {
    final rounded = RRect.fromRectAndRadius(rect, const Radius.circular(26));
    canvas.drawRRect(rounded, nodeFill);
    canvas.drawRRect(rounded, nodeBorder);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(rect.left + 28, rect.top + 32, rect.width - 56, 24),
        const Radius.circular(12),
      ),
      nodeAccent,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(rect.left + 28, rect.top + 82, rect.width * 0.58, 16),
        const Radius.circular(8),
      ),
      nodeAccent..color = const Color(0xFFB7C7D8),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(rect.left + 28, rect.top + 118, rect.width * 0.42, 16),
        const Radius.circular(8),
      ),
      nodeAccent,
    );
    nodeAccent.color = const Color(0xFF77B7E5);
  }

  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  if (data == null) {
    throw StateError('Unable to encode the deterministic diagram fixture.');
  }
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

Widget _libraryHarness(
  SharedPreferences preferences, {
  required Locale locale,
  required TextScaler textScaler,
  required GoldenAppTheme appTheme,
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
        theme: switch (appTheme) {
          GoldenAppTheme.light => AppTheme.light(null),
          GoldenAppTheme.dark => AppTheme.dark(null),
          GoldenAppTheme.sepia => AppTheme.sepia(),
        },
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

final class _PendingDocumentRepository implements DocumentRepository {
  final Completer<Document> _completer = Completer<Document>();

  @override
  Future<Document> load(DocumentId path) => _completer.future;
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
