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
/// (AES-256-GCM). iOS uses the system Keychain. The token never leaves
/// the device.
final patStoreProvider = Provider<PatStore>((ref) {
  return const PatStore(
    FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
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
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'User-Agent': 'MarkdownViewer/1.0 (flutter)',
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      },
    ),
  );
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final pat = await patStore.read();
        if (pat != null && pat.isNotEmpty) {
          options.headers['Authorization'] = 'token $pat';
        }
        handler.next(options);
      },
    ),
  );
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
