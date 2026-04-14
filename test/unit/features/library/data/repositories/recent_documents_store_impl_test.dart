import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/features/library/data/repositories/recent_documents_store_impl.dart';
import 'package:markdown_viewer/features/library/domain/entities/recent_document.dart';
import 'package:markdown_viewer/features/viewer/domain/entities/document.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('RecentDocumentsStoreImpl', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('returns an empty list on a fresh install', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = RecentDocumentsStoreImpl(prefs);

      expect(store.read(), isEmpty);
    });

    test('write then read round-trips entries preserving order', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = RecentDocumentsStoreImpl(prefs);
      final entries = <RecentDocument>[
        RecentDocument(
          documentId: const DocumentId('/tmp/a.md'),
          openedAt: DateTime.utc(2026, 4, 13, 10),
        ),
        RecentDocument(
          documentId: const DocumentId('/tmp/b.md'),
          openedAt: DateTime.utc(2026, 4, 13, 9),
        ),
      ];

      await store.write(entries);
      final round = store.read();

      expect(round, hasLength(2));
      expect(round[0].documentId.value, '/tmp/a.md');
      expect(round[0].openedAt.toUtc(), DateTime.utc(2026, 4, 13, 10));
      expect(round[1].documentId.value, '/tmp/b.md');
      expect(round[1].openedAt.toUtc(), DateTime.utc(2026, 4, 13, 9));
    });

    test('writing an empty list clears any existing entries', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = RecentDocumentsStoreImpl(prefs);

      await store.write(<RecentDocument>[
        RecentDocument(
          documentId: const DocumentId('/tmp/a.md'),
          openedAt: DateTime.utc(2026, 4, 13),
        ),
      ]);
      expect(store.read(), hasLength(1));

      await store.write(const <RecentDocument>[]);

      expect(store.read(), isEmpty);
    });

    test(
      'returns an empty list when the stored blob is not valid JSON',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'library.recentDocuments': 'not json{',
        });
        final prefs = await SharedPreferences.getInstance();
        final store = RecentDocumentsStoreImpl(prefs);

        expect(store.read(), isEmpty);
      },
    );

    test('round-trips the display name for folder-sourced files', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = RecentDocumentsStoreImpl(prefs);

      await store.write(<RecentDocument>[
        RecentDocument(
          documentId: const DocumentId(
            '/tmp/cache/library_folder_files/abc123.md',
          ),
          openedAt: DateTime.utc(2026, 4, 14),
          displayName: 'readme.md',
        ),
      ]);

      final round = store.read();
      expect(round, hasLength(1));
      expect(round.first.displayName, 'readme.md');
    });

    test('round-trips the pinned flag and preview snippet', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = RecentDocumentsStoreImpl(prefs);

      await store.write(<RecentDocument>[
        RecentDocument(
          documentId: const DocumentId('/tmp/pinned.md'),
          openedAt: DateTime.utc(2026, 4, 13, 10),
          isPinned: true,
          preview: 'Opening sentence.',
        ),
        RecentDocument(
          documentId: const DocumentId('/tmp/plain.md'),
          openedAt: DateTime.utc(2026, 4, 13, 9),
        ),
      ]);

      final round = store.read();
      expect(round, hasLength(2));
      expect(round[0].isPinned, isTrue);
      expect(round[0].preview, 'Opening sentence.');
      expect(round[1].isPinned, isFalse);
      expect(round[1].preview, isNull);
    });

    test(
      'accepts legacy entries without the pinned / preview fields',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'library.recentDocuments':
              '[{"path":"/tmp/legacy.md",'
              '"openedAt":"2026-04-13T10:00:00.000Z"}]',
        });
        final prefs = await SharedPreferences.getInstance();
        final store = RecentDocumentsStoreImpl(prefs);

        final round = store.read();
        expect(round, hasLength(1));
        expect(round.first.isPinned, isFalse);
        expect(round.first.preview, isNull);
      },
    );

    test('skips malformed entries but keeps the well-formed ones', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'library.recentDocuments':
            '[{"path":"/tmp/a.md","openedAt":"2026-04-13T10:00:00.000Z"},'
            '{"path":""},'
            '{"path":"/tmp/c.md","openedAt":"not-a-date"},'
            '{"path":"/tmp/d.md","openedAt":"2026-04-13T09:00:00.000Z"}]',
      });
      final prefs = await SharedPreferences.getInstance();
      final store = RecentDocumentsStoreImpl(prefs);

      final round = store.read();

      expect(round, hasLength(2));
      expect(round[0].documentId.value, '/tmp/a.md');
      expect(round[1].documentId.value, '/tmp/d.md');
    });
  });
}
