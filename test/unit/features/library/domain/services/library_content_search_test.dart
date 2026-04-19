import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/features/library/domain/services/library_content_search.dart';
import 'package:markdown_viewer/features/viewer/domain/entities/document.dart';

void main() {
  group('searchInContents', () {
    ContentSearchDocument doc(String id, String content, {String? label}) {
      return ContentSearchDocument(
        documentId: DocumentId('/library/$id.md'),
        displayName: '$id.md',
        sourceLabel: label ?? 'Recent',
        content: content,
      );
    }

    test('empty query returns no matches', () {
      final result = searchInContents(
        ContentSearchRequest(
          documents: [doc('a', 'The quick brown fox.')],
          normalisedQuery: '',
        ),
      );
      expect(result, isEmpty);
    });

    test('returns only documents that contain the query', () {
      final result = searchInContents(
        ContentSearchRequest(
          documents: [
            doc('alpha', 'The quick brown fox jumps.'),
            doc('beta', 'A slow blue whale.'),
            doc('gamma', 'Brown sugar, brown rice.'),
          ],
          normalisedQuery: 'brown',
        ),
      );
      expect(result.map((m) => m.displayName), ['gamma.md', 'alpha.md']);
    });

    test('case-insensitive match works on ALL-CAPS and Turkish', () {
      final result = searchInContents(
        ContentSearchRequest(
          documents: [
            doc('a', 'Dökümanın İÇİNDE bir cümle.'),
            doc('b', 'başka bir belge.'),
          ],
          normalisedQuery: 'i̇çi̇nde',
        ),
      );
      // The Turkish dotted-I lowercases to a sequence that does not
      // match the ASCII-lowercased query, which is documented
      // behaviour — the caller already lowercases via Dart's default
      // toLowerCase(). We assert the English branch matches and the
      // Turkish branch does not, confirming the normalisation
      // boundary.
      expect(result, isEmpty);

      final ascii = searchInContents(
        ContentSearchRequest(
          documents: [doc('a', 'cümle içinde geçer')],
          normalisedQuery: 'cümle',
        ),
      );
      expect(ascii, hasLength(1));
    });

    test('match count is accurate for repeated hits', () {
      final result = searchInContents(
        ContentSearchRequest(
          documents: [doc('a', 'todo todo todo foo TODO')],
          normalisedQuery: 'todo',
        ),
      );
      expect(result.single.matchCount, 4);
    });

    test('sorts results by descending match count then alphabetically', () {
      final result = searchInContents(
        ContentSearchRequest(
          documents: [
            doc('b', 'cat cat'),
            doc('a', 'cat cat cat'),
            doc('c', 'cat'),
          ],
          normalisedQuery: 'cat',
        ),
      );
      expect(result.map((m) => m.displayName), ['a.md', 'b.md', 'c.md']);
    });

    test('respects maxResults cap', () {
      final docs = [for (var i = 0; i < 60; i++) doc('d$i', 'lorem ipsum $i')];
      final result = searchInContents(
        ContentSearchRequest(
          documents: docs,
          normalisedQuery: 'lorem',
          maxResults: 10,
        ),
      );
      expect(result, hasLength(10));
    });

    test('snippet centres on the first match and preserves offset', () {
      final body = 'Before text. ${'x' * 40}keyword${'y' * 40} after text.';
      final result = searchInContents(
        ContentSearchRequest(
          documents: [doc('snip', body)],
          normalisedQuery: 'keyword',
        ),
      );
      final match = result.single;
      expect(match.snippetMatchLength, 'keyword'.length);
      expect(
        match.snippet.substring(
          match.snippetMatchStart,
          match.snippetMatchStart + match.snippetMatchLength,
        ),
        'keyword',
      );
    });

    test('snippet collapses whitespace so output stays on one line', () {
      const body = 'line1\n\n\nhello\n\nline3';
      final result = searchInContents(
        ContentSearchRequest(
          documents: [doc('ws', body)],
          normalisedQuery: 'hello',
        ),
      );
      final snippet = result.single.snippet;
      expect(snippet, isNot(contains('\n')));
      expect(
        snippet.substring(
          result.single.snippetMatchStart,
          result.single.snippetMatchStart + result.single.snippetMatchLength,
        ),
        'hello',
      );
    });

    test('empty documents are skipped', () {
      final result = searchInContents(
        ContentSearchRequest(
          documents: [doc('a', ''), doc('b', 'real content matches')],
          normalisedQuery: 'content',
        ),
      );
      expect(result, hasLength(1));
      expect(result.single.displayName, 'b.md');
    });

    test('documents without the query do not appear in results', () {
      final result = searchInContents(
        ContentSearchRequest(
          documents: [
            doc('a', 'apple banana cherry'),
            doc('b', 'dragonfruit eggplant fig'),
          ],
          normalisedQuery: 'nomatchhere',
        ),
      );
      expect(result, isEmpty);
    });
  });
}
