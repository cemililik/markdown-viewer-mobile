import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:markdown_viewer/app/app.dart';
import 'package:markdown_viewer/core/logging/logger.dart';
import 'package:markdown_viewer/core/path/sandbox_path.dart';
import 'package:markdown_viewer/features/default_handler/application/default_handler_providers.dart';
import 'package:markdown_viewer/features/default_handler/data/default_handler_channel_impl.dart';
import 'package:markdown_viewer/features/library/application/content_search_provider.dart';
import 'package:markdown_viewer/features/library/application/folder_file_materializer_provider.dart';
import 'package:markdown_viewer/features/library/application/library_folders_provider.dart';
import 'package:markdown_viewer/features/library/application/recent_documents_provider.dart';
import 'package:markdown_viewer/features/library/data/repositories/library_folders_store_impl.dart';
import 'package:markdown_viewer/features/library/data/repositories/recent_documents_store_impl.dart';
import 'package:markdown_viewer/features/library/data/services/folder_enumerator_impl.dart';
import 'package:markdown_viewer/features/library/data/services/folder_file_materializer.dart';
import 'package:markdown_viewer/features/library/data/services/library_content_search_impl.dart';
import 'package:markdown_viewer/features/library/data/services/native_library_folders_channel.dart';
import 'package:markdown_viewer/features/observability/application/observability_providers.dart';
import 'package:markdown_viewer/features/observability/data/consent_store_impl.dart';
import 'package:markdown_viewer/features/onboarding/application/onboarding_providers.dart';
import 'package:markdown_viewer/features/onboarding/data/onboarding_store_impl.dart';
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

  // Baseline SystemUiMode — set explicitly so every screen that
  // restores chrome on dispose (diagram fullscreen, in particular)
  // has a deterministic target. Without this the restore path
  // hardcoded `edgeToEdge` while the platform default could be
  // something else, so the very first fullscreen excursion migrated
  // the app into `edgeToEdge` permanently.
  // Reference: code-review CR-20260419-004.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

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
  final onboardingStore = OnboardingStoreImpl(prefs);
  final consentStore = ConsentStoreImpl(prefs);
  final appDatabase = AppDatabase();

  // Sentry — initialise only when the user has opted in AND a DSN
  // was supplied at build time. On first install both conditions are
  // false (consent defaults to off, local builds omit the DSN), so
  // no Sentry code runs until the user consciously enables the
  // toggle in Settings AND the build was produced with
  // `--dart-define=SENTRY_DSN=...`.
  //
  // Fire-and-forget so SentryFlutter.init's native side cost does
  // not sit on the cold-start critical path. ADR-0014 does not
  // require pre-runApp init; global `FlutterError.onError` +
  // `PlatformDispatcher.onError` already forward exceptions through
  // a `Sentry.isEnabled` guard, which evaluates `false` until the
  // background init completes — any crash in that tiny window falls
  // back to the logger, which is exactly the behaviour used on the
  // consent-off path.
  // Reference: performance-review PR-20260419-009.
  unawaited(CrashReportingController.initIfConsented(consentStore));

  // Load the bundled mermaid JS string now (cheap; it is already an
  // in-APK asset) and construct the renderer, but DO NOT prewarm
  // the WebView yet. Prewarm creates a `HeadlessInAppWebView` and
  // loads the data-URI template, which used to sit on the cold
  // path — deferred to a post-frame callback below so the library
  // screen renders first.
  // Reference: performance-review PR-20260419-008.
  final mermaidRenderer = await _buildMermaidRenderer(logger);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(mermaidRenderer.prewarm());
  });

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
        defaultHandlerChannelProvider.overrideWithValue(
          DefaultHandlerChannelImpl(),
        ),
        consentStoreProvider.overrideWithValue(consentStore),
        folderEnumeratorProvider.overrideWithValue(
          const FolderEnumeratorImpl(),
        ),
        libraryContentSearchProvider.overrideWithValue(
          const LibraryContentSearchImpl(),
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

/// Loads the bundled mermaid JS and constructs a production
/// [MermaidRendererImpl]. The WebView prewarm is intentionally NOT
/// awaited here — the caller schedules `prewarm()` via
/// `WidgetsBinding.addPostFrameCallback` so the user sees the
/// library screen before the headless WebView boots.
///
/// The try/catch only covers `rootBundle.loadString`, which can
/// throw when the asset is missing (e.g. a dev forgot to run
/// `tool/fetch_mermaid.sh`). In that case we still return a usable
/// renderer instance constructed with an empty JS payload so the
/// rest of the document continues to load — a diagram-less reading
/// experience is strictly better than a crashed app.
Future<MermaidRenderer> _buildMermaidRenderer(Logger logger) async {
  try {
    final mermaidJs = await rootBundle.loadString(
      'assets/mermaid/mermaid.min.js',
    );
    return MermaidRendererImpl.production(mermaidJs: mermaidJs);
  } catch (error, stackTrace) {
    logger.w(
      'Failed to load mermaid.min.js — falling back to empty renderer',
      error: error,
      stackTrace: stackTrace,
    );
    return MermaidRendererImpl.production(mermaidJs: '');
  }
}
