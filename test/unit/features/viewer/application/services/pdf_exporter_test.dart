import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/features/viewer/application/services/pdf_exporter.dart';

// Minimal 1×1 RGBA PNG (70 bytes).
// Verified with: base64 iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQ...
final _onePxPng = Uint8List.fromList(const <int>[
  137,
  80,
  78,
  71,
  13,
  10,
  26,
  10,
  0,
  0,
  0,
  13,
  73,
  72,
  68,
  82,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  1,
  8,
  6,
  0,
  0,
  0,
  31,
  21,
  196,
  137,
  0,
  0,
  0,
  13,
  73,
  68,
  65,
  84,
  120,
  218,
  99,
  100,
  248,
  207,
  80,
  15,
  0,
  3,
  134,
  1,
  128,
  90,
  52,
  125,
  107,
  0,
  0,
  0,
  0,
  73,
  69,
  78,
  68,
  174,
  66,
  96,
  130,
]);

void main() {
  group('exportToPdf — mermaid image embedding', () {
    const mermaidSource = '''
# Test

```mermaid
graph TD
  A --> B
```
''';

    // The trimmed diagram source that _codeBlock will look up in the map.
    const diagramCode = 'graph TD\n  A --> B';

    test(
      'returns valid PDF bytes when mermaidImages is empty (placeholder path)',
      () async {
        final bytes = await exportToPdf('Test', mermaidSource);
        expect(bytes, isNotEmpty);
        // PDF files always start with "%PDF"
        expect(
          String.fromCharCodes(bytes.take(4)),
          equals('%PDF'),
          reason: 'exportToPdf must return a valid PDF byte stream',
        );
      },
    );

    test(
      'returns valid PDF bytes when a pre-rendered PNG is supplied',
      () async {
        final bytes = await exportToPdf(
          'Test',
          mermaidSource,
          mermaidImages: {diagramCode: _onePxPng},
        );
        expect(bytes, isNotEmpty);
        expect(String.fromCharCodes(bytes.take(4)), equals('%PDF'));
      },
    );

    test('unrecognised diagram source falls back to placeholder', () async {
      // Supply a PNG for a different source — the exporter must not crash
      // and must still produce a valid PDF using the placeholder path.
      final bytes = await exportToPdf(
        'Test',
        mermaidSource,
        mermaidImages: {'different source entirely': _onePxPng},
      );
      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(4)), equals('%PDF'));
    });
  });

  group('extractPdfTitle', () {
    test('returns the first H1 heading when present', () {
      const source = '# My Document\n\nSome body text.';
      expect(extractPdfTitle(source, 'fallback'), 'My Document');
    });

    test('returns the normalized fallback when no H1 is present', () {
      const source = '## Section\n\nNo top-level heading.';
      // The fallback is run through _cleanText so HTML entities and
      // non-Latin-1 characters are substituted just like heading text.
      expect(extractPdfTitle(source, 'fallback'), 'fallback');
    });

    test('normalizes fallback through the same cleaning path as H1 text', () {
      // An em-dash in the fallback should be replaced with '--' so the
      // PDF output is consistent regardless of whether the title came
      // from the document or was supplied externally.
      expect(
        extractPdfTitle('No heading.', 'Title\u2014Subtitle'),
        'Title--Subtitle',
      );
    });
  });

  group('Latin Extended-A transliteration', () {
    test('transliterates Turkish characters', () {
      // ğ Ğ ş Ş ı İ are all > U+00FF and would produce glyph boxes in the
      // built-in Helvetica font without explicit mapping.
      // ü (U+00FC) is within Latin-1 and passes through unchanged.
      expect(
        extractPdfTitle('No heading.', 'Ğüzel bir şey — ı ve İ'),
        'Güzel bir sey -- i ve I',
      );
    });

    test('transliterates Polish characters', () {
      // ó (U+00F3) is within Latin-1 and passes through unchanged.
      expect(
        extractPdfTitle('No heading.', 'Łódź — Ąą Ćć Ęę Śś Źź Żż Ńń'),
        'Lódz -- Aa Cc Ee Ss Zz Zz Nn',
      );
    });

    test('transliterates Czech characters', () {
      expect(
        extractPdfTitle('No heading.', 'Čeština: Čč Šš Žž Řř Ěě Ďď Ťť'),
        'Cestina: Cc Ss Zz Rr Ee Dd Tt',
      );
    });

    test('catch-all strips remaining non-Latin-1 characters', () {
      // Any character above U+00FF not covered by the explicit table
      // is removed rather than producing a glyph box.
      expect(
        extractPdfTitle('No heading.', 'A\u0400B'), // U+0400 Cyrillic
        'AB',
      );
    });
  });

  group('extractMermaidCodes — HTML entity decoding', () {
    test('decodes &lt; &gt; &quot; in fenced mermaid code blocks', () {
      // The markdown parser HTML-escapes raw <, >, " characters inside
      // fenced code blocks. Mermaid's lexer rejects &lt;/&gt;/&quot;
      // as unrecognized text, so extractMermaidCodes must decode them
      // back to the original characters before handing the source to
      // the renderer.
      const source = '''
```mermaid
graph LR
    A["LLaMA<br/>Factory"] --> B["Multi<br/>GPU"]
    subgraph "ForgeLM Unique"
        C[Safety]
    end
```
''';
      final codes = extractMermaidCodes(source);
      expect(codes, hasLength(1));
      expect(codes.first, contains('<br/>'));
      expect(codes.first, contains('"LLaMA<br/>Factory"'));
      expect(codes.first, contains('subgraph "ForgeLM Unique"'));
      expect(codes.first, isNot(contains('&lt;')));
      expect(codes.first, isNot(contains('&gt;')));
      expect(codes.first, isNot(contains('&quot;')));
    });

    test('preserves literal entity text via amp-last decode order', () {
      // If an author writes the literal five-character sequence "&lt;"
      // inside a mermaid label, markdown stores it as "&amp;lt;" (the
      // "&" is itself escaped). Decoding &lt; first and &amp; last
      // yields "&lt;" — exactly what the author wrote — rather than
      // collapsing the whole thing to "<".
      const source = '''
```mermaid
graph LR
    A[Shows &lt; as text]
```
''';
      final codes = extractMermaidCodes(source);
      expect(codes, hasLength(1));
      expect(codes.first, contains('&lt;'));
      expect(codes.first, isNot(contains('<')));
    });

    test('leaves plain-ASCII diagrams untouched', () {
      const source = '''
```mermaid
mindmap
  root((Root))
    Branch A
    Branch B
```
''';
      final codes = extractMermaidCodes(source);
      expect(codes, hasLength(1));
      expect(
        codes.first,
        equals('mindmap\n  root((Root))\n    Branch A\n    Branch B'),
      );
    });
  });

  group('fire-emoji normalization', () {
    test('replaces 🔥 (U+1F525) with [fire] via extractPdfTitle fallback', () {
      // _cleanText is private; exercise it through extractPdfTitle's fallback
      // path (no H1 in source → fallback runs through the same cleaning
      // pipeline used for heading text).
      expect(
        extractPdfTitle('No heading here.', 'Title \u{1F525}'),
        'Title [fire]',
      );
    });

    test('replaces 🔥 in H1 heading text', () {
      const source = '# Hot \u{1F525} Title\n\nBody text.';
      expect(extractPdfTitle(source, 'fallback'), 'Hot [fire] Title');
    });
  });
}
