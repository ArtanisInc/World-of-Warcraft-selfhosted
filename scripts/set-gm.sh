#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "Usage: $0 <username> <gmlevel> [realm-id]" >&2
  exit 2
fi
docker compose --profile tools -f "$ROOT_DIR/docker-compose.yml" run --rm -T operations \
  python3 /azerothcore/tools/admin.py set-gm "$1" "$2" "${3:--1}"
