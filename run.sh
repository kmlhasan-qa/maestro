#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"

if (($# > 0)) && { [[ "$1" == "loopdhands" ]] || [[ "$1" == "still-aware" ]]; }; then
  PROJECT="$1"
  shift
else
  PROJECT="loopdhands"
fi

TARGET="${1:-all}"

if (($# > 1)); then
  echo "Usage: $0 [loopdhands|still-aware] [all|flows/<flow>.yaml]" >&2
  exit 2
fi

if [[ "$PROJECT" == "loopdhands" ]]; then
  exec "$ROOT_DIR/Loopdhands/run.sh" "$TARGET"
fi

PROJECT_DIR="$ROOT_DIR/Still-Aware"
if [[ "$TARGET" == "all" ]]; then
  TEST_TARGET="$PROJECT_DIR/flows"
else
  if [[ "$TARGET" = /* ]]; then
    TEST_TARGET="$TARGET"
  else
    TEST_TARGET="$PROJECT_DIR/$TARGET"
  fi
fi

if [[ ! -d "$PROJECT_DIR/flows" ]]; then
  printf 'Still Aware flows directory not found: %s\n' "$PROJECT_DIR/flows" >&2
  exit 1
fi

if [[ "$TARGET" == "all" ]]; then
  if ! find "$TEST_TARGET" -type f \( -name '*.yaml' -o -name '*.yml' \) -print -quit | grep -q .; then
    printf 'No Maestro flows found in %s\n' "$TEST_TARGET" >&2
    exit 1
  fi
elif [[ ! -f "$TEST_TARGET" ]]; then
  printf 'Flow file not found: %s\n' "$TARGET" >&2
  exit 2
fi

exec maestro test "$TEST_TARGET"
