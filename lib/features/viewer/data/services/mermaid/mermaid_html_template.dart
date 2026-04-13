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
/// - `default-src 'none'` — nothing else can load by default.
/// - `script-src 'unsafe-inline' 'self'` — mermaid's bundled JS
///   plus the inline renderer hook.
/// - `style-src 'unsafe-inline'` — mermaid generates `<style>`
///   blocks at render time; without this they are blocked.
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
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'unsafe-inline' 'self'; style-src 'unsafe-inline'">
<title>mermaid-sandbox</title>
<style>
  html, body {
    margin: 0;
    padding: 0;
    background: transparent;
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
      securityLevel: 'strict'
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

  window.renderMermaid = function (id, code) {
    var sink = document.getElementById('sink');
    if (!sink) {
      postError(id, 'sink element missing');
      return;
    }
    // Blank the sink so a previous render does not bleed into
    // the next screenshot while mermaid is parsing the new
    // source.
    sink.innerHTML = '';
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
        // Two paint ticks: one for the browser to lay out the
        // newly-injected SVG, a second so any late style
        // application or foreignObject metric calculation also
        // settles before we measure.
        requestAnimationFrame(function () {
          requestAnimationFrame(function () {
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
            if (rect.width <= 0 || rect.height <= 0) {
              postError(id, 'svg has zero dimensions after layout');
              return;
            }
            postReady(id, rect.width, rect.height);
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
