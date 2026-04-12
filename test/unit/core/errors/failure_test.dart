import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/core/errors/failure.dart';

void main() {
  group('Failure', () {
    test('should expose a stable tree-shake-safe name for each subtype', () {
      const failures = <Failure>[
        FileNotFoundFailure(message: 'gone'),
        PermissionDeniedFailure(message: 'denied'),
        ParseFailure(message: 'bad'),
        RenderFailure(message: 'render'),
        UnknownFailure(message: 'what'),
      ];

      final names = failures.map((f) => f.name).toList();

      expect(names, const [
        'FileNotFoundFailure',
        'PermissionDeniedFailure',
        'ParseFailure',
        'RenderFailure',
        'UnknownFailure',
      ]);
    });

    test('should implement Exception so repositories can throw them', () {
      expect(const FileNotFoundFailure(message: 'nope'), isA<Exception>());
    });

    test('should render message and type in toString without a cause', () {
      const failure = ParseFailure(message: 'bad utf8');

      expect(failure.toString(), 'ParseFailure(bad utf8)');
    });

    test('should emit only the cause type in toString, never the value', () {
      // Regression guard for the security rule in
      // security-standards.md: `cause` can hold raw file contents,
      // response bodies, or credentials, and must never be rendered
      // into a string that will reach a logger.
      const secret = FormatException('extremely sensitive payload');
      const failure = ParseFailure(message: 'bad utf8', cause: secret);

      final text = failure.toString();

      expect(text, contains('ParseFailure(bad utf8)'));
      expect(text, contains('FormatException'));
      expect(
        text,
        isNot(contains('extremely sensitive payload')),
        reason: 'toString must not leak the raw cause value',
      );
    });

    test('should allow exhaustive switch over all subtypes', () {
      // Regression guard: adding a new Failure subtype without updating
      // call sites should break this build via the compile-time
      // exhaustiveness check on sealed classes.
      const Failure failure = ParseFailure(message: 'bad');

      final label = switch (failure) {
        FileNotFoundFailure() => 'not-found',
        PermissionDeniedFailure() => 'denied',
        ParseFailure() => 'parse',
        RenderFailure() => 'render',
        UnknownFailure() => 'unknown',
      };

      expect(label, 'parse');
    });
  });
}
