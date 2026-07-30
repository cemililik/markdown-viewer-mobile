import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/features/viewer/application/anchor_resolver.dart';
import 'package:markdown_viewer/features/viewer/domain/entities/document.dart';

HeadingRef _h(String text, String anchor, {int level = 2}) =>
    HeadingRef(level: level, text: text, anchor: anchor, blockIndex: 0);

void main() {
  group('resolveAnchor', () {
    final headings = [
      _h('Introduction', 'introduction'),
      _h('My Heading', 'my-heading'),
      _h('Kullanıcı Ayarları', 'kullanıcı-ayarları'),
      _h('Third Step', 'third-step', level: 3),
    ];

    test(
      'should confirm that plain lowercase slug matches the corresponding heading when the behavior is exercised',
      () {
        final result = resolveAnchor(href: '#my-heading', headings: headings);
        expect(result?.text, 'My Heading');
      },
    );

    test(
      'should confirm that mismatched case still resolves (GitHub parity) when the behavior is exercised',
      () {
        final result = resolveAnchor(href: '#My-Heading', headings: headings);
        expect(result?.text, 'My Heading');
      },
    );

    test(
      'should confirm that percent-encoded space resolves (e.g. `%20`) when the behavior is exercised',
      () {
        // A renderer that URL-encodes the slug instead of hyphenating
        // it (`my%20heading`) must still land on the same target.
        final result = resolveAnchor(
          href: '#my%20heading',
          headings: [_h('my heading', 'my heading')],
        );
        expect(result?.anchor, 'my heading');
      },
    );

    test(
      'should confirm that plus-sign-as-space (`+`) resolves when the behavior is exercised',
      () {
        final result = resolveAnchor(
          href: '#my+heading',
          headings: [_h('my heading', 'my heading')],
        );
        expect(result?.anchor, 'my heading');
      },
    );

    test(
      'should confirm that percent-encoded space-separated href resolves via slug pipeline when the behavior is exercised',
      () {
        // A renderer that URL-encodes a human-readable fragment
        // (`#My Heading With Spaces` → `#My%20Heading%20With%20Spaces`)
        // must land on the slugified heading anchor. Exercises the
        // new slugify() candidate added to resolveAnchor.
        final r = resolveAnchor(
          href: '#My%20Heading%20With%20Spaces',
          headings: [_h('My Heading With Spaces', 'my-heading-with-spaces')],
        );
        expect(r?.anchor, 'my-heading-with-spaces');
      },
    );

    test(
      'should confirm that percent-encoded unicode slug resolves when the behavior is exercised',
      () {
        // `kullanıcı-ayarları` — Turkish characters encoded as
        // `kullan%C4%B1c%C4%B1-ayarlar%C4%B1`.
        final result = resolveAnchor(
          href: '#kullan%C4%B1c%C4%B1-ayarlar%C4%B1',
          headings: headings,
        );
        expect(result?.anchor, 'kullanıcı-ayarları');
      },
    );

    test('should return null when no heading matches', () {
      final result = resolveAnchor(href: '#nowhere', headings: headings);
      expect(result, isNull);
    });

    test(
      'should return null for non-anchor href when the behavior is exercised',
      () {
        final result = resolveAnchor(
          href: 'https://example.com',
          headings: headings,
        );
        expect(result, isNull);
      },
    );

    test(
      'should confirm that case mismatch at several mix points resolves to same slug when the behavior is exercised',
      () {
        // Covers the path where `_onLinkTap` (or a GitHub renderer that
        // preserved the author's capitalisation in the href) hands us
        // a mixed-case href that must still reach the lowercased slug.
        expect(
          resolveAnchor(href: '#My-Heading', headings: headings)?.anchor,
          'my-heading',
        );
        expect(
          resolveAnchor(href: '#MY-HEADING', headings: headings)?.anchor,
          'my-heading',
        );
      },
    );

    test(
      'should confirm that empty anchor (`#` alone) returns null when the behavior is exercised',
      () {
        final result = resolveAnchor(href: '#', headings: headings);
        expect(result, isNull);
      },
    );

    test(
      'should confirm that malformed percent escape falls through to raw comparison when the behavior is exercised',
      () {
        // `%ZZ` is not a valid encoded byte. `decodeComponent` throws;
        // we swallow and keep the raw path. A heading with that literal
        // anchor still resolves.
        final result = resolveAnchor(
          href: '#literal%ZZ',
          headings: [_h('weird', 'literal%zz')],
        );
        expect(result?.anchor, 'literal%zz');
      },
    );

    test(
      'should confirm that first match wins when two headings share a slug',
      () {
        final result = resolveAnchor(
          href: '#dup',
          headings: [_h('First', 'dup'), _h('Second', 'dup')],
        );
        expect(result?.text, 'First');
      },
    );
  });
}
