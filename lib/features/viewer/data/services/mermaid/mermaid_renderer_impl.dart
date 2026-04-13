import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:markdown_viewer/features/viewer/data/services/mermaid/headless_mermaid_js_channel.dart';
import 'package:markdown_viewer/features/viewer/data/services/mermaid/mermaid_html_template.dart';
import 'package:markdown_viewer/features/viewer/data/services/mermaid/mermaid_js_channel.dart';
import 'package:markdown_viewer/features/viewer/data/services/mermaid/mermaid_lru_cache.dart';
import 'package:markdown_viewer/features/viewer/domain/services/mermaid_renderer.dart';

/// WebView-backed [MermaidRenderer] implementation.
///
/// Layered over a [MermaidJsChannel] so the queue / cache logic can
/// be unit-tested without a real WebView. Production wiring builds
/// the impl with a [HeadlessMermaidJsChannel] in `lib/main.dart`;
/// tests inject a fake channel.
///
/// Behaviour:
///
/// 1. **SHA-256-keyed LRU cache.** Identical sources hit the cache
///    and short-circuit the JS bridge entirely. The key is the
///    hex SHA-256 of the source string; the value is the rendered
///    SVG. Cache size is bounded (default 64) per ADR-0005.
/// 2. **In-flight collapse.** Two concurrent `render()` calls for
///    the same source share a single `Completer` instead of
///    issuing two JS evals.
/// 3. **Serial queue against the JS channel.** The channel speaks
///    to a single WebView; concurrent native calls have undefined
///    ordering. `_pump` drains the queue one request at a time,
///    awaiting the matching result before issuing the next eval.
/// 4. **Permanent-failure fallback.** If `prewarm` itself fails
///    (e.g. the asset is missing in CI), the renderer flips into a
///    "failed" state and every subsequent `render` returns a
///    [MermaidRenderFailure] without touching the channel. The
///    rest of the document still renders.
class MermaidRendererImpl implements MermaidRenderer {
  MermaidRendererImpl({
    required MermaidJsChannel channel,
    required String mermaidJs,
    int cacheCapacity = _defaultCacheCapacity,
  }) : _channel = channel,
       _mermaidJs = mermaidJs,
       _cache = MermaidLruCache(capacity: cacheCapacity);

  /// Convenience constructor used by `lib/main.dart` to wire a
  /// production [HeadlessMermaidJsChannel]. Tests use the primary
  /// constructor with a fake channel.
  factory MermaidRendererImpl.production({
    required String mermaidJs,
    int cacheCapacity = _defaultCacheCapacity,
  }) {
    return MermaidRendererImpl(
      channel: HeadlessMermaidJsChannel(),
      mermaidJs: mermaidJs,
      cacheCapacity: cacheCapacity,
    );
  }

  static const int _defaultCacheCapacity = 64;

  final MermaidJsChannel _channel;
  final String _mermaidJs;
  final MermaidLruCache _cache;

  /// Per-key in-flight collapse: when two widgets ask for the same
  /// source at the same time, the second call attaches to this
  /// completer instead of enqueuing a duplicate render request.
  final Map<String, Completer<MermaidRenderResult>> _inFlight =
      <String, Completer<MermaidRenderResult>>{};

  /// Pending requests waiting for their turn at the single JS
  /// channel. Drained by [_pump] one at a time.
  final List<_PendingRender> _queue = <_PendingRender>[];

  /// Per-request bookkeeping for `[id] -> completer` so the
  /// asynchronous `onResult` callback can match a JS reply back to
  /// its caller. Distinct from [_inFlight], which is keyed by
  /// source hash and used for collapse; this map is keyed by the
  /// per-request id we send into JS.
  final Map<String, Completer<MermaidRenderResult>> _activeRequests =
      <String, Completer<MermaidRenderResult>>{};

  bool _isPumping = false;
  bool _initialized = false;
  bool _disposed = false;

  /// Set to a non-null message when [prewarm] fails. Subsequent
  /// [render] calls short-circuit to a [MermaidRenderFailure]
  /// containing this message.
  String? _permanentFailure;

  /// In-flight prewarm future so concurrent callers — a user-level
  /// `prewarm()` from the composition root running in parallel with
  /// the lazy prewarm inside [_pump] — share a single channel
  /// `initialize()` call instead of racing and issuing two.
  Future<void>? _prewarmInFlight;

  int _nextRequestSeq = 0;

  @override
  Future<void> prewarm() {
    if (_initialized || _permanentFailure != null) {
      return Future<void>.value();
    }
    final inflight = _prewarmInFlight;
    if (inflight != null) {
      return inflight;
    }
    final future = _runPrewarm();
    _prewarmInFlight = future;
    return future;
  }

  Future<void> _runPrewarm() async {
    try {
      await _channel.initialize(
        html: buildMermaidHtml(mermaidJs: _mermaidJs),
        onResult: _handleChannelResult,
      );
      _initialized = true;
    } on MermaidJsChannelException catch (e) {
      _permanentFailure = e.message;
    } catch (e) {
      _permanentFailure = 'Unexpected mermaid renderer init error: $e';
    } finally {
      _prewarmInFlight = null;
    }
  }

  @override
  Future<MermaidRenderResult> render(
    String source, {
    String initDirective = '',
  }) async {
    if (_disposed) {
      return const MermaidRenderFailure('Renderer has been disposed');
    }
    if (_permanentFailure != null) {
      return MermaidRenderFailure(_permanentFailure!);
    }

    // Prepend the caller-supplied init directive so the sandbox JS
    // renders with the right palette without us having to re-call
    // `mermaid.initialize` (which would need global state on the
    // sandbox page and invite race conditions). An empty directive
    // means the caller wants the raw source respected (used when
    // the source already starts with its own `%%{init: …}%%`).
    // The directive is part of the hashed input, so light and
    // dark variants of the same diagram — or any other theme
    // variation the caller threads through — automatically occupy
    // distinct cache slots.
    final themedSource =
        initDirective.isEmpty ? source : '$initDirective$source';
    final key = sha256.convert(utf8.encode(themedSource)).toString();

    final cached = _cache.get(key);
    if (cached != null) {
      return MermaidRenderSuccess(cached);
    }

    final existing = _inFlight[key];
    if (existing != null) {
      return existing.future;
    }

    final completer = Completer<MermaidRenderResult>();
    _inFlight[key] = completer;
    _queue.add(
      _PendingRender(key: key, source: themedSource, completer: completer),
    );
    unawaited(_pump());
    return completer.future;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _cache.clear();
    const pendingError = MermaidRenderFailure(
      'Renderer disposed before request completed',
    );
    for (final pending in _queue) {
      if (!pending.completer.isCompleted) {
        pending.completer.complete(pendingError);
      }
    }
    _queue.clear();
    for (final completer in _activeRequests.values) {
      if (!completer.isCompleted) {
        completer.complete(pendingError);
      }
    }
    _activeRequests.clear();
    _inFlight.clear();
    await _channel.dispose();
  }

  /// Drains [_queue] one item at a time. Re-entrant calls (a fresh
  /// `render` arriving while we're awaiting an eval) early-out
  /// because [_isPumping] is set; the running pump picks up the
  /// new entry on its next iteration.
  Future<void> _pump() async {
    if (_isPumping || _disposed) {
      return;
    }
    _isPumping = true;
    try {
      while (_queue.isNotEmpty && !_disposed) {
        if (!_initialized && _permanentFailure == null) {
          // A render() landed before prewarm() was called. Run
          // initialisation lazily so the queue can drain.
          await prewarm();
        }
        if (_permanentFailure != null) {
          // Initialisation just failed. Drain the queue with a
          // failure result for every pending entry instead of
          // leaving them hanging.
          for (final pending in _queue) {
            _inFlight.remove(pending.key);
            if (!pending.completer.isCompleted) {
              pending.completer.complete(
                MermaidRenderFailure(_permanentFailure!),
              );
            }
          }
          _queue.clear();
          return;
        }

        final pending = _queue.removeAt(0);
        final requestId = (_nextRequestSeq++).toString();
        _activeRequests[requestId] = pending.completer;
        try {
          await _channel.render(id: requestId, source: pending.source);
          // The result will arrive asynchronously via
          // _handleChannelResult; wait for it before drawing the
          // next item from the queue so the channel sees one
          // request at a time.
          await pending.completer.future;
        } catch (e) {
          if (!pending.completer.isCompleted) {
            pending.completer.complete(
              MermaidRenderFailure('JS channel render threw: $e'),
            );
          }
        } finally {
          _activeRequests.remove(requestId);
          _inFlight.remove(pending.key);
        }
      }
    } finally {
      _isPumping = false;
    }
  }

  /// Single bridge endpoint registered with the JS channel.
  /// Routes a `{id, svg | error}` payload back to the matching
  /// pending [Completer] and updates the cache on success.
  void _handleChannelResult(Map<String, Object?> message) {
    final id = message['id'] as String?;
    if (id == null || id == '__ready__' || id == '__init__') {
      return;
    }
    final completer = _activeRequests[id];
    if (completer == null || completer.isCompleted) {
      return;
    }
    final error = message['error'];
    if (error is String && error.isNotEmpty) {
      completer.complete(MermaidRenderFailure(error));
      return;
    }
    final svg = message['svg'];
    if (svg is! String || svg.isEmpty) {
      completer.complete(
        const MermaidRenderFailure('Mermaid renderer returned empty SVG'),
      );
      return;
    }
    final pendingKey = _keyForCompleter(completer);
    if (pendingKey != null) {
      _cache.put(pendingKey, svg);
    }
    completer.complete(MermaidRenderSuccess(svg));
  }

  String? _keyForCompleter(Completer<MermaidRenderResult> completer) {
    for (final entry in _inFlight.entries) {
      if (identical(entry.value, completer)) {
        return entry.key;
      }
    }
    return null;
  }
}

class _PendingRender {
  _PendingRender({
    required this.key,
    required this.source,
    required this.completer,
  });

  final String key;
  final String source;
  final Completer<MermaidRenderResult> completer;
}
