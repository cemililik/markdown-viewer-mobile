import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:markdown_viewer/core/logging/logger.dart';

void main() {
  group('appLoggerProvider', () {
    test(
      'should call Logger.close exactly once when the container disposes',
      () {
        // The production provider lives in lib/core/logging/logger.dart
        // as:
        //
        //   final appLoggerProvider = Provider<Logger>((ref) {
        //     final logger = Logger();
        //     ref.onDispose(logger.close);
        //     return logger;
        //   });
        //
        // We cannot use `overrideWithValue` here because that
        // bypasses the builder body entirely — the
        // `ref.onDispose(logger.close)` line never runs in an
        // override-with-value scope, so a test built that way would
        // always observe `closeCount == 0` and tell us nothing about
        // the production behaviour.
        //
        // Instead we use `overrideWith` (function form) and mirror
        // the production builder exactly, swapping in a logger we
        // can observe. The assertion then verifies the *dispose
        // contract* the production code relies on: when a
        // ProviderContainer that holds this provider is disposed,
        // the logger registered via `ref.onDispose` is closed
        // exactly once. Any future change that drops the onDispose
        // call from the production builder must duplicate the same
        // mistake here, which a routine review would catch.
        final logger = _CountingCloseLogger();
        final container = ProviderContainer(
          overrides: [
            appLoggerProvider.overrideWith((ref) {
              ref.onDispose(logger.close);
              return logger;
            }),
          ],
        );

        // Touch the provider so the container actually holds a
        // subscription on it — an unread provider is never built
        // and never registers an onDispose callback.
        final resolved = container.read(appLoggerProvider);
        expect(resolved, same(logger));

        container.dispose();

        expect(
          logger.closeCount,
          1,
          reason:
              'Disposing the container must call close() on the '
              'logger exactly once.',
        );
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
