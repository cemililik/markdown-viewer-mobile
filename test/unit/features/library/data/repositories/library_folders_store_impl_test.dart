import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/features/library/data/repositories/library_folders_store_impl.dart';
import 'package:markdown_viewer/features/library/domain/entities/library_folder.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('LibraryFoldersStoreImpl', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test(
      'should return an empty list on a fresh install when the behavior is exercised',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final store = LibraryFoldersStoreImpl(prefs);

        expect(store.read(), isEmpty);
      },
    );

    test(
      'should round-trip entries in order when folders are written then read',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final store = LibraryFoldersStoreImpl(prefs);

        await store.write(<LibraryFolder>[
          LibraryFolder(
            path: '/tmp/notes',
            addedAt: DateTime.utc(2026, 4, 14, 10),
          ),
          LibraryFolder(
            path: '/tmp/blog',
            addedAt: DateTime.utc(2026, 4, 13, 9),
          ),
        ]);
        final round = store.read();

        expect(round, hasLength(2));
        expect(round[0].path, '/tmp/notes');
        expect(round[0].addedAt.toUtc(), DateTime.utc(2026, 4, 14, 10));
        expect(round[1].path, '/tmp/blog');
      },
    );

    test(
      'should return an empty list when the stored blob is not valid JSON',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'library.folders': 'not json{',
        });
        final prefs = await SharedPreferences.getInstance();
        final store = LibraryFoldersStoreImpl(prefs);

        expect(store.read(), isEmpty);
      },
    );

    test(
      'should round-trip the optional bookmark field when the behavior is exercised',
      () async {
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
      },
    );

    test(
      'should accept legacy entries without the bookmark field when the behavior is exercised',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'library.folders':
              '[{"path":"/tmp/legacy","addedAt":"2026-04-14T10:00:00.000Z"}]',
        });
        final prefs = await SharedPreferences.getInstance();
        final store = LibraryFoldersStoreImpl(prefs);

        final round = store.read();
        expect(round, hasLength(1));
        expect(round.first.bookmark, isNull);
      },
    );

    test(
      'should round-trip the optional customName field when the behavior is exercised',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final store = LibraryFoldersStoreImpl(prefs);

        await store.write(<LibraryFolder>[
          LibraryFolder(
            path: '/tmp/renamed',
            addedAt: DateTime.utc(2026, 4, 14),
            customName: 'My Notes',
          ),
          LibraryFolder(path: '/tmp/plain', addedAt: DateTime.utc(2026, 4, 13)),
        ]);

        final round = store.read();
        expect(round, hasLength(2));
        expect(round[0].customName, 'My Notes');
        expect(round[0].displayName, 'My Notes');
        expect(round[1].customName, isNull);
        expect(round[1].displayName, 'plain');
      },
    );

    test(
      'should accept legacy entries written without the customName key when the behavior is exercised',
      () async {
        // Forward-compat regression guard: any entry persisted by a
        // pre-1.3.0 build has no `customName` key. The decode must
        // treat that as `null` (no override) rather than dropping
        // the entry.
        SharedPreferences.setMockInitialValues(<String, Object>{
          'library.folders':
              '[{"path":"/tmp/legacy","addedAt":"2026-04-14T10:00:00.000Z"},'
              '{"path":"/tmp/with-bookmark","addedAt":"2026-04-13T10:00:00.000Z","bookmark":"blob"}]',
        });
        final prefs = await SharedPreferences.getInstance();
        final store = LibraryFoldersStoreImpl(prefs);

        final round = store.read();
        expect(round, hasLength(2));
        expect(round[0].customName, isNull);
        expect(round[1].customName, isNull);
      },
    );

    test(
      'should skip malformed entries but keep the well-formed ones when the behavior is exercised',
      () async {
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
      },
    );
  });
}
