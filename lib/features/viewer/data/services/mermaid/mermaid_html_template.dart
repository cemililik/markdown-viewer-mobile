/// Builds the sandbox HTML page loaded into the headless WebView.
///
/// The page is loaded as a data URI (no file:// or http:// origin)
/// so the WebView's `blockNetworkLoads`, `allowFileAccess: false`
/// and CSP meta tag together pin the runtime to "execute the
/// inlined mermaid bundle and nothing else". The CSP rules match
/// `docs/standards/security-standards.md` §WebView Rules:
///
///   default-src 'none'; script-src 'unsafe-inline' 'self'
///
/// `'unsafe-inline'` is required because the renderer hook is an
/// inline `<script>` block; `'self'` is required so the browser
/// allows the inlined `mermaid.min.js` body that we paste into the
/// page itself.
///
/// The renderer hook exposes exactly one entry point —
/// `window.renderMermaid(id, code)` — and posts results back via
/// the single `flutter_inappwebview` handler `mermaidResult`. No
/// other globals leak across the bridge.
///
/// Before posting, `renderMermaid` runs the returned SVG through
/// `flattenSvgStyles` — see the JS block below for the rationale.
/// In short: mermaid emits `fill` / `stroke` / `font-*` declarations
/// inside a `<style>` block with class-scoped selectors, and
/// `flutter_svg` does not support `<style>` CSS selectors. Without
/// flattening, every rect falls back to default black and the
/// diagram is unreadable. Flattening resolves the computed style
/// against the WebView's real CSS engine and rewrites every
/// element with equivalent inline attributes so `flutter_svg` can
/// render the diagram faithfully.
String buildMermaidHtml({required String mermaidJs}) {
  return '''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'unsafe-inline' 'self'">
<title>mermaid-sandbox</title>
<style>
  html, body { margin: 0; padding: 0; background: transparent; }
  #sink { position: absolute; left: -10000px; top: -10000px; }
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
    mermaid.initialize({ startOnLoad: false, securityLevel: 'strict' });
  } catch (e) {
    window.flutter_inappwebview.callHandler('mermaidResult', {
      id: '__init__',
      error: 'mermaid.initialize threw: ' + (e && e.message ? e.message : e)
    });
    return;
  }

  // Walk the rendered SVG and inline every computed style the
  // flutter_svg renderer can understand, then drop the source
  // `<style>` blocks. `flutter_svg` has no support for `<style>`
  // CSS selectors, so without this the `fill` / `stroke` /
  // `font-*` declarations mermaid stamps on
  // `#mermaid-N .node rect { ... }` selectors never reach the
  // paint — every rect falls back to default black and the
  // diagram is unreadable. `getComputedStyle` runs inside the
  // WebView's real CSS engine, so it resolves inheritance, CSS
  // specificity, and `!important` correctly.
  var FLAT_PROPS = [
    'fill', 'fill-opacity', 'fill-rule',
    'stroke', 'stroke-width', 'stroke-opacity',
    'stroke-dasharray', 'stroke-linecap', 'stroke-linejoin',
    'font-family', 'font-size', 'font-weight', 'font-style',
    'text-anchor', 'dominant-baseline', 'opacity'
  ];
  function flattenSvgStyles(svgString) {
    var host = document.createElement('div');
    host.style.position = 'absolute';
    host.style.left = '-10000px';
    host.style.top = '-10000px';
    host.innerHTML = svgString;
    document.body.appendChild(host);
    try {
      var root = host.querySelector('svg');
      if (!root) {
        return svgString;
      }
      // Keep the original viewBox / width / height so AspectRatio
      // in the Flutter side still lines up.
      var walker = [root];
      while (walker.length > 0) {
        var node = walker.pop();
        if (node.nodeType !== 1) continue;
        var cs = window.getComputedStyle(node);
        for (var i = 0; i < FLAT_PROPS.length; i++) {
          var prop = FLAT_PROPS[i];
          var value = cs.getPropertyValue(prop);
          if (!value) continue;
          value = value.trim();
          if (value === '' || value === 'auto') continue;
          // Do not overwrite an already-explicit attribute —
          // `fill="url(#grad)"` or similar from mermaid must
          // survive unchanged.
          if (node.hasAttribute(prop)) continue;
          node.setAttribute(prop, value);
        }
        // `text` and `tspan` elements often rely on inherited
        // `color` rather than `fill`; set `fill` explicitly so
        // flutter_svg picks the right text colour.
        var tag = node.tagName && node.tagName.toLowerCase();
        if ((tag === 'text' || tag === 'tspan') && !node.hasAttribute('fill')) {
          var textFill = cs.getPropertyValue('fill') || cs.getPropertyValue('color');
          if (textFill) {
            node.setAttribute('fill', textFill.trim());
          }
        }
        var children = node.children;
        for (var j = 0; j < children.length; j++) {
          walker.push(children[j]);
        }
      }
      // Remove `<style>` blocks — their contents are now inlined
      // as presentation attributes, and leaving them around just
      // confuses `flutter_svg`'s CSS-ignorant parser.
      var styles = root.querySelectorAll('style');
      for (var k = 0; k < styles.length; k++) {
        styles[k].parentNode.removeChild(styles[k]);
      }
      return new XMLSerializer().serializeToString(root);
    } catch (e) {
      // Flattening is a best-effort pass — if anything goes wrong
      // (obscure SVG shape, serializer failure), fall back to the
      // original SVG so the user at least sees mermaid's own
      // output instead of a crash.
      return svgString;
    } finally {
      if (host.parentNode) {
        host.parentNode.removeChild(host);
      }
    }
  }

  window.renderMermaid = function (id, code) {
    try {
      mermaid.render('mmd-' + id, code).then(function (out) {
        var raw = out && out.svg ? out.svg : '';
        var flat = raw ? flattenSvgStyles(raw) : '';
        window.flutter_inappwebview.callHandler('mermaidResult', {
          id: id,
          svg: flat
        });
      }).catch(function (err) {
        window.flutter_inappwebview.callHandler('mermaidResult', {
          id: id,
          error: err && err.message ? err.message : String(err)
        });
      });
    } catch (e) {
      window.flutter_inappwebview.callHandler('mermaidResult', {
        id: id,
        error: e && e.message ? e.message : String(e)
      });
    }
  };
  window.flutter_inappwebview.callHandler('mermaidResult', {
    id: '__ready__',
    svg: ''
  });
})();
</script>
</body>
</html>
''';
}
