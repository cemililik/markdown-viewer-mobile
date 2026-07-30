import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/features/library/application/preview_extractor.dart';

void main() {
  group('extractPreviewSnippet', () {
    test(
      'should return null for an empty document when the behavior is exercised',
      () {
        expect(extractPreviewSnippet(''), isNull);
      },
    );

    test(
      'should return null for a document with only headings when the behavior is exercised',
      () {
        const source = '# Heading\n\n## Another heading\n';
        expect(extractPreviewSnippet(source), isNull);
      },
    );

    test(
      'should return the first paragraph below a heading when the behavior is exercised',
      () {
        const source =
            '# Title\n\nFirst real sentence of the doc.\n\n'
            'Second paragraph.';
        expect(
          extractPreviewSnippet(source),
          'First real sentence of the doc.',
        );
      },
    );

    test(
      'should strip inline markdown markup from the preview when the behavior is exercised',
      () {
        const source =
            '# Title\n\n'
            'Combine **bold**, *italic*, `code`, and [a link](https://x).';
        expect(
          extractPreviewSnippet(source),
          'Combine bold, italic, code, and a link.',
        );
      },
    );

    test(
      'should skip fenced code blocks entirely when the behavior is exercised',
      () {
        const source =
            '# Title\n\n'
            '```dart\nvoid main() {}\n```\n\n'
            'Prose after the fence.';
        expect(extractPreviewSnippet(source), 'Prose after the fence.');
      },
    );

    test(
      'should skip a leading YAML frontmatter block when the behavior is exercised',
      () {
        const source =
            '---\n'
            'title: My doc\n'
            'tags: [a, b]\n'
            '---\n\n'
            '# Heading\n\n'
            'Prose after the frontmatter.';
        expect(extractPreviewSnippet(source), 'Prose after the frontmatter.');
      },
    );

    test(
      'should skip blockquotes and list markers when the behavior is exercised',
      () {
        const source =
            '# Title\n\n'
            '> a quote\n\n'
            '- item one\n'
            '- item two\n\n'
            'Finally, the prose.';
        expect(extractPreviewSnippet(source), 'Finally, the prose.');
      },
    );

    test(
      'should truncate long paragraphs to the max length with an ellipsis when the behavior is exercised',
      () {
        final source = '# Title\n\n${'word ' * 200}';
        final preview = extractPreviewSnippet(source, maxPreviewLength: 40)!;
        expect(preview.length, lessThanOrEqualTo(41)); // 40 chars + ellipsis
        expect(preview.endsWith('…'), isTrue);
      },
    );

    test(
      'should return null for a document that is only a fenced code block when the behavior is exercised',
      () {
        const source = '```dart\nvoid main() {}\n```\n';
        expect(extractPreviewSnippet(source), isNull);
      },
    );

    test(
      'should collapse multi-space runs into a single space when the behavior is exercised',
      () {
        const source = '# Title\n\nfoo\t bar   baz\n';
        expect(extractPreviewSnippet(source), 'foo bar baz');
      },
    );
  });
}
