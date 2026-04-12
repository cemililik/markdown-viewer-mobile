import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/core/errors/failure.dart';
import 'package:markdown_viewer/features/viewer/data/parsers/markdown_parser.dart';
import 'package:markdown_viewer/features/viewer/data/repositories/document_repository_impl.dart';
import 'package:markdown_viewer/features/viewer/domain/entities/document.dart';

void main() {
  const repo = DocumentRepositoryImpl(parser: MarkdownParser());

  group('DocumentRepositoryImpl.load', () {
    test('should load and parse an existing fixture file', () async {
      const path = DocumentId('test/fixtures/markdown/minimal.md');

      final doc = await repo.load(path);

      expect(doc.id, path);
      expect(doc.source, contains('# Hello'));
      expect(doc.headings, hasLength(1));
      expect(doc.headings.single.text, 'Hello');
    });

    test(
      'should throw FileNotFoundFailure when the path does not exist',
      () async {
        const path = DocumentId(
          'test/fixtures/markdown/__definitely_missing__.md',
        );

        await expectLater(
          repo.load(path),
          throwsA(
            isA<FileNotFoundFailure>().having(
              (f) => f.message,
              'message',
              contains('__definitely_missing__'),
            ),
          ),
        );
      },
    );

    test(
      'should throw ParseFailure for a file that is not valid UTF-8',
      () async {
        // Write a byte sequence that cannot decode as UTF-8 into a
        // temp file and point the repository at it.
        final tempDir = Directory.systemTemp.createTempSync('md_viewer_test_');
        addTearDown(() => tempDir.deleteSync(recursive: true));
        final tempFile = File('${tempDir.path}/bad.md')
          ..writeAsBytesSync([0xC3, 0x28]); // lone continuation byte

        await expectLater(
          repo.load(DocumentId(tempFile.path)),
          throwsA(isA<ParseFailure>()),
        );
      },
    );

    test(
      'should throw PermissionDeniedFailure when the file is unreadable',
      () async {
        if (Platform.isWindows) {
          markTestSkipped('POSIX permission semantics do not apply on Windows');
          return;
        }

        // Create a temp file we own, then strip every read bit via
        // chmod. The test verifies that the repository translates an
        // EACCES-style FileSystemException into PermissionDeniedFailure
        // rather than falling through to the ENOENT branch or leaking
        // a raw exception.
        final tempDir = Directory.systemTemp.createTempSync('md_viewer_perm_');
        final tempFile = File('${tempDir.path}/locked.md')
          ..writeAsStringSync('# Locked');

        addTearDown(() {
          // Restore read access so the recursive delete in the next
          // line can actually remove the file.
          Process.runSync('chmod', ['600', tempFile.path]);
          tempDir.deleteSync(recursive: true);
        });

        final chmod = Process.runSync('chmod', ['000', tempFile.path]);
        if (chmod.exitCode != 0) {
          markTestSkipped('chmod 000 failed: ${chmod.stderr}');
          return;
        }

        // Some CI runners execute as root and silently bypass file
        // permissions. If a bare read still succeeds, the environment
        // cannot exercise the permission-denied branch — skip rather
        // than produce a misleading pass.
        try {
          await File(tempFile.path).readAsBytes();
          markTestSkipped(
            'read succeeded despite chmod 000; likely a root runner',
          );
          return;
        } on FileSystemException {
          // expected — proceed to the real assertion
        }

        await expectLater(
          repo.load(DocumentId(tempFile.path)),
          throwsA(isA<PermissionDeniedFailure>()),
        );
      },
    );
  });
}
