import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/features/library/data/services/folder_enumerator_impl.dart';
import 'package:markdown_viewer/features/library/domain/entities/library_folder.dart';
import 'package:markdown_viewer/features/library/domain/services/folder_enumerator.dart';
import 'package:path/path.dart' as p;

/// Builds a [LibraryFolder] around [directory] with no bookmark
/// so the enumerator falls through to the `dart:io` code path.
/// On iOS with a non-null bookmark the enumerator would route
/// to the native channel, which is not available in unit tests.
LibraryFolder _bareFolder(Directory directory) =>
    LibraryFolder(path: directory.path, addedAt: DateTime.utc(2026, 4, 14));

void main() {
  group('FolderEnumeratorImpl', () {
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('folder_enum_test_');
    });

    tearDown(() async {
      if (tmp.existsSync()) {
        await tmp.delete(recursive: true);
      }
    });

    Future<void> touchFile(String path) async {
      final file = File(p.join(tmp.path, path));
      await file.create(recursive: true);
      await file.writeAsString('# placeholder');
    }

    Future<void> mkdir(String path) async {
      await Directory(p.join(tmp.path, path)).create(recursive: true);
    }

    test(
      'returns markdown files and subdirectories at the top level',
      () async {
        await touchFile('readme.md');
        await touchFile('notes.markdown');
        await touchFile('image.png');
        await mkdir('chapter-1');
        await mkdir('chapter-2');

        final entries = await const FolderEnumeratorImpl().enumerate(
          _bareFolder(tmp),
        );

        final names = entries.map((e) => e.name).toList();
        // Subdirectories first, then files, both alphabetically.
        expect(names, [
          'chapter-1',
          'chapter-2',
          'notes.markdown',
          'readme.md',
        ]);
        expect(entries[0], isA<FolderSubdirEntry>());
        expect(entries[1], isA<FolderSubdirEntry>());
        expect(entries[2], isA<FolderFileEntry>());
        expect(entries[3], isA<FolderFileEntry>());
      },
    );

    test('hides dot-files and dot-folders', () async {
      await touchFile('readme.md');
      await touchFile('.hidden.md');
      await mkdir('.git');

      final entries = await const FolderEnumeratorImpl().enumerate(
        _bareFolder(tmp),
      );

      expect(entries.map((e) => e.name), ['readme.md']);
    });

    test('hides non-markdown files', () async {
      await touchFile('readme.md');
      await touchFile('notes.txt');
      await touchFile('photo.jpg');

      final entries = await const FolderEnumeratorImpl().enumerate(
        _bareFolder(tmp),
      );

      expect(entries.map((e) => e.name), ['readme.md']);
    });

    test('returns an empty list for an empty directory', () async {
      final entries = await const FolderEnumeratorImpl().enumerate(
        _bareFolder(tmp),
      );

      expect(entries, isEmpty);
    });

    test('throws on a missing directory', () async {
      final missing = p.join(tmp.path, 'does-not-exist');

      expect(
        () => const FolderEnumeratorImpl().enumerate(
          LibraryFolder(path: missing, addedAt: DateTime.utc(2026, 4, 14)),
        ),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('case-insensitive .md / .markdown extension match', () async {
      await touchFile('readme.MD');
      await touchFile('notes.Markdown');

      final entries = await const FolderEnumeratorImpl().enumerate(
        _bareFolder(tmp),
      );

      expect(entries, hasLength(2));
      expect(entries.every((e) => e is FolderFileEntry), isTrue);
    });
  });

  group('FolderEnumeratorImpl.enumerateRecursive', () {
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('folder_enum_recursive_');
    });

    tearDown(() async {
      if (tmp.existsSync()) {
        await tmp.delete(recursive: true);
      }
    });

    Future<void> touchFile(String path) async {
      final file = File(p.join(tmp.path, path));
      await file.create(recursive: true);
      await file.writeAsString('# placeholder');
    }

    test('walks the full tree and returns every markdown file', () async {
      await touchFile('readme.md');
      await touchFile('chapter-1/intro.md');
      await touchFile('chapter-1/details/deep.md');
      await touchFile('chapter-2/notes.markdown');
      await touchFile('chapter-2/photo.png');
      await touchFile('chapter-2/.ignored.md');

      final entries = await const FolderEnumeratorImpl().enumerateRecursive(
        _bareFolder(tmp),
      );

      final names = entries.map((e) => e.name).toSet();
      expect(
        names,
        containsAll(['readme.md', 'intro.md', 'deep.md', 'notes.markdown']),
      );
      expect(names.contains('photo.png'), isFalse);
      expect(
        names.contains('.ignored.md'),
        isFalse,
        reason: 'Dot-prefixed files must be skipped by the walk.',
      );
    });

    test('skips dot-prefixed directories entirely', () async {
      await touchFile('readme.md');
      await touchFile('.git/HEAD.md');
      await touchFile('.cache/doc.md');

      final entries = await const FolderEnumeratorImpl().enumerateRecursive(
        _bareFolder(tmp),
      );

      expect(entries, hasLength(1));
      expect(entries.first.name, 'readme.md');
    });

    test('returns an empty list for an empty directory', () async {
      final entries = await const FolderEnumeratorImpl().enumerateRecursive(
        _bareFolder(tmp),
      );
      expect(entries, isEmpty);
    });

    test('returns alphabetically sorted results', () async {
      await touchFile('c/c.md');
      await touchFile('a/a.md');
      await touchFile('b/b.md');

      final entries = await const FolderEnumeratorImpl().enumerateRecursive(
        _bareFolder(tmp),
      );

      expect(entries.map((e) => e.name), ['a.md', 'b.md', 'c.md']);
    });

    test('throws on a missing directory', () async {
      final missing = p.join(tmp.path, 'does-not-exist');
      expect(
        () => const FolderEnumeratorImpl().enumerateRecursive(
          LibraryFolder(path: missing, addedAt: DateTime.utc(2026, 4, 14)),
        ),
        throwsA(isA<FileSystemException>()),
      );
    });
  });
}
