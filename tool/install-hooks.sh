#!/usr/bin/env bash
#
# Installs the project's git hooks by pointing core.hooksPath at
# tool/git-hooks. Run once after cloning the repo:
#
#   bash tool/install-hooks.sh
#
# Verifying installation:
#
#   git config --get core.hooksPath
#   # → tool/git-hooks

set -euo pipefail

REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

HOOKS_DIR="tool/git-hooks"

if [[ ! -d "$HOOKS_DIR" ]]; then
  printf "Hooks directory %s not found.\n" "$HOOKS_DIR" >&2
  exit 1
fi

chmod +x "$HOOKS_DIR"/*

git config core.hooksPath "$HOOKS_DIR"

printf "Installed git hooks from %s.\n" "$HOOKS_DIR"
printf "Active hooks:\n"
ls -1 "$HOOKS_DIR"
