import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final pullRequestWorkflow =
      File('.github/workflows/integration.yml').readAsStringSync();
  final reusableWorkflow =
      File('.github/workflows/mobile-quality-gates.yml').readAsStringSync();
  final releaseWorkflow =
      File('.github/workflows/release.yml').readAsStringSync();

  test(
    'should pin every external mobile-gate action when workflow dependencies are inspected',
    () {
      final violations = <String>[];
      for (final source in [pullRequestWorkflow, reusableWorkflow]) {
        for (final match in RegExp(
          r'^\s*uses:\s*([^\s#]+)',
          multiLine: true,
        ).allMatches(source)) {
          final reference = match.group(1)!;
          if (reference.startsWith('./')) continue;
          if (!RegExp(r'@[\da-f]{40}$').hasMatch(reference)) {
            violations.add(reference);
          }
        }
      }

      expect(violations, isEmpty);
    },
  );

  test(
    'should run fixed profile benchmarks on every main pull request when triggers are inspected',
    () {
      expect(pullRequestWorkflow, contains('pull_request:'));
      expect(pullRequestWorkflow, contains('branches: [main]'));
      expect(pullRequestWorkflow, isNot(contains('paths:')));
      expect(
        _job(pullRequestWorkflow, 'performance-android'),
        allOf(contains('run_android_benchmark: true'), isNot(contains('if:'))),
      );
      for (final literal in const [
        'runs-on: ubuntu-24.04',
        'api-level: 35',
        'target: google_apis',
        'arch: x86_64',
        'profile: pixel_6',
        'cores: 4',
        'ram-size: 4096M',
        'heap-size: 512M',
        'disable-linux-hw-accel: false',
      ]) {
        expect(reusableWorkflow, contains(literal));
      }
      final runner =
          File('tool/ci/run_android_quality_gate.sh').readAsStringSync();
      expect(runner, contains('--profile'));
      expect(runner, contains('--no-dds'));
      expect(runner, contains('benchmark_gate.dart compare'));
    },
  );

  test(
    'should keep integration jobs isolated from release secrets when workflows are inspected',
    () {
      expect(reusableWorkflow, isNot(contains('secrets.')));
      expect(reusableWorkflow, isNot(contains('environment: release')));
      expect(releaseWorkflow, isNot(contains('secrets: inherit')));
      expect(
        _job(releaseWorkflow, 'android-quality-gate'),
        isNot(contains('secrets.')),
      );
      expect(
        _job(releaseWorkflow, 'ios-quality-gate'),
        isNot(contains('secrets.')),
      );
    },
  );

  test(
    'should preserve signed release credentials and store delivery when release jobs are inspected',
    () {
      const expectedSecrets = <String>{
        'ANDROID_KEYSTORE_BASE64',
        'ANDROID_KEYSTORE_PASSWORD',
        'ANDROID_KEY_ALIAS',
        'ANDROID_KEY_PASSWORD',
        'GOOGLE_PLAY_SERVICE_ACCOUNT_JSON',
        'IOS_DISTRIBUTION_CERT_BASE64',
        'IOS_DISTRIBUTION_CERT_PASSWORD',
        'APPSTORE_ISSUER_ID',
        'APPSTORE_KEY_ID',
        'APPSTORE_PRIVATE_KEY',
      };
      final actualSecrets =
          RegExp(
            r'secrets\.([A-Z0-9_]+)',
          ).allMatches(releaseWorkflow).map((match) => match.group(1)!).toSet();

      expect(actualSecrets, expectedSecrets);
      final androidRelease = _job(releaseWorkflow, 'android-release');
      final iosRelease = _job(releaseWorkflow, 'ios-release');
      expect(androidRelease, contains('environment: release'));
      expect(iosRelease, contains('environment: release'));
      expect(
        androidRelease,
        allOf(
          contains('needs: [version, verify, android-quality-gate]'),
          contains('flutter build appbundle --release'),
          contains('r0adkll/upload-google-play@'),
          contains('track: internal'),
        ),
      );
      expect(
        iosRelease,
        allOf(
          contains('needs: [version, verify, ios-quality-gate]'),
          contains('flutter build ipa --release'),
          contains('xcrun altool --upload-app'),
          contains('--type ios'),
        ),
      );
      expect(
        _job(releaseWorkflow, 'github-release'),
        allOf(
          contains('needs: [version, android-release, ios-release]'),
          contains('softprops/action-gh-release@'),
        ),
      );
    },
  );

  test(
    'should make real Mermaid failures block critical jobs when commands are inspected',
    () {
      final androidRunner =
          File('tool/ci/run_android_quality_gate.sh').readAsStringSync();
      final iosRunner =
          File('tool/ci/run_ios_integration.sh').readAsStringSync();
      for (final runner in [androidRunner, iosRunner]) {
        expect(runner, contains('integration_test/mermaid_render_test.dart'));
        expect(runner, contains('--no-dds'));
        expect(runner, isNot(contains('flutter test || true')));
      }
      expect(RegExp('--no-dds').allMatches(androidRunner), hasLength(2));
      expect(
        _job(pullRequestWorkflow, 'integration-gate'),
        contains('test "\$CRITICAL_RESULT" = "success"'),
      );
    },
  );

  test(
    'should retain success and failure evidence for ninety days when artifact steps are inspected',
    () {
      expect(
        RegExp(r'retention-days:\s*90').allMatches(reusableWorkflow).length,
        3,
      );
      expect(reusableWorkflow, contains('if: always()'));
      expect(
        File('tool/ci/run_android_quality_gate.sh').readAsStringSync(),
        contains('comparison-report.json'),
      );
    },
  );
}

String _job(String workflow, String name) {
  final start = workflow.indexOf('  $name:');
  if (start < 0) {
    fail('Missing workflow job $name');
  }
  final remainder = workflow.substring(start + 2);
  final next = RegExp(
    '^  [a-zA-Z0-9_-]+:',
    multiLine: true,
  ).firstMatch(remainder.substring(name.length + 1));
  if (next == null) return workflow.substring(start);
  final offset = start + 2 + name.length + 1 + next.start;
  return workflow.substring(start, offset);
}
