import 'package:markdown_viewer/features/repo_sync/domain/entities/remote_file.dart';
import 'package:markdown_viewer/features/repo_sync/domain/entities/repo_locator.dart';

/// Service port for a remote repository sync provider.
///
/// Each provider handles a specific hosting service (GitHub,
/// GitLab, etc.). The v1 implementation is [GitHubSyncProvider].
/// The provider abstraction lets the application layer remain
/// independent of any particular API contract.
abstract interface class RepoSyncProvider {
  /// Returns `true` when this provider can handle [url].
  bool canHandle(Uri url);

  /// Parses [url] into a [RepoLocator]. If the URL omits the
  /// branch (bare repository URL), the implementation resolves
  /// the default branch via an API call and returns a fully
  /// populated locator.
  ///
  /// Throws a subclass of [Failure] on invalid URLs or API errors.
  Future<RepoLocator> parse(Uri url);

  /// Yields every markdown file at or below [locator.subPath].
  /// Each [RemoteFile] includes a pre-computed [RemoteFile.rawUrl]
  /// so [downloadRaw] needs no locator reference.
  ///
  /// Throws a subclass of [Failure] on API errors.
  Stream<RemoteFile> listFiles(RepoLocator locator);

  /// Downloads the raw bytes of [file] and returns them.
  ///
  /// Throws a subclass of [Failure] on network or HTTP errors.
  Future<List<int>> downloadRaw(RemoteFile file);
}
