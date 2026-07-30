import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

import '../tool/performance/benchmark_contract.dart';

Future<void> main() {
  return integrationDriver(
    writeResponseOnFailure: true,
    responseDataCallback: (data) async {
      if (data == null) {
        throw const FormatException(
          'performance benchmark returned no response data',
        );
      }
      final metadataPath =
          Platform.environment['BENCHMARK_METADATA_PATH'] ??
          'build/performance/environment.json';
      final outputPath =
          Platform.environment['BENCHMARK_OUTPUT_PATH'] ??
          'build/performance/result.json';
      final metadataValue = jsonDecode(await File(metadataPath).readAsString());
      if (metadataValue is! Map) {
        throw const FormatException(
          'benchmark environment metadata must be a JSON object',
        );
      }
      final result = Map<String, Object?>.from(data)
        ..['environment'] = metadataValue.cast<String, Object?>();
      final output = File(outputPath);
      await output.parent.create(recursive: true);
      await output.writeAsString(prettyBenchmarkJson(result), flush: true);
    },
  );
}
