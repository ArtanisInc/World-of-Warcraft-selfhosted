#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <guid[,guid...]>" >&2
  exit 2
fi
docker compose --profile tools -f "$ROOT_DIR/docker-compose.yml" run --rm -T operations \
  python3 /azerothcore/tools/admin.py setup-ahbot "$1"
