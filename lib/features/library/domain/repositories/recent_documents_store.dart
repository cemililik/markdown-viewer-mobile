import 'package:markdown_viewer/features/library/domain/entities/recent_document.dart';

/// Port for persisting the "recently opened documents" list shown
/// on the library home screen.
///
/// Mirrors the shape used by `SettingsStore` and
/// `ReadingPositionStore`:
///
/// - [read] is **synchronous** against an already-loaded
///   `SharedPreferences` instance so the controller can seed its
///   initial state on the very first frame without an async hop
///   that would cause an empty-then-populated flash.
/// - [write] is asynchronous; production callers fire-and-forget
///   so taps stay responsive.
///
/// Implementations are responsible for ordering the returned list
/// (most recent first) and for capping the length — the
/// application-layer controller assumes the data layer has
/// already done both.
abstract interface class RecentDocumentsStore {
  /// Returns the persisted list, most-recent-first, or an empty
  /// list when the user has never opened a document.
  List<RecentDocument> read();

  /// Persists [documents]. Returns the underlying write [Future]
  /// so callers can `ignore()` it for fire-and-forget UX or
  /// `await` it in tests.
  Future<void> write(List<RecentDocument> documents);
}
