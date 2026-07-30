import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/features/viewer/presentation/services/syntax_highlight_service.dart';

void main() {
  group('SyntaxHighlightService', () {
    test(
      'should preserve the complete source when a supported language is highlighted',
      () {
        final service = SyntaxHighlightService();
        const source = 'final greeting = "merhaba";\nprint(greeting);\n';

        final tokens = service.highlightSynchronously(source, 'dart');

        expect(tokens.map((token) => token.text).join(), source);
        expect(tokens.any((token) => token.scope != null), isTrue);
      },
    );

    test('should reuse an immutable token list when a request is cached', () {
      final service = SyntaxHighlightService();
      const source = 'const answer = 42;';

      final first = service.highlightSynchronously(source, 'dart');
      final second = service.highlightSynchronously(source, 'dart');

      expect(identical(first, second), isTrue);
      expect(
        () => first.add(const SyntaxHighlightToken(text: 'mutation')),
        throwsUnsupportedError,
      );
    });

    test(
      'should share an in-flight result when a background highlight is requested twice',
      () async {
        final service = SyntaxHighlightService();
        const source = 'String mode() => "background";';

        final first = service.highlightInBackground(source, 'dart');
        final second = service.highlightInBackground(source, 'dart');
        final tokens = await first;

        expect(identical(first, second), isTrue);
        expect(tokens.map((token) => token.text).join(), source);
      },
    );
  });
}
