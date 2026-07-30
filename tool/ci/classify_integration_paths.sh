#!/usr/bin/env bash

set -euo pipefail

if (($# > 0)); then
  changed_paths=("$@")
else
  changed_paths=()
  while IFS= read -r path; do
    changed_paths+=("$path")
  done
fi

if ((${#changed_paths[@]} == 0)); then
  echo true
  exit 0
fi

for path in "${changed_paths[@]}"; do
  if [[ -z "$path" || "$path" == /* || "$path" == *".."* ]]; then
    echo true
    exit 0
  fi

  case "$path" in
    lib/features/viewer/* | \
    lib/app/* | \
    lib/core/* | \
    lib/l10n/* | \
    lib/main.dart | \
    assets/mermaid/* | \
    integration_test/* | \
    test_driver/* | \
    test/*viewer* | \
    test/golden/* | \
    test/widget/a11y/* | \
    android/* | \
    ios/* | \
    pubspec.yaml | \
    pubspec.lock | \
    dart_test.yaml | \
    l10n.yaml | \
    tool/fetch_mermaid.sh | \
    tool/ci/* | \
    tool/performance/* | \
    .github/workflows/*)
      echo true
      exit 0
      ;;
    docs/* | \
    site/* | \
    .github/ISSUE_TEMPLATE/* | \
    .github/PULL_REQUEST_TEMPLATE* | \
    AGENTS.md | \
    CLAUDE.md | \
    CHANGELOG.md | \
    CONTRIBUTING.md | \
    LICENSE | \
    README.md | \
    lib/features/library/* | \
    lib/features/onboarding/* | \
    lib/features/repo_sync/* | \
    lib/features/settings/* | \
    test/unit/features/library/* | \
    test/unit/features/onboarding/* | \
    test/unit/features/repo_sync/* | \
    test/unit/features/settings/* | \
    test/widget/features/library/* | \
    test/widget/features/onboarding/* | \
    test/widget/features/repo_sync/* | \
    test/widget/features/settings/*)
      ;;
    *)
      echo true
      exit 0
      ;;
  esac
done

echo false
