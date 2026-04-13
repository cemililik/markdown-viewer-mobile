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

  // Inline every presentation-affecting CSS property from the
  // mermaid-authored `<style>` blocks into the matching SVG
  // elements, then drop the style blocks. `flutter_svg` has no
  // support for `<style>` CSS selectors at all — without this the
  // `fill` / `stroke` / `font-*` declarations mermaid stamps on
  // `#mermaid-N .node rect { ... }` selectors never reach paint
  // and every rect falls back to default black. Every text element
  // loses its colour the same way.
  //
  // The first iteration of this helper used `getComputedStyle`,
  // which is the obvious path — let the WebView's CSS engine
  // resolve every rule and read back the computed value. That
  // worked in desktop Safari but failed silently on iOS WebKit:
  // the returned values were the SVG defaults (fill=black,
  // stroke=black, no font) instead of the mermaid rules, so the
  // flattened SVG was indistinguishable from the broken raw one.
  //
  // This version parses the `<style>` block contents with a
  // minimal regex-based CSS tokeniser and applies each rule to
  // elements found via `querySelectorAll` on the SVG root. It
  // does not depend on iOS WebKit's style-resolution quirks and
  // works identically across every platform.
  var FLAT_PROPS = {
    'fill': 1, 'fill-opacity': 1, 'fill-rule': 1,
    'stroke': 1, 'stroke-width': 1, 'stroke-opacity': 1,
    'stroke-dasharray': 1, 'stroke-linecap': 1, 'stroke-linejoin': 1,
    'font-family': 1, 'font-size': 1, 'font-weight': 1, 'font-style': 1,
    'text-anchor': 1, 'dominant-baseline': 1, 'opacity': 1,
    'color': 1
  };
  function flattenSvgStyles(svgString) {
    var host = document.createElement('div');
    host.style.position = 'absolute';
    host.style.left = '-10000px';
    host.style.top = '-10000px';
    document.body.appendChild(host);
    try {
      host.innerHTML = svgString;
      var root = host.querySelector('svg');
      if (!root) {
        return svgString;
      }

      var styleNodes = root.querySelectorAll('style');
      // Parse every `selector { declarations }` rule from every
      // `<style>` block. We collect them into a flat list before
      // applying so a rule can target elements we have already
      // visited.
      var RULE_RE = /([^{}]+)\\{([^{}]+)\\}/g;
      var rules = [];
      for (var sidx = 0; sidx < styleNodes.length; sidx++) {
        var cssText = styleNodes[sidx].textContent || '';
        RULE_RE.lastIndex = 0;
        var match;
        while ((match = RULE_RE.exec(cssText)) !== null) {
          var rawSelector = match[1].trim();
          var body = match[2];
          if (!rawSelector || !body) continue;
          var props = {};
          var decls = body.split(';');
          for (var di = 0; di < decls.length; di++) {
            var decl = decls[di].trim();
            if (!decl) continue;
            var colon = decl.indexOf(':');
            if (colon <= 0) continue;
            var key = decl.substring(0, colon).trim().toLowerCase();
            if (!FLAT_PROPS[key]) continue;
            var value = decl.substring(colon + 1).trim();
            value = value.replace(/\\s*!important\\s*\$/i, '').trim();
            if (value && value !== 'inherit' && value !== 'initial') {
              props[key] = value;
            }
          }
          if (Object.keys(props).length === 0) continue;
          // Split comma-separated selectors into independent
          // rules — `.a, .b { fill: red; }` is two rules for our
          // purposes.
          var selectors = rawSelector.split(',');
          for (var seli = 0; seli < selectors.length; seli++) {
            var sel = selectors[seli].trim();
            if (!sel) continue;
            // Mermaid scopes every rule with `#mermaid-N` to stop
            // rules from bleeding out of the SVG into the host
            // page. That scoping ID is the SVG root's own id and
            // makes querySelectorAll-from-root weird on some
            // engines, so strip the leading `#id ` prefix and use
            // the inner part directly. Selectors that are only
            // `#id` get dropped — there is no element inside the
            // SVG matching them.
            sel = sel.replace(/^#[\\w-]+(?:\\s+|\$)/, '').trim();
            if (!sel) continue;
            var matched;
            try {
              matched = root.querySelectorAll(sel);
            } catch (e) {
              // Ignore selectors querySelectorAll rejects
              // (non-standard pseudos from mermaid, malformed
              // input, …) — there is no graceful fallback and
              // missing one rule is better than crashing the
              // whole flatten pass.
              continue;
            }
            rules.push({ elements: matched, props: props });
          }
        }
      }

      for (var ri = 0; ri < rules.length; ri++) {
        var rule = rules[ri];
        for (var ei = 0; ei < rule.elements.length; ei++) {
          var el = rule.elements[ei];
          for (var prop in rule.props) {
            if (!Object.prototype.hasOwnProperty.call(rule.props, prop)) continue;
            // SVG presentation attributes use `fill` for text
            // colour, not `color`. Translate on the fly so text
            // elements still pick up mermaid's text-colour rules.
            var attrName = prop;
            if (prop === 'color') {
              var tag = el.tagName && el.tagName.toLowerCase();
              if (tag !== 'text' && tag !== 'tspan' && tag !== 'g') continue;
              attrName = 'fill';
            }
            // Do not overwrite an already-explicit attribute —
            // `fill="url(#grad)"` or an inline style wins.
            if (el.hasAttribute(attrName)) continue;
            el.setAttribute(attrName, rule.props[prop]);
          }
        }
      }

      // Now remove the `<style>` blocks. Leaving them around just
      // confuses `flutter_svg`'s CSS-ignorant parser, and every
      // rule they contain has been inlined above.
      for (var stri = 0; stri < styleNodes.length; stri++) {
        var sn = styleNodes[stri];
        if (sn.parentNode) sn.parentNode.removeChild(sn);
      }
      return new XMLSerializer().serializeToString(root);
    } catch (err) {
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
