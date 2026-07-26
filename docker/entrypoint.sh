#!/usr/bin/env bash
set -Eeuo pipefail

CONF_DIR="${CONF_DIR:-/azerothcore/env/dist/etc}"
REF_DIR="/azerothcore/env/ref/etc"

wait_for_file() {
  local path=$1 label=$2 timeout=${3:-3600} elapsed=0
  until [[ -e "$path" ]]; do
    if (( elapsed >= timeout )); then
      echo "[ERROR] Timed out waiting for $label ($path)" >&2
      exit 1
    fi
    (( elapsed % 30 == 0 )) && echo "[INFO] Waiting for $label..."
    sleep 2
    ((elapsed += 2))
  done
}

mkdir -p "$CONF_DIR" /azerothcore/env/dist/{data,logs,temp}

# Docker copies the image directory ownership into a new named volume, whereas
# rootless Podman can initially expose that volume as root-owned. Initialise the
# writable runtime volumes as root, then always run the server process as acore.
if [[ $(id -u) -eq 0 ]]; then
  chown -R acore:acore "$CONF_DIR"
  chown acore:acore /azerothcore/env/dist/logs /azerothcore/env/dist/temp
fi
cp -a --update=none "$REF_DIR/." "$CONF_DIR/"

case "${ACORE_COMPONENT:-}" in
  dbimport)    wait_for_file "$CONF_DIR/.database-preflight.ready" "SQL world-ID precheck" ;;
  authserver)  wait_for_file "$CONF_DIR/.realm-init.ready" "realm SQL initialization" ;;
  worldserver) wait_for_file "/azerothcore/env/dist/data/.client-data.ready" "client data" ;;
esac

# Enable every module configuration shipped by the compiled image.
if [[ -d "$CONF_DIR/modules" ]]; then
  shopt -s nullglob
  for dist in "$CONF_DIR"/modules/*.conf.dist "$CONF_DIR"/modules/*.dist; do
    target="${dist%.dist}"
    [[ -e "$target" ]] || cp "$dist" "$target"
  done
  shopt -u nullglob
fi

# Existing config volumes may contain the commented defaults distributed by
# older mod-dungeon-master builds. Enable them only when no roguelike buff has
# been configured explicitly, so user-provided values remain untouched.
dungeon_master_conf="$CONF_DIR/modules/mod_dungeon_master.conf"
if [[ -f "$dungeon_master_conf" ]] &&
   ! grep -qE '^[[:space:]]*DungeonMaster\.Roguelike\.Buff\.[0-9]+[[:space:]]*=' "$dungeon_master_conf"; then
  sed -i -E 's/^# (DungeonMaster\.Roguelike\.Buff\.[0-9]+[[:space:]]*=)/\1/' "$dungeon_master_conf"
fi
if [[ -f "$dungeon_master_conf" ]] &&
   ! grep -qE '^[[:space:]]*DungeonMaster\.Roguelike\.Buff\.11[[:space:]]*=' "$dungeon_master_conf"; then
  printf '\nDungeonMaster.Roguelike.Buff.11 = ""\n' >> "$dungeon_master_conf"
fi

# Do not let AHBot claim a player character before a dedicated GUID is set.
# admin.py removes this one-time safety by writing a validated GUID and enabling
# the seller directly in the persistent module configuration.
ahbot_marker="$CONF_DIR/.ahbot-safety-initialized"
if [[ ! -e "$ahbot_marker" ]]; then
  shopt -s nullglob nocaseglob
  ahbot_found=0
  for ahbot in "$CONF_DIR"/modules/*ahbot*.conf "$CONF_DIR"/modules/AuctionHouseBot.conf; do
    [[ -f "$ahbot" ]] || continue
    ahbot_found=1
    python3 - "$ahbot" <<'PY'
import re, sys
from pathlib import Path
path = Path(sys.argv[1])
text = path.read_text()
key = "AuctionHouseBot.EnableSeller"
replacement = f"{key} = false"
pattern = re.compile(rf"^[ \t]*{re.escape(key)}[ \t]*=.*$", re.MULTILINE)
path.write_text(pattern.sub(replacement, text) if pattern.search(text) else text + "\n" + replacement + "\n")
PY
  done
  shopt -u nullglob nocaseglob
  if (( ahbot_found )); then
    touch "$ahbot_marker"
  else
    echo "[WARN] AHBot configuration not found; safety marker not written." >&2
  fi
fi

# Ensure the absolute ALE script directory exists.
mkdir -p /azerothcore/env/dist/bin/lua_scripts

if [[ "${ACORE_COMPONENT:-}" == dbimport ]]; then
  if [[ $(id -u) -eq 0 ]]; then
    gosu acore /azerothcore/upstream-entrypoint.sh "$@"
  else
    /azerothcore/upstream-entrypoint.sh "$@"
  fi
  touch "$CONF_DIR/.db-import.ready"
  echo "[OK] Database import completed."
  exit 0
elif [[ $(id -u) -eq 0 ]]; then
  exec gosu acore /azerothcore/upstream-entrypoint.sh "$@"
fi
exec /azerothcore/upstream-entrypoint.sh "$@"
