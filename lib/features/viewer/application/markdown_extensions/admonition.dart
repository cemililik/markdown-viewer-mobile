import 'package:markdown/markdown.dart' as md;

/// One of the five GitHub Alert kinds supported by the `markdown`
/// package's [AlertBlockSyntax](https://pub.dev/documentation/markdown/latest/markdown/AlertBlockSyntax-class.html).
///
/// Mirrors the set GitHub's README renderer ships — see
/// <https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/basic-writing-and-formatting-syntax#alerts>.
enum AdmonitionKind {
  note,
  tip,
  important,
  warning,
  caution;

  /// Resolves a kind name (case-insensitive) to the matching enum
  /// value, or `null` if it is not one of the known five. Used to
  /// recognise `markdown-alert-<type>` CSS class tokens emitted by
  /// [md.Document] when `AlertBlockSyntax` is enabled.
  static AdmonitionKind? tryFromName(String name) {
    final lower = name.toLowerCase();
    for (final kind in AdmonitionKind.values) {
      if (kind.name == lower) {
        return kind;
      }
    }
    return null;
  }
}

/// CSS class prefix that [md.Document]'s
/// [AlertBlockSyntax](https://pub.dev/documentation/markdown/latest/markdown/AlertBlockSyntax-class.html)
/// stamps on the emitted `<div>` element for each alert kind, e.g.
/// `markdown-alert markdown-alert-warning`.
const String _markdownAlertClass = 'markdown-alert';
const String _markdownAlertKindPrefix = 'markdown-alert-';

/// Tokeniser for the HTML `class` attribute. Cached at top level so
/// [tryParseAdmonitionKind] does not allocate a fresh [RegExp] on
/// every `<div>` the markdown parser walks past.
final RegExp _classAttrSplit = RegExp(r'\s+');

/// Tag name of the [md.Element] that [md.Document]'s
/// [AlertBlockSyntax] emits for a GitHub alert block.
const String admonitionElementTag = 'div';

/// Inspects [element] and returns the matching [AdmonitionKind] if it
/// is a GitHub alert container, or `null` otherwise.
///
/// A container qualifies when:
///
/// 1. Its tag is `'div'`.
/// 2. Its `class` attribute contains the `markdown-alert` token.
/// 3. The class also contains a `markdown-alert-<kind>` token where
///    `<kind>` is one of [AdmonitionKind.values].
///
/// Returning `null` instead of throwing lets the caller fall back to
/// a transparent `ConcreteElementNode` for any `<div>` that is not
/// one of ours (e.g. a raw HTML block that slipped through), so the
/// viewer still renders its children as normal block content.
AdmonitionKind? tryParseAdmonitionKind(md.Element element) {
  if (element.tag != admonitionElementTag) {
    return null;
  }
  final classAttr = element.attributes['class'];
  if (classAttr == null || classAttr.isEmpty) {
    return null;
  }
  final tokens = classAttr.split(_classAttrSplit);
  if (!tokens.contains(_markdownAlertClass)) {
    return null;
  }
  for (final token in tokens) {
    if (token.startsWith(_markdownAlertKindPrefix)) {
      final kindName = token.substring(_markdownAlertKindPrefix.length);
      final kind = AdmonitionKind.tryFromName(kindName);
      if (kind != null) {
        return kind;
      }
    }
  }
  return null;
}
