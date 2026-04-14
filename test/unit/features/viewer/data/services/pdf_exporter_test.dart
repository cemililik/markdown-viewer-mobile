import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/features/viewer/data/services/pdf_exporter.dart';

void main() {
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
