#!/usr/bin/env bash

set -euo pipefail

: "${SIMULATOR_UDID:?SIMULATOR_UDID is required}"

mkdir -p build/quality-logs/ios
flutter --version
xcodebuild -version
flutter test \
  integration_test/mermaid_render_test.dart \
  -d "$SIMULATOR_UDID" \
  2>&1 | tee build/quality-logs/ios/integration.log
