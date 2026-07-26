#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "==== Docker Compose services ===="
docker compose ps
echo
echo "==== Container resources ===="
docker compose stats --no-stream database authserver worldserver || true
echo
docker compose --profile tools run --rm --no-deps -T --entrypoint python3 operations /azerothcore/tools/diagnose.py
echo
echo "==== Recent auth/world logs ===="
docker compose logs --tail=120 authserver worldserver
