import 'dart:async';
import 'dart:convert';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:markdown_viewer/features/viewer/data/services/mermaid/mermaid_js_channel.dart';

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
class HeadlessMermaidJsChannel implements MermaidJsChannel {
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
      // and a future retry would leak it. Any exception from the
      // disposal itself is swallowed because we are already in an
      // error path and the original cause matters more.
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
