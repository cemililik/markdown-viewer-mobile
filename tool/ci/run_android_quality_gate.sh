#!/usr/bin/env bash

set -euo pipefail

: "${RUN_ANDROID_CRITICAL:?RUN_ANDROID_CRITICAL is required}"
: "${RUN_ANDROID_BENCHMARK:?RUN_ANDROID_BENCHMARK is required}"
: "${BENCHMARK_MODE:?BENCHMARK_MODE is required}"

capture_android_log() {
  set +e
  mkdir -p build/quality-logs/android
  timeout 30s adb logcat -d > build/quality-logs/android/logcat.txt || true
}

trap capture_android_log EXIT

mkdir -p build/quality-logs/android build/performance
flutter --version
adb devices -l
emulator_binary="${ANDROID_HOME:?ANDROID_HOME is required}/emulator/emulator"
if ! acceleration_status="$("$emulator_binary" -accel-check 2>&1)"; then
  printf '%s\n' "$acceleration_status" >&2
  exit 1
fi
printf '%s\n' "$acceleration_status"
adb shell wm size 1080x2400
adb shell wm density 420
adb shell settings put global window_animation_scale 0
adb shell settings put global transition_animation_scale 0
adb shell settings put global animator_duration_scale 0

if [[ "$RUN_ANDROID_CRITICAL" == "true" ]]; then
  critical_arguments=(
    integration_test/mermaid_render_test.dart
    -d "emulator-${EMULATOR_PORT:-5554}"
    --no-dds
  )
  if [[ "${CRITICAL_NEGATIVE_CONTROL:-false}" == "true" ]]; then
    critical_arguments+=(--dart-define=MERMAID_GATE_NEGATIVE_CONTROL=true)
  fi
  flutter test "${critical_arguments[@]}" \
    2>&1 | tee build/quality-logs/android/integration.log
fi

if [[ "$RUN_ANDROID_BENCHMARK" == "true" ]]; then
  flutter_json="$(flutter --version --machine)"
  flutter_version="$(jq -r '.frameworkVersion' <<<"$flutter_json")"
  dart_version="$(jq -r '.dartSdkVersion' <<<"$flutter_json")"
  java_version_output="$(java -version 2>&1)"
  java_version="${java_version_output%%$'\n'*}"
  if ! emulator_version_output="$("$emulator_binary" -version 2>&1)"; then
    printf '%s\n' "$emulator_version_output" >&2
    exit 1
  fi
  emulator_version="${emulator_version_output%%$'\n'*}"
  system_image="$(adb shell getprop ro.build.fingerprint | tr -d '\r')"
  actual_locale="$(adb shell getprop persist.sys.locale | tr -d '\r')"
  if [[ -z "$actual_locale" ]]; then
    actual_locale="$(adb shell getprop ro.product.locale | tr -d '\r')"
  fi
  if [[ "$actual_locale" != "en-US" ]]; then
    echo "Fixed-profile locale mismatch: expected en-US, got $actual_locale" >&2
    exit 1
  fi
  actual_size="$(adb shell wm size | tr -d '\r' | tail -n 1)"
  actual_density="$(adb shell wm density | tr -d '\r' | tail -n 1)"
  recorded_at="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"

  jq -n \
    --arg runner "ubuntu-24.04" \
    --arg image_os "${ImageOS:?ImageOS is required}" \
    --arg image_version "${ImageVersion:?ImageVersion is required}" \
    --arg flutter_version "$flutter_version" \
    --arg dart_version "$dart_version" \
    --arg java_version "$java_version" \
    --arg emulator_version "$emulator_version" \
    --arg system_image "$system_image" \
    --arg actual_locale "$actual_locale" \
    --arg actual_size "$actual_size" \
    --arg actual_density "$actual_density" \
    --arg run_id "${GITHUB_RUN_ID:?GITHUB_RUN_ID is required}${BENCHMARK_CALIBRATION_INDEX:+-$BENCHMARK_CALIBRATION_INDEX}" \
    --arg commit_sha "${GITHUB_SHA:?GITHUB_SHA is required}" \
    --arg recorded_at "$recorded_at" \
    --argjson run_attempt "${GITHUB_RUN_ATTEMPT:?GITHUB_RUN_ATTEMPT is required}" \
    '{
      profile: {
        runner: $runner,
        runnerImageOS: $image_os,
        runnerImageVersion: $image_version,
        flutterVersion: $flutter_version,
        dartVersion: $dart_version,
        javaVersion: $java_version,
        androidApiLevel: 35,
        systemImageTarget: "google_apis",
        architecture: "x86_64",
        hardwareProfile: "pixel_6",
        cores: 4,
        ramMb: 4096,
        heapMb: 512,
        locale: $actual_locale,
        displaySize: $actual_size,
        displayDensity: $actual_density,
        emulatorVersion: $emulator_version,
        systemImageFingerprint: $system_image,
        emulatorOptions: "-no-window -gpu swiftshader_indirect -noaudio -no-boot-anim -camera-back none -camera-front none -no-snapshot -no-snapshot-save -no-snapshot-load"
      },
      run: {
        runId: $run_id,
        runAttempt: $run_attempt,
        commitSha: $commit_sha,
        recordedAt: $recorded_at
      }
    }' > build/performance/environment.json

  export BENCHMARK_METADATA_PATH=build/performance/environment.json
  export BENCHMARK_OUTPUT_PATH=build/performance/result.json
  export FLUTTER_TEST_OUTPUTS_DIR=build/performance
  flutter drive \
    --driver=test_driver/performance_test.dart \
    --target=integration_test/benchmark/render_benchmark_test.dart \
    --profile \
    --no-dds \
    --device-id "emulator-${EMULATOR_PORT:-5554}" \
    --timeout 1800 \
    2>&1 | tee build/quality-logs/android/benchmark.log

  jq '.timelineSummaries' \
    build/performance/result.json \
    > build/performance/timeline-summaries.json
  if [[ "$BENCHMARK_MODE" == "enforce" ]]; then
    dart run tool/performance/benchmark_gate.dart compare \
      --result build/performance/result.json \
      --baseline tool/performance/android_fixed_profile_baseline.json \
      --report build/performance/comparison-report.json
  elif [[ "$BENCHMARK_MODE" != "calibrate" ]]; then
    echo "Unsupported BENCHMARK_MODE: $BENCHMARK_MODE" >&2
    exit 64
  fi
fi
