import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown_viewer/core/logging/logger.dart';

/// Fire-and-forget tail for a background write whose failure should
/// still leave a trail.
///
/// Replaces bare `.ignore()` on prefs / disk writes: `.ignore()` drops
/// the error entirely, so a full disk or an OS permission flip never
/// surfaces anywhere. This helper keeps the same non-blocking shape
/// (the returned `Future` is already dropped) but pipes any error
/// through [appLoggerProvider] so an engineer debugging a "setting
/// didn't stick" report has something to go on.
///
/// The `ref.read(appLoggerProvider)` call is itself guarded: a
/// provider container that has been torn down (tests exiting mid-
/// write, hot-restart during a pending persist) throws on `read`,
/// and without the catch the nested throw would be swallowed by the
/// outer `.ignore()` and the original persistence failure would also
/// vanish.
///
/// Use this at any disk / network write site where blocking the
/// caller is wrong (e.g. UI event handlers) but silently losing the
/// failure is equally wrong.
void dropWithLog(Ref ref, Future<void> future, String context) {
  future.onError((error, stackTrace) {
    try {
      ref
          .read(appLoggerProvider)
          .e(
            'Failed background write: $context',
            error: error,
            stackTrace: stackTrace,
          );
    } catch (_) {
      // Last-resort swallow — the container is gone and the original
      // error is already lost. Nothing useful can be done here.
    }
  }).ignore();
}
