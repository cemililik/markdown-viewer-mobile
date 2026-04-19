import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/features/viewer/data/services/mermaid/mermaid_js_channel.dart';
import 'package:markdown_viewer/features/viewer/data/services/mermaid/mermaid_renderer_impl.dart';
import 'package:markdown_viewer/features/viewer/domain/services/mermaid_renderer.dart';

/// Minimal valid 1×1 PNG used as a placeholder payload for every
/// scripted channel reply. Tests do not inspect the pixels — they
/// only care that `base64Decode` accepts the string and that the
/// byte list round-trips through the cache.
const String _tinyPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNgAAIAAAUAAen63/AAAAAASUVORK5CYII=';

void main() {
  group('MermaidRendererImpl', () {
    test('should hit the channel exactly once for a repeated source thanks to '
        'the cache', () async {
      final channel = _FakeChannel();
      final renderer = MermaidRendererImpl(
        channel: channel,
        mermaidJs: '/* fake */',
      );
      await renderer.prewarm();

      channel.scriptResult(
        'flowchart LR; A-->B',
        png: _tinyPngBase64,
        width: 120,
        height: 40,
      );
      final first = await renderer.render('flowchart LR; A-->B');
      final second = await renderer.render('flowchart LR; A-->B');

      expect(first, isA<MermaidRenderSuccess>());
      expect((first as MermaidRenderSuccess).width, 120);
      expect(first.height, 40);
      expect(first.pngBytes, isNotEmpty);
      expect(second, isA<MermaidRenderSuccess>());
      expect(
        channel.renderCallCount,
        1,
        reason: 'Second render call must be served from the LRU cache.',
      );
    });

    test('should collapse two concurrent identical render calls to one channel '
        'eval', () async {
      final channel = _FakeChannel();
      final renderer = MermaidRendererImpl(
        channel: channel,
        mermaidJs: '/* fake */',
      );
      await renderer.prewarm();

      channel.scriptResult(
        'graph TD; X-->Y',
        png: _tinyPngBase64,
        width: 100,
        height: 50,
      );
      final futureA = renderer.render('graph TD; X-->Y');
      final futureB = renderer.render('graph TD; X-->Y');
      final results = await Future.wait([futureA, futureB]);

      expect(results.every((r) => r is MermaidRenderSuccess), isTrue);
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

        channel.scriptResult('A', png: _tinyPngBase64, width: 50, height: 50);
        channel.scriptResult('B', png: _tinyPngBase64, width: 60, height: 60);

        final a = await renderer.render('A');
        final b = await renderer.render('B');

        expect(a, isA<MermaidRenderSuccess>());
        expect(b, isA<MermaidRenderSuccess>());
        expect((a as MermaidRenderSuccess).width, 50);
        expect((b as MermaidRenderSuccess).width, 60);
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
              'A permanently failed renderer must not invoke the channel '
              'for render requests.',
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

    test('should prepend a non-empty initDirective verbatim to a source with '
        'no frontmatter', () async {
      final channel = _FakeChannel();
      final renderer = MermaidRendererImpl(
        channel: channel,
        mermaidJs: '/* fake */',
      );
      await renderer.prewarm();

      const directive =
          '%%{init: {"theme":"base","themeVariables":{"primaryColor":"#aabbcc"}}}%%\n';
      channel.scriptResult(
        'flowchart LR; A-->B',
        png: _tinyPngBase64,
        width: 100,
        height: 50,
      );
      await renderer.render('flowchart LR; A-->B', initDirective: directive);

      expect(channel.observedSources, hasLength(1));
      expect(
        channel.observedSources.single,
        startsWith(directive),
        reason:
            'A source without YAML frontmatter must keep the simple '
            'prepend behaviour.',
      );
    });

    test('should splice the init directive AFTER a leading YAML frontmatter '
        'block so mermaid still sees `---` on line 1', () async {
      final channel = _FakeChannel();
      final renderer = MermaidRendererImpl(
        channel: channel,
        mermaidJs: '/* fake */',
      );
      await renderer.prewarm();

      const directive =
          '%%{init: {"theme":"base","themeVariables":{"primaryColor":"#abcdef"}}}%%\n';
      const userSource =
          '---\ntitle: Architecture Evolution\n---\nflowchart LR\n  A --> B';
      channel.scriptResult(
        'flowchart LR',
        png: _tinyPngBase64,
        width: 100,
        height: 50,
      );
      await renderer.render(userSource, initDirective: directive);

      expect(channel.observedSources, hasLength(1));
      final observed = channel.observedSources.single;
      expect(
        observed,
        startsWith('---\n'),
        reason:
            'The YAML frontmatter opener must remain at the absolute '
            'start of the source — otherwise mermaid fails to parse '
            'the frontmatter and the diagram body.',
      );
      expect(
        observed,
        contains(directive),
        reason: 'The init directive must still reach mermaid.',
      );
      final directiveIdx = observed.indexOf(directive);
      final closingIdx = observed.indexOf('\n---\n');
      expect(
        directiveIdx,
        greaterThan(closingIdx),
        reason:
            'The directive must be spliced in after the frontmatter '
            'closer, not prepended before the opener.',
      );
    });

    test(
      'should leave the user-authored directive alone and force antiscript '
      'via a trailing override directive when initDirective is empty',
      () async {
        final channel = _FakeChannel();
        final renderer = MermaidRendererImpl(
          channel: channel,
          mermaidJs: '/* fake */',
        );
        await renderer.prewarm();

        const userSource =
            '%%{init: {"theme":"forest"}}%%\nflowchart LR; A-->B';
        channel.scriptResult(
          'flowchart LR; A-->B',
          png: _tinyPngBase64,
          width: 100,
          height: 50,
        );
        await renderer.render(userSource);

        expect(channel.observedSources, hasLength(1));
        final observed = channel.observedSources.single;
        expect(
          observed,
          startsWith(userSource),
          reason:
              'An empty initDirective means "do not override" the '
              "user-authored directive — the original source must reach "
              'mermaid.js intact at the top of the payload.',
        );
        expect(
          observed,
          contains("'securityLevel': 'antiscript'"),
          reason:
              'A trailing override directive unconditionally pins '
              "`securityLevel: 'antiscript'` so mermaid's last-write-wins "
              'merge cannot let a user-supplied loose value slip through. '
              'Reference: security-review SR-20260419-014.',
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

        final prewarmFuture = renderer.prewarm();

        channel.scriptResult(
          'flowchart LR; A-->B',
          png: _tinyPngBase64,
          width: 100,
          height: 50,
        );
        final renderFuture = renderer.render('flowchart LR; A-->B');

        channel.completeInitialize();

        await prewarmFuture;
        final result = await renderFuture;

        expect(result, isA<MermaidRenderSuccess>());
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

      channel.scriptResult(
        'flowchart LR; X-->Y',
        png: _tinyPngBase64,
        width: 100,
        height: 50,
      );
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

    test(
      'should reject a result with a zero-sized bitmap as a failure',
      () async {
        final channel = _FakeChannel();
        final renderer = MermaidRendererImpl(
          channel: channel,
          mermaidJs: '/* fake */',
        );
        await renderer.prewarm();

        channel.scriptResult(
          'flowchart LR; A-->B',
          png: _tinyPngBase64,
          width: 0,
          height: 0,
        );
        final result = await renderer.render('flowchart LR; A-->B');

        expect(result, isA<MermaidRenderFailure>());
      },
    );
  });
}

/// Fake [MermaidJsChannel] that lets a test pre-register canned
/// PNG-base64 results keyed by source substring. Each `render`
/// call looks up the first scripted key that the observed source
/// contains and posts the matching reply via the `onResult`
/// callback registered in [initialize].
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

  void scriptResult(
    String sourceContains, {
    required String png,
    required double width,
    required double height,
  }) {
    _replies.add(
      _ScriptedReply(
        match: sourceContains,
        png: png,
        width: width,
        height: height,
      ),
    );
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
    scheduleMicrotask(() {
      if (reply.error != null) {
        callback({'id': id, 'error': reply.error});
        return;
      }
      callback({
        'id': id,
        'png': reply.png,
        'width': reply.width,
        'height': reply.height,
      });
    });
  }

  @override
  Future<void> dispose() async {
    _onResult = null;
  }
}

class _ScriptedReply {
  _ScriptedReply({
    required this.match,
    this.png,
    this.width,
    this.height,
    this.error,
  });

  final String match;
  final String? png;
  final double? width;
  final double? height;
  final String? error;
}

/// Channel that throws on initialize so we can exercise the
/// permanent-failure path.
final class _FailingChannel implements MermaidJsChannel {
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

  void scriptResult(
    String sourceContains, {
    required String png,
    required double width,
    required double height,
  }) {
    _replies.add(
      _ScriptedReply(
        match: sourceContains,
        png: png,
        width: width,
        height: height,
      ),
    );
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
      callback({
        'id': id,
        'png': reply.png,
        'width': reply.width,
        'height': reply.height,
      });
    });
  }

  @override
  Future<void> dispose() async {}
}
