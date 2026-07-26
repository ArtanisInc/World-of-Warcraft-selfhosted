#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
docker compose --profile tools -f "$ROOT_DIR/docker-compose.yml" run --rm --no-deps -T \
  --entrypoint bash operations -c \
  'find /azerothcore/env/dist/logs -maxdepth 1 -type f \( -name "*.log" -o -name "*.txt" \) -delete'
echo "[OK] AzerothCore file logs removed. Docker engine logs are managed by rotation policy."
