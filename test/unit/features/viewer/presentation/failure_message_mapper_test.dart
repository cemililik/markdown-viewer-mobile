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
    test('should return a distinct translation for every Failure, not fall '
        'back to the English copy', () async {
      // Asserting only `isNotEmpty` used to pass even when the ARB
      // generator silently emitted the English string into the
      // Turkish locale. Comparing each TR result against the matching
      // EN result catches that case — a fresh Failure subtype shipped
      // without a real translation would fail this test immediately.
      final en = await loadLocale('en');
      final tr = await loadLocale('tr');

      const failures = <Failure>[
        FileNotFoundFailure(message: 'x'),
        PermissionDeniedFailure(message: 'x'),
        ParseFailure(message: 'x'),
        RenderFailure(message: 'x'),
        UnknownFailure(message: 'x'),
      ];

      for (final f in failures) {
        final enMessage = mapFailureToViewerMessage(f, en);
        final trMessage = mapFailureToViewerMessage(f, tr);

        expect(trMessage, isNotEmpty);
        expect(
          trMessage,
          isNot(equals(enMessage)),
          reason:
              'Turkish copy for ${f.runtimeType} must differ from '
              'English — identical output means the ARB file is '
              'missing a real translation.',
        );
      }
    });
  });
}
