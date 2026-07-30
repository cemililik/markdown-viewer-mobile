import 'dart:convert';

/// Version of the machine-readable benchmark and baseline contract.
const benchmarkSchemaVersion = 2;

/// Hosted regression metrics and aggregation rules approved in ADR-0027.
const benchmarkMetricPolicies = <String, BenchmarkMetricPolicy>{
  'document_open_first_render_ms': BenchmarkMetricPolicy(
    unit: 'ms',
    aggregation: 'median',
  ),
  'decode_parse_ms': BenchmarkMetricPolicy(unit: 'ms', aggregation: 'median'),
  'widget_build_ms': BenchmarkMetricPolicy(unit: 'ms', aggregation: 'median'),
  'scroll_frame_time_ms': BenchmarkMetricPolicy(unit: 'ms', aggregation: 'p95'),
  'code_highlight_ms': BenchmarkMetricPolicy(unit: 'ms', aggregation: 'median'),
  'mermaid_cold_render_ms': BenchmarkMetricPolicy(
    unit: 'ms',
    aggregation: 'median',
  ),
  'library_search_ms': BenchmarkMetricPolicy(unit: 'ms', aggregation: 'median'),
};

/// Immutable policy for one benchmark metric.
final class BenchmarkMetricPolicy {
  /// Creates a metric policy.
  const BenchmarkMetricPolicy({required this.unit, required this.aggregation});

  /// Unit emitted by the benchmark.
  final String unit;

  /// Aggregation applied to the five measured samples.
  final String aggregation;
}

/// A benchmark result together with its content digest for baseline provenance.
final class CalibrationInput {
  /// Creates one calibration input.
  const CalibrationInput({required this.result, required this.sha256});

  /// Parsed benchmark result.
  final Map<String, Object?> result;

  /// SHA-256 of the unmodified result file.
  final String sha256;
}

/// Result of comparing one benchmark run with the versioned baseline.
final class BenchmarkEvaluation {
  /// Creates an evaluation.
  const BenchmarkEvaluation({
    required this.metricReports,
    required this.failures,
  });

  /// Per-metric values and limits suitable for the CI artifact.
  final Map<String, Map<String, Object?>> metricReports;

  /// Human-readable violations. Empty means the gate passed.
  final List<String> failures;

  /// Whether every schema and hosted-regression check passed.
  bool get passed => failures.isEmpty;

  /// Encodes this evaluation as the comparison-report JSON document.
  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': benchmarkSchemaVersion,
    'passed': passed,
    'failures': failures,
    'metrics': metricReports,
  };
}

/// Thrown when a result or baseline is incomplete, malformed, or stale.
final class BenchmarkContractException implements Exception {
  /// Creates a contract exception for [message].
  const BenchmarkContractException(this.message);

  /// Actionable reason the input was rejected.
  final String message;

  @override
  String toString() => 'BenchmarkContractException: $message';
}

/// Compares [result] with [baseline] and returns every budget violation.
///
/// Structural problems throw [BenchmarkContractException] so malformed or
/// differently configured inputs fail closed before values are compared.
BenchmarkEvaluation evaluateBenchmark({
  required Map<String, Object?> result,
  required Map<String, Object?> baseline,
  DateTime? now,
}) {
  _validateEnvelope(result, path: 'result');
  _validateEnvelope(baseline, path: 'baseline');
  _expectEqual(
    result['suite'],
    baseline['suite'],
    'result.suite must match baseline.suite',
  );

  final validUntil = DateTime.tryParse(
    _requiredString(baseline['validUntil'], 'baseline.validUntil'),
  );
  if (validUntil == null) {
    throw const BenchmarkContractException(
      'baseline.validUntil must be an ISO-8601 timestamp',
    );
  }
  final currentTime = (now ?? DateTime.now()).toUtc();
  if (currentTime.isAfter(validUntil.toUtc())) {
    throw BenchmarkContractException(
      'baseline expired at ${validUntil.toUtc().toIso8601String()}',
    );
  }

  final resultEnvironment = _requiredMap(
    result['environment'],
    'result.environment',
  );
  _expectExactKeys(resultEnvironment, const {
    'profile',
    'runObservations',
  }, 'result.environment');
  final resultProfile = _requiredMap(
    resultEnvironment['profile'],
    'result.environment.profile',
  );
  _validateProfile(resultProfile, 'result.environment.profile');
  _validateRunObservations(
    _requiredMap(
      resultEnvironment['runObservations'],
      'result.environment.runObservations',
    ),
    'result.environment.runObservations',
  );
  final baselineProfile = _requiredMap(baseline['profile'], 'baseline.profile');
  _validateProfile(baselineProfile, 'baseline.profile');
  if (!_deepEquals(resultProfile, baselineProfile)) {
    throw const BenchmarkContractException(
      'result.environment.profile must exactly match baseline.profile',
    );
  }

  final resultFixtures = _requiredMap(result['fixtures'], 'result.fixtures');
  _validateFixtures(resultFixtures, 'result.fixtures');
  final baselineFixtures = _requiredMap(
    baseline['fixtures'],
    'baseline.fixtures',
  );
  _validateFixtures(baselineFixtures, 'baseline.fixtures');
  if (!_deepEquals(resultFixtures, baselineFixtures)) {
    throw const BenchmarkContractException(
      'result.fixtures must exactly match baseline.fixtures',
    );
  }

  final measurement = _requiredMap(result['measurement'], 'result.measurement');
  _expectInteger(
    measurement['warmUpCount'],
    1,
    'result.measurement.warmUpCount',
  );
  _expectInteger(
    measurement['sampleCount'],
    5,
    'result.measurement.sampleCount',
  );
  _validateTimelineSummaries(result);
  _validateProvenance(baseline);

  final threshold = _finiteNumber(
    baseline['regressionThresholdPercent'],
    'baseline.regressionThresholdPercent',
  );
  if (threshold != 10) {
    throw const BenchmarkContractException(
      'baseline.regressionThresholdPercent must remain exactly 10',
    );
  }

  final resultMetrics = _requiredMap(result['metrics'], 'result.metrics');
  final baselineMetrics = _requiredMap(baseline['metrics'], 'baseline.metrics');
  _expectMetricSet(resultMetrics, 'result.metrics');
  _expectMetricSet(baselineMetrics, 'baseline.metrics');

  final failures = <String>[];
  final reports = <String, Map<String, Object?>>{};
  for (final entry in benchmarkMetricPolicies.entries) {
    final name = entry.key;
    final policy = entry.value;
    final measured = _requiredMap(resultMetrics[name], 'result.metrics.$name');
    final reference = _requiredMap(
      baselineMetrics[name],
      'baseline.metrics.$name',
    );
    _validatePolicy(reference, name, policy);
    _expectEqual(
      measured['unit'],
      policy.unit,
      'result.metrics.$name.unit must be ${policy.unit}',
    );
    _expectEqual(
      measured['aggregation'],
      policy.aggregation,
      'result.metrics.$name.aggregation must be ${policy.aggregation}',
    );

    final rawSamples = measured['samples'];
    if (rawSamples is! List || rawSamples.length != 5) {
      throw BenchmarkContractException(
        'result.metrics.$name.samples must contain exactly five values',
      );
    }
    final samples = <double>[
      for (var index = 0; index < rawSamples.length; index += 1)
        _nonNegativeFiniteNumber(
          rawSamples[index],
          'result.metrics.$name.samples[$index]',
        ),
    ];
    final expectedValue = _aggregate(samples, policy.aggregation);
    final value = _nonNegativeFiniteNumber(
      measured['value'],
      'result.metrics.$name.value',
    );
    if ((value - expectedValue).abs() > 0.000001) {
      throw BenchmarkContractException(
        'result.metrics.$name.value does not match its '
        '${policy.aggregation} aggregation',
      );
    }

    final baselineValue = _positiveFiniteNumber(
      reference['baselineValue'],
      'baseline.metrics.$name.baselineValue',
    );
    final allowedRegressionValue = baselineValue * 1.1;
    final regressionPassed = value <= allowedRegressionValue + 0.000001;
    if (!regressionPassed) {
      failures.add(
        '$name regressed by more than 10 percent: '
        '$value ${policy.unit} vs baseline $baselineValue ${policy.unit}',
      );
    }
    reports[name] = <String, Object?>{
      'value': value,
      'unit': policy.unit,
      'aggregation': policy.aggregation,
      'baselineValue': baselineValue,
      'maximumRegressionValue': allowedRegressionValue,
      'regressionPassed': regressionPassed,
    };
  }
  return BenchmarkEvaluation(metricReports: reports, failures: failures);
}

/// Builds a versioned baseline from exactly five complete calibrations.
///
/// Each input must use the same suite, fixed profile, fixture manifest, metric
/// set, and five-sample measurement contract. Each metric uses the maximum
/// complete run-level value as its hosted upper-bound reference.
Map<String, Object?> buildBenchmarkBaseline({
  required List<CalibrationInput> calibrations,
  required DateTime recordedAt,
  required DateTime validUntil,
}) {
  if (calibrations.length != 5) {
    throw const BenchmarkContractException(
      'baseline calibration requires exactly five complete result files',
    );
  }
  final first = calibrations.first.result;
  _validateEnvelope(first, path: 'calibration[0]');
  final suite = _requiredString(first['suite'], 'calibration[0].suite');
  final environment = _requiredMap(
    first['environment'],
    'calibration[0].environment',
  );
  _expectExactKeys(environment, const {
    'profile',
    'runObservations',
  }, 'calibration[0].environment');
  final profile = _requiredMap(
    environment['profile'],
    'calibration[0].environment.profile',
  );
  _validateProfile(profile, 'calibration[0].environment.profile');
  final fixtures = _requiredMap(first['fixtures'], 'calibration[0].fixtures');
  _validateFixtures(fixtures, 'calibration[0].fixtures');
  final metricValues = <String, List<double>>{
    for (final name in benchmarkMetricPolicies.keys) name: <double>[],
  };
  final provenance = <Map<String, Object?>>[];

  for (var index = 0; index < calibrations.length; index += 1) {
    final calibration = calibrations[index];
    final result = calibration.result;
    _validateEnvelope(result, path: 'calibration[$index]');
    _expectEqual(
      result['suite'],
      suite,
      'calibration[$index].suite must match the first calibration',
    );
    final currentEnvironment = _requiredMap(
      result['environment'],
      'calibration[$index].environment',
    );
    _expectExactKeys(currentEnvironment, const {
      'profile',
      'runObservations',
    }, 'calibration[$index].environment');
    _validateRunObservations(
      _requiredMap(
        currentEnvironment['runObservations'],
        'calibration[$index].environment.runObservations',
      ),
      'calibration[$index].environment.runObservations',
    );
    if (!_deepEquals(
      _requiredMap(
        currentEnvironment['profile'],
        'calibration[$index].environment.profile',
      ),
      profile,
    )) {
      throw BenchmarkContractException(
        'calibration[$index] uses a different fixed profile',
      );
    }
    if (!_deepEquals(
      _requiredMap(result['fixtures'], 'calibration[$index].fixtures'),
      fixtures,
    )) {
      throw BenchmarkContractException(
        'calibration[$index] uses different fixtures',
      );
    }
    final measurement = _requiredMap(
      result['measurement'],
      'calibration[$index].measurement',
    );
    _expectInteger(
      measurement['warmUpCount'],
      1,
      'calibration[$index].measurement.warmUpCount',
    );
    _expectInteger(
      measurement['sampleCount'],
      5,
      'calibration[$index].measurement.sampleCount',
    );
    _validateTimelineSummaries(result, path: 'calibration[$index]');
    final metrics = _requiredMap(
      result['metrics'],
      'calibration[$index].metrics',
    );
    _expectMetricSet(metrics, 'calibration[$index].metrics');
    for (final entry in benchmarkMetricPolicies.entries) {
      final name = entry.key;
      final policy = entry.value;
      final metric = _requiredMap(
        metrics[name],
        'calibration[$index].metrics.$name',
      );
      final value = _validateCalibrationMetric(metric, name, policy, index);
      metricValues[name]!.add(value);
    }

    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(calibration.sha256)) {
      throw BenchmarkContractException(
        'calibration[$index] has an invalid result SHA-256',
      );
    }
    final observations = _requiredMap(
      currentEnvironment['runObservations'],
      'calibration[$index].environment.runObservations',
    );
    provenance.add(<String, Object?>{
      'runId': _requiredString(
        observations['runId'],
        'calibration[$index].environment.runObservations.runId',
      ),
      'runAttempt': _positiveInteger(
        observations['runAttempt'],
        'calibration[$index].environment.runObservations.runAttempt',
      ),
      'commitSha': _commitSha(
        observations['commitSha'],
        'calibration[$index].environment.runObservations.commitSha',
      ),
      'recordedAt': _requiredString(
        observations['recordedAt'],
        'calibration[$index].environment.runObservations.recordedAt',
      ),
      'runnerImageVersion': _requiredString(
        observations['runnerImageVersion'],
        'calibration[$index].environment.runObservations.runnerImageVersion',
      ),
      'guestMemoryKb': _positiveInteger(
        observations['guestMemoryKb'],
        'calibration[$index].environment.runObservations.guestMemoryKb',
      ),
      'resultSha256': calibration.sha256,
    });
  }

  return <String, Object?>{
    'schemaVersion': benchmarkSchemaVersion,
    'suite': suite,
    'recordedAt': recordedAt.toUtc().toIso8601String(),
    'validUntil': validUntil.toUtc().toIso8601String(),
    'regressionThresholdPercent': 10,
    'profile': profile,
    'fixtures': fixtures,
    'metrics': <String, Object?>{
      for (final entry in benchmarkMetricPolicies.entries)
        entry.key: <String, Object?>{
          'unit': entry.value.unit,
          'aggregation': entry.value.aggregation,
          'baselineValue': _maximum(metricValues[entry.key]!),
        },
    },
    'provenance': <String, Object?>{'calibrationRuns': provenance},
  };
}

double _validateCalibrationMetric(
  Map<String, Object?> metric,
  String name,
  BenchmarkMetricPolicy policy,
  int calibrationIndex,
) {
  _expectEqual(
    metric['unit'],
    policy.unit,
    'calibration[$calibrationIndex].metrics.$name.unit is invalid',
  );
  _expectEqual(
    metric['aggregation'],
    policy.aggregation,
    'calibration[$calibrationIndex].metrics.$name.aggregation is invalid',
  );
  final rawSamples = metric['samples'];
  if (rawSamples is! List || rawSamples.length != 5) {
    throw BenchmarkContractException(
      'calibration[$calibrationIndex].metrics.$name.samples must contain '
      'exactly five values',
    );
  }
  final samples = <double>[
    for (var index = 0; index < rawSamples.length; index += 1)
      _nonNegativeFiniteNumber(
        rawSamples[index],
        'calibration[$calibrationIndex].metrics.$name.samples[$index]',
      ),
  ];
  final aggregate = _aggregate(samples, policy.aggregation);
  final reported = _nonNegativeFiniteNumber(
    metric['value'],
    'calibration[$calibrationIndex].metrics.$name.value',
  );
  if ((aggregate - reported).abs() > 0.000001) {
    throw BenchmarkContractException(
      'calibration[$calibrationIndex].metrics.$name.value does not match '
      'its samples',
    );
  }
  return reported;
}

void _validateEnvelope(Map<String, Object?> input, {required String path}) {
  _expectInteger(
    input['schemaVersion'],
    benchmarkSchemaVersion,
    '$path.schemaVersion',
  );
  _requiredString(input['suite'], '$path.suite');
}

void _validateProfile(Map<String, Object?> profile, String path) {
  const keys = <String>{
    'runner',
    'runnerImageOS',
    'flutterVersion',
    'dartVersion',
    'javaVersion',
    'androidApiLevel',
    'systemImageTarget',
    'architecture',
    'hardwareProfile',
    'configuredCores',
    'configuredRamMb',
    'configuredHeapMb',
    'guestCpuCount',
    'dalvikHeap',
    'locale',
    'displaySize',
    'displayDensity',
    'emulatorVersion',
    'emulatorBuild',
    'systemImageFingerprint',
    'emulatorOptions',
  };
  if (profile.keys.toSet().length != keys.length ||
      !profile.keys.toSet().containsAll(keys)) {
    throw BenchmarkContractException(
      '$path must contain exactly the fixed-profile metadata keys',
    );
  }
  _expectEqual(profile['runner'], 'ubuntu-24.04', '$path.runner is invalid');
  _requiredString(profile['runnerImageOS'], '$path.runnerImageOS');
  _requiredString(profile['flutterVersion'], '$path.flutterVersion');
  _requiredString(profile['dartVersion'], '$path.dartVersion');
  _requiredString(profile['javaVersion'], '$path.javaVersion');
  _expectInteger(profile['androidApiLevel'], 35, '$path.androidApiLevel');
  _expectEqual(
    profile['systemImageTarget'],
    'google_apis',
    '$path.systemImageTarget is invalid',
  );
  _expectEqual(
    profile['architecture'],
    'x86_64',
    '$path.architecture is invalid',
  );
  _expectEqual(
    profile['hardwareProfile'],
    'pixel_6',
    '$path.hardwareProfile is invalid',
  );
  _expectInteger(profile['configuredCores'], 4, '$path.configuredCores');
  _expectInteger(profile['configuredRamMb'], 4096, '$path.configuredRamMb');
  _expectInteger(profile['configuredHeapMb'], 512, '$path.configuredHeapMb');
  _expectInteger(profile['guestCpuCount'], 4, '$path.guestCpuCount');
  _requiredString(profile['dalvikHeap'], '$path.dalvikHeap');
  _expectEqual(profile['locale'], 'en-US', '$path.locale is invalid');
  final size = _requiredString(profile['displaySize'], '$path.displaySize');
  if (!size.contains('1080x2400')) {
    throw BenchmarkContractException('$path.displaySize is invalid');
  }
  final density = _requiredString(
    profile['displayDensity'],
    '$path.displayDensity',
  );
  if (!density.contains('420')) {
    throw BenchmarkContractException('$path.displayDensity is invalid');
  }
  _requiredString(profile['emulatorVersion'], '$path.emulatorVersion');
  _expectInteger(profile['emulatorBuild'], 15507667, '$path.emulatorBuild');
  _requiredString(
    profile['systemImageFingerprint'],
    '$path.systemImageFingerprint',
  );
  final options = _requiredString(
    profile['emulatorOptions'],
    '$path.emulatorOptions',
  );
  for (final requiredOption in const <String>[
    '-no-window',
    '-accel on',
    '-no-metrics',
    '-noaudio',
    '-no-boot-anim',
    '-no-snapshot',
  ]) {
    if (!options.contains(requiredOption)) {
      throw BenchmarkContractException(
        '$path.emulatorOptions must contain $requiredOption',
      );
    }
  }
}

void _validateFixtures(Map<String, Object?> fixtures, String path) {
  const keys = <String>{
    'documentBytes',
    'scrollLines',
    'codeLines',
    'searchDocuments',
    'searchCorpusBytes',
    'locale',
    'viewportLogicalWidth',
    'viewportLogicalHeight',
    'devicePixelRatio',
  };
  if (fixtures.keys.toSet().length != keys.length ||
      !fixtures.keys.toSet().containsAll(keys)) {
    throw BenchmarkContractException(
      '$path must contain exactly the fixture-manifest keys',
    );
  }
  final documentBytes = _positiveInteger(
    fixtures['documentBytes'],
    '$path.documentBytes',
  );
  if (documentBytes < 1024 * 1024) {
    throw BenchmarkContractException(
      '$path.documentBytes must be at least one MiB',
    );
  }
  _expectInteger(fixtures['scrollLines'], 10000, '$path.scrollLines');
  _expectInteger(fixtures['codeLines'], 1000, '$path.codeLines');
  _expectInteger(fixtures['searchDocuments'], 500, '$path.searchDocuments');
  _positiveInteger(fixtures['searchCorpusBytes'], '$path.searchCorpusBytes');
  _expectEqual(fixtures['locale'], 'en-US', '$path.locale is invalid');
  _expectInteger(
    fixtures['viewportLogicalWidth'],
    390,
    '$path.viewportLogicalWidth',
  );
  _expectInteger(
    fixtures['viewportLogicalHeight'],
    844,
    '$path.viewportLogicalHeight',
  );
  _expectInteger(fixtures['devicePixelRatio'], 3, '$path.devicePixelRatio');
}

void _validateRunObservations(Map<String, Object?> observations, String path) {
  const keys = <String>{
    'runnerImageVersion',
    'guestMemoryKb',
    'runId',
    'runAttempt',
    'commitSha',
    'recordedAt',
  };
  if (observations.keys.toSet().length != keys.length ||
      !observations.keys.toSet().containsAll(keys)) {
    throw BenchmarkContractException(
      '$path must contain exactly the run-observation metadata keys',
    );
  }
  _requiredString(
    observations['runnerImageVersion'],
    '$path.runnerImageVersion',
  );
  _positiveInteger(observations['guestMemoryKb'], '$path.guestMemoryKb');
  _requiredString(observations['runId'], '$path.runId');
  _positiveInteger(observations['runAttempt'], '$path.runAttempt');
  _commitSha(observations['commitSha'], '$path.commitSha');
  final recordedAt = DateTime.tryParse(
    _requiredString(observations['recordedAt'], '$path.recordedAt'),
  );
  if (recordedAt == null) {
    throw BenchmarkContractException(
      '$path.recordedAt must be an ISO-8601 timestamp',
    );
  }
}

void _validateTimelineSummaries(
  Map<String, Object?> result, {
  String path = 'result',
}) {
  final summaries = _requiredMap(
    result['timelineSummaries'],
    '$path.timelineSummaries',
  );
  final expectedKeys = <String>{
    for (var index = 0; index < 5; index += 1) 'scroll_run_$index',
  };
  if (summaries.keys.toSet().length != expectedKeys.length ||
      !summaries.keys.toSet().containsAll(expectedKeys)) {
    throw BenchmarkContractException(
      '$path.timelineSummaries must contain all five scroll runs',
    );
  }
  for (final key in expectedKeys) {
    final summary = _requiredMap(
      summaries[key],
      '$path.timelineSummaries.$key',
    );
    final frameCount = _positiveInteger(
      summary['frame_count'],
      '$path.timelineSummaries.$key.frame_count',
    );
    for (final field in const <String>[
      'frame_build_times',
      'frame_rasterizer_times',
    ]) {
      final values = summary[field];
      if (values is! List || values.length != frameCount) {
        throw BenchmarkContractException(
          '$path.timelineSummaries.$key.$field must match frame_count',
        );
      }
      for (var index = 0; index < values.length; index += 1) {
        _nonNegativeFiniteNumber(
          values[index],
          '$path.timelineSummaries.$key.$field[$index]',
        );
      }
    }
  }
}

void _validatePolicy(
  Map<String, Object?> reference,
  String name,
  BenchmarkMetricPolicy policy,
) {
  _expectExactKeys(reference, const {
    'unit',
    'aggregation',
    'baselineValue',
  }, 'baseline.metrics.$name');
  _expectEqual(
    reference['unit'],
    policy.unit,
    'baseline.metrics.$name.unit must be ${policy.unit}',
  );
  _expectEqual(
    reference['aggregation'],
    policy.aggregation,
    'baseline.metrics.$name.aggregation must be ${policy.aggregation}',
  );
}

void _validateProvenance(Map<String, Object?> baseline) {
  final provenance = _requiredMap(
    baseline['provenance'],
    'baseline.provenance',
  );
  final runs = provenance['calibrationRuns'];
  if (runs is! List || runs.length != 5) {
    throw const BenchmarkContractException(
      'baseline.provenance.calibrationRuns must contain exactly five runs',
    );
  }
  for (var index = 0; index < runs.length; index += 1) {
    final run = _requiredMap(
      runs[index],
      'baseline.provenance.calibrationRuns[$index]',
    );
    _expectExactKeys(run, const {
      'runId',
      'runAttempt',
      'commitSha',
      'recordedAt',
      'runnerImageVersion',
      'guestMemoryKb',
      'resultSha256',
    }, 'baseline.provenance.calibrationRuns[$index]');
    _requiredString(
      run['runId'],
      'baseline.provenance.calibrationRuns[$index].runId',
    );
    _positiveInteger(
      run['runAttempt'],
      'baseline.provenance.calibrationRuns[$index].runAttempt',
    );
    _commitSha(
      run['commitSha'],
      'baseline.provenance.calibrationRuns[$index].commitSha',
    );
    final recordedAt = DateTime.tryParse(
      _requiredString(
        run['recordedAt'],
        'baseline.provenance.calibrationRuns[$index].recordedAt',
      ),
    );
    if (recordedAt == null) {
      throw BenchmarkContractException(
        'baseline.provenance.calibrationRuns[$index].recordedAt '
        'must be an ISO-8601 timestamp',
      );
    }
    _requiredString(
      run['runnerImageVersion'],
      'baseline.provenance.calibrationRuns[$index].runnerImageVersion',
    );
    _positiveInteger(
      run['guestMemoryKb'],
      'baseline.provenance.calibrationRuns[$index].guestMemoryKb',
    );
    final digest = _requiredString(
      run['resultSha256'],
      'baseline.provenance.calibrationRuns[$index].resultSha256',
    );
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(digest)) {
      throw BenchmarkContractException(
        'baseline.provenance.calibrationRuns[$index].resultSha256 '
        'must be a lowercase SHA-256',
      );
    }
  }
}

void _expectMetricSet(Map<String, Object?> metrics, String path) {
  final expected = benchmarkMetricPolicies.keys.toSet();
  final actual = metrics.keys.toSet();
  if (actual.length != expected.length || !actual.containsAll(expected)) {
    throw BenchmarkContractException(
      '$path must contain exactly ${expected.toList()..sort()}',
    );
  }
}

void _expectExactKeys(
  Map<String, Object?> value,
  Set<String> expected,
  String path,
) {
  final actual = value.keys.toSet();
  if (actual.length != expected.length || !actual.containsAll(expected)) {
    throw BenchmarkContractException(
      '$path must contain exactly ${expected.toList()..sort()}',
    );
  }
}

double _aggregate(List<double> values, String aggregation) {
  if (values.isEmpty) {
    throw const BenchmarkContractException('cannot aggregate an empty sample');
  }
  final sorted = [...values]..sort();
  return switch (aggregation) {
    'median' => sorted[sorted.length ~/ 2],
    'p95' => sorted[((sorted.length - 1) * 0.95).ceil()],
    _ =>
      throw BenchmarkContractException(
        'unsupported aggregation "$aggregation"',
      ),
  };
}

double _maximum(List<double> values) {
  if (values.isEmpty) {
    throw const BenchmarkContractException('cannot select an empty maximum');
  }
  return values.reduce((current, value) => value > current ? value : current);
}

Map<String, Object?> _requiredMap(Object? value, String path) {
  if (value is! Map) {
    throw BenchmarkContractException('$path must be an object');
  }
  try {
    return value.cast<String, Object?>();
  } on TypeError {
    throw BenchmarkContractException('$path keys must be strings');
  }
}

String _requiredString(Object? value, String path) {
  if (value is! String || value.trim().isEmpty) {
    throw BenchmarkContractException('$path must be a non-empty string');
  }
  return value;
}

String _commitSha(Object? value, String path) {
  final sha = _requiredString(value, path);
  if (!RegExp(r'^[0-9a-f]{40}$').hasMatch(sha)) {
    throw BenchmarkContractException('$path must be a lowercase commit SHA');
  }
  return sha;
}

int _positiveInteger(Object? value, String path) {
  if (value is! int || value <= 0) {
    throw BenchmarkContractException('$path must be a positive integer');
  }
  return value;
}

void _expectInteger(Object? value, int expected, String path) {
  if (value != expected) {
    throw BenchmarkContractException('$path must be exactly $expected');
  }
}

double _finiteNumber(Object? value, String path) {
  if (value is! num || !value.isFinite) {
    throw BenchmarkContractException('$path must be finite');
  }
  return value.toDouble();
}

double _nonNegativeFiniteNumber(Object? value, String path) {
  final number = _finiteNumber(value, path);
  if (number < 0) {
    throw BenchmarkContractException('$path cannot be negative');
  }
  return number;
}

double _positiveFiniteNumber(Object? value, String path) {
  final number = _finiteNumber(value, path);
  if (number <= 0) {
    throw BenchmarkContractException('$path must be greater than zero');
  }
  return number;
}

void _expectEqual(Object? actual, Object? expected, String message) {
  if (actual != expected) {
    throw BenchmarkContractException(message);
  }
}

bool _deepEquals(Object? left, Object? right) {
  if (left is Map && right is Map) {
    if (left.length != right.length) return false;
    for (final entry in left.entries) {
      if (!right.containsKey(entry.key) ||
          !_deepEquals(entry.value, right[entry.key])) {
        return false;
      }
    }
    return true;
  }
  if (left is List && right is List) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index += 1) {
      if (!_deepEquals(left[index], right[index])) return false;
    }
    return true;
  }
  return left == right;
}

/// Pretty-prints a JSON artifact with a trailing newline.
String prettyBenchmarkJson(Map<String, Object?> value) =>
    '${const JsonEncoder.withIndent('  ').convert(value)}\n';
