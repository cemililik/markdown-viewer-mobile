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
  // Bridge between Riverpod state changes and GoRouter's redirect
  // re-evaluation. Using `ref.watch(shouldShowOnboardingProvider)` here
  // would rebuild (and therefore dispose) the entire GoRouter every
  // time the onboarding flow transitions — `OnboardingController.markSeen`
  // flipping `seen` past [currentOnboardingVersion] triggers the
  // provider invalidation, Riverpod fires the `ref.onDispose`
  // callback below, and `GoRouter.dispose` then calls
  // `GoRouteInformationProvider.dispose` while the very navigation
  // that finished onboarding is still propagating through that
  // ChangeNotifier's `notifyListeners`. Flutter asserts on
  // `_notificationCallStackDepth == 0` during a dispose → crash on
  // every "Get started" tap.
  //
  // A `refreshListenable` sidesteps the rebuild: the GoRouter
  // instance stays alive for the whole app lifetime, and we only
  // nudge it to re-run the redirect guard whenever the onboarding
  // seen-version flips.
  final refresh = _RouterRefresh();
  ref.listen<bool>(shouldShowOnboardingProvider, (_, __) => refresh.refresh());
  final router = GoRouter(
    initialLocation: LibraryRoute.path,
    refreshListenable: refresh,
    // Sentry screen-name tracking — records route transitions as
    // breadcrumbs and performance spans when Sentry is active.
    // No-op when Sentry is dormant (no DSN or no consent).
    observers: [
      SentryNavigatorObserver(
        // Redact route arguments from Sentry breadcrumbs and spans.
        // ViewerRoute passes absolute file paths as arguments — these
        // are PII under ADR-0014's security rules. When `settings` is
        // null (cold-start pop to root) we still emit a "/" breadcrumb
        // instead of `null`, otherwise the very first screen the user
        // lands on is invisible in the navigation history.
        routeNameExtractor:
            (settings) => RouteSettings(name: settings?.name ?? '/'),
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
          final initialAnchor =
              state.uri.queryParameters[ViewerRoute.anchorQuery];
          return ViewerScreen(
            documentId: DocumentId(rawPath),
            initialAnchor: initialAnchor,
          );
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
      GoRoute(
        path: DiagramRoute.path,
        name: DiagramRoute.name,
        builder: (context, state) {
          final args = state.extra;
          if (args is! DiagramFullscreenArgs) {
            // Unknown / missing payload should never happen under the
            // current call sites (only `MermaidBlock` pushes this
            // route) — but if a future deep-linker lands here without
            // a payload, pop back to the library rather than crash.
            return Scaffold(
              appBar: AppBar(),
              body: ErrorView(message: context.l10n.errorUnknown),
            );
          }
          return DiagramFullscreenScreen(args: args);
        },
      ),
    ],
  );
  // Wire `GoRouter.dispose` into the provider lifecycle so the delegate
  // and information provider release their listeners when the
  // ProviderScope tears down (app shutdown, or a fresh container in
  // tests). Without this hop the router internals would only be GC'd
  // by reachability, leaving subscriptions behind that surface as
  // leak_tracker `notDisposed` failures in widget tests.
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
}

/// Tiny [ChangeNotifier] used as the router's `refreshListenable`.
///
/// Kept private to this library and exposed only via
/// [GoRouter.refreshListenable]. Wiring a ChangeNotifier (instead of
/// the cheaper `Listenable.merge`) here gives us a stable handle
/// whose `dispose()` can be paired with `ref.onDispose` for leak
/// hygiene in tests.
class _RouterRefresh extends ChangeNotifier {
  void refresh() => notifyListeners();
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

  /// Query parameter name carrying an optional anchor slug (without
  /// the leading `#`). A cross-file link of the form
  /// `[label](other.md#section)` can arrive here through
  /// [resolveRelativeDocument]; the viewer reads this parameter on
  /// first build and scrolls to the matching heading once the target
  /// document has parsed.
  static const String anchorQuery = 'anchor';

  /// Builds the full `/viewer?path=<encoded>` location for navigation.
  /// Pass [anchor] when forwarding a cross-file anchor (`other.md#sec`)
  /// so the destination viewer lands on the heading rather than the
  /// top of the file.
  static String location(String filePath, {String? anchor}) {
    final encodedPath = Uri.encodeQueryComponent(filePath);
    if (anchor == null || anchor.isEmpty) {
      return '$path?$pathQuery=$encodedPath';
    }
    final encodedAnchor = Uri.encodeQueryComponent(anchor);
    return '$path?$pathQuery=$encodedPath&$anchorQuery=$encodedAnchor';
  }
}

/// Route for the Mermaid diagram fullscreen viewer.
///
/// Unlike every other route declared here this one is **never** deep-
/// linkable: the payload is a raw [DiagramFullscreenArgs] containing
/// raster bytes + dimensions handed over [GoRouter]'s `extra`
/// channel. The inline `MermaidBlock` pushes it via
/// `context.push(DiagramRoute.path, extra: args)` after the WebView
/// has produced a PNG, so the fullscreen screen reuses the already-
/// rendered bitmap rather than re-running the sandboxed render. A
/// cold load via URL has no payload available and intentionally
/// bounces to the library error view — the route only exists as a
/// lane for in-app push/pop navigation.
abstract final class DiagramRoute {
  static const String path = '/diagram';
  static const String name = 'diagram';

  static String location() => path;
}
