import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown_viewer/features/viewer/domain/repositories/reading_position_store.dart';

/// Application-layer binding for the [ReadingPositionStore] port.
///
/// Mirrors `documentRepositoryProvider` and `settingsStoreProvider`:
/// the application layer declares the port, the composition root
/// in `lib/main.dart` overrides it with a concrete
/// `ReadingPositionStoreImpl` built from the preloaded
/// `SharedPreferences` instance, and tests override it with a
/// fake. The default build throws so a missing override fails
/// loudly instead of silently dropping every bookmark.
final readingPositionStoreProvider = Provider<ReadingPositionStore>((ref) {
  throw UnimplementedError(
    'readingPositionStoreProvider must be overridden in the composition '
    'root (lib/main.dart) after `SharedPreferences.getInstance()` '
    'completes, or in tests with a fake-backed ReadingPositionStore.',
  );
});
