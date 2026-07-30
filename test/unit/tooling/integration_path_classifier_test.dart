import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'should classify viewer risk and known safe paths when changed files are evaluated',
    () async {
      const cases = <(List<String>, bool)>[
        (['lib/features/viewer/presentation/screens/viewer_screen.dart'], true),
        (['assets/mermaid/mermaid.min.js'], true),
        (['lib/l10n/app_en.arb'], true),
        (['pubspec.lock'], true),
        (['integration_test/mermaid_render_test.dart'], true),
        (['.github/workflows/release.yml'], true),
        (['docs/README.md'], false),
        (['lib/features/library/domain/entities/library_folder.dart'], false),
        (
          [
            'docs/README.md',
            'lib/features/viewer/domain/entities/document.dart',
          ],
          true,
        ),
        (['unrecognized/new-surface.txt'], true),
        (['../outside-worktree'], true),
        (<String>[], true),
      ];

      for (final testCase in cases) {
        final result = await Process.run('bash', [
          'tool/ci/classify_integration_paths.sh',
          ...testCase.$1,
        ]);

        expect(result.exitCode, 0, reason: result.stderr.toString());
        expect(
          result.stdout.toString().trim(),
          testCase.$2.toString(),
          reason: 'Unexpected classification for ${testCase.$1}',
        );
      }
    },
  );
}
