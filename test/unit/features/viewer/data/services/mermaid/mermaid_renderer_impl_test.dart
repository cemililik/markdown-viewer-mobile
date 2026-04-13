import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/features/viewer/data/services/mermaid/mermaid_js_channel.dart';
import 'package:markdown_viewer/features/viewer/data/services/mermaid/mermaid_renderer_impl.dart';
import 'package:markdown_viewer/features/viewer/domain/services/mermaid_renderer.dart';

void main() {
  group('MermaidRendererImpl', () {
    test(
      'should hit the channel exactly once for a repeated source thanks to the cache',
      () async {
        final channel = _FakeChannel();
        final renderer = MermaidRendererImpl(
          channel: channel,
          mermaidJs: '/* fake */',
        );
        await renderer.prewarm();

        channel.scriptResult('flowchart LR; A-->B', 'svg-1');
        final first = await renderer.render('flowchart LR; A-->B');
        final second = await renderer.render('flowchart LR; A-->B');

        expect(first, isA<MermaidRenderSuccess>());
        expect((first as MermaidRenderSuccess).svg, 'svg-1');
        expect(second, isA<MermaidRenderSuccess>());
        expect((second as MermaidRenderSuccess).svg, 'svg-1');
        expect(
          channel.renderCallCount,
          1,
          reason: 'Second render call must be served from the LRU cache.',
        );
      },
    );

    test('should collapse two concurrent identical render calls to one channel '
        'eval', () async {
      final channel = _FakeChannel();
      final renderer = MermaidRendererImpl(
        channel: channel,
        mermaidJs: '/* fake */',
      );
      await renderer.prewarm();

      channel.scriptResult('graph TD; X-->Y', 'svg-xy');
      final futureA = renderer.render('graph TD; X-->Y');
      final futureB = renderer.render('graph TD; X-->Y');
      final results = await Future.wait([futureA, futureB]);

      expect(results.every((r) => r is MermaidRenderSuccess), isTrue);
      expect(
        (results.first as MermaidRenderSuccess).svg,
        (results.last as MermaidRenderSuccess).svg,
      );
      expect(
        channel.renderCallCount,
        1,
        reason: 'In-flight collapse must avoid the second JS eval.',
      );
    });

    test(
      'should run distinct sources through the channel separately',
      () async {
        final channel = _FakeChannel();
        final renderer = MermaidRendererImpl(
          channel: channel,
          mermaidJs: '/* fake */',
        );
        await renderer.prewarm();

        channel.scriptResult('A', 'svg-a');
        channel.scriptResult('B', 'svg-b');

        final a = await renderer.render('A');
        final b = await renderer.render('B');

        expect((a as MermaidRenderSuccess).svg, 'svg-a');
        expect((b as MermaidRenderSuccess).svg, 'svg-b');
        expect(channel.renderCallCount, 2);
      },
    );

    test(
      'should translate a channel error reply into a MermaidRenderFailure',
      () async {
        final channel = _FakeChannel();
        final renderer = MermaidRendererImpl(
          channel: channel,
          mermaidJs: '/* fake */',
        );
        await renderer.prewarm();

        channel.scriptError('flowchart LR; A--', 'mermaid parse error');
        final result = await renderer.render('flowchart LR; A--');

        expect(result, isA<MermaidRenderFailure>());
        expect(
          (result as MermaidRenderFailure).message,
          contains('mermaid parse error'),
        );
      },
    );

    test(
      'should mark the renderer permanently failed when prewarm throws',
      () async {
        final channel = _FailingChannel(
          const MermaidJsChannelException('boom'),
        );
        final renderer = MermaidRendererImpl(
          channel: channel,
          mermaidJs: '/* fake */',
        );

        await renderer.prewarm();
        final result = await renderer.render('any source');

        expect(result, isA<MermaidRenderFailure>());
        expect((result as MermaidRenderFailure).message, contains('boom'));
        expect(
          channel.renderCallCount,
          0,
          reason:
              'A permanently failed renderer must not invoke the channel for '
              'render requests.',
        );
      },
    );

    test('should return a failure for every render after dispose', () async {
      final channel = _FakeChannel();
      final renderer = MermaidRendererImpl(
        channel: channel,
        mermaidJs: '/* fake */',
      );
      await renderer.prewarm();
      await renderer.dispose();

      final result = await renderer.render('anything');

      expect(result, isA<MermaidRenderFailure>());
      expect((result as MermaidRenderFailure).message, contains('disposed'));
    });

    test(
      'should prepend a non-empty initDirective verbatim to the source',
      () async {
        final channel = _FakeChannel();
        final renderer = MermaidRendererImpl(
          channel: channel,
          mermaidJs: '/* fake */',
        );
        await renderer.prewarm();

        const directive =
            '%%{init: {"theme":"base","themeVariables":{"primaryColor":"#aabbcc"}}}%%\n';
        channel.scriptResult('flowchart LR; A-->B', 'svg');
        await renderer.render('flowchart LR; A-->B', initDirective: directive);

        expect(channel.observedSources, hasLength(1));
        expect(
          channel.observedSources.single,
          startsWith(directive),
          reason:
              'The renderer must prepend the caller-supplied init '
              'directive verbatim so mermaid.js picks up the requested '
              'theme variables without us having to re-call '
              'mermaid.initialize on the sandbox page.',
        );
      },
    );

    test(
      'should pass the source through untouched when initDirective is empty',
      () async {
        final channel = _FakeChannel();
        final renderer = MermaidRendererImpl(
          channel: channel,
          mermaidJs: '/* fake */',
        );
        await renderer.prewarm();

        const userSource =
            '%%{init: {"theme":"forest"}}%%\nflowchart LR; A-->B';
        channel.scriptResult('flowchart LR; A-->B', 'svg');
        await renderer.render(userSource);

        expect(channel.observedSources, hasLength(1));
        expect(
          channel.observedSources.single,
          equals(userSource),
          reason:
              'An empty initDirective means "do not override" — the '
              'user-authored directive must reach mermaid.js untouched.',
        );
      },
    );

    test(
      'should queue a render() call issued before prewarm() completes, '
      'initialise once, then drain the request against the real channel',
      () async {
        final channel = _DelayedInitializingChannel();
        final renderer = MermaidRendererImpl(
          channel: channel,
          mermaidJs: '/* fake */',
        );

        // Kick off prewarm without awaiting it — the channel's
        // initialise future is pending, so the renderer is stuck
        // between "uninitialised" and "ready".
        final prewarmFuture = renderer.prewarm();

        channel.scriptResult('flowchart LR; A-->B', 'early-svg');
        // Fire a render() while initialisation is still in flight.
        // The renderer's internal _pump must queue the request and
        // only drain it after the channel becomes ready.
        final renderFuture = renderer.render('flowchart LR; A-->B');

        // Release the channel's initialise future so both the
        // outstanding prewarm AND the pending render can make
        // forward progress.
        channel.completeInitialize();

        await prewarmFuture;
        final result = await renderFuture;

        expect(result, isA<MermaidRenderSuccess>());
        expect((result as MermaidRenderSuccess).svg, 'early-svg');
        expect(
          channel.initializeCallCount,
          1,
          reason:
              'Concurrent prewarm / render must share a single channel '
              'initialisation, not race and issue two.',
        );
        expect(
          channel.renderCallCount,
          1,
          reason:
              'The render request must be drained exactly once against '
              'the channel, after the pump notices initialisation is '
              'complete.',
        );
      },
    );

    test('should give two distinct initDirectives for the same source distinct '
        'cache slots', () async {
      final channel = _FakeChannel();
      final renderer = MermaidRendererImpl(
        channel: channel,
        mermaidJs: '/* fake */',
      );
      await renderer.prewarm();

      channel.scriptResult('flowchart LR; X-->Y', 'svg');
      await renderer.render(
        'flowchart LR; X-->Y',
        initDirective:
            '%%{init: {"theme":"base","themeVariables":{"primaryColor":"#111111"}}}%%\n',
      );
      await renderer.render(
        'flowchart LR; X-->Y',
        initDirective:
            '%%{init: {"theme":"base","themeVariables":{"primaryColor":"#eeeeee"}}}%%\n',
      );

      expect(
        channel.renderCallCount,
        2,
        reason:
            'Two different init directives over the same source must '
            'occupy distinct cache slots because the directive is part '
            'of the hashed input.',
      );
    });
  });
}

/// Fake [MermaidJsChannel] that lets a test pre-register canned
/// results keyed by source substring. Each `render` call looks up
/// the first scripted key that the observed source contains and
/// posts the matching reply via the `onResult` callback registered
/// in [initialize].
///
/// Matching by substring (rather than exact equality) is deliberate:
/// [MermaidRendererImpl] prepends a `%%{init: {...}}%%` directive
/// to every source before handing it to the channel, so an exact
/// match on the raw user source would fail. Tests script with the
/// original source and still find the right reply regardless of
/// the directive the impl stamps on top.
class _FakeChannel implements MermaidJsChannel {
  void Function(Map<String, Object?> message)? _onResult;
  final List<_ScriptedReply> _replies = <_ScriptedReply>[];
  final List<String> observedSources = <String>[];
  int renderCallCount = 0;

  void scriptResult(String sourceContains, String svg) {
    _replies.add(_ScriptedReply(match: sourceContains, svg: svg));
  }

  void scriptError(String sourceContains, String error) {
    _replies.add(_ScriptedReply(match: sourceContains, error: error));
  }

  @override
  Future<void> initialize({
    required String html,
    required void Function(Map<String, Object?> message) onResult,
  }) async {
    _onResult = onResult;
  }

  @override
  Future<void> render({required String id, required String source}) async {
    renderCallCount += 1;
    observedSources.add(source);
    final reply = _replies.firstWhere(
      (r) => source.contains(r.match),
      orElse: () => _ScriptedReply(match: '', error: 'no scripted reply'),
    );
    final callback = _onResult;
    if (callback == null) {
      return;
    }
    // Schedule the reply on the next microtask so the call site has
    // a chance to await the matching completer.
    scheduleMicrotask(() {
      if (reply.error != null) {
        callback({'id': id, 'error': reply.error});
        return;
      }
      callback({'id': id, 'svg': reply.svg});
    });
  }

  @override
  Future<void> dispose() async {
    _onResult = null;
  }
}

class _ScriptedReply {
  _ScriptedReply({required this.match, this.svg, this.error});

  /// Substring that must appear in the observed source for this
  /// reply to be considered a match.
  final String match;
  final String? svg;
  final String? error;
}

/// Channel that throws on initialize so we can exercise the
/// permanent-failure path.
class _FailingChannel implements MermaidJsChannel {
  _FailingChannel(this.error);

  final MermaidJsChannelException error;
  int renderCallCount = 0;

  @override
  Future<void> initialize({
    required String html,
    required void Function(Map<String, Object?> message) onResult,
  }) async {
    throw error;
  }

  @override
  Future<void> render({required String id, required String source}) async {
    renderCallCount += 1;
  }

  @override
  Future<void> dispose() async {}
}

/// Channel whose [initialize] returns a [Future] that only resolves
/// when the test calls [completeInitialize]. Used to simulate a
/// slow WebView warm-up so we can land a `render()` call while
/// the renderer is still mid-initialisation and verify the queue
/// drains correctly once the channel becomes ready.
final class _DelayedInitializingChannel implements MermaidJsChannel {
  final Completer<void> _initCompleter = Completer<void>();
  void Function(Map<String, Object?> message)? _onResult;
  final List<_ScriptedReply> _replies = <_ScriptedReply>[];
  int initializeCallCount = 0;
  int renderCallCount = 0;

  void completeInitialize() {
    if (!_initCompleter.isCompleted) {
      _initCompleter.complete();
    }
  }

  void scriptResult(String sourceContains, String svg) {
    _replies.add(_ScriptedReply(match: sourceContains, svg: svg));
  }

  @override
  Future<void> initialize({
    required String html,
    required void Function(Map<String, Object?> message) onResult,
  }) {
    initializeCallCount += 1;
    _onResult = onResult;
    return _initCompleter.future;
  }

  @override
  Future<void> render({required String id, required String source}) async {
    renderCallCount += 1;
    final reply = _replies.firstWhere(
      (r) => source.contains(r.match),
      orElse: () => _ScriptedReply(match: '', error: 'no scripted reply'),
    );
    final callback = _onResult;
    if (callback == null) {
      return;
    }
    scheduleMicrotask(() {
      if (reply.error != null) {
        callback({'id': id, 'error': reply.error});
        return;
      }
      callback({'id': id, 'svg': reply.svg});
    });
  }

  @override
  Future<void> dispose() async {}
}
