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

    test('plain lowercase slug matches the corresponding heading', () {
      final result = resolveAnchor(href: '#my-heading', headings: headings);
      expect(result?.text, 'My Heading');
    });

    test('mismatched case still resolves (GitHub parity)', () {
      final result = resolveAnchor(href: '#My-Heading', headings: headings);
      expect(result?.text, 'My Heading');
    });

    test('percent-encoded space resolves (e.g. `%20`)', () {
      // A renderer that URL-encodes the slug instead of hyphenating
      // it (`my%20heading`) must still land on the same target.
      final result = resolveAnchor(
        href: '#my%20heading',
        headings: [_h('my heading', 'my heading')],
      );
      expect(result?.anchor, 'my heading');
    });

    test('plus-sign-as-space (`+`) resolves', () {
      final result = resolveAnchor(
        href: '#my+heading',
        headings: [_h('my heading', 'my heading')],
      );
      expect(result?.anchor, 'my heading');
    });

    test('percent-encoded unicode slug resolves', () {
      // `kullanıcı-ayarları` — Turkish characters encoded as
      // `kullan%C4%B1c%C4%B1-ayarlar%C4%B1`.
      final result = resolveAnchor(
        href: '#kullan%C4%B1c%C4%B1-ayarlar%C4%B1',
        headings: headings,
      );
      expect(result?.anchor, 'kullanıcı-ayarları');
    });

    test('returns null when no heading matches', () {
      final result = resolveAnchor(href: '#nowhere', headings: headings);
      expect(result, isNull);
    });

    test('returns null for non-anchor href', () {
      final result = resolveAnchor(
        href: 'https://example.com',
        headings: headings,
      );
      expect(result, isNull);
    });

    test('case mismatch at several mix points resolves to same slug', () {
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
    });

    test('empty anchor (`#` alone) returns null', () {
      final result = resolveAnchor(href: '#', headings: headings);
      expect(result, isNull);
    });

    test('malformed percent escape falls through to raw comparison', () {
      // `%ZZ` is not a valid encoded byte. `decodeComponent` throws;
      // we swallow and keep the raw path. A heading with that literal
      // anchor still resolves.
      final result = resolveAnchor(
        href: '#literal%ZZ',
        headings: [_h('weird', 'literal%zz')],
      );
      expect(result?.anchor, 'literal%zz');
    });

    test('first match wins when two headings share a slug', () {
      final result = resolveAnchor(
        href: '#dup',
        headings: [_h('First', 'dup'), _h('Second', 'dup')],
      );
      expect(result?.text, 'First');
    });
  });
}
