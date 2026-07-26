#!/usr/bin/env bash
set -Eeuo pipefail

ALE_LUA_VERSION="${ALE_LUA_VERSION:-lua52}"
BUILD_TYPE="${BUILD_TYPE:-Release}"
BUILD_JOBS="${BUILD_JOBS:-4}"

case "$ALE_LUA_VERSION" in
  luajit|lua51|lua52|lua53|lua54) ;;
  *) echo "Invalid ALE_LUA_VERSION: $ALE_LUA_VERSION" >&2; exit 2 ;;
esac

test -d /azerothcore/.git
mkdir -p /azerothcore/modules

modules=(
  "mod-playerbots;https://github.com/mod-playerbots/mod-playerbots.git"
  "mod-optimal-bot-raid;https://github.com/barnaclebarry/mod-optimal-bot-raid.git"
  "mod-multibot-bridge;https://github.com/Wishmaster117/mod-multibot-bridge.git"
  "mod-ah-bot-plus;https://github.com/NathanHandley/mod-ah-bot-plus.git"
  "mod-autobalance;https://github.com/azerothcore/mod-autobalance.git"
  "mod-aoe-loot;https://github.com/azerothcore/mod-aoe-loot.git"
  "mod-learn-spells;https://github.com/azerothcore/mod-learn-spells.git"
  "mod-solo-lfg;https://github.com/azerothcore/mod-solo-lfg.git"
  "mod-challenge-modes;https://github.com/ZhengPeiRu21/mod-challenge-modes.git"
  "mod-dungeon-master;https://github.com/InstanceForge/mod-dungeon-master.git"
  "mod-dungeon-questgivers;https://github.com/and-elf/mod-dungeon-questgivers.git"
  "mod-auto-gather;https://github.com/thanhtong89/mod-auto-gather.git"
  "DungeonRespawn;https://github.com/riksbyville/DungeonRespawn.git"
  "mod-player-bot-level-brackets;https://github.com/DustinHendrickson/mod-player-bot-level-brackets.git"
  "mod-junk-to-gold;https://github.com/kadeshar/mod-junk-to-gold.git"
  "mod-rare-drops;https://github.com/StraysFromPath/mod-rare-drops.git"
  "mod-transmog;https://github.com/azerothcore/mod-transmog.git"
  "mod-reagent-bank-account;https://github.com/Brian-Aldridge/mod-reagent-bank-account.git"
  "mod-daily-reset;https://github.com/binboupan/mod-daily-reset.git"
  "mod-mount-scaling;https://github.com/claudevandort/mod-mount-scaling.git"
  "mod-level-one-mounts;https://github.com/tomcoffingiii/mod-level-one-mounts.git"
  "mod-ale;https://github.com/azerothcore/mod-ale.git"
  "mod-quest-loot-party;https://github.com/pangolp/mod-quest-loot-party.git"
  "mod-TimeIsTime;https://github.com/dunjeon/mod-TimeIsTime.git"
  "mod-boss-announcer;https://github.com/azerothcore/mod-boss-announcer.git"
  "mod-auto-revive;https://github.com/azerothcore/mod-auto-revive.git"
  "mod-increased-ghost-speed;https://github.com/TheTollski/mod-increased-ghost-speed.git"
  "mod-duel-reset;https://github.com/azerothcore/mod-duel-reset.git"
  "NoProfessionLimit;https://github.com/AlsoNotMehh/NoProfessionLimit.git"
  "mod-no-hearthstone-cooldown;https://github.com/BytesGalore/mod-no-hearthstone-cooldown.git"
  "mod-autofish;https://github.com/Flerp/mod-autofish.git"
  "mod-skip-dk-starting-area;https://github.com/d23monkey/mod-skip-dk-starting-area.git"
  "mod-gunship-skip;https://github.com/BlaMacfly/mod-gunship-skip.git"
  "portals-in-all-capitals;https://github.com/azerothcore/portals-in-all-capitals.git"
  "mod-gain-honor-guard;https://github.com/azerothcore/mod-gain-honor-guard.git"
  "mod-npc-enchanter;https://github.com/azerothcore/mod-npc-enchanter.git"
  "mod-npc-all-mounts;https://github.com/azerothcore/mod-npc-all-mounts.git"
)

for item in "${modules[@]}"; do
  IFS=';' read -r name url <<<"$item"
  git clone --depth 1 "$url" "/azerothcore/modules/$name"
done

# Level One Mounts is distributed as standalone SQL rather than an AzerothCore
# module. Place its active script in the standard module SQL tree so dbimport
# discovers it.
level_one_mounts=/azerothcore/modules/mod-level-one-mounts
if [[ -f "$level_one_mounts/level-one-mounts.sql" ]]; then
  mkdir -p "$level_one_mounts/data/sql/db-world/base"
  sed '/^[[:space:]]*use[[:space:]]/Id' "$level_one_mounts/level-one-mounts.sql" \
    > "$level_one_mounts/data/sql/db-world/base/level-one-mounts.sql"
fi

# The Playerbot branch uses creature.id rather than the newer id1 column used
# by mod-dungeon-master in its SQL and runtime queries. Its default roguelike
# buffs are documented but left commented, which makes ConfigMgr emit a
# missing-property warning at startup.
dungeon_master=/azerothcore/modules/mod-dungeon-master
if [[ -d "$dungeon_master" ]]; then
  sed -i 's/\bid1\b/id/g' \
    "$dungeon_master/data/sql/db-world/base/dm_setup.sql" \
    "$dungeon_master/src/DMBossSpawnQuery.h" \
    "$dungeon_master/src/DungeonMasterMgr.cpp"
  sed -i -E 's/^# (DungeonMaster\.Roguelike\.Buff\.[0-9]+[[:space:]]*=)/\1/' \
    "$dungeon_master/conf/mod_dungeon_master.conf.dist"
fi

# Auto Gather is intended for connected players. Scanning every nearby object
# once per second for every random Playerbot is both unnecessary and unstable
# while the bot population is being loaded.
auto_gather=/azerothcore/modules/mod-auto-gather/src/AutoGather.cpp
if [[ -f "$auto_gather" ]]; then
  sed -i 's/if (!cfgEnable)/if (!cfgEnable || !player->GetSession() || player->GetSession()->IsBot())/g' "$auto_gather"
fi

# Dungeon Respawn is a player-facing feature; random Playerbots must not fill
# its persistent character-state table. Also stop iterating after erasing the
# logout marker, as the upstream iterator is invalid after erase().
dungeon_respawn=/azerothcore/modules/DungeonRespawn
if [[ -d "$dungeon_respawn" ]]; then
  sed -i 's/DungeonRespawn.Enable = 0/DungeonRespawn.Enable = 1/' \
    "$dungeon_respawn/conf/dungeonrespawn.conf.dist"
  sed -i \
    -e 's/if (!player)/if (!player || !player->GetSession() || player->GetSession()->IsBot())/g' \
    -e '/playersToTeleport.erase(it);/a\            break;' \
    "$dungeon_respawn/src/DungeonRespawn.cpp"
fi

# Compatibility patches retained from the previous deployment.
challenge=/azerothcore/modules/mod-challenge-modes/src/ChallengeModes.cpp
if [[ -f "$challenge" ]]; then
  sed -i 's/bool \/\*applySickness\*\/) override/bool\& \/\*applySickness\*\/) override/' "$challenge"
fi

reagent=/azerothcore/modules/mod-reagent-bank-account/src/ReagentBank_loader.cpp
if [[ -f "$reagent" ]]; then
  sed -i 's/void Addmod_reagent_bankScripts()/void Addmod_reagent_bank_accountScripts()/' "$reagent"
fi

profession=/azerothcore/modules/NoProfessionLimit/src/NoProfessionLimit.cpp
if [[ -f "$profession" ]]; then
  sed -i 's/PLAYERHOOK_ON_SET_SKILL/PLAYERHOOK_ON_UPDATE_SKILL/g; s/void OnPlayerSetSkill/void OnPlayerUpdateSkill/g' "$profession"
fi

# mod-rare-drops is documented upstream as SQL-only. Its repository still
# contains the AzerothCore skeleton C++ and configuration, which merely display
# a "Hello World" login message and are unrelated to rare loot.
rm -rf /azerothcore/modules/mod-rare-drops/src /azerothcore/modules/mod-rare-drops/conf

while IFS= read -r -d '' reagent_sql; do
  sed -i 's/mechanic_immune_mask/CreatureImmunitiesId/g' "$reagent_sql"
done < <(find /azerothcore/modules/mod-reagent-bank-account/data/sql -type f -name '*.sql' -print0 2>/dev/null)

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
