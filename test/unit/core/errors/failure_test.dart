import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/core/errors/failure.dart';

void main() {
  group('Failure', () {
    test('should expose a stable tree-shake-safe name for each subtype', () {
      // arrange
      const failures = <Failure>[
        FileNotFoundFailure(message: 'gone'),
        PermissionDeniedFailure(message: 'denied'),
        ParseFailure(message: 'bad'),
        RenderFailure(message: 'render'),
        UnknownFailure(message: 'what'),
      ];
      const expected = <String>[
        'FileNotFoundFailure',
        'PermissionDeniedFailure',
        'ParseFailure',
        'RenderFailure',
        'UnknownFailure',
      ];

      // act
      final names = failures.map((f) => f.name).toList();

      // assert
      expect(names, expected);
    });

    test('should implement Exception so repositories can throw them', () {
      // act & assert
      expect(const FileNotFoundFailure(message: 'nope'), isA<Exception>());
    });

    test('should render message and type in toString without a cause', () {
      // act
      const failure = ParseFailure(message: 'bad utf8');

      // assert
      expect(failure.toString(), 'ParseFailure(bad utf8)');
    });

    test('should include cause in toString when present', () {
      // arrange
      const cause = FormatException('not utf8');

      // act
      const failure = ParseFailure(message: 'bad utf8', cause: cause);

      // assert
      expect(failure.toString(), contains('ParseFailure(bad utf8)'));
      expect(failure.toString(), contains('FormatException'));
    });

    test('should allow exhaustive switch over all subtypes', () {
      // arrange
      const Failure failure = ParseFailure(message: 'bad');

      // act — a switch expression on a sealed class is exhaustive at
      // compile time; this test is a regression guard so adding a new
      // Failure subtype without updating call sites breaks the build.
      final label = switch (failure) {
        FileNotFoundFailure() => 'not-found',
        PermissionDeniedFailure() => 'denied',
        ParseFailure() => 'parse',
        RenderFailure() => 'render',
        UnknownFailure() => 'unknown',
      };

      // assert
      expect(label, 'parse');
    });
  });
}
