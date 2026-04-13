import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:markdown_viewer/features/viewer/application/markdown_extensions/math_syntax.dart';

void main() {
  /// Parses [source] with the same parser configuration `MarkdownView`
  /// uses at runtime: GFM extension set, the math block syntax for
  /// display math, and the math inline syntax for `$ … $`.
  List<md.Node> parse(String source) {
    final document = md.Document(
      extensionSet: md.ExtensionSet.gitHubFlavored,
      encodeHtml: false,
      blockSyntaxes: buildMathBlockSyntaxes(),
      inlineSyntaxes: buildMathInlineSyntaxes(),
    );
    return document.parseLines(source.split('\n'));
  }

  /// Depth-first walk that returns every [md.Element] whose tag
  /// matches [tag].
  List<md.Element> findByTag(List<md.Node> nodes, String tag) {
    final out = <md.Element>[];
    void visit(md.Node node) {
      if (node is md.Element) {
        if (node.tag == tag) {
          out.add(node);
        }
        for (final child in node.children ?? const <md.Node>[]) {
          visit(child);
        }
      }
    }

    for (final node in nodes) {
      visit(node);
    }
    return out;
  }

  String plainTextOf(md.Element element) {
    final buffer = StringBuffer();
    for (final child in element.children ?? const <md.Node>[]) {
      if (child is md.Text) {
        buffer.write(child.text);
      }
    }
    return buffer.toString();
  }

  group('InlineMathSyntax', () {
    test('should recognise a single inline math expression in a paragraph', () {
      final nodes = parse(r'Einstein says $E = mc^2$ about mass-energy.');

      final matches = findByTag(nodes, mathInlineTag);

      expect(matches, hasLength(1));
      expect(plainTextOf(matches.single), 'E = mc^2');
    });

    test('should recognise multiple inline expressions in one paragraph', () {
      final nodes = parse(r'$\alpha$, $\beta$, and $\gamma$.');

      final matches = findByTag(nodes, mathInlineTag);

      expect(matches.map(plainTextOf).toList(), [
        r'\alpha',
        r'\beta',
        r'\gamma',
      ]);
    });

    test(r'should not match empty `$$` as an inline math expression', () {
      final nodes = parse(r'Just prose with $$ in it.');

      final matches = findByTag(nodes, mathInlineTag);

      expect(matches, isEmpty);
    });

    test(r'should leave escaped `\$` alone', () {
      // Escaped dollar followed by a number — the `\` should prevent
      // the dollar from opening a math run. The `markdown` package
      // applies escape processing before our inline syntax runs.
      final nodes = parse(r'A \$100 bill and another \$5 note.');

      final matches = findByTag(nodes, mathInlineTag);

      expect(matches, isEmpty);
    });

    test('should not match adjacent currency amounts as one math run', () {
      // Regression guard: without the negative lookahead `(?!\d)` on
      // the closing `$`, the regex would match `$5 and $` as a math
      // run wrapping `5 and `, turning currency text into garbage
      // math. Both forms below must stay as plain prose.
      final nodes = parse(r'Pay $5 and $10 in change.');

      final matches = findByTag(nodes, mathInlineTag);

      expect(
        matches,
        isEmpty,
        reason:
            'Currency-like `\$5 and \$10` must not be eaten by the '
            'inline math regex.',
      );
    });

    test(
      'should not span an opener and a closer that sit on different lines',
      () {
        // Real cross-line case: an opening `$` at the end of one line
        // and a closing `$` at the start of the next line. Without
        // the `\n` exclusion in the body class, the regex would
        // happily eat the newline and treat the two as a single
        // multi-line inline match.
        final nodes = parse('First line ends with \$\nNext line \$ closes.');

        final matches = findByTag(nodes, mathInlineTag);

        expect(matches, isEmpty);
      },
    );
  });

  group('DisplayMathBlockSyntax', () {
    test(r'should recognise a single-line `$$ … $$` display block', () {
      final nodes = parse(r'$$E = mc^2$$');

      final displays = findByTag(nodes, mathBlockTag);
      final inlines = findByTag(nodes, mathInlineTag);

      expect(
        displays,
        hasLength(1),
        reason:
            'A line containing only `\$\$ … \$\$` must be parsed '
            'as a display block by DisplayMathBlockSyntax.',
      );
      expect(plainTextOf(displays.single), 'E = mc^2');
      expect(inlines, isEmpty);
    });

    test('should recognise a multi-line display block', () {
      const source = r'''
Prose before.

$$
\frac{\partial^2 u}{\partial t^2}
= c^2 \nabla^2 u
$$

Prose after.
''';

      final nodes = parse(source);
      final displays = findByTag(nodes, mathBlockTag);

      expect(displays, hasLength(1));
      expect(
        plainTextOf(displays.single),
        contains(r'\frac{\partial^2 u}{\partial t^2}'),
      );
      expect(plainTextOf(displays.single), contains(r'\nabla^2 u'));
    });

    test(r'should reject an empty `$$$$` block', () {
      final nodes = parse(r'$$$$');

      final displays = findByTag(nodes, mathBlockTag);

      expect(displays, isEmpty);
    });

    test(
      'should leave `\$\$ … \$\$` mid-paragraph as literal text, not a block',
      () {
        // Regression guard: with the previous InlineSyntax-based
        // implementation, `$$ … $$` inside a sentence matched and
        // produced a layout-disrupting WidgetSpan. The BlockSyntax
        // refuses to match anything that is not a `$$`-only line,
        // so this case stays as prose and no display element is
        // emitted.
        final nodes = parse(r'Hello $$E=mc^2$$ world.');

        final displays = findByTag(nodes, mathBlockTag);

        expect(displays, isEmpty);
      },
    );
  });

  group('factory shape', () {
    test('block factory returns one DisplayMathBlockSyntax', () {
      final syntaxes = buildMathBlockSyntaxes();

      expect(syntaxes, hasLength(1));
      expect(syntaxes.single, isA<DisplayMathBlockSyntax>());
    });

    test('inline factory returns one InlineMathSyntax', () {
      // Regression guard: a future refactor must not silently ship
      // a list of zero (forgetting to register) or two (re-adding
      // the deleted DisplayMathSyntax) inline syntaxes.
      final syntaxes = buildMathInlineSyntaxes();

      expect(syntaxes, hasLength(1));
      expect(syntaxes.single, isA<InlineMathSyntax>());
    });
  });
}
