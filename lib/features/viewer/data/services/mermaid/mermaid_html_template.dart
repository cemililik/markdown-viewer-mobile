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
  window.renderMermaid = function (id, code) {
    try {
      mermaid.render('mmd-' + id, code).then(function (out) {
        window.flutter_inappwebview.callHandler('mermaidResult', {
          id: id,
          svg: out && out.svg ? out.svg : ''
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
