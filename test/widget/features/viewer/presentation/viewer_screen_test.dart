import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/core/errors/failure.dart';
import 'package:markdown_viewer/features/viewer/data/repositories/document_repository_provider.dart';
import 'package:markdown_viewer/features/viewer/domain/entities/document.dart';
import 'package:markdown_viewer/features/viewer/domain/repositories/document_repository.dart';
import 'package:markdown_viewer/features/viewer/presentation/screens/viewer_screen.dart';
import 'package:markdown_viewer/l10n/generated/app_localizations.dart';
import 'package:visibility_detector/visibility_detector.dart';

void main() {
  // `markdown_widget` renders its content through `visibility_detector`,
  // which schedules a 500 ms debounce timer on paint to batch
  // visibility callbacks. Under `flutter_test`'s fake clock that timer
  // is never drained and the test framework then reports it as a
  // pending-timer leak at teardown. Collapsing the debounce interval
  // to zero here makes the callback fire synchronously on each paint,
  // which avoids the leak without changing any production behaviour.
  TestWidgetsFlutterBinding.ensureInitialized();
  VisibilityDetectorController.instance.updateInterval = Duration.zero;

  const id = DocumentId('/tmp/example.md');

  const sampleDocument = Document(
    id: id,
    source: '# Example\n\nBody text.',
    headings: [HeadingRef(level: 1, text: 'Example', anchor: 'example')],
    lineCount: 3,
    byteSize: 22,
  );

  Widget harness(DocumentRepository repo) {
    return ProviderScope(
      overrides: [documentRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: ViewerScreen(documentId: id),
      ),
    );
  }

  group('ViewerScreen', () {
    testWidgets('shows the loading view while the repository is pending', (
      tester,
    ) async {
      final completer = Completer<Document>();
      await tester.pumpWidget(
        harness(_CompleterDocumentRepository(completer.future)),
      );

      // No settle — we want to freeze the provider in the pending state.
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading document…'), findsOneWidget);

      // Complete the future so the test can tear down cleanly. The
      // provider transitions to its data state, ViewerScreen rebuilds
      // with MarkdownView, and because we collapsed the
      // `visibility_detector` debounce to zero at the top of main(),
      // the debounce timer fires synchronously and does not leak.
      completer.complete(sampleDocument);
      await tester.pumpAndSettle();
    });

    testWidgets('renders the document body after a successful load', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(const _ImmediateDocumentRepository(sampleDocument)),
      );
      await tester.pumpAndSettle();

      // `markdown_widget` renders the source into real text nodes so a
      // substring match on "Body text." is enough to prove the data
      // branch was taken.
      expect(find.textContaining('Body text.'), findsOneWidget);
      // The app bar shows the basename, never the full path.
      expect(find.text('example.md'), findsOneWidget);
    });

    testWidgets('maps a Failure to the localized error view', (tester) async {
      await tester.pumpWidget(
        harness(
          const _ThrowingDocumentRepository(
            FileNotFoundFailure(message: 'gone'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'This file no longer exists. It may have been moved or deleted.',
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      // Retry button is present and labelled per the actionRetry ARB
      // key — tapping it would invalidate the provider.
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets(
      'wraps a non-Failure exception in UnknownFailure and still shows an error',
      (tester) async {
        await tester.pumpWidget(
          harness(_ThrowingNonFailureRepository(StateError('boom'))),
        );
        await tester.pumpAndSettle();

        // errorUnknown ARB key content
        expect(
          find.text('Something went wrong. Please try again.'),
          findsOneWidget,
        );
      },
    );
  });
}

final class _ImmediateDocumentRepository implements DocumentRepository {
  const _ImmediateDocumentRepository(this._document);
  final Document _document;

  @override
  Future<Document> load(DocumentId path) async => _document;
}

final class _CompleterDocumentRepository implements DocumentRepository {
  const _CompleterDocumentRepository(this._future);
  final Future<Document> _future;

  @override
  Future<Document> load(DocumentId path) => _future;
}

final class _ThrowingDocumentRepository implements DocumentRepository {
  const _ThrowingDocumentRepository(this._failure);
  final Failure _failure;

  @override
  Future<Document> load(DocumentId path) async => throw _failure;
}

final class _ThrowingNonFailureRepository implements DocumentRepository {
  const _ThrowingNonFailureRepository(this._error);
  final Object _error;

  @override
  Future<Document> load(DocumentId path) async => throw _error;
}
