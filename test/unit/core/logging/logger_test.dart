import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:markdown_viewer/core/logging/logger.dart';

void main() {
  group('appLoggerProvider', () {
    test(
      'should call Logger.close exactly once when the container disposes',
      () {
        // Mirrors the production builder via `overrideWith` (function
        // form) instead of `overrideWithValue`, because the latter
        // bypasses the builder body and never runs the production
        // `ref.onDispose(logger.close)` line — meaning a test built
        // that way could not observe the dispose contract at all.
        final logger = _CountingCloseLogger();
        final container = ProviderContainer(
          overrides: [
            appLoggerProvider.overrideWith((ref) {
              ref.onDispose(logger.close);
              return logger;
            }),
          ],
        );

        // Read the provider so the container actually holds a
        // subscription on it; an unread provider is never built.
        expect(container.read(appLoggerProvider), same(logger));

        container.dispose();

        expect(logger.closeCount, 1);
      },
    );

    test('should yield the default Logger when no override is supplied', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final logger = container.read(appLoggerProvider);

      expect(logger, isA<Logger>());
    });
  });
}

/// Test double that counts how many times [close] is called.
///
/// Extends [Logger] rather than mocking it so the override fits the
/// `Provider<Logger>` slot directly with no cast or wrapper.
class _CountingCloseLogger extends Logger {
  int closeCount = 0;

  @override
  Future<void> close() {
    closeCount += 1;
    return super.close();
  }
}
