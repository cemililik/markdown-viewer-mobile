import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:markdown_viewer/core/l10n/build_context_l10n.dart';
import 'package:markdown_viewer/core/widgets/error_view.dart';
import 'package:markdown_viewer/features/library/library.dart';
import 'package:markdown_viewer/features/onboarding/application/onboarding_providers.dart';
import 'package:markdown_viewer/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:markdown_viewer/features/repo_sync/presentation/screens/repo_sync_screen.dart';
import 'package:markdown_viewer/features/settings/presentation/screens/settings_screen.dart';
import 'package:markdown_viewer/features/viewer/viewer.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

part 'router.g.dart';

@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  // Watch so the router provider rebuilds (and re-evaluates redirects) when
  // the onboarding state changes at runtime — e.g. a debug reset from the
  // settings screen via OnboardingController.reset().
  ref.watch(shouldShowOnboardingProvider);
  return GoRouter(
    initialLocation: LibraryRoute.path,
    // Sentry screen-name tracking — records route transitions as
    // breadcrumbs and performance spans when Sentry is active.
    // No-op when Sentry is dormant (no DSN or no consent).
    observers: [
      SentryNavigatorObserver(
        // Redact route arguments from Sentry breadcrumbs and spans.
        // ViewerRoute passes absolute file paths as arguments — these
        // are PII under ADR-0014's security rules.
        routeNameExtractor:
            (settings) =>
                settings == null ? null : RouteSettings(name: settings.name),
      ),
    ],
    // Global redirect guards the onboarding flow. On every navigation
    // event the router reads [shouldShowOnboardingProvider] (a cheap,
    // sync-backed Riverpod read against the preloaded preferences):
    //
    // - Fresh install or post-update version bump → push the user
    //   into [OnboardingRoute] no matter what destination they
    //   requested. Deep links into the viewer still land on
    //   onboarding first, and the library navigation is never
    //   exposed before the user acknowledges the flow.
    // - Already-seen user attempting to visit /onboarding directly
    //   (e.g. from a stale deep link) → bounce them back to the
    //   library so the flow is not re-enterable.
    //
    // The redirect must return `null` when no change is required,
    // otherwise go_router enters a redirect loop.
    redirect: (context, state) {
      final shouldShow = ref.read(shouldShowOnboardingProvider);
      final goingToOnboarding = state.matchedLocation == OnboardingRoute.path;
      if (shouldShow && !goingToOnboarding) return OnboardingRoute.path;
      if (!shouldShow && goingToOnboarding) return LibraryRoute.path;
      return null;
    },
    routes: [
      GoRoute(
        path: OnboardingRoute.path,
        name: OnboardingRoute.name,
        builder: (context, state) => const OnboardingScreen(),
      ),
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

/// Route for the first-run / post-update onboarding flow.
///
/// Not meant to be navigated to explicitly — the router redirect
/// takes any incoming request and sends it here when
/// [shouldShowOnboardingProvider] reports `true`. Callers inside
/// the onboarding screen finish the flow by calling
/// `context.go(LibraryRoute.location())`, which triggers the
/// redirect to re-evaluate against the now-updated state.
abstract final class OnboardingRoute {
  static const String path = '/onboarding';
  static const String name = 'onboarding';

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
