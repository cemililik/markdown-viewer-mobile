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
  });
}
