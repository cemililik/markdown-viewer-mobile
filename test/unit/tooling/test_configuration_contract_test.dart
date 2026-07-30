import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'should enforce finite tests and a slower golden tier when test configuration is inspected',
    () {
      final configuration = File('dart_test.yaml').readAsStringSync();

      expect(configuration, contains('timeout: 60s'));
      expect(configuration, contains(RegExp(r'golden:[\s\S]*timeout: 2x')));
      expect(
        configuration,
        contains(RegExp(r'presets:[\s\S]*ci:[\s\S]*reporter: expanded')),
      );
    },
  );

  test(
    'should execute the golden selector explicitly when CI workflow is inspected',
    () {
      final workflow = File('.github/workflows/ci.yml').readAsStringSync();
      final goldenSources =
          Directory('test/golden')
              .listSync(recursive: true)
              .whereType<File>()
              .where((file) => file.path.endsWith('_golden_test.dart'))
              .map((file) => file.readAsStringSync())
              .toList();

      expect(
        workflow,
        contains('flutter test --coverage --exclude-tags golden'),
      );
      expect(workflow, contains('flutter test --tags golden test/golden'));
      expect(goldenSources, isNotEmpty);
      for (final source in goldenSources) {
        expect(
          RegExp(r'goldenTest\(').allMatches(source).length,
          RegExp(r"tags:\s*const\s*\['golden'\]").allMatches(source).length,
        );
      }
    },
  );

  test(
    'should encode benchmark fixtures as UTF-8 when benchmark sources are inspected',
    () {
      final benchmark =
          File(
            'integration_test/benchmark/render_benchmark_test.dart',
          ).readAsStringSync();

      expect(benchmark, contains('utf8.encode'));
      expect(benchmark, isNot(contains('.codeUnits')));
    },
  );
}
