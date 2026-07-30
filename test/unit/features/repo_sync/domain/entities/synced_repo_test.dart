import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/features/repo_sync/domain/entities/synced_repo.dart';

SyncedRepo _seed({String? customName}) => SyncedRepo(
  id: 1,
  provider: 'github',
  owner: 'cemililik',
  repo: 'markdown-viewer-mobile',
  ref: 'main',
  localRoot: '/tmp/mv',
  lastSyncedAt: DateTime.utc(2026, 4, 14),
  customName: customName,
);

void main() {
  group('SyncedRepo.displayName', () {
    test('falls back to owner/repo when no customName is set', () {
      expect(_seed().displayName, 'cemililik/markdown-viewer-mobile');
    });

    test('returns the trimmed customName when one is set', () {
      expect(_seed(customName: '  My Docs  ').displayName, 'My Docs');
    });

    test(
      'falls back to owner/repo when customName is empty or whitespace-only',
      () {
        expect(
          _seed(customName: '').displayName,
          'cemililik/markdown-viewer-mobile',
        );
        expect(
          _seed(customName: '   ').displayName,
          'cemililik/markdown-viewer-mobile',
        );
      },
    );
  });
}
