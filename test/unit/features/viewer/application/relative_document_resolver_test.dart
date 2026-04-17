import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/features/viewer/application/relative_document_resolver.dart';
import 'package:path/path.dart' as p;

void main() {
  // Use a `p.join` to keep the assertions readable on both Unix-style
  // hosts (what the CI runner is) and Windows-style local devs; no
  // test here assumes a specific path separator.
  const currentDoc = '/home/user/docs/guide.md';

  group('resolveRelativeDocument', () {
    test('sibling file resolves to the document-directory path', () {
      final r = resolveRelativeDocument(
        href: 'api.md',
        currentDocumentPath: currentDoc,
      );
      expect(r?.path, p.normalize('/home/user/docs/api.md'));
      expect(r?.fragment, '');
    });

    test('explicit `./` prefix works the same as bare', () {
      final r = resolveRelativeDocument(
        href: './intro.markdown',
        currentDocumentPath: currentDoc,
      );
      expect(r?.path, p.normalize('/home/user/docs/intro.markdown'));
    });

    test('`..` traversal normalises correctly', () {
      final r = resolveRelativeDocument(
        href: '../shared/types.md',
        currentDocumentPath: currentDoc,
      );
      expect(r?.path, p.normalize('/home/user/shared/types.md'));
    });

    test('file + fragment splits the anchor out', () {
      final r = resolveRelativeDocument(
        href: 'guide.md#configuration',
        currentDocumentPath: currentDoc,
      );
      expect(r?.path, p.normalize('/home/user/docs/guide.md'));
      expect(r?.fragment, 'configuration');
    });

    test('empty href returns null', () {
      final r = resolveRelativeDocument(
        href: '',
        currentDocumentPath: currentDoc,
      );
      expect(r, isNull);
    });

    test('pure-anchor href returns null (caller handles anchors)', () {
      final r = resolveRelativeDocument(
        href: '#section',
        currentDocumentPath: currentDoc,
      );
      expect(r, isNull);
    });

    test('absolute path href returns null', () {
      // A schemeless absolute href would let malicious markdown
      // aim at `/etc/passwd` or similar. Refuse by construction.
      final r = resolveRelativeDocument(
        href: '/etc/passwd',
        currentDocumentPath: currentDoc,
      );
      expect(r, isNull);
    });

    test('href with a scheme returns null', () {
      final r = resolveRelativeDocument(
        href: 'https://example.com/doc.md',
        currentDocumentPath: currentDoc,
      );
      expect(r, isNull);
    });

    test('non-markdown extension returns null', () {
      final r = resolveRelativeDocument(
        href: 'logo.png',
        currentDocumentPath: currentDoc,
      );
      expect(r, isNull);
    });

    test('uppercase MARKDOWN extension still resolves', () {
      final r = resolveRelativeDocument(
        href: 'README.MD',
        currentDocumentPath: currentDoc,
      );
      expect(r?.path, p.normalize('/home/user/docs/README.MD'));
    });

    test('percent-encoded filename resolves (with %20 space)', () {
      // Matches the encoding fix in `resolveRelativeDocument`:
      // the href may carry percent-escaped bytes that must be
      // decoded before the extension check and filesystem join.
      final r = resolveRelativeDocument(
        href: 'api%20docs.md',
        currentDocumentPath: currentDoc,
      );
      expect(r?.path, p.normalize('/home/user/docs/api docs.md'));
    });

    test('percent-encoded Unicode filename resolves', () {
      final r = resolveRelativeDocument(
        href: 'kullan%C4%B1c%C4%B1.md',
        currentDocumentPath: currentDoc,
      );
      expect(r?.path, p.normalize('/home/user/docs/kullanıcı.md'));
    });
  });
}
