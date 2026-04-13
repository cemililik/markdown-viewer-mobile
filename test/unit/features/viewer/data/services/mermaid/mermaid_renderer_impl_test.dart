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
  });
}

/// Fake [MermaidJsChannel] that lets a test pre-register canned
/// results keyed by source string. Each `render` call looks up the
/// source in [_replies] and posts the matching reply via the
/// `onResult` callback registered in [initialize].
class _FakeChannel implements MermaidJsChannel {
  void Function(Map<String, Object?> message)? _onResult;
  final Map<String, _ScriptedReply> _replies = <String, _ScriptedReply>{};
  int renderCallCount = 0;

  void scriptResult(String source, String svg) {
    _replies[source] = _ScriptedReply(svg: svg);
  }

  void scriptError(String source, String error) {
    _replies[source] = _ScriptedReply(error: error);
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
    final reply = _replies[source];
    final callback = _onResult;
    if (callback == null) {
      return;
    }
    // Schedule the reply on the next microtask so the call site has
    // a chance to await the matching completer.
    scheduleMicrotask(() {
      if (reply == null) {
        callback({'id': id, 'error': 'no scripted reply for source'});
        return;
      }
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
  _ScriptedReply({this.svg, this.error});

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
