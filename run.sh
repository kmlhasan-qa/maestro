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
  echo "Usage: $0 [loopdhands|still-aware] [all|links|flows/<flow>.yaml]" >&2
  exit 2
fi

if [[ "$PROJECT" == "loopdhands" ]]; then
  exec "$ROOT_DIR/Loopdhands/run.sh" "$TARGET"
fi

PROJECT_DIR="$ROOT_DIR/Still-Aware"
exec "$PROJECT_DIR/run.sh" "$TARGET"
