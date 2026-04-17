import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:markdown_viewer/app/app.dart';
import 'package:markdown_viewer/core/logging/logger.dart';
import 'package:markdown_viewer/core/path/sandbox_path.dart';
import 'package:markdown_viewer/features/library/application/folder_file_materializer_provider.dart';
import 'package:markdown_viewer/features/library/application/library_folders_provider.dart';
import 'package:markdown_viewer/features/library/application/recent_documents_provider.dart';
import 'package:markdown_viewer/features/library/data/repositories/library_folders_store_impl.dart';
import 'package:markdown_viewer/features/library/data/repositories/recent_documents_store_impl.dart';
import 'package:markdown_viewer/features/library/data/services/folder_enumerator_impl.dart';
import 'package:markdown_viewer/features/library/data/services/folder_file_materializer.dart';
import 'package:markdown_viewer/features/library/data/services/native_library_folders_channel.dart';
import 'package:markdown_viewer/features/observability/application/observability_providers.dart';
import 'package:markdown_viewer/features/observability/data/consent_store_impl.dart';
import 'package:markdown_viewer/features/onboarding/application/onboarding_providers.dart';
import 'package:markdown_viewer/features/onboarding/data/onboarding_store.dart';
import 'package:markdown_viewer/features/repo_sync/application/repo_sync_providers.dart';
import 'package:markdown_viewer/features/repo_sync/data/database/app_database.dart';
import 'package:markdown_viewer/features/settings/application/settings_providers.dart';
import 'package:markdown_viewer/features/settings/data/settings_store_impl.dart';
import 'package:markdown_viewer/features/viewer/application/document_repository_provider.dart';
import 'package:markdown_viewer/features/viewer/application/mermaid_renderer_provider.dart';
import 'package:markdown_viewer/features/viewer/application/reading_position_store_provider.dart';
import 'package:markdown_viewer/features/viewer/data/parsers/markdown_parser.dart';
import 'package:markdown_viewer/features/viewer/data/repositories/document_repository_impl.dart';
import 'package:markdown_viewer/features/viewer/data/repositories/reading_position_store_impl.dart';
import 'package:markdown_viewer/features/viewer/data/services/mermaid/mermaid_renderer_impl.dart';
import 'package:markdown_viewer/features/viewer/domain/services/mermaid_renderer.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  // Required so we can load asset bundles, hit SharedPreferences,
  // and run the mermaid pre-warm before the first frame.
  WidgetsFlutterBinding.ensureInitialized();

  // Create the logger before the error hooks so they use the shared
  // instance with ProductionFilter — the default Logger() constructor
  // uses DevelopmentFilter which suppresses all output in release mode.
  final logger = Logger(
    filter: ProductionFilter(),
    printer: kReleaseMode ? LogfmtPrinter() : PrettyPrinter(),
    level: kReleaseMode ? Level.warning : Level.debug,
  );

  // ── Global error hooks (ADR-0014 Phase 1) ──────────────────────
  //
  // Catch framework-level errors (layout, paint, build) and
  // uncaught async exceptions from the platform so they are logged
  // instead of silently vanishing. Both handlers keep the default
  // debug-mode behaviour (red error screen / console dump) and add
  // a structured log entry on top.

  FlutterError.onError = (details) {
    // Preserve the default red-screen / console-dump in debug.
    FlutterError.presentError(details);
    logger.e(
      'FlutterError: ${details.exceptionAsString()}',
      error: details.exception,
      stackTrace: details.stack,
    );
    // Forward to Sentry when active (consent + DSN both present).
    // Sentry.isEnabled is false when init was skipped.
    if (Sentry.isEnabled) {
      Sentry.captureException(details.exception, stackTrace: details.stack);
    }
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    logger.e('Uncaught platform error', error: error, stackTrace: stack);
    if (Sentry.isEnabled) {
      Sentry.captureException(error, stackTrace: stack);
    }
    return true;
  };

  // Cache the sandbox roots BEFORE any stored paths are read back.
  // `RecentDocumentsStoreImpl.read` uses the cached roots to rewrite
  // portable `sandbox:cache:foo.md` tokens to their current absolute
  // form, which is necessary after an iOS dev reinstall changes the
  // container UUID (and keeps production resilient against any future
  // fresh-install scenarios).
  await SandboxPath.initialize();

  // Preload SharedPreferences so the settings controllers can seed
  // their initial state synchronously — otherwise the very first
  // frame would render with the default light theme / system locale
  // regardless of what the user last picked. The same instance also
  // backs the reading-position store so its synchronous `read` can
  // run inside a post-frame callback without an extra disk hop.
  final prefs = await SharedPreferences.getInstance();
  final settingsStore = SettingsStoreImpl(prefs);
  final readingPositionStore = ReadingPositionStoreImpl(prefs, logger: logger);
  final recentDocumentsStore = RecentDocumentsStoreImpl(prefs);
  final libraryFoldersStore = LibraryFoldersStoreImpl(prefs, logger: logger);
  final onboardingStore = OnboardingStore(prefs);
  final consentStore = ConsentStoreImpl(prefs);
  final appDatabase = AppDatabase();

  // Sentry — initialise only when the user has opted in AND a DSN
  // was supplied at build time. On first install both conditions are
  // false (consent defaults to off, local builds omit the DSN), so
  // no Sentry code runs until the user consciously enables the
  // toggle in Settings AND the build was produced with
  // `--dart-define=SENTRY_DSN=...`.
  await CrashReportingController.initIfConsented(consentStore);

  final mermaidRenderer = await _buildMermaidRenderer(logger);

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
        appLoggerProvider.overrideWithValue(logger),
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
        onboardingStoreProvider.overrideWithValue(onboardingStore),
        consentStoreProvider.overrideWithValue(consentStore),
        folderEnumeratorProvider.overrideWithValue(
          const FolderEnumeratorImpl(),
        ),
        nativeLibraryFoldersChannelProvider.overrideWithValue(
          NativeLibraryFoldersChannelImpl(),
        ),
        folderFileMaterializerProvider.overrideWith(
          (ref) => FolderFileMaterializerImpl(
            channel: ref.watch(nativeLibraryFoldersChannelProvider),
          ),
        ),
        appDatabaseProvider.overrideWith((ref) {
          ref.onDispose(appDatabase.close);
          return appDatabase;
        }),
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
Future<MermaidRenderer> _buildMermaidRenderer(Logger logger) async {
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
    logger.w(
      'Failed to load mermaid.min.js — falling back to empty renderer',
      error: error,
      stackTrace: stackTrace,
    );
    return MermaidRendererImpl.production(mermaidJs: '');
  }
}
