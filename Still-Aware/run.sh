#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="${1:-all}"
TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"
RUN_ID="${TIMESTAMP}-$$"
LOG_DIR="$DIR/logs"
SUMMARY_FILE="$LOG_DIR/still-aware-${RUN_ID}-summary.log"

if (($# > 1)); then
  echo "Usage: $0 [all|links|check_all_links|flows/<flow>.yaml]" >&2
  exit 2
fi

if [[ ! -d "$DIR/flows" ]]; then
  printf 'Still Aware flows directory not found: %s\n' "$DIR/flows" >&2
  exit 1
fi

mkdir -p "$LOG_DIR"
printf 'Still Aware run started: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" | tee "$SUMMARY_FILE"

PASSED=0
FAILED=0

run_scenario() {
  local name="$1"
  local log_file="$LOG_DIR/still-aware-${RUN_ID}-${name}.log"
  shift

  printf '\n=== Running: %s ===\n' "$name"
  set +e
  "$@" 2>&1 | tee "$log_file"
  local scenario_status="${PIPESTATUS[0]}"
  set -e

  if ((scenario_status == 0)); then
    PASSED=$((PASSED + 1))
    printf 'PASS | %s | log: %s\n' "$name" "$log_file" | tee -a "$SUMMARY_FILE"
  else
    FAILED=$((FAILED + 1))
    printf 'FAIL | %s | exit: %s | log: %s\n' \
      "$name" "$scenario_status" "$log_file" | tee -a "$SUMMARY_FILE"
  fi
}

run_links() {
  run_scenario "check-all-links" python3 "$DIR/scripts/check_all_links.py"
}

run_all() {
  local found=0
  local flow

  while IFS= read -r flow; do
    [[ -n "$flow" ]] || continue
    found=1
    run_scenario "$(basename "${flow%.*}")" maestro test "$flow"
  done < <(find "$DIR/flows" -type f \( -name '*.yaml' -o -name '*.yml' \) -print | sort)

  if ((found == 0)); then
    printf 'No Maestro flows found in %s\n' "$DIR/flows" >&2
    FAILED=$((FAILED + 1))
  fi

  run_links
}

case "$TARGET" in
  all)
    run_all
    ;;
  links|check-all-links|check_all_links)
    run_links
    ;;
  flows/*)
    FLOW_FILE="$DIR/$TARGET"
    if [[ ! -f "$FLOW_FILE" ]]; then
      printf 'Flow file not found: %s\n' "$TARGET" >&2
      exit 2
    fi
    run_scenario "$(basename "${FLOW_FILE%.*}")" maestro test "$FLOW_FILE"
    ;;
  *)
    printf 'Unknown Still Aware scenario: %s\nUsage: %s [all|links|check_all_links|flows/<flow>.yaml]\n' \
      "$TARGET" "$0" >&2
    exit 2
    ;;
esac

printf '\nSummary: %s passed, %s failed\n' "$PASSED" "$FAILED" | tee -a "$SUMMARY_FILE"
printf 'Detailed summary: %s\n' "$SUMMARY_FILE"

if ((FAILED > 0)); then
  exit 1
fi
