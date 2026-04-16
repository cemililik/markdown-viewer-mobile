#!/usr/bin/env bash
# Fetch and verify the bundled mermaid.min.js asset.
#
# The asset is intentionally NOT committed to the repository
# (see .gitignore). Every developer machine and every CI runner
# must invoke this script before running `flutter test`,
# `flutter build`, or any tooling that needs the asset to exist.
#
# The pinned version + SHA-256 are baked in; bumping mermaid is an
# explicit diff review, not a silent CDN follow.
set -euo pipefail

readonly MERMAID_VERSION="11.14.0"
readonly MERMAID_URL="https://cdn.jsdelivr.net/npm/mermaid@${MERMAID_VERSION}/dist/mermaid.min.js"
readonly EXPECTED_SHA256="217b66ef4279c33c141b4afe22effad10a91c02558dc70917be2c0981e78ed87"

# Resolve the project root regardless of where the script is invoked
# from, so `bash tool/fetch_mermaid.sh` and `./tool/fetch_mermaid.sh`
# both write to the correct location.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly TARGET_DIR="${PROJECT_ROOT}/assets/mermaid"
readonly TARGET_FILE="${TARGET_DIR}/mermaid.min.js"

mkdir -p "${TARGET_DIR}"

compute_sha256() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    echo "ERROR: neither shasum nor sha256sum is installed" >&2
    exit 2
  fi
}

if [[ -f "${TARGET_FILE}" ]]; then
  existing_sha="$(compute_sha256 "${TARGET_FILE}")"
  if [[ "${existing_sha}" == "${EXPECTED_SHA256}" ]]; then
    echo "mermaid.min.js already present and verified (v${MERMAID_VERSION})"
    exit 0
  fi
  echo "mermaid.min.js present but SHA-256 mismatch — re-downloading"
fi

echo "Downloading mermaid v${MERMAID_VERSION} from ${MERMAID_URL}"
tmp_file="$(mktemp)"
trap 'rm -f "${tmp_file}"' EXIT

if command -v curl >/dev/null 2>&1; then
  curl -sSfL "${MERMAID_URL}" -o "${tmp_file}"
elif command -v wget >/dev/null 2>&1; then
  wget -q "${MERMAID_URL}" -O "${tmp_file}"
else
  echo "ERROR: neither curl nor wget is installed" >&2
  exit 2
fi

actual_sha="$(compute_sha256 "${tmp_file}")"
if [[ "${actual_sha}" != "${EXPECTED_SHA256}" ]]; then
  echo "ERROR: SHA-256 mismatch for mermaid v${MERMAID_VERSION}" >&2
  echo "  expected: ${EXPECTED_SHA256}" >&2
  echo "  actual:   ${actual_sha}" >&2
  exit 3
fi

mv "${tmp_file}" "${TARGET_FILE}"
trap - EXIT
echo "mermaid.min.js installed (v${MERMAID_VERSION}, $(wc -c <"${TARGET_FILE}" | tr -d ' ') bytes)"
