#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
INTERVAL="${1:-30}"
OUT_FILE="${HEALTH_LOG_FILE:-$ROOT_DIR/logs/health.log}"

if [[ ! "$INTERVAL" =~ ^[0-9]+$ ]] || (( INTERVAL < 5 )); then
  echo "Usage: $0 [interval-seconds>=5]" >&2
  exit 2
fi

mkdir -p "$(dirname "$OUT_FILE")"
echo "[INFO] Watching Docker services every ${INTERVAL}s; log=$OUT_FILE"
while true; do
  {
    printf '[%s]\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    "$ROOT_DIR/scripts/healthcheck.sh"
  } >> "$OUT_FILE" 2>&1 || true
  sleep "$INTERVAL"
done
