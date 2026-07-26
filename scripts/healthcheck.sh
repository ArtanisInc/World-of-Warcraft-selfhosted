#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
docker compose --profile tools -f "$ROOT_DIR/docker-compose.yml" run --rm --no-deps -T \
  --entrypoint python3 operations /azerothcore/tools/health.py
