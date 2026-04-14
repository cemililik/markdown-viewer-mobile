import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:markdown_viewer/features/viewer/data/services/mermaid/mermaid_js_channel.dart';
import 'package:markdown_viewer/features/viewer/data/services/mermaid/mermaid_utils.dart';

/// Production [MermaidJsChannel] backed by a sandboxed
/// [HeadlessInAppWebView].
///
/// `Headless` because no Flutter widget hosts the view: the renderer
/// is a pure service, and the WebView lives offscreen for the entire
/// app lifetime. Sandbox flags follow
/// `docs/standards/security-standards.md` §WebView Rules:
///
/// - `javaScriptEnabled: true` — required by mermaid
/// - `allowFileAccess: false`
/// - `allowFileAccessFromFileURLs: false`
/// - `allowUniversalAccessFromFileURLs: false`
/// - `clearCache: true` — wipe any vestigial state at startup
/// - `blockNetworkLoads: true` — the renderer must run fully
///   offline; the bundled mermaid bundle is the only JS we trust
/// - No JS bridge handlers beyond the single `mermaidResult`
///   endpoint registered in [initialize]
///
/// The page is loaded as a `data:` URI so there is no file:// or
/// http:// origin to leak through the sandbox.
///
/// ## Native screenshot flow
///
/// The channel does not just marshal `render()` calls into
/// JavaScript — it also intercepts the `state: 'ready'` handshake
/// the sandbox posts once an SVG has been injected into the page
/// and laid out, calls
/// [InAppWebViewController.takeScreenshot] to grab the region the
/// SVG occupies, and forwards the resulting PNG bytes to the
/// caller's `onResult` callback as
/// `{id, pngBytes: Uint8List, width, height}`.
///
/// Going through `takeScreenshot` — which hits the native WKWebView
/// snapshot API — is the only reliable way to get pixel data out
/// of an iOS WebView for SVG content: every JS-canvas path
/// (drawImage + toDataURL, createImageBitmap, Blob + fetch) taints
/// the canvas under WebKit and throws
/// `SecurityError: The operation is insecure` on export. The
/// native snapshot path has no such restriction.
class HeadlessMermaidJsChannel implements MermaidJsChannel {
  /// Initial CSS pixel footprint of the offscreen WebView.
  ///
  /// Width matches the 900 px sink in `mermaid_html_template.dart`
  /// so mermaid lays out within a deterministic horizontal box.
  /// Height is generous (4000 px) so even tall vertical flowcharts
  /// have room to render before the screenshot rect captures
  /// them — anything taller than this would clip, but the cost of
  /// a backbuffer that size is cheap on a headless view.
  static const Size _initialSize = Size(900, 4000);

  HeadlessInAppWebView? _view;

  /// In-flight initialise future. The first caller starts the work
  /// and stores its [Future] here; every concurrent caller awaits
  /// the same future so they all block until the WebView is truly
  /// ready, instead of racing through on a "_view != null" early
  /// return that would let them call `render()` before the page
  /// has emitted the `__ready__` handshake.
  Future<void>? _initializing;

  @override
  Future<void> initialize({
    required String html,
    required void Function(Map<String, Object?> message) onResult,
  }) {
    if (_view != null) {
      return Future<void>.value();
    }
    final inflight = _initializing;
    if (inflight != null) {
      return inflight;
    }
    final future = _runInitialize(html: html, onResult: onResult);
    _initializing = future;
    return future;
  }

  Future<void> _runInitialize({
    required String html,
    required void Function(Map<String, Object?> message) onResult,
  }) async {
    final ready = Completer<void>();

    final view = HeadlessInAppWebView(
      initialSize: _initialSize,
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        allowFileAccess: false,
        allowFileAccessFromFileURLs: false,
        allowUniversalAccessFromFileURLs: false,
        clearCache: true,
        blockNetworkLoads: true,
        transparentBackground: true,
      ),
      initialData: InAppWebViewInitialData(
        data: html,
        mimeType: 'text/html',
        encoding: 'utf-8',
        baseUrl: WebUri('about:blank'),
      ),
      onWebViewCreated: (controller) {
        controller.addJavaScriptHandler(
          handlerName: 'mermaidResult',
          callback: (args) {
            final raw = args.isNotEmpty ? args.first : null;
            final message = _coerceMessage(raw);
            if (message == null) {
              return null;
            }
            final id = message['id'];
            if (id == '__ready__') {
              if (!ready.isCompleted) {
                ready.complete();
              }
              return null;
            }
            if (id == '__init__') {
              if (!ready.isCompleted) {
                final error = message['error'];
                ready.completeError(
                  MermaidJsChannelException(
                    error is String
                        ? error
                        : 'mermaid sandbox failed to initialise',
                  ),
                );
              }
              return null;
            }
            // The JS hook signals "the SVG is on screen, here is
            // its rect". We grab a native screenshot of that rect
            // and forward the PNG bytes to the renderer impl as
            // a `{id, pngBytes, width, height}` result. We
            // fire-and-forget here because the JavaScriptHandler
            // callback cannot be async — any error inside
            // `_captureAndForward` bubbles out as a forwarded
            // `{error: ...}` message instead.
            if (message['state'] == 'ready') {
              unawaited(
                _captureAndForward(
                  controller: controller,
                  message: message,
                  onResult: onResult,
                ),
              );
              return null;
            }
            onResult(message);
            return null;
          },
        );
      },
    );

    try {
      await view.run();
      await ready.future;
    } catch (e) {
      // Tear the partially-created view down before bubbling the
      // failure up — without this, _view stays null but the
      // platform side might still hold the live HeadlessInAppWebView,
      // and a future retry would leak it.
      try {
        await view.dispose();
      } catch (_) {
        // Intentionally suppressed.
      }
      _initializing = null;
      if (e is MermaidJsChannelException) {
        rethrow;
      }
      throw MermaidJsChannelException(
        'HeadlessInAppWebView failed to start: $e',
      );
    }

    // Only assign `_view` once the page has actually reached the
    // ready handshake; before that, `render()` would be unsafe.
    _view = view;
    _initializing = null;
  }

  /// Reads `width` / `height` out of the JS ready message, asks
  /// WKWebView for a native snapshot of exactly that rect, and
  /// forwards the PNG bytes to [onResult] as
  /// `{id, pngBytes: Uint8List, width, height}`.
  ///
  /// Every failure path translates to a forwarded `{id, error}`
  /// message so the renderer impl's regular result pipeline can
  /// surface it to the UI.
  Future<void> _captureAndForward({
    required InAppWebViewController controller,
    required Map<String, Object?> message,
    required void Function(Map<String, Object?> message) onResult,
  }) async {
    final id = message['id'];
    final width = asPositiveDouble(message['width']);
    final height = asPositiveDouble(message['height']);
    if (id is! String || width == null || height == null) {
      onResult({
        'id': id,
        'error': 'ready handshake missing id / width / height: $message',
      });
      return;
    }
    Uint8List? bytes;
    try {
      bytes = await controller.takeScreenshot(
        screenshotConfiguration: ScreenshotConfiguration(
          rect: InAppWebViewRect(x: 0, y: 0, width: width, height: height),
          compressFormat: CompressFormat.PNG,
          quality: 100,
        ),
      );
    } catch (e) {
      onResult({'id': id, 'error': 'takeScreenshot threw: $e'});
      return;
    }
    if (bytes == null || bytes.isEmpty) {
      onResult({'id': id, 'error': 'takeScreenshot returned no bytes'});
      return;
    }
    onResult({'id': id, 'pngBytes': bytes, 'width': width, 'height': height});
  }

  @override
  Future<void> render({required String id, required String source}) async {
    final view = _view;
    if (view == null) {
      throw const MermaidJsChannelException(
        'render() called before initialize()',
      );
    }
    final controller = view.webViewController;
    if (controller == null) {
      throw const MermaidJsChannelException(
        'WebView controller is not yet available',
      );
    }
    // Encode the source as a JSON string literal so embedded quotes,
    // backslashes, and newlines survive the JS eval boundary safely.
    final encodedSource = jsonEncode(source);
    final encodedId = jsonEncode(id);
    await controller.evaluateJavascript(
      source: 'window.renderMermaid($encodedId, $encodedSource);',
    );
  }

  @override
  Future<void> dispose() async {
    final view = _view;
    _view = null;
    if (view != null) {
      await view.dispose();
    }
  }

  Map<String, Object?>? _coerceMessage(Object? raw) {
    if (raw is Map) {
      return raw.map(
        (key, value) => MapEntry(key.toString(), value as Object?),
      );
    }
    return null;
  }
}
