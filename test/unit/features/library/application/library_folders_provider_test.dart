import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/features/library/application/library_folders_provider.dart';
import 'package:markdown_viewer/features/library/domain/entities/library_folder.dart';
import 'package:markdown_viewer/features/library/domain/repositories/library_folders_store.dart';

class _FakeStore implements LibraryFoldersStore {
  _FakeStore([List<LibraryFolder>? seed]) : _state = <LibraryFolder>[...?seed];

  List<LibraryFolder> _state;
  int writeCount = 0;

  @override
  List<LibraryFolder> read() => List.unmodifiable(_state);

  @override
  Future<void> write(List<LibraryFolder> folders) async {
    writeCount += 1;
    _state = List<LibraryFolder>.from(folders);
  }
}

ProviderContainer _containerWith(_FakeStore store) {
  final container = ProviderContainer(
    overrides: [libraryFoldersStoreProvider.overrideWithValue(store)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('LibraryFoldersController', () {
    test('seeds initial state from the store, newest first', () {
      final store = _FakeStore([
        LibraryFolder(path: '/tmp/older', addedAt: DateTime.utc(2026, 4, 13)),
        LibraryFolder(path: '/tmp/newer', addedAt: DateTime.utc(2026, 4, 14)),
      ]);
      final container = _containerWith(store);

      final state = container.read(libraryFoldersControllerProvider);
      expect(state, hasLength(2));
      expect(state[0].path, '/tmp/newer');
      expect(state[1].path, '/tmp/older');
    });

    test('add prepends a new entry and persists', () {
      final store = _FakeStore();
      final container = _containerWith(store);

      final added = container
          .read(libraryFoldersControllerProvider.notifier)
          .add('/tmp/a');

      expect(added, isTrue);
      final state = container.read(libraryFoldersControllerProvider);
      expect(state, hasLength(1));
      expect(state.first.path, '/tmp/a');
      expect(state.first.bookmark, isNull);
      expect(store.writeCount, 1);
    });

    test('add carries the optional iOS security-scoped bookmark', () {
      final store = _FakeStore();
      final container = _containerWith(store);

      container
          .read(libraryFoldersControllerProvider.notifier)
          .add('/tmp/ios', bookmark: 'base64-blob');

      final state = container.read(libraryFoldersControllerProvider);
      expect(state.first.bookmark, 'base64-blob');
    });

    test('add returns false and is a no-op for a duplicate path', () {
      final store = _FakeStore([
        LibraryFolder(path: '/tmp/dup', addedAt: DateTime.utc(2026, 4, 14)),
      ]);
      final container = _containerWith(store);

      final added = container
          .read(libraryFoldersControllerProvider.notifier)
          .add('/tmp/dup');

      expect(added, isFalse);
      expect(container.read(libraryFoldersControllerProvider), hasLength(1));
      expect(store.writeCount, 0);
    });

    test('remove drops the matching entry and persists', () {
      final store = _FakeStore([
        LibraryFolder(path: '/tmp/a', addedAt: DateTime.utc(2026, 4, 14)),
        LibraryFolder(path: '/tmp/b', addedAt: DateTime.utc(2026, 4, 13)),
      ]);
      final container = _containerWith(store);

      container
          .read(libraryFoldersControllerProvider.notifier)
          .remove('/tmp/a');

      final state = container.read(libraryFoldersControllerProvider);
      expect(state, hasLength(1));
      expect(state.first.path, '/tmp/b');
      expect(store.writeCount, 1);
    });

    test('remove is a no-op when the path is not present', () {
      final store = _FakeStore([
        LibraryFolder(path: '/tmp/a', addedAt: DateTime.utc(2026, 4, 14)),
      ]);
      final container = _containerWith(store);

      container
          .read(libraryFoldersControllerProvider.notifier)
          .remove('/tmp/ghost');

      expect(container.read(libraryFoldersControllerProvider), hasLength(1));
      expect(store.writeCount, 0);
    });

    test('rename writes the trimmed customName and persists', () {
      final store = _FakeStore([
        LibraryFolder(path: '/tmp/notes', addedAt: DateTime.utc(2026, 4, 14)),
      ]);
      final container = _containerWith(store);

      container
          .read(libraryFoldersControllerProvider.notifier)
          .rename(path: '/tmp/notes', customName: '  My Notes  ');

      final state = container.read(libraryFoldersControllerProvider);
      expect(state.first.customName, 'My Notes');
      expect(state.first.displayName, 'My Notes');
      expect(store.writeCount, 1);
    });

    test('rename normalises empty / whitespace input back to null', () {
      final store = _FakeStore([
        LibraryFolder(
          path: '/tmp/notes',
          addedAt: DateTime.utc(2026, 4, 14),
          customName: 'Old',
        ),
      ]);
      final container = _containerWith(store);

      container
          .read(libraryFoldersControllerProvider.notifier)
          .rename(path: '/tmp/notes', customName: '   ');

      final state = container.read(libraryFoldersControllerProvider);
      expect(state.first.customName, isNull);
      // displayName falls back to the basename now that the override
      // is gone.
      expect(state.first.displayName, 'notes');
      expect(store.writeCount, 1);
    });

    test('rename clamps over-long input to the source-rename cap', () {
      final store = _FakeStore([
        LibraryFolder(path: '/tmp/notes', addedAt: DateTime.utc(2026, 4, 14)),
      ]);
      final container = _containerWith(store);

      // 200 chars — well over the 64-char cap.
      container
          .read(libraryFoldersControllerProvider.notifier)
          .rename(path: '/tmp/notes', customName: 'a' * 200);

      final state = container.read(libraryFoldersControllerProvider);
      expect(state.first.customName, isNotNull);
      // Codepoint length must not exceed the cap.
      expect(state.first.customName!.runes.length, lessThanOrEqualTo(64));
    });

    test('rename is a no-op when the path is not present', () {
      final store = _FakeStore([
        LibraryFolder(path: '/tmp/a', addedAt: DateTime.utc(2026, 4, 14)),
      ]);
      final container = _containerWith(store);

      container
          .read(libraryFoldersControllerProvider.notifier)
          .rename(path: '/tmp/ghost', customName: 'X');

      expect(store.writeCount, 0);
    });

    test('rename short-circuits when the normalised value is unchanged', () {
      final store = _FakeStore([
        LibraryFolder(
          path: '/tmp/notes',
          addedAt: DateTime.utc(2026, 4, 14),
          customName: 'Notes',
        ),
      ]);
      final container = _containerWith(store);

      container
          .read(libraryFoldersControllerProvider.notifier)
          .rename(path: '/tmp/notes', customName: '  Notes  ');

      // No write — the trimmed input matches the persisted value.
      expect(store.writeCount, 0);
    });

    test(
      'updateBookmark preserves the rename — regression guard for the '
      'pre-1.3.0 fresh-constructor path that silently dropped customName',
      () {
        final store = _FakeStore([
          LibraryFolder(
            path: '/tmp/ios',
            addedAt: DateTime.utc(2026, 4, 14),
            bookmark: 'old-blob',
            customName: 'My iOS Folder',
          ),
        ]);
        final container = _containerWith(store);

        container
            .read(libraryFoldersControllerProvider.notifier)
            .updateBookmark(path: '/tmp/ios', bookmark: 'fresh-blob');

        // Assert both halves of the contract:
        //   1. In-memory state — the UI rebuilds against this.
        //   2. Persistence side-effect — the store write is the
        //      part that survives a cold restart, and the
        //      pre-1.3.0 regression skipped this side as well.
        final state = container.read(libraryFoldersControllerProvider);
        expect(state.first.bookmark, 'fresh-blob');
        expect(state.first.customName, 'My iOS Folder');
        expect(store.writeCount, 1);
        final persisted = store.read();
        expect(persisted.first.bookmark, 'fresh-blob');
        expect(persisted.first.customName, 'My iOS Folder');
      },
    );
  });
}
