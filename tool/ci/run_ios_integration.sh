#!/usr/bin/env bash

set -euo pipefail

: "${SIMULATOR_UDID:?SIMULATOR_UDID is required}"
: "${IOS_DRIVE_TIMEOUT_SECONDS:?IOS_DRIVE_TIMEOUT_SECONDS is required}"

mkdir -p build/quality-logs/ios
flutter --version
xcodebuild -version
python3 --version
python3 tool/ci/run_with_timeout.py \
  "$IOS_DRIVE_TIMEOUT_SECONDS" \
  flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/mermaid_render_test.dart \
  --device-id "$SIMULATOR_UDID" \
  --no-dds \
  --timeout 1800 \
  2>&1 | tee build/quality-logs/ios/integration.log
