import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:markdown_viewer/app/app.dart';
import 'package:markdown_viewer/features/library/application/library_folders_provider.dart';
import 'package:markdown_viewer/features/library/application/recent_documents_provider.dart';
import 'package:markdown_viewer/features/library/data/repositories/library_folders_store_impl.dart';
import 'package:markdown_viewer/features/library/data/repositories/recent_documents_store_impl.dart';
import 'package:markdown_viewer/features/library/data/services/folder_enumerator_impl.dart';
import 'package:markdown_viewer/features/repo_sync/application/repo_sync_providers.dart';
import 'package:markdown_viewer/features/repo_sync/data/database/app_database.dart';
import 'package:markdown_viewer/features/settings/application/settings_providers.dart';
import 'package:markdown_viewer/features/settings/data/settings_store.dart';
import 'package:markdown_viewer/features/viewer/application/document_repository_provider.dart';
import 'package:markdown_viewer/features/viewer/application/mermaid_renderer_provider.dart';
import 'package:markdown_viewer/features/viewer/application/reading_position_store_provider.dart';
import 'package:markdown_viewer/features/viewer/data/parsers/markdown_parser.dart';
import 'package:markdown_viewer/features/viewer/data/repositories/document_repository_impl.dart';
import 'package:markdown_viewer/features/viewer/data/repositories/reading_position_store_impl.dart';
import 'package:markdown_viewer/features/viewer/data/services/mermaid/mermaid_renderer_impl.dart';
import 'package:markdown_viewer/features/viewer/domain/services/mermaid_renderer.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  // Required so we can load asset bundles, hit SharedPreferences,
  // and run the mermaid pre-warm before the first frame.
  WidgetsFlutterBinding.ensureInitialized();

  // Preload SharedPreferences so the settings controllers can seed
  // their initial state synchronously — otherwise the very first
  // frame would render with the default light theme / system locale
  // regardless of what the user last picked. The same instance also
  // backs the reading-position store so its synchronous `read` can
  // run inside a post-frame callback without an extra disk hop.
  final prefs = await SharedPreferences.getInstance();
  final logger = Logger();
  final settingsStore = SettingsStore(prefs);
  final readingPositionStore = ReadingPositionStoreImpl(prefs, logger: logger);
  final recentDocumentsStore = RecentDocumentsStoreImpl(prefs);
  final libraryFoldersStore = LibraryFoldersStoreImpl(prefs);
  final appDatabase = AppDatabase();

  final mermaidRenderer = await _buildMermaidRenderer();

  runApp(
    ProviderScope(
      // Composition root — this is the only place in the app that is
      // allowed to reach into `features/**/data/` and hand a concrete
      // implementation to an application-layer port. Every other file
      // depends on the abstract providers declared in the application
      // layer, so data implementations can be swapped (tests, fakes,
      // integration harnesses) without touching application or
      // presentation code.
      overrides: [
        documentRepositoryProvider.overrideWithValue(
          const DocumentRepositoryImpl(parser: MarkdownParser()),
        ),
        mermaidRendererProvider.overrideWith((ref) {
          ref.onDispose(mermaidRenderer.dispose);
          return mermaidRenderer;
        }),
        settingsStoreProvider.overrideWithValue(settingsStore),
        readingPositionStoreProvider.overrideWithValue(readingPositionStore),
        recentDocumentsStoreProvider.overrideWithValue(recentDocumentsStore),
        libraryFoldersStoreProvider.overrideWithValue(libraryFoldersStore),
        folderEnumeratorProvider.overrideWithValue(
          const FolderEnumeratorImpl(),
        ),
        appDatabaseProvider.overrideWithValue(appDatabase),
      ],
      child: const MarkdownViewerApp(),
    ),
  );
}

/// Loads the bundled mermaid runtime, constructs a production
/// [MermaidRendererImpl], and pre-warms its sandboxed WebView.
///
/// `prewarm` itself is non-throwing per the contract in
/// `mermaid_renderer.dart` — a failed initialisation just flips the
/// renderer into permanent-failure mode and every subsequent render
/// returns a typed [MermaidRenderFailure]. The try/catch here only
/// covers the `rootBundle.loadString` call, which can throw when
/// the asset is genuinely missing (e.g. a dev forgot to run
/// `tool/fetch_mermaid.sh`). In that case we still return a usable
/// renderer instance constructed with an empty JS payload so the
/// rest of the document continues to load — a diagram-less reading
/// experience is strictly better than a crashed app.
Future<MermaidRenderer> _buildMermaidRenderer() async {
  try {
    final mermaidJs = await rootBundle.loadString(
      'assets/mermaid/mermaid.min.js',
    );
    final renderer = MermaidRendererImpl.production(mermaidJs: mermaidJs);
    await renderer.prewarm();
    return renderer;
  } catch (error, stackTrace) {
    // Surface the cause in debug / profile builds so a dev who
    // forgot `tool/fetch_mermaid.sh` (or hit a transient WebView
    // initialisation glitch) sees why diagrams aren't working
    // instead of silently getting the empty-JS fallback. `debugPrint`
    // + `kDebugMode` keeps release builds silent so the user never
    // sees raw stack traces, matching the project's logging
    // policy in `docs/standards/error-handling-standards.md`.
    if (kDebugMode) {
      debugPrint(
        'Failed to load assets/mermaid/mermaid.min.js — falling back '
        'to an empty renderer so the rest of the document still '
        'loads. Error: $error',
      );
      debugPrint(stackTrace.toString());
    }
    return MermaidRendererImpl.production(mermaidJs: '');
  }
}
