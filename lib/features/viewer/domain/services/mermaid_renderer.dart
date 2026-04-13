/// Port for rendering a mermaid diagram source string into an SVG.
///
/// Lives in the domain layer so the application and presentation
/// layers can depend on an abstraction without ever seeing the
/// concrete WebView-backed implementation. The implementation lives
/// in `lib/features/viewer/data/services/mermaid/`.
///
/// Implementations must:
///
/// 1. Treat [render] as a pure function of [source] — identical
///    sources must return identical SVG.
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

  /// Renders [source] under [theme] and returns either an SVG string
  /// or a typed failure. Identical `(source, theme)` pairs should
  /// hit a cache instead of re-running the underlying renderer, but
  /// the same source under different themes must NOT collide —
  /// light and dark variants are distinct renders with distinct
  /// SVG output.
  Future<MermaidRenderResult> render(
    String source, {
    MermaidDiagramTheme theme = MermaidDiagramTheme.defaultTheme,
  });

  /// Releases any resources held by the renderer. Called by the
  /// composition root when the [ProviderContainer] disposes.
  Future<void> dispose();
}

/// Which mermaid theme to render with. Maps directly to the
/// `%%{init: {'theme':'<name>'}}%%` directive that mermaid parses
/// at the top of any diagram source, so the dart side can flip
/// palettes without calling `mermaid.initialize` again in the
/// sandboxed WebView.
///
/// Only two values: `defaultTheme` covers Flutter light mode
/// (mermaid's default white-background palette) and `dark` covers
/// Flutter dark mode (mermaid's "dark" preset, high-contrast
/// strokes on transparent background).
enum MermaidDiagramTheme {
  defaultTheme('default'),
  dark('dark');

  const MermaidDiagramTheme(this.directiveName);

  /// Name used in the `%%{init: {'theme':'<name>'}}%%` directive.
  final String directiveName;
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
