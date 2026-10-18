#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "==== Docker Compose services ===="
"$ROOT_DIR/scripts/compose.sh" ps
echo
echo "==== Container resources ===="
"$ROOT_DIR/scripts/compose.sh" stats --no-stream database authserver worldserver || true
echo
"$ROOT_DIR/scripts/compose.sh" --profile tools run --rm --no-deps -T --entrypoint python3 operations /azerothcore/tools/diagnose.py
echo
echo "==== Recent auth/world logs ===="
"$ROOT_DIR/scripts/compose.sh" logs --tail=120 authserver worldserver
