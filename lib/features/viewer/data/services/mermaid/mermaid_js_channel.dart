/// Thin port over the WebView mermaid bridge.
///
/// Exists so [MermaidRendererImpl] can be unit-tested without
/// instantiating a real `flutter_inappwebview` (which needs a
/// platform binding and an actual native view). Tests substitute a
/// fake channel that completes results synchronously; production
/// uses [HeadlessMermaidJsChannel].
abstract interface class MermaidJsChannel {
  /// Loads the sandbox HTML page and registers [onResult] as the
  /// single bridge endpoint. Completes when the page reports
  /// `id == '__ready__'` (the initialise-success handshake from
  /// `mermaid_html_template.dart`).
  ///
  /// Throws a [MermaidJsChannelException] if the page reports
  /// `__init__` with an error or fails to load.
  Future<void> initialize({
    required String html,
    required void Function(Map<String, Object?> message) onResult,
  });

  /// Invokes `window.renderMermaid(id, source)` inside the loaded
  /// page. The result will arrive asynchronously via the
  /// `onResult` callback registered in [initialize], tagged with
  /// the same [id] that was passed in.
  Future<void> render({required String id, required String source});

  /// Releases the underlying WebView. Safe to call multiple times.
  Future<void> dispose();
}

/// Thrown by [MermaidJsChannel.initialize] when the sandbox HTML
/// fails to come up (mermaid global missing, initialise error,
/// page never reached the ready handshake within the timeout).
class MermaidJsChannelException implements Exception {
  const MermaidJsChannelException(this.message);

  final String message;

  @override
  String toString() => 'MermaidJsChannelException: $message';
}
