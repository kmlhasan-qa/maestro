#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$DIR/.." && pwd)"
TARGET="${1:-all}"

if (($# > 1)); then
  printf 'Usage: %s [all|flows/<flow>.yaml]\n' "$0" >&2
  exit 2
fi

if [[ -f "$ROOT_DIR/.env" ]]; then
  set -a
  source "$ROOT_DIR/.env"
  set +a
fi

MAILSLURP_API_KEY="${LOOPDHANDS_MAILSLURP_API_KEY:-}"
EMAIL="${LOOPDHANDS_EMAIL:-}"
PASSWORD="${LOOPDHANDS_PASSWORD:-}"
MAILSLURP_INBOX_ID="${LOOPDHANDS_MAILSLURP_INBOX_ID:-}"

APP_FILE="${LOOPDHANDS_APP_FILE:-$DIR/build/outputs/apk/loopdhands-2.6-staging.apk}"
if [[ "$APP_FILE" != /* ]]; then
  APP_FILE="$ROOT_DIR/$APP_FILE"
fi

for name in MAESTRO_API_KEY MAESTRO_PROJECT_ID MAILSLURP_API_KEY EMAIL PASSWORD; do
  if [[ -z "${!name:-}" ]]; then
    printf 'Missing required value for Maestro Cloud: %s\n' "$name" >&2
    exit 1
  fi
done

if [[ ! -f "$APP_FILE" ]]; then
  printf 'Android APK not found: %s\n' "$APP_FILE" >&2
  exit 1
fi

FLOW_OPTIONS=()
if [[ "$TARGET" == "all" ]]; then
  FLOWS_DIR="$DIR/flows"
  FLOW_OPTIONS=(--exclude-tags login)
else
  if [[ "$TARGET" = /* ]]; then
    FLOWS_DIR="$TARGET"
  else
    FLOWS_DIR="$DIR/$TARGET"
  fi
  if [[ ! -f "$FLOWS_DIR" ]]; then
    printf 'Flow file not found: %s\n' "$TARGET" >&2
    exit 2
  fi
  FLOW_OPTIONS=()
fi

LOG_DIR="$DIR/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/maestro-cloud-$(date '+%Y%m%d-%H%M%S')-$$.log"

set +e
maestro cloud \
  --api-key "$MAESTRO_API_KEY" \
  --project-id "$MAESTRO_PROJECT_ID" \
  --app-file "$APP_FILE" \
  --flows "$FLOWS_DIR" \
  ${FLOW_OPTIONS[@]+"${FLOW_OPTIONS[@]}"} \
  -e MAILSLURP_API_KEY="$MAILSLURP_API_KEY" \
  -e EMAIL="$EMAIL" \
  -e PASSWORD="$PASSWORD" \
  -e MAILSLURP_INBOX_ID="${MAILSLURP_INBOX_ID:-}" \
  2>&1 | python3 -u -c '
import os
import re
import sys

log = open(sys.argv[1], "w", encoding="utf-8")
secrets = [
    os.environ.get("MAESTRO_API_KEY", ""),
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
  printf 'Could not write Maestro Cloud run log: %s\n' "$LOG_FILE" >&2
  exit "${PIPE_STATUS[1]}"
fi

printf '\nCloud run log: %s\n' "$LOG_FILE"
exit "${PIPE_STATUS[0]}"
