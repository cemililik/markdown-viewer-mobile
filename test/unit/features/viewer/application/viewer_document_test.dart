import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/core/errors/failure.dart';
import 'package:markdown_viewer/features/viewer/application/document_repository_provider.dart';
import 'package:markdown_viewer/features/viewer/application/viewer_document.dart';
import 'package:markdown_viewer/features/viewer/domain/entities/document.dart';
import 'package:markdown_viewer/features/viewer/domain/repositories/document_repository.dart';

void main() {
  const id = DocumentId('/tmp/example.md');
  const otherId = DocumentId('/tmp/other.md');

  const sampleDocument = Document(
    id: id,
    source: '# Example',
    headings: [HeadingRef(level: 1, text: 'Example', anchor: 'example')],
    lineCount: 1,
    byteSize: 9,
  );

  ProviderContainer makeContainer(DocumentRepository repo) {
    return ProviderContainer(
      overrides: [documentRepositoryProvider.overrideWithValue(repo)],
    );
  }

  /// Subscribes to [viewerDocumentProvider] for [forId] and completes
  /// with the first settled [AsyncValue] emitted. Using a listener
  /// instead of `container.read(...future)` keeps the subscription
  /// alive for the whole wait and sidesteps Riverpod's auto-dispose,
  /// which otherwise reports "was disposed during loading state" when
  /// a short-lived read closes mid-build.
  ///
  /// "Settled" here means either `hasValue` or `hasError`. In Riverpod
  /// 3, an errored provider's state is still an [AsyncLoading] wrapper
  /// with an error attached (the "loading with previous error"
  /// pattern), so `isLoading` alone is not enough to know the build
  /// has produced a result — we have to check for data or error
  /// presence instead.
  Future<AsyncValue<Document>> awaitSettled(
    ProviderContainer container,
    DocumentId forId,
  ) {
    bool isSettled(AsyncValue<Document> value) =>
        value.hasValue || value.hasError;

    final completer = Completer<AsyncValue<Document>>();
    late final ProviderSubscription<AsyncValue<Document>> sub;
    sub = container.listen<AsyncValue<Document>>(
      viewerDocumentProvider(forId),
      (_, next) {
        if (isSettled(next) && !completer.isCompleted) {
          completer.complete(next);
        }
      },
      fireImmediately: true,
    );
    final initial = sub.read();
    if (isSettled(initial) && !completer.isCompleted) {
      completer.complete(initial);
    }
    return completer.future.whenComplete(sub.close);
  }

  group('viewerDocumentProvider', () {
    test('should resolve to the parsed document on success', () async {
      final container = makeContainer(
        const _FakeDocumentRepository(sampleDocument),
      );
      addTearDown(container.dispose);

      final value = await awaitSettled(container, id);

      expect(value.hasValue, isTrue);
      expect(value.requireValue, sampleDocument);
    });

    test('should surface a typed Failure through AsyncValue.error', () async {
      const failure = FileNotFoundFailure(message: 'missing');
      final container = makeContainer(
        const _ThrowingDocumentRepository(failure),
      );
      addTearDown(container.dispose);

      final value = await awaitSettled(container, id);

      expect(value.hasError, isTrue);
      expect(value.error, same(failure));
    });

    test(
      'should keep distinct ids in independent provider instances',
      () async {
        // Regression guard: the family provider must produce a fresh
        // AsyncValue per DocumentId so invalidating one document does
        // not wipe unrelated open documents from cache.
        final container = makeContainer(
          _RecordingDocumentRepository(sampleDocument),
        );
        addTearDown(container.dispose);

        final firstValue = await awaitSettled(container, id);
        final secondValue = await awaitSettled(container, otherId);

        expect(firstValue.hasValue, isTrue);
        expect(secondValue.hasValue, isTrue);

        final repo =
            container.read(documentRepositoryProvider)
                as _RecordingDocumentRepository;

        expect(repo.loadedIds, [id, otherId]);
      },
    );
  });
}

final class _FakeDocumentRepository implements DocumentRepository {
  const _FakeDocumentRepository(this._document);
  final Document _document;

  @override
  Future<Document> load(DocumentId path) async => _document;
}

final class _ThrowingDocumentRepository implements DocumentRepository {
  const _ThrowingDocumentRepository(this._failure);
  final Failure _failure;

  @override
  Future<Document> load(DocumentId path) => Future<Document>.error(_failure);
}

final class _RecordingDocumentRepository implements DocumentRepository {
  _RecordingDocumentRepository(this._document);
  final Document _document;
  final List<DocumentId> loadedIds = [];

  @override
  Future<Document> load(DocumentId path) async {
    loadedIds.add(path);
    return _document;
  }
}
