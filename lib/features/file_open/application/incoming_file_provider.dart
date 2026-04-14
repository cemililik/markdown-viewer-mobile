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
@Riverpod(keepAlive: true)
Stream<String> incomingFile(Ref ref) {
  const channel = EventChannel('com.cemililik.markdown_viewer/file_open');
  return channel
      .receiveBroadcastStream()
      .where((e) => e is String)
      .cast<String>();
}
