import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:markdown_viewer/features/viewer/application/mermaid_utils.dart';
import 'package:markdown_viewer/features/viewer/data/services/mermaid/headless_mermaid_js_channel.dart';
import 'package:markdown_viewer/features/viewer/data/services/mermaid/mermaid_html_template.dart';
import 'package:markdown_viewer/features/viewer/data/services/mermaid/mermaid_js_channel.dart';
import 'package:markdown_viewer/features/viewer/data/services/mermaid/mermaid_lru_cache.dart';
import 'package:markdown_viewer/features/viewer/data/services/mermaid/mermaid_utils.dart';
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
///    and short-circuit the JS bridge entirely, returning cached
///    PNG bytes. The key is the hex SHA-256 of the source string;
///    the value is a [_CachedBitmap] containing PNG bytes and
///    natural dimensions. Cache size is bounded (default 64) per
///    ADR-0005.
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
       _cache = MermaidLruCache<_CachedBitmap>(capacity: cacheCapacity);

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
  final MermaidLruCache<_CachedBitmap> _cache;

  /// Per-key in-flight collapse: when two widgets ask for the same
  /// source at the same time, the second call attaches to this
  /// completer instead of enqueuing a duplicate render request.
  final Map<String, Completer<MermaidRenderResult>> _inFlight =
      <String, Completer<MermaidRenderResult>>{};

  /// Pending requests waiting for their turn at the single JS
  /// channel. Drained by [_pump] one at a time.
  final List<_PendingRender> _queue = <_PendingRender>[];

  /// Maps per-request JS bridge id → (completer, cacheKey).
  ///
  /// Two maps track pending work in parallel:
  /// * [_inFlight] is keyed by source hash and exists so that two
  ///   concurrent `render()` calls for the same diagram collapse onto
  ///   a single completer. It is populated in [render] and cleared in
  ///   [_pump] once `pending.completer.future` resolves.
  /// * [_activeRequests] (this map) is keyed by the per-request id we
  ///   send into JS so [_handleChannelResult] can look up the
  ///   completer when the `onResult` callback fires.
  ///
  /// We carry the cache key inside this record so
  /// [_handleChannelResult] can write the resulting bitmap into the
  /// LRU cache directly. An earlier implementation tried to reverse-
  /// look up the key by identity-scanning [_inFlight], but `_pump`
  /// removes the in-flight entry in its `finally` block before the
  /// channel callback fires — the scan always returned `null` and
  /// cache writes silently no-oped.
  final Map<
    String,
    ({Completer<MermaidRenderResult> completer, String cacheKey})
  >
  _activeRequests = {};

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
      // Deliberate ordering: any caller waiting on [_prewarmInFlight]
      // gets released here, but by this point [_initialized] has
      // already flipped to true (or [_permanentFailure] is set). A
      // third concurrent [prewarm] arriving between the state write
      // and the in-flight clear would have observed `_initialized ==
      // true` at the top guard and returned immediately; arriving
      // AFTER the clear it would still observe the same terminal
      // state and short-circuit. No race window remains in which a
      // caller could trigger a second initialization cycle.
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

    // Splice the caller-supplied init directive into the source so
    // the sandbox JS renders with the right palette without us
    // having to re-call `mermaid.initialize` (which would need
    // global state on the sandbox page and invite race
    // conditions). An empty directive means the caller wants the
    // raw source respected (used when the source already starts
    // with its own `%%{init: …}%%`). The directive is part of the
    // hashed input, so light and dark variants of the same diagram
    // automatically occupy distinct cache slots.
    final themedSource = _composeSourceWithInit(source, initDirective);
    final key = sha256.convert(utf8.encode(themedSource)).toString();

    final cached = _cache.get(key);
    if (cached != null) {
      return MermaidRenderSuccess(
        pngBytes: cached.pngBytes,
        width: cached.width,
        height: cached.height,
      );
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

  /// Live snapshot of the SVG LRU cache hit/miss counters.
  ///
  /// Exposed for instrumentation and integration-test assertions.
  /// [hits] and [misses] are cumulative since the renderer was
  /// constructed (or since the last `dispose` call reset the cache).
  ({int hits, int misses}) get cacheStats => (
    hits: _cache.hits,
    misses: _cache.misses,
  );

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
    for (final entry in _activeRequests.values) {
      if (!entry.completer.isCompleted) {
        entry.completer.complete(pendingError);
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
        _activeRequests[requestId] = (
          completer: pending.completer,
          cacheKey: pending.key,
        );
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
  /// Routes a `{id, pngBytes | png, width, height | error}` payload
  /// back to the matching pending [Completer] and updates the
  /// cache on success.
  ///
  /// The production channel takes a native WKWebView snapshot and
  /// forwards the raw [Uint8List] under `pngBytes`; test fakes
  /// stage a base64 string under `png` because they have no real
  /// WebView to screenshot. The handler accepts either shape so a
  /// single code path covers both.
  void _handleChannelResult(Map<String, Object?> message) {
    final id = message['id'] as String?;
    if (id == null || id == '__ready__' || id == '__init__') {
      return;
    }
    final entry = _activeRequests[id];
    if (entry == null || entry.completer.isCompleted) {
      return;
    }
    final completer = entry.completer;
    final cacheKey = entry.cacheKey;
    final error = message['error'];
    if (error is String && error.isNotEmpty) {
      completer.complete(MermaidRenderFailure(error));
      return;
    }
    final Uint8List bytes;
    final rawBytes = message['pngBytes'];
    if (rawBytes is Uint8List && rawBytes.isNotEmpty) {
      bytes = rawBytes;
    } else {
      final rawBase64 = message['png'];
      if (rawBase64 is! String || rawBase64.isEmpty) {
        completer.complete(
          const MermaidRenderFailure('Mermaid renderer returned an empty PNG'),
        );
        return;
      }
      try {
        bytes = base64Decode(rawBase64);
      } on FormatException catch (e) {
        completer.complete(
          MermaidRenderFailure('Mermaid renderer PNG was not valid base64: $e'),
        );
        return;
      }
    }
    if (bytes.isEmpty) {
      completer.complete(
        const MermaidRenderFailure('Mermaid renderer returned an empty PNG'),
      );
      return;
    }
    final width = asPositiveDouble(message['width']);
    final height = asPositiveDouble(message['height']);
    if (width == null || height == null) {
      completer.complete(
        const MermaidRenderFailure(
          'Mermaid renderer returned a PNG without natural dimensions',
        ),
      );
      return;
    }
    final bitmap = _CachedBitmap(pngBytes: bytes, width: width, height: height);
    _cache.put(cacheKey, bitmap);
    completer.complete(
      MermaidRenderSuccess(
        pngBytes: bitmap.pngBytes,
        width: bitmap.width,
        height: bitmap.height,
      ),
    );
  }

  /// Splices [initDirective] into [source] at the correct position
  /// for mermaid's parser.
  ///
  /// The naive path is `'$initDirective$source'`, but that breaks
  /// mermaid's YAML frontmatter handling: mermaid expects the
  /// opening `---` of a frontmatter block to be the very first
  /// token of the source, and any `%%{init: …}%%` line pushed in
  /// front of it derails the frontmatter parser. The visible
  /// symptom is a "Parse error on line 1: ---title: X / Expecting
  /// NEWLINE, got LINK" message from mermaid's diagram parser,
  /// because once the frontmatter parse fails mermaid falls
  /// through to the diagram parser which cannot make sense of
  /// `---title: …`.
  ///
  /// The fix is to insert the init directive AFTER the closing
  /// `---` of a leading frontmatter block so frontmatter stays on
  /// line 1. Sources without frontmatter keep the original
  /// "prepend to the top" behaviour.
  static String _composeSourceWithInit(String source, String initDirective) {
    final String composed;
    if (initDirective.isEmpty) {
      composed = source;
    } else {
      final end = frontmatterEndIndex(source);
      composed =
          end == null
              ? '$initDirective$source'
              : '${source.substring(0, end)}$initDirective${source.substring(end)}';
    }
    // Unconditionally pin `securityLevel: 'antiscript'` as a trailing
    // directive so mermaid's last-write-wins merge rule overrides any
    // user-supplied `%%{init: {"securityLevel":"loose"}}%%` in the
    // source. Forcing `antiscript` keeps `<script>` tags inside
    // mermaid-rendered HTML labels stripped even when the document
    // author tries to opt out of the hardening — the CSP +
    // `blockNetworkLoads: true` invariants from ADR-0005 depend on
    // this mode.
    // Reference: security-review SR-20260419-014.
    return '$composed\n$_securityLevelOverride\n';
  }

  static const String _securityLevelOverride =
      "%%{init: {'securityLevel': 'antiscript'} }%%";
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

/// Internal cache value type — PNG bytes + natural dimensions.
///
/// Kept private to the impl because it exists only to thread the
/// three values through the LRU cache together. The public result
/// shape is [MermaidRenderSuccess]; this is the in-memory form
/// the cache holds so that a cache hit does not have to rebuild
/// the fields one-by-one from scattered maps.
class _CachedBitmap {
  const _CachedBitmap({
    required this.pngBytes,
    required this.width,
    required this.height,
  });

  final Uint8List pngBytes;
  final double width;
  final double height;
}
