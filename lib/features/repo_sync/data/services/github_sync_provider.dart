import 'dart:convert';
import 'dart:isolate';

import 'package:dio/dio.dart';
import 'package:markdown_viewer/core/errors/failure.dart';
import 'package:markdown_viewer/features/repo_sync/domain/entities/remote_file.dart';
import 'package:markdown_viewer/features/repo_sync/domain/entities/repo_locator.dart';
import 'package:markdown_viewer/features/repo_sync/domain/services/repo_sync_provider.dart';

/// GitHub implementation of [RepoSyncProvider].
///
/// Discovery uses the Git Trees API (one recursive call) to avoid
/// per-directory walking. Raw file downloads use
/// `raw.githubusercontent.com`, which does not count against the
/// GitHub REST API rate limit.
///
/// Recognised URL shapes:
///   - `https://github.com/{owner}/{repo}`
///   - `https://github.com/{owner}/{repo}/tree/{ref}`
///   - `https://github.com/{owner}/{repo}/tree/{ref}/{path…}`
///   - `https://github.com/{owner}/{repo}/blob/{ref}/{path}`
class GitHubSyncProvider implements RepoSyncProvider {
  GitHubSyncProvider({required this.dio});

  final Dio dio;

  static const String _apiBase = 'https://api.github.com';
  static const String _rawBase = 'https://raw.githubusercontent.com';

  @override
  bool canHandle(Uri url) => url.host == 'github.com';

  @override
  Future<RepoLocator> parse(Uri url) async {
    if (!canHandle(url)) {
      throw const UnsupportedProviderFailure(
        message: 'URL is not a GitHub URL',
      );
    }

    final segments = url.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.length < 2) {
      throw const UnsupportedProviderFailure(
        message: 'GitHub URL must include owner and repo',
      );
    }

    final owner = segments[0];
    final repo = segments[1];

    // Bare repo URL — resolve default branch.
    if (segments.length == 2) {
      final ref = await _defaultBranch(owner, repo);
      return RepoLocator(
        provider: 'github',
        owner: owner,
        repo: repo,
        ref: ref,
        subPath: '',
      );
    }

    // /tree/{ref} or /tree/{ref}/{path...}
    if (segments[2] == 'tree' && segments.length >= 4) {
      final ref = segments[3];
      final subPath = segments.length > 4 ? segments.sublist(4).join('/') : '';
      return RepoLocator(
        provider: 'github',
        owner: owner,
        repo: repo,
        ref: ref,
        subPath: subPath,
      );
    }

    // /blob/{ref}/{path}
    if (segments[2] == 'blob' && segments.length >= 5) {
      final ref = segments[3];
      final subPath = segments.sublist(4).join('/');
      return RepoLocator(
        provider: 'github',
        owner: owner,
        repo: repo,
        ref: ref,
        subPath: subPath,
        singleFile: true,
      );
    }

    throw const UnsupportedProviderFailure(
      message: 'Unrecognised GitHub URL shape',
    );
  }

  @override
  Stream<RemoteFile> listFiles(RepoLocator locator) async* {
    // Single-file blob URL — look up the blob SHA via the Contents API
    // so incremental re-sync can skip unchanged files. Without this,
    // a hardcoded empty SHA would fail the `knownShas[path] == sha`
    // check on every re-sync and force a redundant raw download.
    //
    // If the Contents API call fails for any reason we fall back to
    // an empty SHA and continue — a download cost beats aborting the
    // sync entirely. The user still gets the file, just without the
    // skip-unchanged optimisation.
    if (locator.singleFile) {
      final rawUrl =
          '$_rawBase/${locator.owner}/${locator.repo}/${locator.ref}/${locator.subPath}';
      String sha = '';
      try {
        final meta = await _fetchBlobMetadata(
          owner: locator.owner,
          repo: locator.repo,
          ref: locator.ref,
          path: locator.subPath,
        );
        sha = meta['sha'] as String? ?? '';
      } on Failure {
        // Leave sha empty; download path still works.
      }
      yield RemoteFile(path: locator.subPath, sha: sha, rawUrl: rawUrl);
      return;
    }

    final treeJson = await _fetchTree(
      owner: locator.owner,
      repo: locator.repo,
      ref: locator.ref,
    );

    final tree = treeJson['tree'];
    if (tree is! List) {
      throw const UnknownFailure(message: 'Unexpected tree API response shape');
    }

    // The Trees API silently omits entries when a repo exceeds 100 000 items.
    // Abort so the user is not silently handed an incomplete file list.
    if (treeJson['truncated'] == true) {
      throw const UnknownFailure(
        message:
            'Repository tree is too large for a single API call and was '
            'truncated. The sync has been aborted — no files will be synced.',
      );
    }

    final prefix =
        locator.subPath.isEmpty
            ? ''
            : locator.subPath.endsWith('/')
            ? locator.subPath
            : '${locator.subPath}/';

    for (final entry in tree) {
      if (entry is! Map<String, dynamic>) continue;
      if (entry['type'] != 'blob') continue;

      final path = entry['path'] as String? ?? '';
      if (!_isMarkdown(path)) continue;
      if (prefix.isNotEmpty && !path.startsWith(prefix)) continue;

      final sha = entry['sha'] as String? ?? '';
      final size = (entry['size'] as num?)?.toInt() ?? 0;
      final rawUrl =
          '$_rawBase/${locator.owner}/${locator.repo}/${locator.ref}/$path';

      yield RemoteFile(path: path, sha: sha, size: size, rawUrl: rawUrl);
    }
  }

  @override
  Future<List<int>> downloadRaw(RemoteFile file) async {
    try {
      final response = await dio.get<List<int>>(
        file.rawUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      final data = response.data;
      if (data == null) {
        throw const UnknownFailure(message: 'Empty response body');
      }
      return data;
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  // ── Private helpers ──────────────────────────────────────────────────

  Future<String> _defaultBranch(String owner, String repo) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        '$_apiBase/repos/$owner/$repo',
      );
      final data = response.data;
      final branch = data?['default_branch'];
      if (branch is String && branch.isNotEmpty) {
        return branch;
      }
      return 'main';
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Future<Map<String, dynamic>> _fetchTree({
    required String owner,
    required String repo,
    required String ref,
  }) async {
    try {
      // Request raw text so we can decode on a background isolate.
      // Large repos return multi-MB JSON; decoding inline blocks the
      // UI isolate for several frames (visible as a spinner freeze).
      final response = await dio.get<String>(
        '$_apiBase/repos/$owner/$repo/git/trees/$ref',
        queryParameters: {'recursive': '1'},
        options: Options(responseType: ResponseType.plain),
      );
      final body = response.data;
      if (body == null || body.isEmpty) return const {};
      return await Isolate.run(() => json.decode(body) as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  /// Fetches a single blob's metadata from the Contents API so we can
  /// populate [RemoteFile.sha] for `/blob/` single-file URLs. Only
  /// used by the single-file path; batch tree discovery uses the
  /// Trees API which already carries SHAs per entry.
  Future<Map<String, dynamic>> _fetchBlobMetadata({
    required String owner,
    required String repo,
    required String ref,
    required String path,
  }) async {
    try {
      final encodedPath = path.split('/').map(Uri.encodeComponent).join('/');
      final response = await dio.get<Map<String, dynamic>>(
        '$_apiBase/repos/$owner/$repo/contents/$encodedPath',
        queryParameters: {'ref': ref},
      );
      return response.data ?? const {};
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  static bool _isMarkdown(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.md') || lower.endsWith('.markdown');
  }

  static Failure _mapDioError(DioException e) {
    // Treat every connection-family Dio error as "no network" so the
    // user gets the actionable "check your connection" message rather
    // than an opaque "HTTP null" — this includes connection refused
    // (`connectionError`), DNS failure (`unknown`), and both timeout
    // flavours (`connectionTimeout` / `receiveTimeout` / `sendTimeout`)
    // where the response is never populated.
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.unknown) {
      return NetworkUnavailableFailure(
        message: 'No network connection',
        cause: e,
      );
    }
    final status = e.response?.statusCode;
    if (status == 401) {
      // 401 = invalid or expired token. A missing token on a public
      // repo never hits this branch — GitHub answers with a 200 — so
      // this is always actionable for the user (regenerate the PAT
      // and paste it again). Reuses RateLimitedFailure's "add a token"
      // UX slot because the user-facing recovery is the same shape:
      // go to Settings, update your token, try again.
      return RateLimitedFailure(
        message: 'Invalid or expired GitHub token',
        cause: e,
      );
    }
    if (status == 403) {
      final remaining = e.response?.headers.value('x-ratelimit-remaining');
      if (remaining == '0') {
        return RateLimitedFailure(
          message: 'GitHub rate limit exceeded',
          cause: e,
        );
      }
      // Non-rate-limit 403 = private repo without a PAT, SAML-enforced
      // org the token cannot access, etc. Same user fix as 401, so
      // the same Failure type keeps the message copy aligned.
      return RateLimitedFailure(
        message: 'Access denied — repository may be private',
        cause: e,
      );
    }
    if (status == 404) {
      return RepoNotFoundFailure(
        message: 'Repository or path not found',
        cause: e,
      );
    }
    return UnknownFailure(message: 'HTTP $status', cause: e);
  }
}
