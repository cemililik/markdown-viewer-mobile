import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'incoming_file_provider.g.dart';

/// Absolute filesystem path of a markdown file delivered by the OS
/// via an "Open In" intent (Android) or file URL context (iOS).
///
/// Emits once per file-open event. The consumer — [MarkdownViewerApp]
/// via `ref.listen` — navigates to [ViewerRoute] on each emission.
///
/// `keepAlive: true` so the subscription persists for the lifetime of
/// the app and cold-start events (buffered by the native channel) are
/// not missed between widget rebuilds.
///
/// ### Filter contract
///
/// - Non-string payloads are silently dropped (`where((e) => e is String)`).
/// - Empty / whitespace-only paths are dropped — a provider that fires
///   a blank is always a bug on the native side; surfacing it as an
///   error would bounce the viewer through the error screen for a
///   degenerate payload. (Reference: security-review SR-20260419-035.)
/// - Typed errors from the native side (e.g. `FILE_TOO_LARGE`) arrive
///   as `PlatformException` and propagate as stream errors so
///   [MarkdownViewerApp] can surface a localised snackbar. (Reference:
///   code-review CR-20260419-034.)
@Riverpod(keepAlive: true)
Stream<String> incomingFile(Ref ref) {
  const channel = EventChannel('com.cemililik.markdown_viewer/file_open');
  return channel
      .receiveBroadcastStream()
      .where((e) => e is String)
      .cast<String>()
      .where((p) => p.trim().isNotEmpty);
}
