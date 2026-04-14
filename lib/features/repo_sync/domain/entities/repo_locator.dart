/// Typed result of parsing a remote repository URL.
///
/// [ref] may be empty for bare repository URLs where the default
/// branch has not yet been resolved from the provider API. The
/// data layer resolves it before calling [RepoSyncProvider.listFiles].
final class RepoLocator {
  const RepoLocator({
    required this.provider,
    required this.owner,
    required this.repo,
    required this.ref,
    required this.subPath,
    this.singleFile = false,
  });

  /// Provider identifier, e.g. `'github'`.
  final String provider;

  /// Repository owner (user or organisation).
  final String owner;

  /// Repository name.
  final String repo;

  /// Branch, tag, or commit SHA. Empty when not yet resolved.
  final String ref;

  /// Sub-path within the repository root to sync. Empty string
  /// means sync the entire repository.
  final String subPath;

  /// `true` when the URL points at a single blob (file) rather
  /// than a tree (directory). The sync downloads only that file.
  final bool singleFile;

  RepoLocator copyWith({
    String? provider,
    String? owner,
    String? repo,
    String? ref,
    String? subPath,
    bool? singleFile,
  }) {
    return RepoLocator(
      provider: provider ?? this.provider,
      owner: owner ?? this.owner,
      repo: repo ?? this.repo,
      ref: ref ?? this.ref,
      subPath: subPath ?? this.subPath,
      singleFile: singleFile ?? this.singleFile,
    );
  }

  @override
  String toString() => '$provider:$owner/$repo@$ref/$subPath';
}
