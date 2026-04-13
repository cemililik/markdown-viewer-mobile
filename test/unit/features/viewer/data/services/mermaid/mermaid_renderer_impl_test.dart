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
      'should prepend the mermaid dark init directive when theme is dark',
      () async {
        final channel = _FakeChannel();
        final renderer = MermaidRendererImpl(
          channel: channel,
          mermaidJs: '/* fake */',
        );
        await renderer.prewarm();

        channel.scriptResult('flowchart LR; A-->B', 'svg');
        await renderer.render(
          'flowchart LR; A-->B',
          theme: MermaidDiagramTheme.dark,
        );

        expect(channel.observedSources, hasLength(1));
        expect(
          channel.observedSources.single,
          startsWith("%%{init: {'theme':'dark'}}%%\n"),
          reason:
              'The renderer must prepend the dark init directive to the '
              'user source so mermaid.js picks the dark palette without '
              'us having to call mermaid.initialize a second time on '
              'the sandbox page.',
        );
      },
    );

    test('should place light and dark renders of the same source in distinct '
        'cache slots', () async {
      final channel = _FakeChannel();
      final renderer = MermaidRendererImpl(
        channel: channel,
        mermaidJs: '/* fake */',
      );
      await renderer.prewarm();

      channel.scriptResult('flowchart LR; X-->Y', 'svg');
      await renderer.render('flowchart LR; X-->Y');
      await renderer.render(
        'flowchart LR; X-->Y',
        theme: MermaidDiagramTheme.dark,
      );

      expect(
        channel.renderCallCount,
        2,
        reason:
            'Light and dark variants of the same source must be rendered '
            'separately — their cache keys differ because the theme '
            'directive is baked into the hashed source.',
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
