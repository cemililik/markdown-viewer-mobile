import 'dart:typed_data';

/// Port for rendering a mermaid diagram source string into an SVG.
///
/// Lives in the domain layer so the application and presentation
/// layers can depend on an abstraction without ever seeing the
/// concrete WebView-backed implementation. The implementation lives
/// in `lib/features/viewer/data/services/mermaid/`.
///
/// Implementations must:
///
/// 1. Treat `(source, initDirective)` as the cache key — identical
///    pairs must return identical SVG.
/// 2. Catch every error path that comes out of the underlying
///    renderer (mermaid syntax errors, WebView crashes, JS
///    exceptions, asset-load failures) and translate it into a
///    [MermaidRenderFailure]. Callers must never see a raw
///    exception.
/// 3. Be safe to call from the UI thread without blocking — the
///    returned [Future] may be backed by an off-thread WebView eval
///    or a cache lookup.
abstract interface class MermaidRenderer {
  /// Initialises the renderer (loads mermaid.min.js into a sandboxed
  /// WebView, runs the first warm-up render, etc.). Calling [render]
  /// before [prewarm] completes is allowed — the implementation must
  /// queue the request behind initialisation rather than failing.
  ///
  /// **Resilient by contract: this never throws.** A failed
  /// initialisation (missing asset, WebView platform binding
  /// unavailable, mermaid global not present after script load,
  /// …) flips the renderer into a permanent-failure state where
  /// every subsequent [render] call returns a
  /// [MermaidRenderFailure] with the original cause. The rest of
  /// the document keeps loading and the user sees the inline
  /// "diagram could not be rendered" placeholder instead of a
  /// crashed app.
  ///
  /// Calling [prewarm] more than once is a no-op once the
  /// renderer has either initialised successfully or recorded a
  /// permanent failure.
  Future<void> prewarm();

  /// Renders [source] and returns either an SVG string or a typed
  /// failure.
  ///
  /// [initDirective] is an opaque prefix that the implementation
  /// prepends to [source] before handing it to the underlying
  /// renderer. Callers use it to thread Flutter-derived theming
  /// (a `%%{init: {"theme":"base","themeVariables":{…}}}%%`
  /// directive built from the active `ColorScheme`) without
  /// leaking Flutter types into the domain layer. Distinct
  /// directives produce distinct cache keys so a single source
  /// can coexist in the cache in light and dark variants.
  ///
  /// An empty [initDirective] means "do not prepend anything" —
  /// used when the user's source already carries its own init
  /// directive that must be respected.
  Future<MermaidRenderResult> render(
    String source, {
    String initDirective = '',
  });

  /// Releases any resources held by the renderer. Called by the
  /// composition root when the [ProviderContainer] disposes.
  Future<void> dispose();
}

/// Sealed result of a single [MermaidRenderer.render] call.
sealed class MermaidRenderResult {
  const MermaidRenderResult();
}

/// Successful render — the implementation has rasterised the
/// mermaid SVG into a PNG bitmap inside its sandboxed WebView and
/// is handing us the bytes along with the natural pixel dimensions
/// the presentation layer needs to size an [AspectRatio].
///
/// Rasterisation happens in the WebView (not on the Dart side)
/// because `flutter_svg` cannot render mermaid's output
/// faithfully: it has no CSS selector engine, no `<foreignObject>`
/// support, and no access to mermaid's layout-time font metrics.
/// Shipping pixels instead of SVG sidesteps every one of those
/// limitations and keeps the mermaid feature surface complete
/// across flowchart / sequence / class / state / gantt / ER /
/// mindmap / timeline / git diagram types.
final class MermaidRenderSuccess extends MermaidRenderResult {
  const MermaidRenderSuccess({
    required this.pngBytes,
    required this.width,
    required this.height,
  });

  /// PNG byte stream, ready to hand to `Image.memory`.
  final Uint8List pngBytes;

  /// Natural pixel width of the rasterised diagram in CSS pixels
  /// (the WebView may have rendered at a higher physical multiplier
  /// for crispness). Used by the presentation layer to drive an
  /// `AspectRatio` parent.
  final double width;

  /// Natural pixel height; see [width].
  final double height;
}

/// Failed render — [message] is a renderer-supplied diagnostic
/// (typically the mermaid parse error). The presentation layer is
/// free to show or hide it; the canonical error UI shows a generic
/// localized title and uses [message] only as a debug-mode tooltip.
final class MermaidRenderFailure extends MermaidRenderResult {
  const MermaidRenderFailure(this.message);

  final String message;
}
