#!/usr/bin/env bash
set -Eeuo pipefail

ALE_LUA_VERSION="${ALE_LUA_VERSION:-lua52}"
BUILD_TYPE="${BUILD_TYPE:-Release}"
BUILD_JOBS="${BUILD_JOBS:-4}"

case "$ALE_LUA_VERSION" in
  luajit|lua51|lua52|lua53|lua54) ;;
  *) echo "Invalid ALE_LUA_VERSION: $ALE_LUA_VERSION" >&2; exit 2 ;;
esac

LOCK_FILE="${SOURCE_LOCK:-/usr/local/share/acore-sources.lock}"
test -d /azerothcore/.git
test -r "$LOCK_FILE"

lock_field() {
  local name="$1" field="$2"
  awk -F ';' -v name="$name" -v field="$field" '$1 == name { print $field; exit }' "$LOCK_FILE"
}

assert_sha() {
  [[ "$1" =~ ^[0-9a-f]{40}$ ]] || {
    echo "Invalid locked SHA for $2: $1" >&2
    exit 2
  }
}

core_sha="$(lock_field core 4)"
assert_sha "$core_sha" core
test "$(git -C /azerothcore rev-parse HEAD)" = "$core_sha" || {
  echo "Core checkout does not match docker/sources.lock" >&2
  exit 1
}

mkdir -p /azerothcore/modules
while IFS=';' read -r name url ref sha; do
  [[ -z "$name" || "$name" == \#* ]] && continue
  [[ "$name" == core ]] && continue
  [[ "$name" =~ ^[A-Za-z0-9._-]+$ ]] || {
    echo "Invalid module name in $LOCK_FILE: $name" >&2
    exit 2
  }
  [[ "$url" =~ ^https:// ]] || {
    echo "Invalid module URL in $LOCK_FILE: $url" >&2
    exit 2
  }
  assert_sha "$sha" "$name"
  destination="/azerothcore/modules/$name"
  test ! -e "$destination" || {
    echo "Duplicate module destination: $destination" >&2
    exit 1
  }
  git init "$destination"
  git -C "$destination" remote add origin "$url"
  git -C "$destination" fetch --depth=1 origin "$sha"
  git -C "$destination" checkout --detach --force FETCH_HEAD
  test "$(git -C "$destination" rev-parse HEAD)" = "$sha" || {
    echo "Module checkout does not match docker/sources.lock: $name" >&2
    exit 1
  }
done < "$LOCK_FILE"

require_file() {
  test -f "$1" || { echo "Expected source file is missing: $1" >&2; exit 1; }
}

require_contains() {
  grep -Fq -- "$2" "$1" || { echo "Patch postcondition missing in $1: $2" >&2; exit 1; }
}

require_absent() {
  ! grep -Fq -- "$2" "$1" || { echo "Patch precondition remains in $1: $2" >&2; exit 1; }
}

require_matches() {
  grep -Eq -- "$2" "$1" || { echo "Patch postcondition missing in $1: $2" >&2; exit 1; }
}

# Level One Mounts is distributed as standalone SQL rather than an AzerothCore
# module. Place its active script in the standard module SQL tree so dbimport
# discovers it.
level_one_mounts=/azerothcore/modules/mod-level-one-mounts
if [[ -f "$level_one_mounts/level-one-mounts.sql" ]]; then
  mkdir -p "$level_one_mounts/data/sql/db-world/base"
  sed '/^[[:space:]]*use[[:space:]]/Id' "$level_one_mounts/level-one-mounts.sql" \
    > "$level_one_mounts/data/sql/db-world/base/level-one-mounts.sql"
fi

# Playerbots Life modules ship their required world schema under a custom
# `data/sql/{manual,world}` layout. Copy the required, idempotent SQL into
# AzerothCore's standard module tree so dbimport discovers it automatically.
for module in mod-playerbots-pvp-life mod-playerbots-city-life; do
  module_dir="/azerothcore/modules/$module"
  if [[ -d "$module_dir" ]]; then
    mkdir -p "$module_dir/data/sql/db-world/base" "$module_dir/data/sql/db-world/updates"
    for sql in "$module_dir"/data/sql/world/updates/*.sql; do
      [[ -f "$sql" ]] || continue
      cp -f "$sql" "$module_dir/data/sql/db-world/updates/$(basename "$sql")"
    done
    rm -rf "$module_dir/data/sql/world"
  fi
done

# The Playerbot core renamed this configuration member to match its public
# naming convention; keep level-brackets compatible with both spellings.
level_brackets=/azerothcore/modules/mod-player-bot-level-brackets/src/mod-player-bot-level-brackets.cpp
if [[ -f "$level_brackets" ]]; then
  sed -i 's/\.equipAndSpecPersistence/\.EquipAndSpecPersistence/g' "$level_brackets"
  require_contains "$level_brackets" "EquipAndSpecPersistence"
fi

# Forever Journal targets an older PlayerScript hook name. The pinned
# Playerbot core exposes the equivalent kill-credit event as
# PLAYERHOOK_ON_CREATURE_KILL / OnPlayerCreatureKill.
journal_lore=/azerothcore/modules/mod-forever-journal/src/JournalLore.cpp
if [[ -f "$journal_lore" ]]; then
  sed -i \
    -e 's/PLAYERHOOK_ON_CREATURE_KILL_CREDIT/PLAYERHOOK_ON_CREATURE_KILL/g' \
    -e 's/OnPlayerCreatureKillCredit/OnPlayerCreatureKill/g' \
    "$journal_lore"
  require_contains "$journal_lore" "PLAYERHOOK_ON_CREATURE_KILL"
  require_contains "$journal_lore" "void OnPlayerCreatureKill(Player* player, Creature* killed) override"
fi

# The Playerbot fork identifies bot sessions through WorldSession::IsBot(); its
# WorldSession API has no IsHeadless() helper used by newer upstream LFG code.
lfg_progression=/azerothcore/modules/mod-lfg-progression/src/LfgProgression.cpp
if [[ -f "$lfg_progression" ]]; then
  python3 - "$lfg_progression" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()
marker = '#include "WorldSession.h"\n'
compat = '''#include <type_traits>
#include <utility>

namespace
{
template <typename T, typename = void>
struct HasIsBot : std::false_type {};

template <typename T>
struct HasIsBot<T, std::void_t<decltype(std::declval<T const&>().IsBot())>> : std::true_type {};

template <typename T>
bool SessionIsBot(T* session)
{
    if constexpr (HasIsBot<T>::value)
        return session && session->IsBot();
    return false;
}
}
'''
if marker in text and 'bool SessionIsBot' not in text:
    text = text.replace(marker, marker + compat, 1)
text = text.replace('session && session->IsHeadless()', 'session && SessionIsBot(session)')
text = text.replace('session && session->IsBot()', 'session && SessionIsBot(session)')
path.write_text(text)
PY
  sed -i 's/bool CanCreateLfgProposal(lfg::Lfg5Guids const\& guids) override/bool CanCreateLfgProposal(lfg::Lfg5Guids const\& guids)/' "$lfg_progression"
  sed -i '/^[[:space:]]*GLOBALHOOK_CAN_CREATE_LFG_PROPOSAL,[[:space:]]*$/d' "$lfg_progression"
  require_contains "$lfg_progression" "bool SessionIsBot"
  require_contains "$lfg_progression" "session && SessionIsBot(session)"
fi

# The locked Playerbots API does not expose the newer TankTarget exclusion
# discriminator. Keep Raid Clear's generic exclusion logic and gate the BWL
# split by its configuration instead of referencing the missing enum member.
raid_discipline=/azerothcore/modules/mod-raid-clear/src/Common/RaidDiscipline.cpp
bwl_raid_clear=/azerothcore/modules/mod-raid-clear/src/Raids/BlackwingLair/BwlRaidClear.cpp
if [[ -f "$raid_discipline" ]]; then
  sed -i '/TargetValueExclusionType::TankTarget/,+1d' "$raid_discipline"
fi
if [[ -f "$bwl_raid_clear" ]]; then
  sed -i 's/type != TargetValueExclusionType::TankTarget || !RaidClear::GetConfig().tankSplit/!RaidClear::GetConfig().tankSplit/' "$bwl_raid_clear"
fi
# This Playerbot fork does not expose ResetActionDuration().  Keep the
# surrounding conditional statements syntactically intact while making the
# optional wake-up hint a harmless no-op.
find /azerothcore/modules/mod-raid-clear/src -type f -name '*.cpp' -print0 2>/dev/null \
  | xargs -0 sed -E -i 's/([A-Za-z_][A-Za-z0-9_]*)->ResetActionDuration\(\);/static_cast<void>(\1);/'
find /azerothcore/modules/mod-raid-clear/src -type f \( -name '*.cpp' -o -name '*.h' \) -print0 2>/dev/null \
  | xargs -0 sed -i 's/BossRearFlankAction/RearFlankAction/g'

# The Playerbot branch uses creature.id rather than the newer id1 column used
# by mod-dungeon-master in its SQL and runtime queries. Its default roguelike
# buffs are documented but left commented, which makes ConfigMgr emit a
# missing-property warning at startup.
dungeon_master=/azerothcore/modules/mod-dungeon-master
for file in \
  "$dungeon_master/data/sql/db-world/base/dm_setup.sql" \
  "$dungeon_master/src/DMBossSpawnQuery.h" \
  "$dungeon_master/src/DungeonMasterMgr.cpp"; do
  require_file "$file"
  sed -i 's/\bid1\b/id/g' "$file"
  require_absent "$file" "id1"
done
require_file "$dungeon_master/conf/mod_dungeon_master.conf.dist"
sed -i -E 's/^# (DungeonMaster\.Roguelike\.Buff\.[0-9]+[[:space:]]*=)/\1/' \
  "$dungeon_master/conf/mod_dungeon_master.conf.dist"
require_matches "$dungeon_master/conf/mod_dungeon_master.conf.dist" '^DungeonMaster\.Roguelike\.Buff\.1[[:space:]]*='

# Auto Gather is intended for connected players. Scanning every nearby object
# once per second for every random Playerbot is both unnecessary and unstable
# while the bot population is being loaded.
auto_gather=/azerothcore/modules/mod-auto-gather/src/AutoGather.cpp
require_file "$auto_gather"
python3 - "$auto_gather" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()
header = '#include "AutoGather.h"\n'
if header not in text:
    header = '#include "Chat.h"\n'
compat = '''#include <type_traits>
#include <utility>

namespace
{
template <typename T, typename = void>
struct HasIsBot : std::false_type {};

template <typename T>
struct HasIsBot<T, std::void_t<decltype(std::declval<T const&>().IsBot())>> : std::true_type {};

template <typename T>
bool SessionIsBot(T* session)
{
    if constexpr (HasIsBot<T>::value)
        return session && session->IsBot();
    return false;
}
}
'''
if header in text and 'bool SessionIsBot' not in text:
    text = text.replace(header, header + compat, 1)
text = text.replace(
    'if (!cfgEnable)',
    'if (!cfgEnable || !player->GetSession() || SessionIsBot(player->GetSession()))')
path.write_text(text)
PY
require_contains "$auto_gather" "bool SessionIsBot"
require_contains "$auto_gather" "SessionIsBot(player->GetSession())"

# Dungeon Respawn is a player-facing feature; random Playerbots must not fill
# its persistent character-state table. Also stop iterating after erasing the
# logout marker, as the upstream iterator is invalid after erase().
dungeon_respawn=/azerothcore/modules/DungeonRespawn
require_file "$dungeon_respawn/conf/dungeonrespawn.conf.dist"
require_file "$dungeon_respawn/src/DungeonRespawn.cpp"
sed -i 's/DungeonRespawn.Enable = 0/DungeonRespawn.Enable = 1/' \
  "$dungeon_respawn/conf/dungeonrespawn.conf.dist"
python3 - "$dungeon_respawn/src/DungeonRespawn.cpp" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()
header = '#include "DungeonRespawn.h"\n'
compat = '''#include <type_traits>
#include <utility>

namespace
{
template <typename T, typename = void>
struct HasIsBot : std::false_type {};

template <typename T>
struct HasIsBot<T, std::void_t<decltype(std::declval<T const&>().IsBot())>> : std::true_type {};

template <typename T>
bool SessionIsBot(T* session)
{
    if constexpr (HasIsBot<T>::value)
        return session && session->IsBot();
    return false;
}
}
'''
if header in text and 'bool SessionIsBot' not in text:
    text = text.replace(header, header + compat, 1)
text = text.replace(
    'if (!player || !player->GetSession() || player->GetSession()->IsBot())',
    'if (!player || SessionIsBot(player->GetSession()))')
text = text.replace('if (!player)\n', 'if (!player || SessionIsBot(player->GetSession()))\n', 1)
needle = 'playersToTeleport.erase(it);'
if needle in text and needle + '\n            break;' not in text:
    text = text.replace(needle, needle + '\n            break;', 1)
path.write_text(text)
PY
require_contains "$dungeon_respawn/conf/dungeonrespawn.conf.dist" "DungeonRespawn.Enable = 1"
require_contains "$dungeon_respawn/src/DungeonRespawn.cpp" "bool SessionIsBot"
require_contains "$dungeon_respawn/src/DungeonRespawn.cpp" "if (!player || SessionIsBot(player->GetSession()))"
require_contains "$dungeon_respawn/src/DungeonRespawn.cpp" "playersToTeleport.erase(it);"
require_contains "$dungeon_respawn/src/DungeonRespawn.cpp" "            break;"

# Compatibility patches retained from the previous deployment.
challenge=/azerothcore/modules/mod-challenge-modes/src/ChallengeModes.cpp
require_file "$challenge"
sed -i 's/bool \/\*applySickness\*\/) override/bool\& \/\*applySickness\*\/) override/' "$challenge"
require_contains "$challenge" "bool& /*applySickness*/) override"

# Current buildthehomelab fork already exports the canonical loader symbol.
# Keep compatibility for older snapshots without making the build depend on
# the legacy filename/layout.
reagent_loader=/azerothcore/modules/mod-reagent-bank-account/src/ReagentBank_loader.cpp
if [[ -f "$reagent_loader" ]]; then
  sed -i 's/void Addmod_reagent_bankScripts()/void Addmod_reagent_bank_accountScripts()/' "$reagent_loader"
  grep -Fq "void Addmod_reagent_bank_accountScripts()" "$reagent_loader"
fi

profession=/azerothcore/modules/NoProfessionLimit/src/NoProfessionLimit.cpp
require_file "$profession"
sed -i 's/PLAYERHOOK_ON_SET_SKILL/PLAYERHOOK_ON_UPDATE_SKILL/g; s/void OnPlayerSetSkill/void OnPlayerUpdateSkill/g' "$profession"
require_contains "$profession" "PLAYERHOOK_ON_UPDATE_SKILL"
require_contains "$profession" "void OnPlayerUpdateSkill"

# Rootless containers cannot raise their nice priority (EPERM/EACCES), even
# though this is harmless and the server continues normally.  Keep reporting
# real scheduler failures while suppressing only this expected capability
# limitation.
process_priority=/azerothcore/src/common/Threading/ProcessPriority.cpp
require_file "$process_priority"
python3 - "$process_priority" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()
old = "LOG_ERROR(logChannel, \"Can't set process priority class, error: {}\", strerror(errno));"
new = "if (errno != EPERM && errno != EACCES)\n                LOG_ERROR(logChannel, \"Can't set process priority class, error: {}\", strerror(errno));"
if old in text and 'errno != EPERM && errno != EACCES' not in text:
    text = text.replace(old, new, 1)
path.write_text(text)
PY
require_contains "$process_priority" "errno != EPERM && errno != EACCES"

# ALE versions before the current Playerbot API called the removed
# PlayerbotAI::InterruptSpell method. Newer ALE exposes the supported
# RequestSpellInterrupt API directly; accept either form so updating ALE does
# not make the compatibility patch fail the whole build.
ale_playerbot=/azerothcore/modules/mod-ale/src/LuaEngine/methods/Playerbots/PlayerBotAIMethods.h
require_file "$ale_playerbot"
if grep -Fq 'botAI->InterruptSpell();' "$ale_playerbot"; then
  sed -i 's/botAI->InterruptSpell();/botAI->RequestSpellInterrupt();/' "$ale_playerbot"
fi
if ! grep -Fq 'botAI->RequestSpellInterrupt();' "$ale_playerbot"; then
  echo "ALE Playerbot interrupt API not found in $ale_playerbot" >&2
  exit 1
fi

# mod-rare-drops is documented upstream as SQL-only. Its repository still
# contains the AzerothCore skeleton C++ and configuration, which merely display
# a "Hello World" login message and are unrelated to rare loot.
rm -rf /azerothcore/modules/mod-rare-drops/src /azerothcore/modules/mod-rare-drops/conf
test ! -e /azerothcore/modules/mod-rare-drops/src
test ! -e /azerothcore/modules/mod-rare-drops/conf

# The current Playerbot core renamed the inventory hook and added bag/slot
# parameters; adapt the upstream hook registration to that API.
transmog_collect=/azerothcore/modules/mod-transmog-plus/src/TransmogCollectScript.cpp
require_file "$transmog_collect"
sed -i \
  -e 's/PLAYERHOOK_ON_AFTER_MOVE_ITEM_TO_INVENTORY/PLAYERHOOK_ON_AFTER_MOVE_ITEM_FROM_INVENTORY/' \
  -e 's|void OnPlayerAfterMoveItemToInventory(Player\* player, Item\* item, bool|void OnPlayerAfterMoveItemFromInventory(Player* player, Item* item, uint8 bag, uint8 slot, bool|' \
  "$transmog_collect"
! grep -Fq 'OnPlayerAfterMoveItemToInventory' "$transmog_collect"
grep -Fq 'PLAYERHOOK_ON_AFTER_MOVE_ITEM_FROM_INVENTORY' "$transmog_collect"
grep -Fq 'OnPlayerAfterMoveItemFromInventory(Player* player, Item* item, uint8 bag, uint8 slot' "$transmog_collect"

# Keep the localized cost parser usable with the French client; the upstream
# addon currently recognizes English and Spanish class labels only.
transmog_costs=/azerothcore/modules/mod-transmog-plus/addon/Transmog/ui/costs.lua
require_file "$transmog_costs"
sed -i \
  -e 's/itemClassStr == "Weapon" or itemClassStr == "Arma"/itemClassStr == "Weapon" or itemClassStr == "Arma" or itemClassStr == "Armes" or itemClassStr == "arme"/' \
  -e 's/itemClassStr == "Armor" or itemClassStr == "Armadura"/itemClassStr == "Armor" or itemClassStr == "Armadura" or itemClassStr == "Armure"/' \
  "$transmog_costs"
grep -Fq 'itemClassStr == "Armes"' "$transmog_costs"
grep -Fq 'itemClassStr == "arme"' "$transmog_costs"
grep -Fq 'itemClassStr == "Armure"' "$transmog_costs"

# A backpack unlock token already present in a character's bags is equivalent
# to using the introduction-mail token. Upstream otherwise sends the mail but
# leaves existing inventory items locked until the player manually uses them.
transmog_backpacks=/azerothcore/modules/mod-transmog-plus/src/TransmogBackpacks.cpp
require_file "$transmog_backpacks"
python3 - "$transmog_backpacks" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
source = path.read_text()
old = (
    "        sTransmog->LoadPlayerBackpacks(player->GetGUID());\n"
    "        sTransmog->SyncPhaseUnlocks(player, false);"
)
new = (
    "        sTransmog->LoadPlayerBackpacks(player->GetGUID());\n"
    "        for (Transmog::BackpackEntry const& entry : sTransmog->backpacks)\n"
    "        {\n"
    "            if (!entry.unlockItem || !player->GetItemCount(entry.unlockItem))\n"
    "                continue;\n"
    "\n"
    "            if (sTransmog->UnlockBackpack(player, entry.id, false))\n"
    "            {\n"
    "                sTransmog->ApplyBackpack(player, entry.id);\n"
    "                player->DestroyItemCount(entry.unlockItem, 1, true);\n"
    "            }\n"
    "        }\n"
    "        sTransmog->SyncPhaseUnlocks(player, false);"
)
if new in source:
    pass
elif old in source:
    path.write_text(source.replace(old, new, 1))
else:
    raise SystemExit(f"unexpected mod-transmog-plus login code in {path}")
PY
grep -Fq 'player->GetItemCount(entry.unlockItem)' "$transmog_backpacks"
grep -Fq 'player->DestroyItemCount(entry.unlockItem, 1, true)' "$transmog_backpacks"

while IFS= read -r -d '' reagent_sql; do
  sed -i 's/mechanic_immune_mask/CreatureImmunitiesId/g' "$reagent_sql"
done < <(find /azerothcore/modules/mod-reagent-bank-account -type f -name '*.sql' -print0 2>/dev/null)
! grep -R -Fq -- "mechanic_immune_mask" /azerothcore/modules/mod-reagent-bank-account --include='*.sql' 2>/dev/null

# Retail-AH schemas are imported by dbimport. The module's startup CREATE
# statements are redundant and violate the runtime account's least-privilege
# grants, so keep the migration definitions but disable those two calls.
retail_ledger=/azerothcore/modules/mod-retail-ah/src/RetailAHLedger.cpp
retail_era=/azerothcore/modules/mod-retail-ah/src/RetailAHGate.cpp
if [[ -f "$retail_ledger" ]]; then
  sed -i 's/^[[:space:]]*CharacterDatabase\.DirectExecute(/        if (false) CharacterDatabase.DirectExecute(/' "$retail_ledger"
fi
if [[ -f "$retail_era" ]]; then
  sed -i 's/^[[:space:]]*WorldDatabase\.DirectExecute(/                if (false) WorldDatabase.DirectExecute(/' "$retail_era"
fi

# Playerbot Life modules target a newer WorldSession API and call IsBot()
# directly.  The pinned Playerbot core may not expose that member; provide a
# single local compatibility helper and rewrite all module call sites.  The
# fallback is conservative: sessions without an IsBot API are treated as
# human sessions, preserving the modules' player-facing behavior.
for life_module in mod-playerbots-city-life mod-playerbots-pvp-life; do
  life_dir="/azerothcore/modules/$life_module"
  [[ -d "$life_dir" ]] || continue
  compat_header="$life_dir/src/SessionCompat.h"
  cat > "$compat_header" <<'EOF'
#pragma once

#include <type_traits>
#include <utility>

namespace PlayerbotLifeCompat
{
template <typename T, typename = void>
struct HasIsBot : std::false_type {};

template <typename T>
struct HasIsBot<T, std::void_t<decltype(std::declval<T const&>().IsBot())>> : std::true_type {};

template <typename T>
bool SessionIsBot(T* session)
{
    if constexpr (HasIsBot<T>::value)
        return session && session->IsBot();
    return false;
}
}
EOF
  while IFS= read -r -d '' source; do
    [[ "$source" == "$compat_header" ]] && continue
    grep -Fq -- '->IsBot()' "$source" || continue
    sed -i '1i#include "SessionCompat.h"' "$source"
    python3 - "$source" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
text = path.read_text()
# Covers the module's session expressions (session, player->GetSession(),
# member->GetSession(), etc.) without touching unrelated identifiers.
text = re.sub(r'([A-Za-z_][A-Za-z0-9_]*(?:->|\.)[A-Za-z0-9_()\-\.>]+)->IsBot\(\)',
              r'PlayerbotLifeCompat::SessionIsBot(\1)', text)
text = text.replace('session->IsBot()', 'PlayerbotLifeCompat::SessionIsBot(session)')
text = re.sub(r'([A-Za-z_][A-Za-z0-9_]*)->GetSession\(\)\s*->\s*IsBot\(\)',
              r'PlayerbotLifeCompat::SessionIsBot(\1->GetSession())', text)
path.write_text(text)
PY
  done < <(find "$life_dir/src" -type f \( -name '*.cpp' -o -name '*.h' \) -print0)
  ! grep -R -Fq --exclude='SessionCompat.h' -- '->IsBot()' "$life_dir/src" || {
    echo "Unpatched IsBot call remains in $life_dir" >&2
    exit 1
  }
done

# CityLife destinations can carry stale Z values from a different floor.  The
# old 15-yard guard kept those values and made bots sink through terrain.  When
# the map height probe is valid, pin the destination to the actual ground.
citylife_movement=/azerothcore/modules/mod-playerbots-city-life/src/CityLifeMovement.cpp
if [[ -f "$citylife_movement" ]]; then
  sed -i 's/probedZ > -1000\.0f && std::abs(probedZ - z) < 15\.0f/probedZ > -1000.0f \&\& std::isfinite(probedZ)/' "$citylife_movement"
  require_contains "$citylife_movement" 'probedZ > -1000.0f && std::isfinite(probedZ)'
  require_absent "$citylife_movement" 'std::abs(probedZ - z) < 15.0f'
fi

python3 /usr/local/bin/patch-gunship.py

mkdir -p /azerothcore/build /azerothcore/env/dist
cd /azerothcore/build

cmake .. \
  -DCMAKE_INSTALL_PREFIX=/azerothcore/env/dist \
  -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
  -DCMAKE_C_COMPILER=clang-20 \
  -DCMAKE_CXX_COMPILER=clang++-20 \
  -DCMAKE_CXX_FLAGS=--gcc-install-dir=/usr/lib/gcc/x86_64-linux-gnu/15 \
  -DCMAKE_C_COMPILER_LAUNCHER=ccache \
  -DCMAKE_CXX_COMPILER_LAUNCHER=ccache \
  -DBoost_USE_STATIC_LIBS=ON \
  -DAPPS_BUILD=all \
  -DTOOLS_BUILD=all \
  -DSCRIPTS=static \
  -DMODULES=static \
  -DMODULE_MOD_PLAYERBOTS=static \
  -DLUA_VERSION="$ALE_LUA_VERSION" \
  -DWITH_WARNINGS=ON

cmake --build . --parallel "$BUILD_JOBS"
cmake --install .

mkdir -p /azerothcore/env/dist/bin/lua_scripts

{
  printf 'core\t%s\t%s\n' "$(git -C /azerothcore rev-parse HEAD)" "$(git -C /azerothcore log -1 --format=%cI)"
  for module_dir in /azerothcore/modules/*; do
    [[ -d "$module_dir/.git" ]] || continue
    printf '%s\t%s\t%s\n' \
      "$(basename "$module_dir")" \
      "$(git -C "$module_dir" rev-parse HEAD)" \
      "$(git -C "$module_dir" log -1 --format=%cI)"
  done
} > /azerothcore/env/dist/build-manifest.tsv

# SQL is needed by dbimport, Git object databases are not.
find /azerothcore/modules -type d -name .git -prune -exec rm -rf {} +

test -x /azerothcore/env/dist/bin/authserver
test -x /azerothcore/env/dist/bin/worldserver
test -x /azerothcore/env/dist/bin/dbimport
