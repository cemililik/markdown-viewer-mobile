/// Builds the sandbox HTML page loaded into the headless WebView.
///
/// ## Why the WebView renders + the native API screenshots — instead
/// of feeding flutter_svg the raw mermaid SVG
///
/// `flutter_svg` is a partial SVG renderer designed for icon-style
/// vectors. Mermaid's output violates three of its hard limitations:
///
/// 1. Mermaid theming lives in `<style>` CSS selectors. `flutter_svg`
///    has no CSS selector engine; every themed rect falls back to
///    default black.
/// 2. Mermaid uses `<foreignObject>` + HTML `<div>` for flowchart /
///    class / state labels. `flutter_svg` drops `foreignObject`
///    entirely, so labels disappear.
/// 3. Mermaid computes text bounding boxes against browser font
///    metrics at authoring time. `flutter_svg` recomputes layout
///    against its own metrics, so even labels that survive end up
///    overflowing or misaligned.
///
/// Every Dart-side workaround attempted (themeVariables, init
/// directive renderer pin, CSS flattener, foreignObject → text
/// conversion) closed one hole and opened another — the third
/// limitation in particular cannot be patched from outside the
/// renderer because the layout is baked into the SVG before
/// flutter_svg ever sees it.
///
/// The strategically-correct path is to stop feeding `flutter_svg`
/// mermaid output at all. The sandbox WebView already has a full
/// browser SVG renderer that handles CSS, foreignObject, fonts, and
/// layout correctly, so we let it render the diagram natively and
/// then capture the result via `WKWebView.takeSnapshot`
/// (`InAppWebViewController.takeScreenshot` on the Flutter side).
///
/// The capture path that this template implements:
///
/// 1. `window.renderMermaid(id, code)` calls `mermaid.render(...)`
///    with the user's source. Mermaid's defaults are kept —
///    `htmlLabels: true`, `useMaxWidth: true` — because the
///    browser will render them correctly anyway.
/// 2. The rendered SVG string is injected into `#sink`, a fixed-
///    width offscreen container at `(0, 0)` of the viewport. The
///    sink's CSS width pins the diagram to a known horizontal
///    footprint, which keeps mermaid's layout deterministic across
///    devices.
/// 3. After two `requestAnimationFrame` ticks (so layout +
///    foreignObject + late style application all settle), JS
///    measures the SVG's bounding rect and posts
///    `{ id, state: 'ready', width, height }` to the
///    `mermaidResult` JS handler.
/// 4. The Dart side intercepts `state: 'ready'` in
///    `HeadlessMermaidJsChannel`, calls
///    `controller.takeScreenshot(rect: …)` with the reported
///    region, and forwards the resulting PNG bytes to
///    `MermaidRendererImpl` as `{id, pngBytes, width, height}`.
///
/// `takeScreenshot` goes through the native WKWebView snapshot
/// API, which has none of the canvas-taint restrictions that
/// blocked the earlier `<canvas>` + `toDataURL` rasterisation
/// attempts on iOS. The rendered SVG appears exactly as the
/// browser painted it.
///
/// ## Sink width — why 900 px
///
/// The sink width determines the horizontal footprint mermaid
/// gets at layout time. Picked so that:
///
/// - Most flowcharts and sequence diagrams fit without horizontal
///   overflow at typical author densities.
/// - The screenshot scales down cleanly to a 360–420 px reading
///   column on the Flutter side via `BoxFit.contain`.
/// - Text inside boxes does not need to wrap aggressively, so
///   mermaid's intrinsic text-width calculations stay readable.
///
/// ## Content Security Policy
///
/// - `default-src 'none'` — nothing else can load by default. On
///   CSP Level 3 clients this also cascades to `img-src` /
///   `font-src` / `connect-src`; Android WebView on API 24–28 is
///   CSP Level 2, so those directives are spelled out below too.
/// - `script-src 'unsafe-inline'` — mermaid's bundled JS plus the
///   inline renderer hook. `'self'` was removed: the document
///   loads from a `data:` URI whose origin is `null`, so `'self'`
///   matches nothing and created a misleading appearance of
///   allow-listing (SR-20260419-038).
/// - `style-src 'unsafe-inline'` — mermaid generates `<style>`
///   blocks at render time.
/// - `img-src 'none'`, `font-src 'none'`, `connect-src 'none'`,
///   `base-uri 'none'`, `form-action 'none'` — spelled out so
///   SVG sub-resources, webfonts, and `fetch()` calls are rejected
///   on every CSP level. Reference: SR-20260419-037.
///
/// The SVG-injection safety (SR-20260419-039) depends on this CSP
/// PLUS `blockNetworkLoads: true` on the `InAppWebViewSettings`.
/// If either invariant is relaxed, `innerHTML = svgString` with
/// `securityLevel: 'antiscript'` is no longer sufficient to
/// neutralise `<img onerror=…>` / `<a href="javascript:…">`
/// attacks — see ADR-0005 §Rendering invariants.
///
/// The renderer hook exposes exactly one entry point —
/// `window.renderMermaid(id, code)` — and posts results back via
/// the single `flutter_inappwebview` handler `mermaidResult`. No
/// other globals leak across the bridge.
String buildMermaidHtml({required String mermaidJs}) {
  return '''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; img-src 'none'; font-src 'none'; connect-src 'none'; base-uri 'none'; form-action 'none'">
<title>mermaid-sandbox</title>
<style>
  html, body {
    margin: 0;
    padding: 0;
    background: transparent;
    /* `color-scheme: only light` pins the HTML rendering to a
       deterministic "light" canvas so WKWebView on iOS does NOT
       auto-invert `foreignObject` content when the user's OS is
       in dark mode. Mermaid draws its `.label` HTML spans inside
       `<foreignObject>`, which browsers can otherwise re-tint
       with system-default colours — the ER attribute rows were
       rendering as black-on-white on a dark-theme reader because
       the HTML content ignored our theme override.
       Our palette is injected via `themeVariables` +
       `themeCSS`, so we control the effective colours ourselves.
       Reference: PR-review (mermaid ER dark-mode follow-up). */
    color-scheme: only light;
  }
  html, body, #sink {
    /* iOS / macOS native UI font for closest visual match to the
       Flutter reading column typography. */
    font-family: -apple-system, BlinkMacSystemFont, "Helvetica Neue",
                 Arial, sans-serif;
  }
  #sink {
    position: absolute;
    left: 0;
    top: 0;
    /* Fixed-width box so mermaid lays out against a deterministic
       horizontal footprint. The native screenshot rect captures
       just this region. */
    width: 900px;
    background: transparent;
  }
  #sink svg {
    display: block;
  }
  /* Neutralise default foreignObject backgrounds. Mermaid ER
     attribute rows render as `<foreignObject>` → `<div>` →
     `<span class="attribute-name">…` etc., and WKWebView paints
     a solid white backplate on every nested `<div>` unless we
     explicitly force transparency here. The underlying SVG
     `<rect>` (entityBox / mainBkg) is already themed via
     `themeVariables`; making the HTML overlay transparent lets
     that background show through. */
  #sink foreignObject,
  #sink foreignObject > *,
  #sink foreignObject div,
  #sink foreignObject span,
  #sink foreignObject p {
    background: transparent !important;
    background-color: transparent !important;
  }
</style>
</head>
<body>
<div id="sink"></div>
<script>
$mermaidJs
</script>
<script>
(function () {
  if (typeof mermaid === 'undefined') {
    window.flutter_inappwebview.callHandler('mermaidResult', {
      id: '__init__',
      error: 'mermaid global is undefined after script load'
    });
    return;
  }
  try {
    // Keep mermaid's defaults — htmlLabels: true, useMaxWidth:
    // true — because the browser will render them faithfully.
    // Init directives the Dart side prepends still apply via
    // `%%{init: …}%%` pragmas in the source.
    mermaid.initialize({
      startOnLoad: false,
      // 'antiscript' strips <script> tags from diagram labels while still
      // allowing HTML labels required by quadrantChart and certain flowchart
      // nodes. 'strict' blocks HTML labels entirely and causes quadrantChart
      // to fail. Since this renderer processes the user's own local files
      // (not untrusted remote content), antiscript is appropriate.
      securityLevel: 'antiscript',
      // 'classic' suppresses the per-diagram-type decorative icons that
      // Mermaid v11 introduced. The mindmap icon in particular renders as
      // a starburst/bomb shape that is confusing and undesirable in both
      // the viewer and PDF output.
      look: 'classic'
    });
  } catch (e) {
    window.flutter_inappwebview.callHandler('mermaidResult', {
      id: '__init__',
      error: 'mermaid.initialize threw: ' + (e && e.message ? e.message : e)
    });
    return;
  }

  function postError(id, message) {
    window.flutter_inappwebview.callHandler('mermaidResult', {
      id: id,
      error: message
    });
  }

  function postReady(id, width, height) {
    window.flutter_inappwebview.callHandler('mermaidResult', {
      id: id,
      state: 'ready',
      width: width,
      height: height
    });
  }

  // Per-render theme stylesheet. The Dart side passes a CSS blob
  // derived from the active ColorScheme; the mermaid init pragma
  // carries `themeVariables` (which mermaid honours) but not
  // `themeCSS` (which the init pragma silently ignores in v11).
  // We keep a stable `<style id="__mermaid_theme__">` node in the
  // document head and rewrite its `textContent` before each render.
  // The selectors in this sheet target the classes mermaid emits
  // regardless of diagram type — `.attribute-*` for ER rows,
  // `.label` for every label-bearing group, `.entityBox` /
  // `.relationshipLine` / `.relationshipLabelBox` for ER chrome.
  // Without this override the ER attribute rows rendered as
  // white-on-mid-grey under dark themes because mermaid's
  // `attributeBackgroundColorOdd/Even` variables are dead code in
  // v11 and the `<foreignObject>` HTML spans inherited the HTML
  // default text colour (black) on a dark SVG background.
  // Reference: PR-review (mermaid dark-mode follow-up).
  window.__setMermaidTheme = function (css) {
    var themeStyle = document.getElementById('__mermaid_theme__');
    if (!themeStyle) {
      themeStyle = document.createElement('style');
      themeStyle.id = '__mermaid_theme__';
      document.head.appendChild(themeStyle);
    }
    themeStyle.textContent = css || '';
  };

  window.renderMermaid = function (id, code, themeCss) {
    var sink = document.getElementById('sink');
    if (!sink) {
      postError(id, 'sink element missing');
      return;
    }
    // Install the per-render theme stylesheet BEFORE we rebuild
    // the SVG, so the first paint already has the right colours.
    // Passing `null` / `undefined` keeps whatever was in place
    // from the previous render (tests that speak the old 2-arg
    // shape).
    if (typeof themeCss === 'string') {
      window.__setMermaidTheme(themeCss);
    }
    // Blank the sink so a previous render does not bleed into
    // the next screenshot while mermaid is parsing the new
    // source.
    sink.innerHTML = '';
    // Remove any stray mermaid-injected elements (error SVGs, temp
    // containers) left in the document by a previous failed render.
    // Mermaid appends these at document.body level; because #sink is
    // positioned at (0,0), a leftover element at the same origin
    // appears inside the screenshot rect and produces bomb icons or
    // "Syntax error" text on top of an otherwise-successful diagram.
    document.querySelectorAll('[id^="mmd-"]').forEach(function(el) {
      el.remove();
    });
    try {
      mermaid.render('mmd-' + id, code).then(function (out) {
        var svgString = out && out.svg ? out.svg : '';
        if (!svgString) {
          postError(id, 'mermaid returned an empty SVG');
          return;
        }
        sink.innerHTML = svgString;
        var svg = sink.querySelector('svg');
        if (!svg) {
          postError(id, 'svg injection produced no root element');
          return;
        }
        // Poll up to 10 animation frames for non-zero dimensions.
        // Complex diagram types (quadrantChart, large flowcharts)
        // can take more than 2 frames before the browser has
        // finished computing their final layout.
        function measureSvg(remaining) {
          var rect;
          try {
            rect = svg.getBoundingClientRect();
          } catch (e) {
            postError(
              id,
              'getBoundingClientRect threw: ' + (e && e.message ? e.message : e)
            );
            return;
          }
          if (rect.width > 0 && rect.height > 0) {
            postReady(id, rect.width, rect.height);
            return;
          }
          if (remaining <= 0) {
            postError(id, 'svg has zero dimensions after layout');
            return;
          }
          requestAnimationFrame(function () { measureSvg(remaining - 1); });
        }
        requestAnimationFrame(function () {
          requestAnimationFrame(function () {
            measureSvg(8);
          });
        });
      }).catch(function (err) {
        postError(id, err && err.message ? err.message : String(err));
      });
    } catch (e) {
      postError(id, e && e.message ? e.message : String(e));
    }
  };
  window.flutter_inappwebview.callHandler('mermaidResult', {
    id: '__ready__'
  });
})();
</script>
</body>
</html>
''';
}
