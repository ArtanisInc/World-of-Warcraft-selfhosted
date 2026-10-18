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

wait_for_tcp() {
  local host=$1 port=$2 label=$3 timeout=${4:-900} elapsed=0
  until timeout 2 bash -c "</dev/tcp/${host}/${port}" 2>/dev/null; do
    if (( elapsed >= timeout )); then
      echo "[ERROR] Timed out waiting for $label (${host}:${port})" >&2
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

# The Playerbot fork renamed its configuration namespace from
# ``AiPlayerbot`` to ``Playerbots``.  Named config volumes survive image
# rebuilds, so an older volume can otherwise keep the obsolete keys forever;
# the server then falls back to defaults and emits hundreds of misleading
# "Missing property Playerbots.*" warnings.  Migrate only this known namespace
# in-place and preserve all user values.
playerbots_conf="$CONF_DIR/modules/playerbots.conf"
if [[ -f "$playerbots_conf" ]] &&
   grep -qE '^[[:space:]]*AiPlayerbot\.' "$playerbots_conf" &&
   grep -qE '^[[:space:]]*Playerbots\.' "$REF_DIR/modules/playerbots.conf.dist" 2>/dev/null; then
  sed -i -E 's/^([[:space:]]*)AiPlayerbot\./\1Playerbots./' "$playerbots_conf"
  echo "[OK] migrated playerbots.conf namespace AiPlayerbot -> Playerbots"
fi

# The compose profile exposes Playerbots settings as AC_* variables.  Apply
# them after the distributed files have been copied, including on a fresh
# named volume.  The versioned environment is authoritative; local edits to
# these keys must be made in docker/acore.env so restarts stay reproducible.
if [[ -f "$playerbots_conf" ]]; then
  python3 - "$playerbots_conf" <<'PY'
import os
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
lines = path.read_text().splitlines()
out = []
changed = 0
for line in lines:
    match = re.match(r"^(\s*)(Playerbots\.[A-Za-z0-9_.]+)(\s*=\s*).*$", line)
    if not match:
        out.append(line)
        continue
    suffix = match.group(2)[len("Playerbots."):]
    suffix = re.sub(r"([a-z0-9])([A-Z])", r"\1_\2", suffix)
    env_name = "AC_PLAYERBOTS_" + re.sub(r"[^A-Za-z0-9]", "_", suffix).upper()
    if env_name not in os.environ:
        out.append(line)
        continue
    out.append(f"{match.group(1)}{match.group(2)}{match.group(3)}{os.environ[env_name]}")
    changed += 1
path.write_text("\n".join(out) + "\n")
if changed:
    print(f"[OK] applied {changed} Playerbots environment overrides")
PY
fi

# Enable every module configuration shipped by the compiled image.
if [[ -d "$CONF_DIR/modules" ]]; then
  shopt -s nullglob
  for dist in "$CONF_DIR"/modules/*.conf.dist "$CONF_DIR"/modules/*.dist; do
    target="${dist%.dist}"
    [[ -e "$target" ]] || cp "$dist" "$target"
  done
  shopt -u nullglob
fi

# Persistent config volumes survive module upgrades. Merge newly shipped
# active defaults without replacing existing user values.
python3 - "$CONF_DIR" <<'PY'
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
key_re = re.compile(r"^\s*([A-Za-z0-9_.]+)\s*=")
for dist in sorted(root.glob("**/*.conf.dist")):
    target = Path(str(dist)[:-5])
    if not target.is_file():
        continue
    text = target.read_text()
    keys = {m.group(1) for m in (key_re.match(line) for line in text.splitlines()) if m}
    additions = []
    for line in dist.read_text().splitlines():
        match = key_re.match(line)
        if match and match.group(1) not in keys:
            additions.append(line)
            keys.add(match.group(1))
    if additions:
        with target.open("a") as handle:
            handle.write("\n# Added from current module defaults; edit to override.\n")
            handle.write("\n".join(additions) + "\n")
        print(f"[OK] merged {len(additions)} defaults into {target.name}")
PY

# Apply compatibility aliases after module defaults have been materialised.
# (On a fresh volume the target files do not exist until the copy/merge above.)
level_brackets_conf="$CONF_DIR/modules/mod_player_bot_level_brackets.conf"
if [[ -f "$level_brackets_conf" ]]; then
  python3 - "$level_brackets_conf" <<'PY'
import re, sys
from pathlib import Path
path = Path(sys.argv[1])
lines = path.read_text().splitlines()
keys = {m.group(1) for m in (re.match(r"^\s*([^#;][A-Za-z0-9_.]+)\s*=", l) for l in lines) if m}
added = []
for line in lines:
    m = re.match(r"^(\s*)BotLevelBrackets\.(\S+?)(\s*=\s*.*)$", line)
    if m:
        target = f"Playerbots.LevelBrackets.{m.group(2)}"
        if target not in keys:
            added.append(f"{m.group(1)}{target}{m.group(3)}")
            keys.add(target)
if added:
    path.write_text(path.read_text().rstrip() + "\n\n# Compatibility aliases for the Playerbot fork.\n" + "\n".join(added) + "\n")
    print(f"[OK] added {len(added)} Playerbots.LevelBrackets compatibility keys")
PY
fi

citylife_conf="$CONF_DIR/modules/mod_playerbots_city_life.conf"
if [[ -f "$citylife_conf" ]]; then
  python3 - "$citylife_conf" <<'PY'
import re, sys
from pathlib import Path
path = Path(sys.argv[1]); text = path.read_text()
defaults = {"WanderDistrict":30,"SitInTavern":20,"RandomEmote":15,"VisitAuctionHouse":10,
            "VisitMailbox":10,"BuyFood":10,"VisitTrainer":8,"DrinkInTavern":10,
            "WalkCityWalls":10,"FishAtDocks":5,"ReturnToInn":15}
added = [f"CityLife.Weight.{k} = {v}" for k,v in defaults.items()
         if not re.search(rf"^\s*CityLife\.Weight\.{re.escape(k)}\s*=", text, re.M)]
if added:
    path.write_text(text.rstrip() + "\n\n# Compatibility defaults for current CityLife actions.\n" + "\n".join(added) + "\n")
    print(f"[OK] added {len(added)} CityLife weight defaults")
PY
fi

# PvPLife currently attempts duels in protected/non-duel areas and repeatedly
# logs failed challenge requests. Keep the PvPLife world events enabled, but
# disable only the broken automatic duel producer until upstream validates zone
# eligibility before issuing a challenge.
pvp_life_conf="$CONF_DIR/modules/mod_playerbots_pvp_life.conf"
if [[ -f "$pvp_life_conf" ]]; then
  sed -i -E \
    -e 's/^([[:space:]]*PvPLife\.Duel\.Enable[[:space:]]*=).*/\1 0/' \
    -e 's/^([[:space:]]*PvPLife\.Duel\.AlwaysActive[[:space:]]*=).*/\1 0/' \
    "$pvp_life_conf"
fi

# A few module/core revisions request optional keys that are not present in
# their distributed .conf.dist yet.  Materialise the documented defaults once
# so startup is deterministic and does not spam misleading warnings.
python3 - "$CONF_DIR" <<'PY'
import re, sys
from pathlib import Path
root = Path(sys.argv[1]); target = root / "worldserver.conf"
defaults = {
    "AOELoot.MailEnable": "0", "CAIS.Enable": "0",
    "Creature.Instance.TeleportToUnreachableTarget": "0",
    "IndividualProgression.VanillaPvpKeepAllEarnedTitles": "0",
    "Mail.PushInboxOnDelivery": "0", "PlayerSave.AdditionalSaves": "0",
    "TaxiFlightSpeed": "32", "Wintergrasp.DeferShutdownTimer": "0",
    "Battleground.Override.LowLevels.MinPlayers.AB": "0",
    "Battleground.Override.LowLevels.MinPlayers.AV": "0",
    "Battleground.Override.LowLevels.MinPlayers.EY": "0",
    "Battleground.Override.LowLevels.MinPlayers.IC": "0",
    "Battleground.Override.LowLevels.MinPlayers.SA": "0",
    "Battleground.Override.LowLevels.MinPlayers.WS": "0",
    "DungeonMaster.Variety.RecentEntries": "12",
    "DungeonMaster.VisualScale.Beast": "1",
    "DungeonMaster.VisualScale.Demon": "0.95",
    "DungeonMaster.VisualScale.Dragonkin": "0.85",
    "DungeonMaster.VisualScale.Elemental": "0.9",
    "DungeonMaster.VisualScale.Giant": "0.7",
    "DungeonMaster.VisualScale.Humanoid": "1",
    "DungeonMaster.VisualScale.Mechanical": "0.9",
    "DungeonMaster.VisualScale.Undead": "1",
    "Playerbots.AddClassRandomCharacter": "0",
    "Playerbots.AllowBattlegroundCommands": "0",
    "Playerbots.AnnounceConsumableUse": "1",
    "Playerbots.ForceRebuffMarginSecs": "60",
    "Playerbots.ForceRebuffOnReadyCheck": "0",
    "Playerbots.RandomBotConcentrateInPlayerZone": "0",
    "Playerbots.RandomBotJoinLfgOutleveledExpansion": "1",
    "Playerbots.RandomBotPrintStatsInterval": "300",
    "Playerbots.ResetBotLevel.Enabled": "0",
    "Playerbots.ResetBotLevel.IgnoreGuildBotsWithRealPlayers": "0",
    "Playerbots.ResetBotLevel.MaxLevel": "80",
    "Playerbots.ResetBotLevel.MinTimePlayed": "86400",
    "Playerbots.ResetBotLevel.PlayedTimeCheckFrequency": "864",
    "Playerbots.ResetBotLevel.ResetChance": "100",
    "Playerbots.ResetBotLevel.ResetToLevel": "1",
    "Playerbots.ResetBotLevel.RestrictTimePlayed": "0",
    "Playerbots.ResetBotLevel.ScaledChance": "0",
    "Playerbots.ResetBotLevel.SkipFromLevel": "0",
    "Playerbots.ResetBotLevel.SkipToLevel": "1",
    "Playerbots.RpgStatusProbWeight.DoGather": "15",
    "Playerbots.ReactStrategies": "",
    "Playerbots.RandomBotReactStrategies": "",
    "Playerbots.ResetBotLevel.ExcludeNames": "",
    "Transmog.Backpacks.Mail.Body": "Adventurers have started carrying their gear on their backs!",
}
all_text = "\n".join(p.read_text(errors="ignore") for p in root.glob("**/*.conf") if p.is_file())
added = [f"{k} = {v}" for k,v in defaults.items()
         if not re.search(rf"^\s*{re.escape(k)}\s*=", all_text, re.M)]
if added:
    target.write_text(target.read_text() + "\n# Compatibility defaults for current core/modules.\n" + "\n".join(added) + "\n")
    print(f"[OK] added {len(added)} core/module compatibility defaults")
PY

# Namespace migration can expose duplicate keys when an old volume already
# contained both names. Keep the first explicit value; Config rejects dupes.
if [[ -f "$playerbots_conf" ]]; then
  python3 - "$playerbots_conf" <<'PY'
import re, sys
from pathlib import Path
path = Path(sys.argv[1]); seen = set(); out = []
for line in path.read_text().splitlines():
    m = re.match(r"^\s*(Playerbots\.[A-Za-z0-9_.]+)\s*=", line)
    if m and m.group(1) in seen:
        continue
    if m: seen.add(m.group(1))
    out.append(line)
path.write_text("\n".join(out) + "\n")
PY
fi

# Existing config volumes may contain the commented defaults distributed by
# older mod-dungeon-master builds. Enable them only when no roguelike buff has
# been configured explicitly, so user-provided values remain untouched.
dungeon_master_conf="$CONF_DIR/modules/mod_dungeon_master.conf"
if [[ -f "$dungeon_master_conf" ]] &&
   ! grep -qE '^[[:space:]]*DungeonMaster\.Roguelike\.Buff\.[0-9]+[[:space:]]*=' "$dungeon_master_conf"; then
  sed -i -E 's/^# (DungeonMaster\.Roguelike\.Buff\.[0-9]+[[:space:]]*=)/\1/' "$dungeon_master_conf"
fi

# Schema is applied by db-import with the DDL-capable migration account. Avoid
# a redundant runtime CREATE attempt by the reagent-bank module.
reagent_conf="$CONF_DIR/modules/mod_reagent_bank_account.conf"
if [[ -f "$reagent_conf" ]]; then
  sed -i -E 's/^([[:space:]]*ReagentBankAccount\.AutoMigrate[[:space:]]*=).*/\1 0/' "$reagent_conf"
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

# Podman cannot reliably express a dependency on the one-shot client-data
# service.  Wait for its success marker before starting worldserver so a fresh
# stack never boots against an empty data volume.
if [[ "${ACORE_COMPONENT:-}" == worldserver ]]; then
  wait_for_file "/azerothcore/env/dist/data/.client-data.ready" "client data"
  wait_for_file "$CONF_DIR/.database-post-import.ready" "database post-import"
elif [[ "${ACORE_COMPONENT:-}" == authserver ]]; then
  wait_for_file "$CONF_DIR/.realm-init.ready" "realm initialization"
  # Authserver exits when the realm list has no online realm. Start it only
  # after worldserver has opened its port and registered the realm, avoiding a
  # rapid restart loop during a cold Podman boot.
  wait_for_tcp "${WORLD_HOST:-worldserver}" "${WORLD_PORT:-8085}" "worldserver realm registration"
fi

if [[ "${ACORE_COMPONENT:-}" == dbimport ]]; then
  rm -f "$CONF_DIR/.database-post-import.ready" "$CONF_DIR/.realm-init.ready"
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
