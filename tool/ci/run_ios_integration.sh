#!/usr/bin/env bash

set -euo pipefail

: "${SIMULATOR_UDID:?SIMULATOR_UDID is required}"

mkdir -p build/quality-logs/ios
flutter --version
xcodebuild -version
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/mermaid_render_test.dart \
  --device-id "$SIMULATOR_UDID" \
  --no-dds \
  --timeout 1800 \
  2>&1 | tee build/quality-logs/ios/integration.log
