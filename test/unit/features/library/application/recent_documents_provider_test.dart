import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/features/library/application/recent_documents_provider.dart';
import 'package:markdown_viewer/features/library/domain/entities/recent_document.dart';
import 'package:markdown_viewer/features/library/domain/repositories/recent_documents_store.dart';
import 'package:markdown_viewer/features/viewer/domain/entities/document.dart';

/// In-memory [RecentDocumentsStore] fake. Records every write so the
/// tests can assert that the controller persists on each mutation
/// without reaching into SharedPreferences.
class _FakeStore implements RecentDocumentsStore {
  _FakeStore([List<RecentDocument>? seed])
    : _state = <RecentDocument>[...?seed];

  List<RecentDocument> _state;
  int writeCount = 0;

  @override
  List<RecentDocument> read() => List.unmodifiable(_state);

  @override
  Future<void> write(List<RecentDocument> documents) async {
    writeCount += 1;
    _state = List<RecentDocument>.from(documents);
  }
}

ProviderContainer _containerWith(_FakeStore store) {
  final container = ProviderContainer(
    overrides: [recentDocumentsStoreProvider.overrideWithValue(store)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('RecentDocumentsController', () {
    test(
      'should seed initial state from the store when the behavior is exercised',
      () {
        final seed = [
          RecentDocument(
            documentId: const DocumentId('/tmp/a.md'),
            openedAt: DateTime.utc(2026, 4, 13, 10),
          ),
        ];
        final container = _containerWith(_FakeStore(seed));

        final state = container.read(recentDocumentsControllerProvider);
        expect(state, hasLength(1));
        expect(state.first.documentId.value, '/tmp/a.md');
      },
    );

    test(
      'should confirm that touch prepends a new entry to the top of the list when the behavior is exercised',
      () {
        final store = _FakeStore([
          RecentDocument(
            documentId: const DocumentId('/tmp/old.md'),
            openedAt: DateTime.utc(2026, 4, 12),
          ),
        ]);
        final container = _containerWith(store);

        container
            .read(recentDocumentsControllerProvider.notifier)
            .touch(const DocumentId('/tmp/fresh.md'));

        final state = container.read(recentDocumentsControllerProvider);
        expect(state, hasLength(2));
        expect(state[0].documentId.value, '/tmp/fresh.md');
        expect(state[1].documentId.value, '/tmp/old.md');
        expect(store.writeCount, 1);
      },
    );

    test(
      'should confirm that touch carries the preview snippet onto the fresh entry when the behavior is exercised',
      () {
        final store = _FakeStore();
        final container = _containerWith(store);

        container
            .read(recentDocumentsControllerProvider.notifier)
            .touch(
              const DocumentId('/tmp/a.md'),
              preview: 'first paragraph of the document',
            );

        final state = container.read(recentDocumentsControllerProvider);
        expect(state.first.preview, 'first paragraph of the document');
      },
    );

    test(
      'should confirm that touch carries the display name onto the fresh entry when the behavior is exercised',
      () {
        final store = _FakeStore();
        final container = _containerWith(store);

        container
            .read(recentDocumentsControllerProvider.notifier)
            .touch(
              const DocumentId('/tmp/cache/sha256hash.md'),
              displayName: 'readme.md',
            );

        final state = container.read(recentDocumentsControllerProvider);
        expect(state.first.displayName, 'readme.md');
      },
    );

    test(
      'should confirm that touch preserves an existing display name when the call does not '
      'provide a new one',
      () {
        final store = _FakeStore([
          RecentDocument(
            documentId: const DocumentId('/tmp/cache/sha256hash.md'),
            openedAt: DateTime.utc(2026, 4, 13),
            displayName: 'readme.md',
          ),
        ]);
        final container = _containerWith(store);

        container
            .read(recentDocumentsControllerProvider.notifier)
            .touch(
              const DocumentId('/tmp/cache/sha256hash.md'),
              preview: 'updated preview',
            );

        final state = container.read(recentDocumentsControllerProvider);
        expect(
          state.first.displayName,
          'readme.md',
          reason:
              'Re-touching an entry without a displayName argument must '
              'keep the previously stamped name intact.',
        );
        expect(state.first.preview, 'updated preview');
      },
    );

    test(
      'should confirm that touch preserves the pinned flag on re-open so a tap does not unpin when the behavior is exercised',
      () {
        final store = _FakeStore([
          RecentDocument(
            documentId: const DocumentId('/tmp/a.md'),
            openedAt: DateTime.utc(2026, 4, 12),
            isPinned: true,
            preview: 'original preview',
          ),
        ]);
        final container = _containerWith(store);

        container
            .read(recentDocumentsControllerProvider.notifier)
            .touch(const DocumentId('/tmp/a.md'));

        final state = container.read(recentDocumentsControllerProvider);
        expect(state.first.isPinned, isTrue);
        expect(
          state.first.preview,
          'original preview',
          reason:
              'A touch without an explicit preview must keep the '
              'previously stored snippet, not wipe it.',
        );
      },
    );

    test(
      'should confirm that touch deduplicates by path and promotes the existing entry when the behavior is exercised',
      () {
        final store = _FakeStore([
          RecentDocument(
            documentId: const DocumentId('/tmp/a.md'),
            openedAt: DateTime.utc(2026, 4, 13),
          ),
          RecentDocument(
            documentId: const DocumentId('/tmp/b.md'),
            openedAt: DateTime.utc(2026, 4, 12),
          ),
        ]);
        final container = _containerWith(store);

        container
            .read(recentDocumentsControllerProvider.notifier)
            .touch(const DocumentId('/tmp/b.md'));

        final state = container.read(recentDocumentsControllerProvider);
        expect(state, hasLength(2));
        expect(state[0].documentId.value, '/tmp/b.md');
        expect(state[1].documentId.value, '/tmp/a.md');
      },
    );

    test(
      'should confirm that touch caps the list at 20 entries (most recent wins) when the behavior is exercised',
      () {
        // Seed is stored most-recent-first, so index 0 is the newest
        // entry and index 19 is the oldest. After prepending the fresh
        // touch, the oldest (tail) entry must be the one that drops.
        final seed = List<RecentDocument>.generate(
          20,
          (i) => RecentDocument(
            documentId: DocumentId('/tmp/$i.md'),
            openedAt: DateTime.utc(2026, 4, 13).subtract(Duration(minutes: i)),
          ),
        );
        final store = _FakeStore(seed);
        final container = _containerWith(store);

        container
            .read(recentDocumentsControllerProvider.notifier)
            .touch(const DocumentId('/tmp/fresh.md'));

        final state = container.read(recentDocumentsControllerProvider);
        expect(state, hasLength(20));
        expect(state.first.documentId.value, '/tmp/fresh.md');
        expect(
          state.any((e) => e.documentId.value == '/tmp/19.md'),
          isFalse,
          reason: 'The oldest entry should be dropped when the list overflows.',
        );
        expect(
          state.any((e) => e.documentId.value == '/tmp/0.md'),
          isTrue,
          reason: 'The newest seeded entry should be preserved.',
        );
      },
    );

    test(
      'should confirm that remove drops the matching entry and persists when the behavior is exercised',
      () {
        final store = _FakeStore([
          RecentDocument(
            documentId: const DocumentId('/tmp/a.md'),
            openedAt: DateTime.utc(2026, 4, 13),
          ),
          RecentDocument(
            documentId: const DocumentId('/tmp/b.md'),
            openedAt: DateTime.utc(2026, 4, 12),
          ),
        ]);
        final container = _containerWith(store);

        container
            .read(recentDocumentsControllerProvider.notifier)
            .remove(const DocumentId('/tmp/a.md'));

        final state = container.read(recentDocumentsControllerProvider);
        expect(state, hasLength(1));
        expect(state.first.documentId.value, '/tmp/b.md');
        expect(store.writeCount, 1);
      },
    );

    test('should leave state unchanged when the removed path is absent', () {
      final store = _FakeStore([
        RecentDocument(
          documentId: const DocumentId('/tmp/a.md'),
          openedAt: DateTime.utc(2026, 4, 13),
        ),
      ]);
      final container = _containerWith(store);

      container
          .read(recentDocumentsControllerProvider.notifier)
          .remove(const DocumentId('/tmp/ghost.md'));

      expect(container.read(recentDocumentsControllerProvider), hasLength(1));
      expect(store.writeCount, 0);
    });

    test(
      'should confirm that clear wipes the list and persists the empty state when the behavior is exercised',
      () {
        final store = _FakeStore([
          RecentDocument(
            documentId: const DocumentId('/tmp/a.md'),
            openedAt: DateTime.utc(2026, 4, 13),
          ),
        ]);
        final container = _containerWith(store);

        container.read(recentDocumentsControllerProvider.notifier).clear();

        expect(container.read(recentDocumentsControllerProvider), isEmpty);
        expect(store.writeCount, 1);
      },
    );

    test(
      'should confirm that clear is a no-op when the list is already empty',
      () {
        final store = _FakeStore();
        final container = _containerWith(store);

        container.read(recentDocumentsControllerProvider.notifier).clear();

        expect(store.writeCount, 0);
      },
    );

    test(
      'should confirm that togglePin flips the pinned flag and re-sorts pinned to the top when the behavior is exercised',
      () {
        final store = _FakeStore([
          RecentDocument(
            documentId: const DocumentId('/tmp/a.md'),
            openedAt: DateTime.utc(2026, 4, 13, 10),
          ),
          RecentDocument(
            documentId: const DocumentId('/tmp/b.md'),
            openedAt: DateTime.utc(2026, 4, 13, 9),
          ),
        ]);
        final container = _containerWith(store);

        container
            .read(recentDocumentsControllerProvider.notifier)
            .togglePin(const DocumentId('/tmp/b.md'));

        final afterPin = container.read(recentDocumentsControllerProvider);
        expect(afterPin.first.documentId.value, '/tmp/b.md');
        expect(afterPin.first.isPinned, isTrue);
        expect(afterPin[1].documentId.value, '/tmp/a.md');

        container
            .read(recentDocumentsControllerProvider.notifier)
            .togglePin(const DocumentId('/tmp/b.md'));

        final afterUnpin = container.read(recentDocumentsControllerProvider);
        expect(afterUnpin.first.documentId.value, '/tmp/a.md');
        expect(afterUnpin[1].isPinned, isFalse);
      },
    );

    test(
      'should confirm that togglePin is a no-op when the path is not present',
      () {
        final store = _FakeStore([
          RecentDocument(
            documentId: const DocumentId('/tmp/a.md'),
            openedAt: DateTime.utc(2026, 4, 13),
          ),
        ]);
        final container = _containerWith(store);

        container
            .read(recentDocumentsControllerProvider.notifier)
            .togglePin(const DocumentId('/tmp/ghost.md'));

        expect(store.writeCount, 0);
      },
    );

    test(
      'should confirm that pinned entries are exempt from the 20-entry cap on the unpinned tail when the behavior is exercised',
      () {
        final pinned = List<RecentDocument>.generate(
          5,
          (i) => RecentDocument(
            documentId: DocumentId('/tmp/pin$i.md'),
            openedAt: DateTime.utc(2026, 4, 13).subtract(Duration(hours: i)),
            isPinned: true,
          ),
        );
        final unpinned = List<RecentDocument>.generate(
          20,
          (i) => RecentDocument(
            documentId: DocumentId('/tmp/u$i.md'),
            openedAt: DateTime.utc(2026, 4, 12).subtract(Duration(minutes: i)),
          ),
        );
        final store = _FakeStore([...pinned, ...unpinned]);
        final container = _containerWith(store);

        container
            .read(recentDocumentsControllerProvider.notifier)
            .touch(const DocumentId('/tmp/fresh.md'));

        final state = container.read(recentDocumentsControllerProvider);
        final pinnedCount = state.where((e) => e.isPinned).length;
        final unpinnedCount = state.where((e) => !e.isPinned).length;
        expect(
          pinnedCount,
          5,
          reason: 'Pinned entries should never be truncated.',
        );
        expect(unpinnedCount, 20);
        expect(state.any((e) => e.documentId.value == '/tmp/fresh.md'), isTrue);
        expect(
          state.any((e) => e.documentId.value == '/tmp/u19.md'),
          isFalse,
          reason: 'The oldest unpinned entry should be dropped.',
        );
      },
    );
  });
}
