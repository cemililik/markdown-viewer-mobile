import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../../../tool/performance/benchmark_contract.dart';

void main() {
  test(
    'should pass absolute and relative budgets when a valid result is evaluated',
    () {
      final evaluation = evaluateBenchmark(
        result: _result(),
        baseline: _baseline(),
        now: DateTime.utc(2026, 7, 30),
      );

      expect(evaluation.passed, isTrue);
      expect(evaluation.failures, isEmpty);
    },
  );

  test(
    'should allow exactly ten percent regression when the boundary is evaluated',
    () {
      final result = _result(
        values: const {'document_open_first_render_ms': 330},
      );

      final evaluation = evaluateBenchmark(
        result: result,
        baseline: _baseline(),
        now: DateTime.utc(2026, 7, 30),
      );

      expect(evaluation.passed, isTrue);
    },
  );

  test(
    'should fail above ten percent regression when a measured value is evaluated',
    () {
      final result = _result(
        values: const {'document_open_first_render_ms': 330.01},
      );

      final evaluation = evaluateBenchmark(
        result: result,
        baseline: _baseline(),
        now: DateTime.utc(2026, 7, 30),
      );

      expect(evaluation.passed, isFalse);
      expect(evaluation.failures.single, contains('more than 10 percent'));
    },
  );

  test(
    'should fail an absolute budget even without a relative regression when the ceiling is evaluated',
    () {
      final baseline = _baseline(
        values: const {'document_open_first_render_ms': 490},
      );
      final result = _result(
        values: const {'document_open_first_render_ms': 500},
      );

      final evaluation = evaluateBenchmark(
        result: result,
        baseline: baseline,
        now: DateTime.utc(2026, 7, 30),
      );

      expect(evaluation.passed, isFalse);
      expect(evaluation.failures.single, contains('absolute budget'));
    },
  );

  test(
    'should reject incomplete non-finite and negative samples when malformed results are evaluated',
    () {
      final missingMetric = _copy(_result());
      (missingMetric['metrics']! as Map<String, Object?>).remove(
        'library_search_ms',
      );
      final nonFinite = _copy(_result());
      final nonFiniteMetric =
          (nonFinite['metrics']! as Map<String, Object?>)['decode_parse_ms']!
              as Map<String, Object?>;
      nonFiniteMetric['samples'] = <double>[double.nan, 100, 100, 100, 100];
      final negative = _copy(_result());
      final negativeMetric =
          (negative['metrics']! as Map<String, Object?>)['code_highlight_ms']!
              as Map<String, Object?>;
      negativeMetric['samples'] = <double>[-1, 30, 30, 30, 30];

      for (final malformed in [missingMetric, nonFinite, negative]) {
        expect(
          () => evaluateBenchmark(
            result: malformed,
            baseline: _baseline(),
            now: DateTime.utc(2026, 7, 30),
          ),
          throwsA(isA<BenchmarkContractException>()),
        );
      }
    },
  );

  test(
    'should reject a differently configured device when profile metadata is evaluated',
    () {
      final result = _copy(_result());
      final environment = result['environment']! as Map<String, Object?>;
      final profile = environment['profile']! as Map<String, Object?>;
      profile['cores'] = 2;

      expect(
        () => evaluateBenchmark(
          result: result,
          baseline: _baseline(),
          now: DateTime.utc(2026, 7, 30),
        ),
        throwsA(isA<BenchmarkContractException>()),
      );
    },
  );

  test(
    'should reject a stale baseline when its validity window is evaluated',
    () {
      expect(
        () => evaluateBenchmark(
          result: _result(),
          baseline: _baseline(),
          now: DateTime.utc(2026, 11),
        ),
        throwsA(
          isA<BenchmarkContractException>().having(
            (error) => error.message,
            'message',
            contains('expired'),
          ),
        ),
      );
    },
  );

  test(
    'should build provenance from five green runs when calibration inputs are evaluated',
    () {
      final inputs = <CalibrationInput>[
        for (var index = 0; index < 5; index += 1)
          CalibrationInput(
            result: _result(runId: 'run-$index'),
            sha256: index.toString() * 64,
          ),
      ];

      final baseline = buildBenchmarkBaseline(
        calibrations: inputs,
        recordedAt: DateTime.utc(2026, 7, 30),
        validUntil: DateTime.utc(2026, 10, 30),
      );
      final evaluation = evaluateBenchmark(
        result: inputs.first.result,
        baseline: baseline,
        now: DateTime.utc(2026, 7, 30),
      );

      expect(evaluation.passed, isTrue);
      final provenance = baseline['provenance']! as Map<String, Object?>;
      expect(provenance['calibrationRuns'], hasLength(5));
    },
  );

  test(
    'should reject incomplete or over-budget calibration when a baseline is built',
    () {
      final fourRuns = <CalibrationInput>[
        for (var index = 0; index < 4; index += 1)
          CalibrationInput(
            result: _result(runId: 'run-$index'),
            sha256: index.toString() * 64,
          ),
      ];
      final overBudget = <CalibrationInput>[
        for (var index = 0; index < 5; index += 1)
          CalibrationInput(
            result: _result(
              runId: 'run-$index',
              values: const {'code_highlight_ms': 50},
            ),
            sha256: index.toString() * 64,
          ),
      ];

      for (final calibrations in [fourRuns, overBudget]) {
        expect(
          () => buildBenchmarkBaseline(
            calibrations: calibrations,
            recordedAt: DateTime.utc(2026, 7, 30),
            validUntil: DateTime.utc(2026, 10, 30),
          ),
          throwsA(isA<BenchmarkContractException>()),
        );
      }
    },
  );
}

Map<String, Object?> _result({
  String runId = 'run-1',
  Map<String, double> values = const {},
}) {
  const defaults = <String, double>{
    'document_open_first_render_ms': 300,
    'decode_parse_ms': 100,
    'widget_build_ms': 100,
    'scroll_frame_time_ms': 10,
    'code_highlight_ms': 30,
    'mermaid_cold_render_ms': 500,
    'library_search_ms': 100,
  };
  final resolved = {...defaults, ...values};
  return <String, Object?>{
    'schemaVersion': benchmarkSchemaVersion,
    'suite': 'android-fixed-profile-v1',
    'measurement': <String, Object?>{'warmUpCount': 1, 'sampleCount': 5},
    'fixtures': _fixtures(),
    'environment': <String, Object?>{
      'profile': _profile(),
      'run': <String, Object?>{
        'runId': runId,
        'runAttempt': 1,
        'commitSha': 'a' * 40,
        'recordedAt': '2026-07-30T00:00:00Z',
      },
    },
    'metrics': <String, Object?>{
      for (final entry in benchmarkMetricPolicies.entries)
        entry.key: <String, Object?>{
          'unit': entry.value.unit,
          'aggregation': entry.value.aggregation,
          'samples': List<double>.filled(5, resolved[entry.key]!),
          'value': resolved[entry.key]!,
        },
    },
    'timelineSummaries': <String, Object?>{
      for (var index = 0; index < 5; index += 1)
        'scroll_run_$index': <String, Object?>{
          'frame_count': 2,
          'frame_build_times': <int>[9000, 10000],
          'frame_rasterizer_times': <int>[8000, 9000],
        },
    },
  };
}

Map<String, Object?> _baseline({Map<String, double> values = const {}}) {
  const defaults = <String, double>{
    'document_open_first_render_ms': 300,
    'decode_parse_ms': 100,
    'widget_build_ms': 100,
    'scroll_frame_time_ms': 10,
    'code_highlight_ms': 30,
    'mermaid_cold_render_ms': 500,
    'library_search_ms': 100,
  };
  final resolved = {...defaults, ...values};
  return <String, Object?>{
    'schemaVersion': benchmarkSchemaVersion,
    'suite': 'android-fixed-profile-v1',
    'recordedAt': '2026-07-30T00:00:00Z',
    'validUntil': '2026-10-30T00:00:00Z',
    'regressionThresholdPercent': 10,
    'profile': _profile(),
    'fixtures': _fixtures(),
    'metrics': <String, Object?>{
      for (final entry in benchmarkMetricPolicies.entries)
        entry.key: <String, Object?>{
          'unit': entry.value.unit,
          'aggregation': entry.value.aggregation,
          'absoluteBudget': entry.value.absoluteBudget,
          'comparison': entry.value.comparison.name,
          'baselineValue': resolved[entry.key]!,
        },
    },
    'provenance': <String, Object?>{
      'calibrationRuns': <Object?>[
        for (var index = 0; index < 5; index += 1)
          <String, Object?>{
            'runId': 'run-$index',
            'runAttempt': 1,
            'commitSha': 'a' * 40,
            'resultSha256': index.toString() * 64,
          },
      ],
    },
  };
}

Map<String, Object?> _profile() => <String, Object?>{
  'runner': 'ubuntu-24.04',
  'runnerImageOS': 'ubuntu24',
  'runnerImageVersion': '20260727.1',
  'flutterVersion': '3.41.4',
  'dartVersion': '3.11.1',
  'javaVersion': '17.0.12',
  'androidApiLevel': 35,
  'systemImageTarget': 'google_apis',
  'architecture': 'x86_64',
  'hardwareProfile': 'pixel_6',
  'cores': 4,
  'ramMb': 4096,
  'heapMb': 512,
  'locale': 'en-US',
  'displaySize': 'Override size: 1080x2400',
  'displayDensity': 'Override density: 420',
  'emulatorVersion': 'Android emulator version 36.2.2',
  'systemImageFingerprint': 'google/sdk_gphone64_x86_64/emu64',
  'emulatorOptions':
      '-no-window -noaudio -no-boot-anim -no-snapshot -gpu swiftshader_indirect',
};

Map<String, Object?> _fixtures() => <String, Object?>{
  'documentBytes': 1048700,
  'scrollLines': 10000,
  'codeLines': 1000,
  'searchDocuments': 500,
  'searchCorpusBytes': 64000,
  'locale': 'en-US',
  'viewportLogicalWidth': 390,
  'viewportLogicalHeight': 844,
  'devicePixelRatio': 3,
};

Map<String, Object?> _copy(Map<String, Object?> value) =>
    (jsonDecode(jsonEncode(value)) as Map).cast<String, Object?>();
