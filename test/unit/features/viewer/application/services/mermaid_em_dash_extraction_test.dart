import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/features/viewer/application/services/pdf_exporter.dart';

/// Diagnostic test for the gantt rendering bug reported against
/// the ForgeLM `05_content_strategy.md` document. The user's gantt
/// has em-dash (`—`, U+2014) characters in task names; rendering
/// fails inside the WebView with `invalid date: why safety
/// matters:2026-03-31`. Direct `mermaid.parse` of the same fence
/// content with mermaid 11.4.1 succeeds, so the bug is somewhere
/// in OUR Dart-side extraction path.
///
/// This test runs the real `extractMermaidCodes` against a fixture
/// that mirrors the failing fence content and prints the extracted
/// bytes so any silent character substitution (smart quote,
/// dash-to-entity conversion, etc.) is visible in the test log.
void main() {
  group('extractMermaidCodes — em-dash diagnostic', () {
    const source = '''
## Calendar

```mermaid
gantt
    title Content Publishing Schedule
    dateFormat YYYY-MM-DD

    section Launch Week
    Show HN post                    :2026-03-24, 1d

    section Week 2-3
    Blog — Why safety matters        :2026-03-31, 5d
    YouTube — 5-min demo             :2026-04-02, 5d
```
''';

    test('em-dash characters survive the AST → string round-trip', () {
      final codes = extractMermaidCodes(source);
      expect(codes, hasLength(1));

      final code = codes.first;
      // Print the extracted code for human inspection — useful when
      // diagnosing a silent transformation in the markdown parser.
      // ignore: avoid_print
      print('---- extracted code (length ${code.length}) ----');
      // ignore: avoid_print
      print(code);
      // ignore: avoid_print
      print('---- non-ASCII characters ----');
      for (var i = 0; i < code.length; i += 1) {
        final cu = code.codeUnitAt(i);
        if (cu > 127) {
          // ignore: avoid_print
          print(
            '  idx=$i char="${code[i]}" code=$cu (0x${cu.toRadixString(16)})',
          );
        }
      }

      // Hard assertions: the literal em-dash must survive intact and
      // no HTML entity form must leak through.
      expect(
        code.contains('—'),
        isTrue,
        reason:
            'em-dash characters must survive the markdown round-trip; '
            'losing them is the smoking gun for a smart-punctuation or '
            'entity-encoding bug',
      );
      expect(
        code.contains('&mdash;'),
        isFalse,
        reason: 'no HTML entity form may leak through to the renderer',
      );
      expect(
        code.contains('&#8212;'),
        isFalse,
        reason: 'no decimal entity form may leak through to the renderer',
      );
      expect(
        code.contains('&#x2014;'),
        isFalse,
        reason: 'no hex entity form may leak through to the renderer',
      );

      // The exact tasks from the fence must be intact, byte-for-byte.
      expect(
        code.contains('Blog — Why safety matters        :2026-03-31, 5d'),
        isTrue,
      );
      expect(
        code.contains('YouTube — 5-min demo             :2026-04-02, 5d'),
        isTrue,
      );
    });
  });
}
