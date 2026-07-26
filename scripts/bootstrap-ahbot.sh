#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <username> <password>" >&2
  exit 2
fi
docker compose --profile tools -f "$ROOT_DIR/docker-compose.yml" run --rm -T operations \
  python3 /azerothcore/tools/admin.py bootstrap-ahbot "$1" "$2"
