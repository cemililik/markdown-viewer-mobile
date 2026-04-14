/// Public API barrel for the `repo_sync` feature.
///
/// Other features that need to reference synced-repo types import
/// through this barrel rather than reaching into private sub-layers.
library;

export 'application/repo_sync_notifier.dart'
    show
        CancelException,
        RepoSyncNotifier,
        RepoSyncState,
        SyncComplete,
        SyncDiscovering,
        SyncDownloading,
        SyncError,
        SyncIdle,
        repoSyncNotifierProvider;
export 'application/repo_sync_providers.dart'
    show
        appDatabaseProvider,
        gitHubSyncProviderProvider,
        patStoreProvider,
        syncDioProvider,
        syncedReposProvider,
        syncedReposStoreProvider;
export 'domain/entities/repo_locator.dart' show RepoLocator;
export 'domain/entities/sync_result.dart' show SyncResult;
export 'domain/entities/synced_repo.dart' show SyncStatus, SyncedRepo;
export 'presentation/screens/repo_sync_screen.dart' show RepoSyncScreen;
