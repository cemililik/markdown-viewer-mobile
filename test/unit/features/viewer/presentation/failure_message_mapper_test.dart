import 'dart:io';

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

  const failures = <Failure>[
    FileNotFoundFailure(message: 'x'),
    PermissionDeniedFailure(message: 'x'),
    ParseFailure(message: 'x'),
    RenderFailure(message: 'x'),
    NetworkUnavailableFailure(message: 'x'),
    RateLimitedFailure(message: 'x'),
    AuthFailure(message: 'x'),
    RepoNotFoundFailure(message: 'x'),
    RepoTooLargeFailure(message: 'x'),
    PartialSyncFailure(message: 'x', syncedCount: 1, failedCount: 1),
    UnsupportedProviderFailure(message: 'x'),
    UnknownFailure(message: 'x'),
  ];

  group('mapFailureToViewerMessage (en)', () {
    late AppLocalizations l10n;

    setUpAll(() async {
      l10n = await loadLocale('en');
    });

    test(
      'should confirm that FileNotFoundFailure maps to the errorFileNotFound key when the behavior is exercised',
      () {
        const failure = FileNotFoundFailure(message: 'x');

        final result = mapFailureToViewerMessage(failure, l10n);

        expect(result, l10n.errorFileNotFound);
      },
    );

    test(
      'should confirm that PermissionDeniedFailure maps to the errorPermissionDenied key when the behavior is exercised',
      () {
        const failure = PermissionDeniedFailure(message: 'x');

        final result = mapFailureToViewerMessage(failure, l10n);

        expect(result, l10n.errorPermissionDenied);
      },
    );

    test(
      'should confirm that ParseFailure maps to the errorParseFailed key when the behavior is exercised',
      () {
        const failure = ParseFailure(message: 'x');

        final result = mapFailureToViewerMessage(failure, l10n);

        expect(result, l10n.errorParseFailed);
      },
    );

    test(
      'should confirm that RenderFailure maps to the errorRenderFailed key when the behavior is exercised',
      () {
        const failure = RenderFailure(message: 'x');

        final result = mapFailureToViewerMessage(failure, l10n);

        expect(result, l10n.errorRenderFailed);
      },
    );

    test(
      'should confirm that UnknownFailure maps to the errorUnknown key when the behavior is exercised',
      () {
        const failure = UnknownFailure(message: 'x');

        final result = mapFailureToViewerMessage(failure, l10n);

        expect(result, l10n.errorUnknown);
      },
    );

    test(
      'should cover every concrete Failure subtype when the behavior is exercised',
      () {
        final declaredSubtypeNames =
            RegExp(r'final class (\w+Failure) extends Failure')
                .allMatches(
                  File('lib/core/errors/failure.dart').readAsStringSync(),
                )
                .map((match) => match.group(1)!)
                .toSet();
        final fixtureSubtypeNames =
            failures.map((failure) => failure.name).toSet();

        expect(
          fixtureSubtypeNames,
          declaredSubtypeNames,
          reason:
              'Every concrete Failure declared in failure.dart needs an '
              'independent mapper fixture.',
        );
      },
    );

    test(
      'should deliberately map fallback failure types to errorUnknown when the behavior is exercised',
      () {
        for (final failure in failures.where(
          (failure) =>
              failure is PartialSyncFailure ||
              failure is UnsupportedProviderFailure ||
              failure is UnknownFailure,
        )) {
          expect(mapFailureToViewerMessage(failure, l10n), l10n.errorUnknown);
        }
      },
    );

    test(
      'should return the expected key for every Failure subtype when the behavior is exercised',
      () {
        final expected = <Type, String>{
          FileNotFoundFailure: l10n.errorFileNotFound,
          PermissionDeniedFailure: l10n.errorPermissionDenied,
          ParseFailure: l10n.errorParseFailed,
          RenderFailure: l10n.errorRenderFailed,
          NetworkUnavailableFailure: l10n.errorNetworkUnavailable,
          RateLimitedFailure: l10n.errorRateLimited,
          AuthFailure: l10n.errorAuthFailed,
          RepoNotFoundFailure: l10n.errorRepoNotFound,
          RepoTooLargeFailure: l10n.errorRepoTooLarge,
          PartialSyncFailure: l10n.errorUnknown,
          UnsupportedProviderFailure: l10n.errorUnknown,
          UnknownFailure: l10n.errorUnknown,
        };

        for (final failure in failures) {
          expect(
            mapFailureToViewerMessage(failure, l10n),
            expected[failure.runtimeType],
            reason: '${failure.runtimeType} must map to its intended ARB key',
          );
        }
      },
    );
  });

  group('mapFailureToViewerMessage (tr)', () {
    test('should return a distinct translation for every Failure, not fall '
        'back to the English copy when the behavior is exercised', () async {
      // Asserting only `isNotEmpty` used to pass even when the ARB
      // generator silently emitted the English string into the
      // Turkish locale. Comparing each TR result against the matching
      // EN result catches that case — a fresh Failure subtype shipped
      // without a real translation would fail this test immediately.
      final en = await loadLocale('en');
      final tr = await loadLocale('tr');

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
