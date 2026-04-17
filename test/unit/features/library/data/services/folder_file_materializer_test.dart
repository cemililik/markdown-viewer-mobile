import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/features/library/data/services/folder_file_materializer.dart';
import 'package:markdown_viewer/features/library/domain/entities/library_folder.dart';
import 'package:markdown_viewer/features/library/domain/services/native_library_folders_channel.dart';

/// Fake [NativeLibraryFoldersChannel] that records its read calls
/// and yields a deterministic byte payload. Implements the domain
/// port directly — no `MethodChannel` plumbing needed because every
/// call route used by `FolderFileMaterializerImpl` (currently just
/// `readFileBytes`) is overridden here.
class _FakeChannel implements NativeLibraryFoldersChannel {
  _FakeChannel({required this.payload});

  final Uint8List payload;
  final List<({String bookmark, String path})> reads = [];

  @override
  Future<Uint8List> readFileBytes({
    required String bookmark,
    required String path,
  }) async {
    reads.add((bookmark: bookmark, path: path));
    return payload;
  }

  @override
  Future<NativeFolderPick?> pickDirectory() async {
    throw UnimplementedError('pickDirectory is not used by this test');
  }

  @override
  Future<List<NativeFolderEntry>> listDirectory(
    String bookmark, {
    String? subPath,
  }) async {
    throw UnimplementedError('listDirectory is not used by this test');
  }

  @override
  Future<List<NativeFolderEntry>> listDirectoryRecursive(
    String bookmark,
  ) async {
    throw UnimplementedError('listDirectoryRecursive is not used by this test');
  }
}

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('folder_materializer_');
  });

  tearDown(() async {
    if (tmp.existsSync()) {
      await tmp.delete(recursive: true);
    }
  });

  FolderFileMaterializerImpl makeMaterializer(_FakeChannel fake) {
    return FolderFileMaterializerImpl(
      channel: fake,
      cacheDirectoryProvider: () async => tmp,
    );
  }

  group('FolderFileMaterializer', () {
    test('bookmark-less folders short-circuit to the source path', () async {
      final fake = _FakeChannel(payload: Uint8List(0));
      final materializer = makeMaterializer(fake);

      final folder = LibraryFolder(
        path: '/tmp/notes',
        addedAt: DateTime.utc(2026, 4, 14),
      );

      final result = await materializer.materialize(
        folder: folder,
        sourcePath: '/tmp/notes/readme.md',
      );

      expect(result, '/tmp/notes/readme.md');
      expect(
        fake.reads,
        isEmpty,
        reason:
            'No bookmark means no native channel hop — the path is '
            'returned verbatim.',
      );
    });

    test('bookmarked folders write the channel bytes into the cache and '
        'return the cache path', () async {
      final payload = Uint8List.fromList('# Hello'.codeUnits);
      final fake = _FakeChannel(payload: payload);
      final materializer = makeMaterializer(fake);

      final folder = LibraryFolder(
        path: '/tmp/notes',
        addedAt: DateTime.utc(2026, 4, 14),
        bookmark: 'base64-blob',
      );

      final cachePath = await materializer.materialize(
        folder: folder,
        sourcePath: '/tmp/notes/intro.md',
      );

      expect(cachePath, contains('library_folder_files'));
      expect(cachePath.endsWith('.md'), isTrue);
      expect(File(cachePath).existsSync(), isTrue);
      expect(await File(cachePath).readAsBytes(), payload);
      expect(fake.reads, hasLength(1));
      expect(fake.reads.single.bookmark, 'base64-blob');
      expect(fake.reads.single.path, '/tmp/notes/intro.md');
    });

    test('preserves the .markdown extension when present', () async {
      final fake = _FakeChannel(
        payload: Uint8List.fromList('payload'.codeUnits),
      );
      final materializer = makeMaterializer(fake);

      final folder = LibraryFolder(
        path: '/tmp/notes',
        addedAt: DateTime.utc(2026, 4, 14),
        bookmark: 'base64-blob',
      );

      final cachePath = await materializer.materialize(
        folder: folder,
        sourcePath: '/tmp/notes/long.markdown',
      );

      expect(cachePath.endsWith('.markdown'), isTrue);
    });

    test(
      'two materializations of the same source land at the same slot',
      () async {
        final firstFake = _FakeChannel(
          payload: Uint8List.fromList('first'.codeUnits),
        );
        final firstMaterializer = makeMaterializer(firstFake);
        final folder = LibraryFolder(
          path: '/tmp/notes',
          addedAt: DateTime.utc(2026, 4, 14),
          bookmark: 'base64-blob',
        );

        final firstPath = await firstMaterializer.materialize(
          folder: folder,
          sourcePath: '/tmp/notes/intro.md',
        );

        final secondFake = _FakeChannel(
          payload: Uint8List.fromList('second'.codeUnits),
        );
        final secondMaterializer = makeMaterializer(secondFake);
        final secondPath = await secondMaterializer.materialize(
          folder: folder,
          sourcePath: '/tmp/notes/intro.md',
        );

        expect(firstPath, secondPath);
        expect(
          await File(secondPath).readAsString(),
          'second',
          reason:
              'A second materialise call must overwrite the previous '
              'cache slot so edits to the source are picked up.',
        );
      },
    );
  });
}
