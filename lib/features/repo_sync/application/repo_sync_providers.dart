// This file is the composition root for the repo_sync feature.
// Intentional deviation from the layering rule: providers here wire domain
// ports to concrete data-layer implementations (AppDatabase,
// SyncedReposStoreImpl, GitHubSyncProvider, PatStore). All other files in the
// feature import only the domain-layer abstractions declared in this file.
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:markdown_viewer/features/repo_sync/data/database/app_database.dart';
import 'package:markdown_viewer/features/repo_sync/data/repositories/synced_repos_store_impl.dart';
import 'package:markdown_viewer/features/repo_sync/data/services/github_sync_provider.dart';
import 'package:markdown_viewer/features/repo_sync/data/services/pat_store.dart';
import 'package:markdown_viewer/features/repo_sync/domain/entities/synced_repo.dart';
import 'package:markdown_viewer/features/repo_sync/domain/repositories/synced_repos_store.dart';
import 'package:markdown_viewer/features/repo_sync/domain/services/repo_sync_provider.dart';
import 'package:sentry_dio/sentry_dio.dart';

/// The shared drift database. Created once at app start and kept
/// alive for the app lifetime. Overridden in the composition root
/// (main.dart) with the production instance.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError(
    'appDatabaseProvider must be overridden in the composition root '
    '(lib/main.dart) with AppDatabase(), or in tests with an in-memory DB.',
  );
});

/// Drift-backed [SyncedReposStore]. Derived from [appDatabaseProvider].
final syncedReposStoreProvider = Provider<SyncedReposStore>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return SyncedReposStoreImpl(db);
});

/// Secure storage for the optional GitHub Personal Access Token.
///
/// Android uses EncryptedSharedPreferences backed by Android Keystore
/// (AES-256-GCM). iOS uses the system Keychain. The token is stored
/// encrypted at rest and is transmitted to GitHub only during
/// user-triggered sync operations.
final patStoreProvider = Provider<PatStore>((ref) {
  return const PatStore(
    FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      // iOS accessibility: the PAT must remain readable only after
      // the device has been unlocked at least once since boot, and
      // must never migrate in a device-to-device restore (the new
      // device hasn't been authorised to talk to the user's GitHub
      // account yet). Default `kSecAttrAccessibleWhenUnlocked` would
      // leak the PAT to a background task while the device is locked.
      // Reference: security-review SR-20260419-005.
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
      ),
    ),
  );
});

/// Shared [Dio] client for all GitHub API and raw download calls.
///
/// Configured with a descriptive User-Agent and JSON accept header.
/// An `Authorization` header is injected per-request via an interceptor
/// that reads the stored PAT from [patStoreProvider] so it is always
/// fresh without mutating the shared [Dio] instance's global headers.
final syncDioProvider = Provider<Dio>((ref) {
  final patStore = ref.watch(patStoreProvider);
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 60),
      headers: {
        'User-Agent': 'MarkdownViewer/1.0 (flutter)',
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      },
      // Turn off transparent redirect following so the request-side
      // interceptor can re-validate every hop through the allow-list
      // and strip `Authorization` when a 3xx lands on an off-list
      // host. `dart:io` `HttpClient` (Dio 5's default transport) does
      // NOT re-invoke the interceptor chain on transparent redirects,
      // so a 301 from `api.github.com` to an attacker-controlled host
      // would otherwise leak the PAT header.
      // Reference: security-review SR-20260419-003 (M-3 carry).
      followRedirects: false,
      maxRedirects: 0,
      // Accept 3xx so the response interceptor can replay through the
      // allow-list + PAT scrubbing logic instead of Dio throwing.
      validateStatus: (status) => status != null && status < 400,
    ),
  );
  const allowedHosts = {'api.github.com', 'raw.githubusercontent.com'};
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Host allow-list — enforced on every request (direct calls
        // and redirect follow-ups both pass through this interceptor)
        // so a misconfigured base URL, an interpolation bug, or a
        // 3xx to a third-party host is rejected before the socket
        // opens. Reference: security-standards.md §Network Rules and
        // securityreports/20260417T091912 §M-1.
        final host = options.uri.host.toLowerCase();
        if (!allowedHosts.contains(host)) {
          return handler.reject(
            DioException.connectionError(
              requestOptions: options,
              reason:
                  'Host "$host" is not in the GitHub sync allow-list '
                  '(${allowedHosts.join(", ")})',
            ),
          );
        }
        final pat = await patStore.read();
        if (pat != null && pat.isNotEmpty) {
          options.headers['Authorization'] = 'token $pat';
        }
        handler.next(options);
      },
      onResponse: (response, handler) async {
        // Manual redirect follow: a 3xx response carries a Location
        // header that must be validated against the allow-list before
        // we replay the request. If the target host is off-list we
        // strip `Authorization` so a compromised GitHub CDN redirect
        // cannot smuggle the PAT to a third party; if on-list we
        // replay through the full interceptor chain so host-check +
        // PAT injection happen again cleanly.
        // Reference: security-review SR-20260419-003.
        final status = response.statusCode ?? 0;
        if (status < 300 || status >= 400) {
          return handler.next(response);
        }
        final locationRaw = response.headers.value('location');
        if (locationRaw == null || locationRaw.isEmpty) {
          return handler.next(response);
        }
        final resolved = response.requestOptions.uri.resolve(locationRaw);
        final nextHost = resolved.host.toLowerCase();
        final replayOptions = response.requestOptions.copyWith(
          path: resolved.toString(),
        );
        if (!allowedHosts.contains(nextHost)) {
          replayOptions.headers.remove('Authorization');
          return handler.reject(
            DioException.connectionError(
              requestOptions: replayOptions,
              reason:
                  'Redirect target "$nextHost" is not in the allow-list '
                  '(${allowedHosts.join(", ")})',
            ),
          );
        }
        try {
          final replayed = await dio.fetch<dynamic>(replayOptions);
          return handler.resolve(replayed);
        } on DioException catch (e) {
          return handler.reject(e);
        }
      },
      onError: (error, handler) async {
        // 5xx retry with exponential backoff (1 s → 2 s → 4 s). Caps
        // at three retries total so a persistent server error is
        // surfaced to the user inside ~10 seconds instead of after
        // several tens of seconds of silent retrying.
        // Reference: security-review SR-20260419-004 (M-4 carry).
        final status = error.response?.statusCode ?? 0;
        if (status < 500 || status >= 600) {
          return handler.next(error);
        }
        final attempt =
            (error.requestOptions.extra['_retryAttempt'] as int?) ?? 0;
        if (attempt >= 3) {
          return handler.next(error);
        }
        final delay = Duration(seconds: 1 << attempt); // 1, 2, 4
        await Future<void>.delayed(delay);
        final nextOptions = error.requestOptions.copyWith(
          extra: {...error.requestOptions.extra, '_retryAttempt': attempt + 1},
        );
        try {
          final response = await dio.fetch<dynamic>(nextOptions);
          return handler.resolve(response);
        } on DioException catch (e) {
          return handler.next(e);
        }
      },
    ),
  );
  // Sentry Dio integration — records HTTP breadcrumbs and performance
  // spans when Sentry is active (consent + DSN both present). When
  // Sentry is dormant the extension is a no-op with zero overhead.
  //
  // `captureFailedRequests: false` — the default-true path wires a
  // `DioEventProcessor` that enriches every 5xx event with the full
  // request URL, bypassing `sendDefaultPii: false`. All Sentry
  // capture for this app goes through the global error hooks in
  // `main.dart`; we do not want a second, hidden activation path.
  // Reference: security-review SR-20260419-042 / SR-20260419-018.
  dio.addSentry(captureFailedRequests: false);
  ref.onDispose(dio.close);
  return dio;
});

/// The GitHub-backed [RepoSyncProvider].
final gitHubSyncProviderProvider = Provider<RepoSyncProvider>((ref) {
  final dio = ref.watch(syncDioProvider);
  return GitHubSyncProvider(dio: dio);
});

/// Watches the list of all persisted synced repositories, refreshing
/// automatically after any mutation.
final syncedReposProvider = FutureProvider<List<SyncedRepo>>((ref) async {
  final store = ref.watch(syncedReposStoreProvider);
  return store.readAll();
});
