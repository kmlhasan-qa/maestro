#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [[ -f "$ROOT_DIR/.env" ]]; then
  set -a
  source "$ROOT_DIR/.env"
  set +a
fi

PROJECT="loopdhands"
if (($# > 0)); then
  case "$1" in
    all|links|check-all-links|check_all_links|flows/*|/*)
      ;;
    *)
      PROJECT="$1"
      shift
      ;;
  esac
fi

TARGET="${1:-all}"

if (($# > 1)); then
  echo "Usage: $0 [project] [all|links|flows/<flow>.yaml]" >&2
  exit 2
fi

case "$PROJECT" in
  loopdhands|Loopdhands)
    PROJECT_DIR="$ROOT_DIR/Loopdhands"
    PROJECT_NAME="Loopdhands"
    ;;
  still-aware|Still-Aware)
    PROJECT_DIR="$ROOT_DIR/Still-Aware"
    PROJECT_NAME="Still Aware"
    ;;
  *)
    PROJECT_DIR="$ROOT_DIR/$PROJECT"
    PROJECT_NAME="$(printf '%s' "$PROJECT" | sed 's/-/ /g')"
    ;;
esac

if [[ ! -x "$PROJECT_DIR/run.sh" ]]; then
  printf 'Project runner not found: %s/run.sh\n' "$PROJECT_DIR" >&2
  printf 'Available projects:\n' >&2
  while IFS= read -r runner; do
    printf '  %s\n' "$(basename "$(dirname "$runner")")" >&2
  done < <(find "$ROOT_DIR" -mindepth 2 -maxdepth 2 -type f -name run.sh -print | sort)
  exit 2
fi

REPORT_FILE="$(mktemp)"
trap 'rm -f "$REPORT_FILE"' EXIT

RUN_STARTED="$PROJECT_NAME run started: $(date '+%Y-%m-%d %H:%M:%S')"
printf '%s\n' "$RUN_STARTED"
set +e
"$PROJECT_DIR/run.sh" "$TARGET" 2>&1 | tee "$REPORT_FILE"
PROJECT_STATUS="${PIPESTATUS[0]}"
set -e

REPORT="$(python3 - "$PROJECT_NAME" "$TARGET" "$RUN_STARTED" "$PROJECT_STATUS" "$REPORT_FILE" <<'PY'
import os
import re
import sys

project_name, target, run_started, status, report_path = sys.argv[1:]
results = []
with open(report_path, encoding="utf-8", errors="replace") as report_file:
    for line in report_file:
        match = re.match(r"^(PASS|FAIL) \| ([^|]+)", line)
        if match:
            results.append(f"{match.group(1)} | {match.group(2).strip()}")

if not results:
    result = "PASS" if status == "0" else "FAIL"
    scenario = os.path.splitext(os.path.basename(target))[0] if target.startswith("flows/") else project_name
    results.append(f"{result} | {scenario}")

passed = sum(result.startswith("PASS | ") for result in results)
failed = len(results) - passed
print(run_started)
print("\n".join(results))
print(f"\nSummary: {passed} passed, {failed} failed")
PY
)"

WEBHOOK_URL="${TEAMS_WEBHOOK_URL:-${STILL_AWARE_TEAMS_WEBHOOK_URL:-}}"
if [[ -n "$WEBHOOK_URL" ]]; then
  if payload="$(python3 -c '
import json
import sys

print(json.dumps({
    "$schema": "https://adaptivecards.io/schemas/adaptive-card.json",
    "type": "AdaptiveCard",
    "version": "1.2",
    "body": [{"type": "TextBlock", "text": sys.argv[1], "wrap": True}],
}))
' "$REPORT")" && curl --silent --show-error --fail-with-body --max-time 20 \
    -H 'Content-Type: application/json' \
    --data-binary "$payload" \
    "$WEBHOOK_URL" >/dev/null; then
    printf 'Microsoft Teams report sent.\n'
  else
    printf 'Failed to send the Microsoft Teams report. Check the webhook URL and Teams workflow.\n' >&2
    if ((PROJECT_STATUS == 0)); then
      PROJECT_STATUS=1
    fi
  fi
fi

exit "$PROJECT_STATUS"
