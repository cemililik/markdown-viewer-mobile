import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:markdown_viewer/core/l10n/build_context_l10n.dart';
import 'package:markdown_viewer/core/widgets/error_view.dart';
import 'package:markdown_viewer/features/library/library.dart';
import 'package:markdown_viewer/features/repo_sync/presentation/screens/repo_sync_screen.dart';
import 'package:markdown_viewer/features/settings/presentation/screens/settings_screen.dart';
import 'package:markdown_viewer/features/viewer/viewer.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'router.g.dart';

@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  return GoRouter(
    initialLocation: LibraryRoute.path,
    routes: [
      GoRoute(
        path: LibraryRoute.path,
        name: LibraryRoute.name,
        builder: (context, state) => const LibraryScreen(),
      ),
      GoRoute(
        path: ViewerRoute.path,
        name: ViewerRoute.name,
        builder: (context, state) {
          final rawPath = state.uri.queryParameters[ViewerRoute.pathQuery];
          if (rawPath == null || rawPath.isEmpty) {
            return Scaffold(
              appBar: AppBar(),
              body: ErrorView(message: context.l10n.libraryFilePickFailed),
            );
          }
          return ViewerScreen(documentId: DocumentId(rawPath));
        },
      ),
      GoRoute(
        path: SettingsRoute.path,
        name: SettingsRoute.name,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: RepoSyncRoute.path,
        name: RepoSyncRoute.name,
        builder: (context, state) {
          final initialUrl = state.uri.queryParameters[RepoSyncRoute.urlQuery];
          return RepoSyncScreen(initialUrl: initialUrl);
        },
      ),
    ],
  );
}

abstract final class LibraryRoute {
  static const String path = '/';
  static const String name = 'library';

  /// Canonical location of the library screen, used by navigation
  /// fall-throughs (e.g. [ViewerScreen]'s back button when the stack
  /// is empty) so deep-linked routes still have a way home.
  static String location() => path;
}

abstract final class SettingsRoute {
  static const String path = '/settings';
  static const String name = 'settings';

  static String location() => path;
}

/// Route for the repository sync screen.
///
/// The optional [urlQuery] query parameter (`'url'`) pre-populates the
/// repository URL field when the screen opens. The value is
/// percent-encoded via [Uri.encodeQueryComponent] so it survives
/// deep-link serialisation and round-trips through [GoRouter].
///
/// Usage:
/// ```dart
/// // Navigate with a pre-filled URL:
/// context.push(RepoSyncRoute.location(url: 'https://github.com/owner/repo'));
/// // Navigate without a pre-filled URL:
/// context.push(RepoSyncRoute.location());
/// ```
abstract final class RepoSyncRoute {
  static const String path = '/repo-sync';
  static const String name = 'repoSync';

  /// Query parameter carrying the pre-populated repository URL.
  static const String urlQuery = 'url';

  /// Builds the full `/repo-sync` location string.
  ///
  /// Returns [path] directly when [url] is null, empty, or blank.
  /// Otherwise appends the percent-encoded [url] as the [urlQuery] parameter.
  static String location({String? url}) {
    final trimmed = url?.trim();
    if (trimmed == null || trimmed.isEmpty) return path;
    return '$path?$urlQuery=${Uri.encodeQueryComponent(trimmed)}';
  }
}

/// Route for [ViewerScreen]. The document path is passed as a query
/// parameter so it survives deep-link serialisation (share intents,
/// Android file handlers) and round-trips through [GoRouter].
abstract final class ViewerRoute {
  static const String path = '/viewer';
  static const String name = 'viewer';

  /// Query parameter name carrying the absolute file path to open.
  static const String pathQuery = 'path';

  /// Builds the full `/viewer?path=<encoded>` location for navigation.
  static String location(String filePath) {
    final encoded = Uri.encodeQueryComponent(filePath);
    return '$path?$pathQuery=$encoded';
  }
}
