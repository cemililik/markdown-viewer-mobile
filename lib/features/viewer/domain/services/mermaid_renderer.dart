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
  /// Returning normally means the renderer is ready. Throwing means
  /// it is permanently unusable; the composition root catches the
  /// error and substitutes a fallback that returns
  /// [MermaidRenderFailure] for every subsequent [render] call so
  /// the rest of the document still loads.
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

/// Successful render — [svg] is a self-contained SVG document
/// suitable for `flutter_svg`'s `SvgPicture.string` constructor.
final class MermaidRenderSuccess extends MermaidRenderResult {
  const MermaidRenderSuccess(this.svg);

  final String svg;
}

/// Failed render — [message] is a renderer-supplied diagnostic
/// (typically the mermaid parse error). The presentation layer is
/// free to show or hide it; the canonical error UI shows a generic
/// localized title and uses [message] only as a debug-mode tooltip.
final class MermaidRenderFailure extends MermaidRenderResult {
  const MermaidRenderFailure(this.message);

  final String message;
}
