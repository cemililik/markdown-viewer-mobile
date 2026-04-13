import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/features/viewer/data/repositories/reading_position_store_impl.dart';
import 'package:markdown_viewer/features/viewer/domain/entities/document.dart';
import 'package:markdown_viewer/features/viewer/domain/entities/reading_position.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ReadingPositionStoreImpl', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test(
      'returns null for a document that has never been bookmarked',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final store = ReadingPositionStoreImpl(prefs);

        expect(store.read(const DocumentId('/tmp/none.md')), isNull);
      },
    );

    test('write then read round-trips the offset and timestamp', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = ReadingPositionStoreImpl(prefs);
      final timestamp = DateTime.utc(2026, 4, 13, 12, 30);
      const id = DocumentId('/tmp/example.md');

      await store.write(
        ReadingPosition(documentId: id, offset: 1234.5, savedAt: timestamp),
      );
      final round = store.read(id);

      expect(round, isNotNull);
      expect(round!.offset, 1234.5);
      expect(round.savedAt.toUtc(), timestamp);
      expect(round.documentId, id);
    });

    test('clear removes a previously written bookmark', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = ReadingPositionStoreImpl(prefs);
      const id = DocumentId('/tmp/clear.md');

      await store.write(
        ReadingPosition(
          documentId: id,
          offset: 42,
          savedAt: DateTime.utc(2026, 4, 13),
        ),
      );
      expect(store.read(id), isNotNull);

      await store.clear(id);

      expect(store.read(id), isNull);
    });

    test(
      'two different document paths sit in two different storage slots',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final store = ReadingPositionStoreImpl(prefs);
        const a = DocumentId('/tmp/a.md');
        const b = DocumentId('/tmp/b.md');

        await store.write(
          ReadingPosition(
            documentId: a,
            offset: 100,
            savedAt: DateTime.utc(2026, 4, 13),
          ),
        );
        await store.write(
          ReadingPosition(
            documentId: b,
            offset: 200,
            savedAt: DateTime.utc(2026, 4, 13),
          ),
        );

        expect(store.read(a)!.offset, 100);
        expect(store.read(b)!.offset, 200);
      },
    );

    test(
      'does not leak the raw file path into SharedPreferences keys',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final store = ReadingPositionStoreImpl(prefs);
        const id = DocumentId('/Users/dev/Documents/secret-document.md');

        await store.write(
          ReadingPosition(
            documentId: id,
            offset: 0,
            savedAt: DateTime.utc(2026, 4, 13),
          ),
        );

        expect(
          prefs.getKeys().any((k) => k.contains('secret-document')),
          isFalse,
          reason:
              'File paths must be sha256-hashed before becoming pref keys '
              'so they do not leak into iOS / Android backup blobs.',
        );
        expect(prefs.getKeys().any((k) => k.startsWith('reading.')), isTrue);
      },
    );

    test(
      'survives a corrupted JSON blob by returning null instead of throwing',
      () async {
        SharedPreferences.setMockInitialValues({
          // Use the same hash the impl would produce for the test path
          // by writing through the public API first, then poisoning.
        });
        final prefs = await SharedPreferences.getInstance();
        final store = ReadingPositionStoreImpl(prefs);
        const id = DocumentId('/tmp/poison.md');

        // Save a real value, then corrupt the underlying string.
        await store.write(
          ReadingPosition(
            documentId: id,
            offset: 1,
            savedAt: DateTime.utc(2026, 4, 13),
          ),
        );
        final realKey = prefs.getKeys().firstWhere(
          (k) => k.startsWith('reading.'),
        );
        await prefs.setString(realKey, 'not json{');

        expect(store.read(id), isNull);
      },
    );
  });
}
