import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/features/library/domain/entities/library_folder.dart';

void main() {
  group('LibraryFolder.displayName', () {
    test('returns the trimmed customName when one is set', () {
      final folder = LibraryFolder(
        path: '/tmp/markdown-viewer',
        addedAt: DateTime.utc(2026, 4, 14),
        customName: '  My Notes  ',
      );

      expect(folder.displayName, 'My Notes');
    });

    test('falls back to the path basename when customName is null', () {
      final folder = LibraryFolder(
        path: '/Users/dev/Documents/notes',
        addedAt: DateTime.utc(2026, 4, 14),
      );

      expect(folder.displayName, 'notes');
    });

    test(
      'falls back to the path basename when customName is empty / whitespace',
      () {
        final empty = LibraryFolder(
          path: '/tmp/notes',
          addedAt: DateTime.utc(2026, 4, 14),
          customName: '',
        );
        final blank = LibraryFolder(
          path: '/tmp/notes',
          addedAt: DateTime.utc(2026, 4, 14),
          customName: '   ',
        );

        expect(empty.displayName, 'notes');
        expect(blank.displayName, 'notes');
      },
    );

    test('falls back to the full path when no basename can be derived', () {
      // `p.basename('/')` is empty — that branch of the
      // displayName getter must surface the full path instead of
      // returning an empty string the UI cannot render.
      final folder = LibraryFolder(
        path: '/',
        addedAt: DateTime.utc(2026, 4, 14),
      );

      expect(folder.displayName, '/');
    });
  });

  group('LibraryFolder.copyWith', () {
    final original = LibraryFolder(
      path: '/tmp/notes',
      addedAt: DateTime.utc(2026, 4, 14),
      bookmark: 'original-blob',
      customName: 'Notes',
    );

    test('leaves untouched fields unchanged', () {
      final copy = original.copyWith(addedAt: DateTime.utc(2026, 4, 15));

      expect(copy.path, original.path);
      expect(copy.bookmark, 'original-blob');
      expect(copy.customName, 'Notes');
      expect(copy.addedAt, DateTime.utc(2026, 4, 15));
    });

    test(
      'explicit null clears bookmark — sentinel distinguishes from omit',
      () {
        final cleared = original.copyWith(bookmark: null);

        expect(cleared.bookmark, isNull);
        // Other fields preserved.
        expect(cleared.customName, 'Notes');
        expect(cleared.path, original.path);
      },
    );

    test('explicit null clears customName so displayName falls back', () {
      final cleared = original.copyWith(customName: null);

      expect(cleared.customName, isNull);
      expect(cleared.displayName, 'notes');
      // Other fields preserved.
      expect(cleared.bookmark, 'original-blob');
    });

    test('omitting an argument is not the same as passing null', () {
      // Regression guard for the sentinel pattern: a hand-rolled
      // `copyWith({String? bookmark})` that defaulted to `null`
      // would silently drop bookmark on every rename / update call.
      final renamed = original.copyWith(customName: 'Diary');

      expect(renamed.bookmark, 'original-blob');
      expect(renamed.customName, 'Diary');
    });
  });
}
