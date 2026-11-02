#!/usr/bin/env bash
# Usage: ./run.sh [all|flows/<flow>.yaml]
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="${1:-all}"

if (($# > 1)); then
  echo "Usage: $0 [all|flows/<flow>.yaml]" >&2
  exit 2
fi

if [[ "$TARGET" == "all" ]]; then
  TEST_TARGET="$DIR/flows"
else
  if [[ "$TARGET" = /* ]]; then
    TEST_TARGET="$TARGET"
  else
    TEST_TARGET="$DIR/$TARGET"
  fi
  if [[ ! -f "$TEST_TARGET" ]]; then
    printf 'Flow file not found: %s\n' "$TARGET" >&2
    exit 2
  fi
fi

if [[ ! -f "$DIR/.env" ]]; then
  printf 'Missing %s (copy .env.example and configure it)\n' "$DIR/.env" >&2
  exit 1
fi

set -a
source "$DIR/.env"
set +a

for name in MAILSLURP_API_KEY EMAIL PASSWORD; do
  if [[ -z "${!name:-}" ]]; then
    printf 'Missing required value in .env: %s\n' "$name" >&2
    exit 1
  fi
done

LOG_DIR="$DIR/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/maestro-$(date '+%Y%m%d-%H%M%S')-$$.log"

set +e
maestro test \
  -e MAILSLURP_API_KEY="$MAILSLURP_API_KEY" \
  -e EMAIL="$EMAIL" \
  -e PASSWORD="$PASSWORD" \
  -e MAILSLURP_INBOX_ID="${MAILSLURP_INBOX_ID:-}" \
  "$TEST_TARGET" 2>&1 | python3 -u -c '
import os
import re
import sys

log = open(sys.argv[1], "w", encoding="utf-8")
secrets = [
    os.environ.get("MAILSLURP_API_KEY", ""),
    os.environ.get("EMAIL", ""),
    os.environ.get("PASSWORD", ""),
    os.environ.get("MAILSLURP_INBOX_ID", ""),
]
secrets = [secret for secret in secrets if secret]

for line in sys.stdin:
    for secret in secrets:
        line = line.replace(secret, "[REDACTED]")
    line = re.sub(r"(?i)(OTP retrieved:\s*)\d+", r"\1[REDACTED]", line)
    sys.stdout.write(line)
    sys.stdout.flush()
    log.write(line)
    log.flush()

log.close()
' "$LOG_FILE"
PIPE_STATUS=("${PIPESTATUS[@]}")
set -e

if [[ "${PIPE_STATUS[1]}" -ne 0 ]]; then
  printf 'Could not write run log: %s\n' "$LOG_FILE" >&2
  exit "${PIPE_STATUS[1]}"
fi

printf '\nRun log: %s\n' "$LOG_FILE"
exit "${PIPE_STATUS[0]}"
