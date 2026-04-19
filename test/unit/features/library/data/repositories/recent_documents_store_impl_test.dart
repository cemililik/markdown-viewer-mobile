import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/features/library/data/repositories/recent_documents_store_impl.dart';
import 'package:markdown_viewer/features/library/domain/entities/recent_document.dart';
import 'package:markdown_viewer/features/viewer/domain/entities/document.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('RecentDocumentsStoreImpl', () {
    late Directory tempDir;
    late String pathA;
    late String pathB;

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      // Historical note: earlier revisions self-cleaned entries whose
      // backing file had disappeared via an `existsSync()` filter at
      // read time. That filter is gone — `read()` now returns stale
      // entries intact and the viewer surfaces the "file no longer
      // available" error on tap. Real temp files are still used so
      // the "stale entry" test can delete one between write and read
      // without the whole suite needing a filesystem abstraction.
      // Reference: code-review CR-20260419-019.
      tempDir = Directory.systemTemp.createTempSync('recents_test_');
      pathA = '${tempDir.path}/a.md';
      pathB = '${tempDir.path}/b.md';
      File(pathA).writeAsStringSync('');
      File(pathB).writeAsStringSync('');
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
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
          documentId: DocumentId(pathA),
          openedAt: DateTime.utc(2026, 4, 13, 10),
        ),
        RecentDocument(
          documentId: DocumentId(pathB),
          openedAt: DateTime.utc(2026, 4, 13, 9),
        ),
      ];

      await store.write(entries);
      final round = store.read();

      expect(round, hasLength(2));
      expect(round[0].documentId.value, pathA);
      expect(round[0].openedAt.toUtc(), DateTime.utc(2026, 4, 13, 10));
      expect(round[1].documentId.value, pathB);
      expect(round[1].openedAt.toUtc(), DateTime.utc(2026, 4, 13, 9));
    });

    test('writing an empty list clears any existing entries', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = RecentDocumentsStoreImpl(prefs);

      await store.write(<RecentDocument>[
        RecentDocument(
          documentId: DocumentId(pathA),
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
          documentId: DocumentId(pathA),
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
          documentId: DocumentId(pathA),
          openedAt: DateTime.utc(2026, 4, 13, 10),
          isPinned: true,
          preview: 'Opening sentence.',
        ),
        RecentDocument(
          documentId: DocumentId(pathB),
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
        final legacyPath = '${tempDir.path}/legacy.md';
        File(legacyPath).writeAsStringSync('');
        SharedPreferences.setMockInitialValues(<String, Object>{
          'library.recentDocuments':
              '[{"path":"$legacyPath",'
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
      final pathC = '${tempDir.path}/c.md';
      final pathD = '${tempDir.path}/d.md';
      File(pathD).writeAsStringSync('');
      // Intentionally do NOT touch pathC — its entry is still
      // dropped, but via the "openedAt: not-a-date" malformed-entry
      // branch rather than an existsSync check (that filter was
      // removed as part of CR-20260419-019). The "pinned missing
      // file" case is now handled by the viewer surfacing a localised
      // error on tap instead of by the read path silently dropping
      // the entry.
      SharedPreferences.setMockInitialValues(<String, Object>{
        'library.recentDocuments':
            '[{"path":"$pathA","openedAt":"2026-04-13T10:00:00.000Z"},'
            '{"path":""},'
            '{"path":"$pathC","openedAt":"not-a-date"},'
            '{"path":"$pathD","openedAt":"2026-04-13T09:00:00.000Z"}]',
      });
      final prefs = await SharedPreferences.getInstance();
      final store = RecentDocumentsStoreImpl(prefs);

      final round = store.read();

      expect(round, hasLength(2));
      expect(round[0].documentId.value, pathA);
      expect(round[1].documentId.value, pathD);
    });

    test(
      'read() returns stale entries intact; cold start never hits disk',
      () async {
        // Behaviour change: `read()` is purely in-memory. Earlier
        // versions called `File(path).existsSync()` per entry, which
        // blocked the UI isolate during cold start on slow SMB /
        // iCloud Drive paths. The viewer now surfaces a localised
        // "file no longer available" error on tap for a stale entry,
        // which is the only code path where staleness matters.
        // Reference: code-review CR-20260419-019.
        final prefs = await SharedPreferences.getInstance();
        final store = RecentDocumentsStoreImpl(prefs);

        await store.write(<RecentDocument>[
          RecentDocument(
            documentId: DocumentId(pathA),
            openedAt: DateTime.utc(2026, 4, 13),
          ),
          RecentDocument(
            documentId: DocumentId(pathB),
            openedAt: DateTime.utc(2026, 4, 13),
          ),
        ]);
        File(pathB).deleteSync();

        final round = store.read();
        // Both entries are returned — staleness is handled at tap time,
        // not at read time.
        expect(round, hasLength(2));
        expect(round.map((e) => e.documentId.value).toSet(), {pathA, pathB});
      },
    );
  });
}
