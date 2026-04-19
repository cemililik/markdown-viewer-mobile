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
// Formatter is a presentation helper but is also used by
// `source_picker_drawer.dart` in the library feature — exporting it
// through the barrel keeps cross-feature imports from reaching into
// `presentation/` directly.
// Reference: code-review CR-20260419-024.
export 'presentation/sync_time_format.dart' show formatLastSynced;
