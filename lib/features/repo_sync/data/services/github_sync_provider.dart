import 'dart:convert';
import 'dart:isolate';

import 'package:dio/dio.dart';
import 'package:markdown_viewer/core/errors/failure.dart';
import 'package:markdown_viewer/features/repo_sync/domain/entities/remote_file.dart';
import 'package:markdown_viewer/features/repo_sync/domain/entities/repo_locator.dart';
import 'package:markdown_viewer/features/repo_sync/domain/services/repo_sync_provider.dart';
import 'package:path/path.dart' as p;

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

  /// Per-file download cap from `security-standards.md` §Network
  /// Rules — protects against a malicious or corrupted repo serving a
  /// multi-GB payload that would OOM the client.
  static const int _maxFileBytes = 5 * 1024 * 1024;

  /// Per discovery-call cap (Trees API JSON, Contents API JSON,
  /// default-branch metadata) from the same standards section.
  static const int _maxDiscoveryBytes = 25 * 1024 * 1024;

  /// Builds a Dio [CancelToken] + `onReceiveProgress` pair that
  /// aborts the request as soon as either the advertised content-
  /// length or the cumulative received bytes exceed [maxBytes].
  ///
  /// Returning both pieces together keeps the call sites compact —
  /// every GET gets `cancelToken: tok, onReceiveProgress: prog` and
  /// the caller does not have to repeat the threshold logic.
  ({CancelToken token, void Function(int, int) onProgress}) _sizeCap(
    int maxBytes,
    String label,
  ) {
    final token = CancelToken();
    void onProgress(int received, int total) {
      if (total > 0 && total > maxBytes) {
        token.cancel('$label advertised $total bytes > cap $maxBytes');
      } else if (received > maxBytes) {
        token.cancel('$label received $received bytes > cap $maxBytes');
      }
    }

    return (token: token, onProgress: onProgress);
  }

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
      // URI-encode each ref / sub-path segment so branch names with
      // slashes (`feature/foo`) and paths with spaces or unicode
      // survive the round-trip. Owner and repo are restricted by
      // GitHub to `[A-Za-z0-9._-]`, no encoding required.
      final rawRef = locator.ref.split('/').map(Uri.encodeComponent).join('/');
      final rawSub = locator.subPath
          .split('/')
          .map(Uri.encodeComponent)
          .join('/');
      final rawUrl =
          '$_rawBase/${locator.owner}/${locator.repo}/$rawRef/$rawSub';
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
    // Computed once — the encoded ref is the same for every blob in
    // this tree. Previous revisions recomputed it inside the loop,
    // wasting a split+map+join per file on large repos.
    final rawRef = locator.ref.split('/').map(Uri.encodeComponent).join('/');

    for (final entry in tree) {
      if (entry is! Map<String, dynamic>) continue;
      if (entry['type'] != 'blob') continue;

      final path = entry['path'] as String? ?? '';
      if (!_isMarkdown(path)) continue;
      if (prefix.isNotEmpty && !path.startsWith(prefix)) continue;

      final sha = entry['sha'] as String? ?? '';
      final size = (entry['size'] as num?)?.toInt() ?? 0;
      final rawPath = path.split('/').map(Uri.encodeComponent).join('/');
      final rawUrl =
          '$_rawBase/${locator.owner}/${locator.repo}/$rawRef/$rawPath';

      yield RemoteFile(path: path, sha: sha, size: size, rawUrl: rawUrl);
    }
  }

  @override
  Future<List<int>> downloadRaw(RemoteFile file) async {
    // Exception messages use only `p.basename(file.path)` because
    // the full `file.path` carries the remote repo directory
    // structure into any upstream log / Sentry event. The basename is
    // enough to identify which file tripped the cap for debugging
    // without propagating PII-adjacent path segments.
    // Reference: security-review SR-20260419-019.
    final displayName = p.basename(file.path);
    final cap = _sizeCap(_maxFileBytes, 'file $displayName');
    try {
      final response = await dio.get<List<int>>(
        file.rawUrl,
        options: Options(responseType: ResponseType.bytes),
        cancelToken: cap.token,
        onReceiveProgress: cap.onProgress,
      );
      final data = response.data;
      if (data == null) {
        throw const UnknownFailure(message: 'Empty response body');
      }
      // Belt-and-suspenders: a server that omits Content-Length and
      // delivers the payload in a single chunk skips `onReceiveProgress`
      // between "0 bytes" and "done", so re-check the final size here.
      if (data.length > _maxFileBytes) {
        throw UnknownFailure(
          message:
              'File $displayName exceeds the '
              '$_maxFileBytes-byte per-file cap',
        );
      }
      return data;
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  // ── Private helpers ──────────────────────────────────────────────────

  Future<String> _defaultBranch(String owner, String repo) async {
    final cap = _sizeCap(_maxDiscoveryBytes, 'repo metadata $owner/$repo');
    try {
      final response = await dio.get<Map<String, dynamic>>(
        '$_apiBase/repos/$owner/$repo',
        cancelToken: cap.token,
        onReceiveProgress: cap.onProgress,
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
    final cap = _sizeCap(_maxDiscoveryBytes, 'tree $owner/$repo@$ref');
    try {
      // Request raw text so we can decode on a background isolate.
      // Large repos return multi-MB JSON; decoding inline blocks the
      // UI isolate for several frames (visible as a spinner freeze).
      final response = await dio.get<String>(
        '$_apiBase/repos/$owner/$repo/git/trees/$ref',
        queryParameters: {'recursive': '1'},
        options: Options(responseType: ResponseType.plain),
        cancelToken: cap.token,
        onReceiveProgress: cap.onProgress,
      );
      final body = response.data;
      if (body == null || body.isEmpty) return const {};
      // UTF-8 bytes may slightly exceed `body.length` (String is
      // UTF-16 code units), but we already enforced the byte-level
      // cap via `onReceiveProgress`. This guard catches the same
      // single-chunk edge case as `downloadRaw`.
      if (body.length > _maxDiscoveryBytes) {
        throw const UnknownFailure(
          message:
              'Tree response exceeds the $_maxDiscoveryBytes-byte discovery cap',
        );
      }
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
    final cap = _sizeCap(_maxDiscoveryBytes, 'blob metadata $path');
    try {
      final encodedPath = path.split('/').map(Uri.encodeComponent).join('/');
      final response = await dio.get<Map<String, dynamic>>(
        '$_apiBase/repos/$owner/$repo/contents/$encodedPath',
        queryParameters: {'ref': ref},
        cancelToken: cap.token,
        onReceiveProgress: cap.onProgress,
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

  /// Scrubs URL- and IP-shaped substrings from a Dio inner error
  /// message and bounds the result length. Keeps the class name +
  /// error category so debugging is still possible, but the PII-
  /// adjacent request target never propagates into Sentry via
  /// `Failure.cause.toString()`.
  ///
  /// Three patterns run in sequence:
  ///   1. `scheme://host[:port][/path]` / bare dotted hostnames —
  ///      `SocketException: Failed host lookup: 'raw.github…'`.
  ///   2. IPv4 literals with an optional port — SocketException on
  ///      a failed `connect()` typically reports the resolved IP
  ///      (`203.0.113.4:443`) rather than the hostname.
  ///   3. Bracketed IPv6 literals with an optional port —
  ///      `[2001:db8::1]:443`.
  static String _sanitizeUnknownReason(String raw) {
    const maxLen = 200;
    final urlLike = RegExp(
      r'(?:https?://)?[A-Za-z0-9.-]+\.[A-Za-z]{2,}'
      r'(?::\d+)?(?:/[^\s,)"]*)?',
    );
    // `\b` anchors keep the IPv4 regex from matching the leading
    // four digits of `12345` — the boundary requires a non-word
    // character (or string start/end) on either side.
    final ipv4 = RegExp(r'\b\d{1,3}(?:\.\d{1,3}){3}(?::\d+)?\b');
    final ipv6 = RegExp(r'\[[0-9a-fA-F:]+\](?::\d+)?');
    var scrubbed = raw
        .replaceAll(urlLike, '[redacted]')
        .replaceAll(ipv6, '[redacted]')
        .replaceAll(ipv4, '[redacted]');
    // Bounded length: an inner message the size of a full
    // SocketException can otherwise run to a few KB.
    if (scrubbed.length > maxLen) {
      scrubbed = '${scrubbed.substring(0, maxLen)}…';
    }
    return scrubbed;
  }

  static Failure _mapDioError(DioException e) {
    // Treat every connection-family Dio error as "no network" so the
    // user gets the actionable "check your connection" message rather
    // than an opaque "HTTP null" — this includes connection refused
    // (`connectionError`) and both timeout flavours
    // (`connectionTimeout` / `receiveTimeout` / `sendTimeout`) where
    // the response is never populated.
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return NetworkUnavailableFailure(
        message: 'No network connection',
        cause: e,
      );
    }
    if (e.type == DioExceptionType.unknown) {
      // `unknown` fires on TLS handshake failures, JSON parse errors,
      // SocketException (DNS failure), and anything else Dio cannot
      // pigeon-hole. Previously all of those landed on the "no
      // network" message, which was misleading for a certificate
      // expiry or a malformed response body. Split into a dedicated
      // UnknownFailure so the UI surfaces the inner error instead of
      // wrongly blaming connectivity.
      // Reference: code-review CR-20260419-044.
      // Inner `toString()` can embed the full request URL (Dio
      // ships `requestOptions.uri` inside its exception text on
      // some code paths, and a SocketException.toString() includes
      // the address), which would then propagate into Sentry via
      // the `Failure.cause` chain. Strip any URL-shaped substring
      // and truncate before surfacing.
      // Reference: PR-review (Cluster C follow-up) — mirrors SR-019.
      final inner = e.error;
      final raw =
          inner is Exception || inner is Error
              ? inner.toString()
              : (e.message ?? 'Unknown network error');
      return UnknownFailure(message: _sanitizeUnknownReason(raw), cause: e);
    }
    final status = e.response?.statusCode;
    if (status == 401) {
      // 401 = invalid or expired token. A missing token on a public
      // repo never hits this branch — GitHub answers with a 200 — so
      // this is always actionable for the user (regenerate the PAT
      // and paste it again).
      return AuthFailure(message: 'Invalid or expired GitHub token', cause: e);
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
      // org the token cannot access, etc. Distinct from rate-limit
      // because the user fix is different: update your token, not
      // wait for a quota reset.
      return AuthFailure(
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
