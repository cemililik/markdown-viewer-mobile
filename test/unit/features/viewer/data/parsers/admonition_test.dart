import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:markdown_viewer/features/viewer/data/parsers/admonition.dart';

void main() {
  /// Parses [source] with the same parser options MarkdownView uses
  /// at runtime: GFM extension set plus the AlertBlockSyntax that
  /// emits the markdown-alert-<kind> div we are testing against.
  List<md.Node> parse(String source) {
    final document = md.Document(
      extensionSet: md.ExtensionSet.gitHubFlavored,
      encodeHtml: false,
      blockSyntaxes: const [md.AlertBlockSyntax()],
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

  group('AdmonitionKind.tryFromName', () {
    test('recognises every known kind case-insensitively', () {
      for (final kind in AdmonitionKind.values) {
        expect(AdmonitionKind.tryFromName(kind.name), kind);
        expect(AdmonitionKind.tryFromName(kind.name.toUpperCase()), kind);
      }
    });

    test('returns null for unknown kind names', () {
      expect(AdmonitionKind.tryFromName(''), isNull);
      expect(AdmonitionKind.tryFromName('unknown'), isNull);
      expect(AdmonitionKind.tryFromName('danger'), isNull);
    });
  });

  group('tryParseAdmonitionKind', () {
    test('returns the kind for each markdown-alert div variant', () {
      // Every kind emitted by package:markdown's AlertBlockSyntax
      // must round-trip through tryParseAdmonitionKind into the
      // matching enum value.
      for (final kind in AdmonitionKind.values) {
        final element = md.Element.empty('div')
          ..attributes['class'] = 'markdown-alert markdown-alert-${kind.name}';

        expect(tryParseAdmonitionKind(element), kind);
      }
    });

    test('returns null for a plain div without the markdown-alert class', () {
      final element = md.Element.empty('div')
        ..attributes['class'] = 'some-other-class';

      expect(tryParseAdmonitionKind(element), isNull);
    });

    test('returns null for a div with no class attribute at all', () {
      final element = md.Element.empty('div');

      expect(tryParseAdmonitionKind(element), isNull);
    });

    test('returns null for a non-div element even with the alert class', () {
      final element = md.Element.empty('span')
        ..attributes['class'] = 'markdown-alert markdown-alert-note';

      expect(tryParseAdmonitionKind(element), isNull);
    });

    test('returns null when the kind token is unknown', () {
      final element = md.Element.empty('div')
        ..attributes['class'] = 'markdown-alert markdown-alert-danger';

      expect(tryParseAdmonitionKind(element), isNull);
    });

    test('tolerates extra whitespace between class tokens', () {
      final element = md.Element.empty('div')
        ..attributes['class'] = '  markdown-alert   markdown-alert-warning  ';

      expect(tryParseAdmonitionKind(element), AdmonitionKind.warning);
    });
  });

  group('AlertBlockSyntax integration', () {
    test('produces a markdown-alert div for every fixture kind', () {
      const source = '''
> [!NOTE]
> Body one.

> [!TIP]
> Body two.

> [!IMPORTANT]
> Body three.

> [!WARNING]
> Body four.

> [!CAUTION]
> Body five.
''';

      final nodes = parse(source);
      final divs = findByTag(nodes, 'div');
      final kinds = divs.map(tryParseAdmonitionKind).toList();

      expect(kinds, [
        AdmonitionKind.note,
        AdmonitionKind.tip,
        AdmonitionKind.important,
        AdmonitionKind.warning,
        AdmonitionKind.caution,
      ]);
    });

    test('leaves a plain blockquote as a blockquote element, not a div', () {
      const source = '''
> Just a normal blockquote without a kind marker.
''';

      final nodes = parse(source);

      expect(findByTag(nodes, 'div'), isEmpty);
      expect(findByTag(nodes, 'blockquote'), hasLength(1));
    });
  });
}
