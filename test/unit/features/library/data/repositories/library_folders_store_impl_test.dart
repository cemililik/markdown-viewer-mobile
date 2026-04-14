import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/features/library/data/repositories/library_folders_store_impl.dart';
import 'package:markdown_viewer/features/library/domain/entities/library_folder.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('LibraryFoldersStoreImpl', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('returns an empty list on a fresh install', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = LibraryFoldersStoreImpl(prefs);

      expect(store.read(), isEmpty);
    });

    test('write then read round-trips entries preserving order', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = LibraryFoldersStoreImpl(prefs);

      await store.write(<LibraryFolder>[
        LibraryFolder(
          path: '/tmp/notes',
          addedAt: DateTime.utc(2026, 4, 14, 10),
        ),
        LibraryFolder(path: '/tmp/blog', addedAt: DateTime.utc(2026, 4, 13, 9)),
      ]);
      final round = store.read();

      expect(round, hasLength(2));
      expect(round[0].path, '/tmp/notes');
      expect(round[0].addedAt.toUtc(), DateTime.utc(2026, 4, 14, 10));
      expect(round[1].path, '/tmp/blog');
    });

    test(
      'returns an empty list when the stored blob is not valid JSON',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'library.folders': 'not json{',
        });
        final prefs = await SharedPreferences.getInstance();
        final store = LibraryFoldersStoreImpl(prefs);

        expect(store.read(), isEmpty);
      },
    );

    test('round-trips the optional bookmark field', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = LibraryFoldersStoreImpl(prefs);

      await store.write(<LibraryFolder>[
        LibraryFolder(
          path: '/tmp/ios-bookmarked',
          addedAt: DateTime.utc(2026, 4, 14),
          bookmark: 'base64-bookmark-blob',
        ),
        LibraryFolder(path: '/tmp/plain', addedAt: DateTime.utc(2026, 4, 13)),
      ]);

      final round = store.read();
      expect(round, hasLength(2));
      expect(round[0].bookmark, 'base64-bookmark-blob');
      expect(round[1].bookmark, isNull);
    });

    test('accepts legacy entries without the bookmark field', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'library.folders':
            '[{"path":"/tmp/legacy","addedAt":"2026-04-14T10:00:00.000Z"}]',
      });
      final prefs = await SharedPreferences.getInstance();
      final store = LibraryFoldersStoreImpl(prefs);

      final round = store.read();
      expect(round, hasLength(1));
      expect(round.first.bookmark, isNull);
    });

    test('skips malformed entries but keeps the well-formed ones', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'library.folders':
            '[{"path":"/tmp/a","addedAt":"2026-04-14T10:00:00.000Z"},'
            '{"path":""},'
            '{"path":"/tmp/c","addedAt":"not-a-date"},'
            '{"path":"/tmp/d","addedAt":"2026-04-14T09:00:00.000Z"}]',
      });
      final prefs = await SharedPreferences.getInstance();
      final store = LibraryFoldersStoreImpl(prefs);

      final round = store.read();
      expect(round, hasLength(2));
      expect(round[0].path, '/tmp/a');
      expect(round[1].path, '/tmp/d');
    });
  });
}
