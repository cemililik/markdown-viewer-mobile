import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/core/errors/failure.dart';
import 'package:markdown_viewer/features/viewer/presentation/failure_message_mapper.dart';
import 'package:markdown_viewer/l10n/generated/app_localizations.dart';

void main() {
  /// Loads a real [AppLocalizations] for [code] instead of mocking it —
  /// mocks would make the test meaningless because we specifically
  /// want to verify that the mapper returns ARB keys that actually
  /// exist on the generated class.
  Future<AppLocalizations> loadLocale(String code) =>
      AppLocalizations.delegate.load(Locale(code));

  group('mapFailureToViewerMessage (en)', () {
    late AppLocalizations l10n;

    setUpAll(() async {
      l10n = await loadLocale('en');
    });

    test('FileNotFoundFailure maps to the errorFileNotFound key', () {
      const failure = FileNotFoundFailure(message: 'x');

      final result = mapFailureToViewerMessage(failure, l10n);

      expect(result, l10n.errorFileNotFound);
    });

    test('PermissionDeniedFailure maps to the errorPermissionDenied key', () {
      const failure = PermissionDeniedFailure(message: 'x');

      final result = mapFailureToViewerMessage(failure, l10n);

      expect(result, l10n.errorPermissionDenied);
    });

    test('ParseFailure maps to the errorParseFailed key', () {
      const failure = ParseFailure(message: 'x');

      final result = mapFailureToViewerMessage(failure, l10n);

      expect(result, l10n.errorParseFailed);
    });

    test('RenderFailure maps to the errorRenderFailed key', () {
      const failure = RenderFailure(message: 'x');

      final result = mapFailureToViewerMessage(failure, l10n);

      expect(result, l10n.errorRenderFailed);
    });

    test('UnknownFailure maps to the errorUnknown key', () {
      const failure = UnknownFailure(message: 'x');

      final result = mapFailureToViewerMessage(failure, l10n);

      expect(result, l10n.errorUnknown);
    });
  });

  group('mapFailureToViewerMessage (tr)', () {
    test(
      'should resolve every Failure in Turkish without falling back',
      () async {
        // Regression guard: if a Failure subtype gets added without a
        // matching Turkish ARB key, the AppLocalizations getter would
        // throw here rather than silently showing the English fallback.
        final tr = await loadLocale('tr');

        const failures = <Failure>[
          FileNotFoundFailure(message: 'x'),
          PermissionDeniedFailure(message: 'x'),
          ParseFailure(message: 'x'),
          RenderFailure(message: 'x'),
          UnknownFailure(message: 'x'),
        ];

        for (final f in failures) {
          expect(mapFailureToViewerMessage(f, tr), isNotEmpty);
        }
      },
    );
  });
}
