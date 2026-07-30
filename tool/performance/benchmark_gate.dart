import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'benchmark_contract.dart';

Future<void> main(List<String> arguments) async {
  try {
    if (arguments.isEmpty) {
      throw const FormatException('expected compare or calibrate command');
    }
    final command = arguments.first;
    final options = _parseOptions(arguments.skip(1).toList());
    switch (command) {
      case 'compare':
        await _compare(options);
      case 'calibrate':
        await _calibrate(options);
      default:
        throw FormatException('unknown command "$command"');
    }
  } on Object catch (error) {
    stderr.writeln(error);
    exitCode = 64;
  }
}

Future<void> _compare(Map<String, String> options) async {
  final resultPath = _requiredOption(options, 'result');
  final baselinePath = _requiredOption(options, 'baseline');
  final reportPath = _requiredOption(options, 'report');
  final result = await _readJson(resultPath);
  final baseline = await _readJson(baselinePath);

  try {
    final evaluation = evaluateBenchmark(result: result, baseline: baseline);
    await _writeJson(reportPath, evaluation.toJson());
    stdout.writeln(
      evaluation.passed
          ? 'Performance gate passed.'
          : 'Performance gate failed:\n${evaluation.failures.join('\n')}',
    );
    if (!evaluation.passed) {
      exitCode = 1;
    }
  } on BenchmarkContractException catch (error) {
    await _writeJson(reportPath, <String, Object?>{
      'schemaVersion': benchmarkSchemaVersion,
      'passed': false,
      'failures': <String>[error.message],
      'metrics': <String, Object?>{},
    });
    stderr.writeln(error);
    exitCode = 1;
  }
}

Future<void> _calibrate(Map<String, String> options) async {
  final resultPaths =
      _requiredOption(
        options,
        'results',
      ).split(',').where((path) => path.isNotEmpty).toList();
  final outputPath = _requiredOption(options, 'output');
  final validUntil =
      DateTime.tryParse(_requiredOption(options, 'valid-until')) ??
      (throw const FormatException('--valid-until must be ISO-8601'));
  final calibrations = <CalibrationInput>[];
  for (final path in resultPaths) {
    final bytes = await File(path).readAsBytes();
    calibrations.add(
      CalibrationInput(
        result: _decodeJson(bytes, path),
        sha256: sha256.convert(bytes).toString(),
      ),
    );
  }
  final baseline = buildBenchmarkBaseline(
    calibrations: calibrations,
    recordedAt: DateTime.now().toUtc(),
    validUntil: validUntil,
  );
  await _writeJson(outputPath, baseline);
  stdout.writeln('Wrote calibrated baseline to $outputPath.');
}

Map<String, String> _parseOptions(List<String> arguments) {
  final options = <String, String>{};
  for (var index = 0; index < arguments.length; index += 1) {
    final option = arguments[index];
    if (!option.startsWith('--') || index + 1 >= arguments.length) {
      throw FormatException('invalid option sequence at "$option"');
    }
    final name = option.substring(2);
    if (options.containsKey(name)) {
      throw FormatException('duplicate option --$name');
    }
    options[name] = arguments[++index];
  }
  return options;
}

String _requiredOption(Map<String, String> options, String name) {
  final value = options[name];
  if (value == null || value.isEmpty) {
    throw FormatException('missing --$name');
  }
  return value;
}

Future<Map<String, Object?>> _readJson(String path) async {
  final bytes = await File(path).readAsBytes();
  return _decodeJson(bytes, path);
}

Map<String, Object?> _decodeJson(List<int> bytes, String path) {
  final Object? decoded;
  try {
    decoded = jsonDecode(utf8.decode(bytes));
  } on Object catch (error) {
    throw FormatException('$path is not valid UTF-8 JSON: $error');
  }
  if (decoded is! Map) {
    throw FormatException('$path must contain a JSON object');
  }
  try {
    return decoded.cast<String, Object?>();
  } on TypeError {
    throw FormatException('$path must use string object keys');
  }
}

Future<void> _writeJson(String path, Map<String, Object?> value) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsString(prettyBenchmarkJson(value), flush: true);
}
