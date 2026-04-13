import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:markdown_viewer/features/viewer/data/parsers/math_syntax.dart';

void main() {
  /// Parses [source] with our math syntaxes plus the default GFM
  /// extension set — matches the configuration `MarkdownView` uses at
  /// runtime so the tests exercise the same code path.
  List<md.Node> parse(String source) {
    final document = md.Document(
      extensionSet: md.ExtensionSet.gitHubFlavored,
      encodeHtml: false,
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

    test('should not span across a newline', () {
      // The regex forbids `\n` in the body so a stray `$` at end of
      // one line cannot accidentally eat content from the next one.
      final nodes = parse('Start of a paragraph \$oops\nNext line.');

      final matches = findByTag(nodes, mathInlineTag);

      expect(matches, isEmpty);
    });
  });

  group('DisplayMathSyntax', () {
    test(r'should recognise a single-line `$$ … $$` display block', () {
      final nodes = parse(r'$$E = mc^2$$');

      final displays = findByTag(nodes, mathBlockTag);
      final inlines = findByTag(nodes, mathInlineTag);

      expect(
        displays,
        hasLength(1),
        reason:
            'Display syntax must win over the inline syntax for '
            r'`$$ … $$` — otherwise two empty inline runs surround '
            'the body.',
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
      final nodes = parse(r'Nothing here: $$$$');

      final displays = findByTag(nodes, mathBlockTag);

      expect(displays, isEmpty);
    });
  });

  group('syntax ordering', () {
    test('factory list must put display before inline', () {
      // Regression guard: if this order ever flips, `$$x$$` breaks
      // into two empty inline runs surrounding `x`.
      final syntaxes = buildMathInlineSyntaxes();

      expect(syntaxes, hasLength(2));
      expect(syntaxes[0], isA<DisplayMathSyntax>());
      expect(syntaxes[1], isA<InlineMathSyntax>());
    });
  });
}
