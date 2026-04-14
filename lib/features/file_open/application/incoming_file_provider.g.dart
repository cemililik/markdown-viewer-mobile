// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'incoming_file_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Absolute filesystem path of a markdown file delivered by the OS
/// via an "Open In" intent (Android) or file URL context (iOS).
///
/// Emits once per file-open event. The consumer — [MarkdownViewerApp]
/// via `ref.listen` — navigates to [ViewerRoute] on each emission.
///
/// `keepAlive: true` so the subscription persists for the lifetime of
/// the app and cold-start events (buffered by the native channel) are
/// not missed between widget rebuilds.

@ProviderFor(incomingFile)
final incomingFileProvider = IncomingFileProvider._();

/// Absolute filesystem path of a markdown file delivered by the OS
/// via an "Open In" intent (Android) or file URL context (iOS).
///
/// Emits once per file-open event. The consumer — [MarkdownViewerApp]
/// via `ref.listen` — navigates to [ViewerRoute] on each emission.
///
/// `keepAlive: true` so the subscription persists for the lifetime of
/// the app and cold-start events (buffered by the native channel) are
/// not missed between widget rebuilds.

final class IncomingFileProvider
    extends $FunctionalProvider<AsyncValue<String>, String, Stream<String>>
    with $FutureModifier<String>, $StreamProvider<String> {
  /// Absolute filesystem path of a markdown file delivered by the OS
  /// via an "Open In" intent (Android) or file URL context (iOS).
  ///
  /// Emits once per file-open event. The consumer — [MarkdownViewerApp]
  /// via `ref.listen` — navigates to [ViewerRoute] on each emission.
  ///
  /// `keepAlive: true` so the subscription persists for the lifetime of
  /// the app and cold-start events (buffered by the native channel) are
  /// not missed between widget rebuilds.
  IncomingFileProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'incomingFileProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$incomingFileHash();

  @$internal
  @override
  $StreamProviderElement<String> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<String> create(Ref ref) {
    return incomingFile(ref);
  }
}

String _$incomingFileHash() => r'afa942cfbc4a3e7d8cd4bdef594b264ddf0b0d32';
