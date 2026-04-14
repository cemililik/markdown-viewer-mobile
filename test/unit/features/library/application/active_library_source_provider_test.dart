import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/features/library/application/active_library_source_provider.dart';
import 'package:markdown_viewer/features/library/application/library_folders_provider.dart';
import 'package:markdown_viewer/features/library/domain/entities/library_folder.dart';
import 'package:markdown_viewer/features/library/domain/entities/library_source.dart';
import 'package:markdown_viewer/features/library/domain/repositories/library_folders_store.dart';

class _FakeStore implements LibraryFoldersStore {
  _FakeStore([List<LibraryFolder>? seed]) : _state = <LibraryFolder>[...?seed];

  List<LibraryFolder> _state;

  @override
  List<LibraryFolder> read() => List.unmodifiable(_state);

  @override
  Future<void> write(List<LibraryFolder> folders) async {
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
  group('ActiveLibrarySourceController', () {
    test('defaults to RecentsSource on first build', () {
      final container = _containerWith(_FakeStore());

      expect(container.read(activeLibrarySourceProvider), isA<RecentsSource>());
    });

    test('selectFolder switches state to a FolderSource', () {
      final folder = LibraryFolder(
        path: '/tmp/notes',
        addedAt: DateTime.utc(2026, 4, 14),
      );
      final container = _containerWith(_FakeStore([folder]));

      container.read(activeLibrarySourceProvider.notifier).selectFolder(folder);

      final state = container.read(activeLibrarySourceProvider);
      expect(state, isA<FolderSource>());
      expect((state as FolderSource).folder.path, '/tmp/notes');
    });

    test('selectRecents flips back to RecentsSource', () {
      final folder = LibraryFolder(
        path: '/tmp/notes',
        addedAt: DateTime.utc(2026, 4, 14),
      );
      final container = _containerWith(_FakeStore([folder]));

      container.read(activeLibrarySourceProvider.notifier).selectFolder(folder);
      container.read(activeLibrarySourceProvider.notifier).selectRecents();

      expect(container.read(activeLibrarySourceProvider), isA<RecentsSource>());
    });

    test('auto-falls back to Recents when the active folder is removed', () {
      final folder = LibraryFolder(
        path: '/tmp/notes',
        addedAt: DateTime.utc(2026, 4, 14),
      );
      final container = _containerWith(_FakeStore([folder]));

      // Activate the source listener by reading the provider
      // once — Riverpod only runs `build()` on first read.
      container.read(activeLibrarySourceProvider);
      container.read(activeLibrarySourceProvider.notifier).selectFolder(folder);
      expect(container.read(activeLibrarySourceProvider), isA<FolderSource>());

      // Remove the folder — the listener inside
      // ActiveLibrarySourceController should reset to Recents
      // so the UI never renders against a dangling folder.
      container
          .read(libraryFoldersControllerProvider.notifier)
          .remove('/tmp/notes');

      expect(container.read(activeLibrarySourceProvider), isA<RecentsSource>());
    });
  });
}
