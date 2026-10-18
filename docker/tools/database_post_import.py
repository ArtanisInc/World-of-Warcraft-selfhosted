#!/usr/bin/env python3
"""Idempotent post-import schema and module-data synchronization."""

from __future__ import annotations

import os
import re
import tempfile
from pathlib import Path

from admin import create_account, set_gm
from common import (
    MODULES_DIR,
    ToolError,
    first_created_table,
    first_existing,
    mysql,
    mysql_transaction,
    scalar,
    table_exists,
)

# Resource template IDs used by Upload Academy's MIT-licensed Better
# Professions pack. We only port its spawn-density behavior; quests and Lua are
# intentionally excluded. Source:
# https://github.com/Upload-Academy/azerothcore-daisy/tree/master/packs/mcrilly/better-professions
BETTER_PROFESSIONS_RESOURCES = {
    "herbalism": (
        "Adder's Tongue", "Ancient Lichen", "Arthas' Tears", "Black Lotus",
        "Blindweed", "Bloodthistle", "Briarthorn", "Bruiseweed", "Dreamfoil",
        "Dreaming Glory", "Earthroot", "Fadeleaf", "Felweed", "Firebloom",
        "Firethorn", "Flame Cap", "Frost Lotus", "Frozen Herb", "Ghost Mushroom",
        "Golden Sansam", "Goldclover", "Goldthorn", "Grave Moss", "Gromsblood",
        "Icecap", "Icethorn", "Khadgar's Whisker", "Kingsblood", "Lichbloom",
        "Liferoot", "Mageroyal", "Mana Thistle", "Mountain Silversage",
        "Netherbloom", "Netherdust Bush", "Nightmare Vine", "Peacebloom",
        "Plaguebloom", "Purple Lotus", "Ragveil", "Sanguine Hibiscus",
        "Silverleaf", "Stranglekelp", "Sungrass", "Talandra's Rose", "Terocone",
        "Tiger Lily", "Wild Steelbloom", "Wintersbite",
    ),
    "mining": (
        "Adamantite Deposit", "Cobalt Deposit", "Copper Vein", "Dark Iron Deposit",
        "Fel Iron Deposit", "Gold Vein", "Hakkari Thorium Vein",
        "Incendicite Mineral Vein", "Iron Deposit", "Khorium Vein",
        "Lesser Bloodstone Deposit", "Mithril Deposit", "Nethercite Deposit",
        "Ooze Covered Gold Vein", "Ooze Covered Mithril Deposit",
        "Ooze Covered Rich Thorium Vein", "Ooze Covered Thorium Vein",
        "Ooze Covered Truesilver Deposit", "Rich Adamantite Deposit",
        "Rich Cobalt Deposit", "Rich Saronite Deposit", "Rich Thorium Vein",
        "Saronite Deposit", "Silver Vein", "Small Thorium Vein", "Tin Vein",
        "Titanium Vein", "Truesilver Deposit",
    ),
}

TRANSMOG_CAPITAL_SPAWNS = (
    # guid, map, x, y, z, orientation, capital
    (8000100, 0, -8991.90, 850.33, 29.621, 4.8936, "Stormwind"),
    (8000101, 0, -4611.54, -915.00, 501.146, 6.2483, "Ironforge"),
    (8000102, 1, 9655.54, 2512.58, 1331.700, 5.3931, "Darnassus"),
    (8000103, 530, -4039.96, -11560.23, -138.307, 2.2689, "Exodar"),
    (8000104, 1, 1470.05, -4222.27, 59.321, 6.1087, "Orgrimmar"),
    (8000105, 1, -966.59, 286.72, 110.805, 4.5030, "Thunder Bluff"),
    (8000106, 0, 1773.49, 67.20, -46.237, 5.9341, "Undercity"),
    (8000107, 530, 9990.38, -7105.12, 47.788, 2.9671, "Silvermoon"),
)

REAGENT_BANK_CITY_SPAWNS = (
    # guid, map, x, y, z, orientation, location
    (8000110, 0, -8926.82, 608.15, 99.610, 3.6306, "Stormwind"),
    (8000111, 0, -4889.63, -993.65, 504.020, 5.3756, "Ironforge"),
    (8000112, 1, 9940.15, 2514.61, 1317.660, 1.1864, "Darnassus"),
    (8000113, 530, -3919.57, -11549.66, -150.040, 1.4464, "Exodar"),
    (8000114, 1, 1622.54, -4377.53, 12.060, 0.2964, "Orgrimmar"),
    (8000115, 1, -1258.41, 24.50, 128.270, 4.8696, "Thunder Bluff"),
    (8000116, 0, 1586.52, 240.85, -52.060, 6.1786, "Undercity"),
    (8000117, 530, 9525.23, -7216.82, 16.210, 4.7126, "Silvermoon"),
    (8000118, 530, -2005.29, 5349.94, -9.270, 0.3844, "Shattrath Scryers"),
    (8000119, 530, -1724.49, 5507.88, -9.720, 3.4206, "Shattrath Aldor"),
    (8000120, 571, 5628.62, 693.52, 652.680, 2.7924, "Dalaran Horde"),
    (8000121, 571, 5979.88, 608.82, 651.260, 5.9346, "Dalaran Alliance"),
)

ENCHANTER_CAPITAL_SPAWNS = (
    # guid, map, x, y, z, orientation, capital
    (8000130, 0, -8862.15, 800.30, 96.520, 0.4100, "Stormwind"),
    (8000131, 0, -4805.40, -1182.75, 512.560, 4.0200, "Ironforge"),
    (8000132, 1, 10141.80, 2324.10, 1333.080, 5.7600, "Darnassus"),
    (8000133, 530, -3887.10, -11494.10, -136.060, 5.0400, "Exodar"),
    (8000134, 1, 1908.15, -4432.70, 24.900, 5.9800, "Orgrimmar"),
    (8000135, 1, -1114.80, 43.70, 140.520, 2.1500, "Thunder Bluff"),
    (8000136, 0, 1478.30, 278.10, -62.080, 5.7600, "Undercity"),
    (8000137, 530, 9958.00, -7252.30, 32.160, 0.8500, "Silvermoon"),
)

ALL_MOUNTS_CAPITAL_SPAWNS = (
    # guid, map, x, y, z, orientation, capital
    (8000140, 0, -8988.60, 850.33, 29.621, 4.8936, "Stormwind"),
    (8000141, 0, -4611.54, -911.50, 501.146, 6.2483, "Ironforge"),
    (8000142, 1, 9658.54, 2512.58, 1331.700, 5.3931, "Darnassus"),
    (8000143, 530, -4037.00, -11558.00, -138.307, 2.2689, "Exodar"),
    (8000144, 1, 1473.05, -4222.27, 59.321, 6.1087, "Orgrimmar"),
    (8000145, 1, -963.59, 286.72, 110.805, 4.5030, "Thunder Bluff"),
    (8000146, 0, 1776.49, 67.20, -46.237, 5.9341, "Undercity"),
    (8000147, 530, 9990.38, -7101.80, 47.788, 2.9671, "Silvermoon"),
)

GUILDHOUSE_CAPITAL_SPAWNS = (
    # guid, map, x, y, z, orientation, capital; near the city portal trainers
    (8000150, 0, -8995.20, 850.33, 29.621, 4.8936, "Stormwind"),
    (8000151, 0, -4611.54, -918.50, 501.146, 6.2483, "Ironforge"),
    (8000152, 1, 9661.54, 2512.58, 1331.700, 5.3931, "Darnassus"),
    (8000153, 530, -4034.00, -11560.23, -138.307, 2.2683, "Exodar"),
    (8000154, 1, 1466.50, -4222.27, 59.321, 6.1087, "Orgrimmar"),
    (8000155, 1, -969.59, 286.72, 110.805, 4.5030, "Thunder Bluff"),
    (8000156, 0, 1779.50, 67.20, -46.237, 5.9341, "Undercity"),
    (8000157, 530, 9993.38, -7105.12, 47.788, 2.9671, "Silvermoon"),
)


def import_sql(database: str, path: Path, label: str) -> None:
    print(f"[INFO] {label}: importing {path.name}")
    mysql(database=database, input_file=path, capture=False)


def ensure_schema(database: str, path: Path | None, label: str) -> None:
    if not path:
        print(f"[WARN] {label}: SQL file not found")
        return
    sentinel = first_created_table(path)
    if not sentinel:
        raise ToolError(f"{label}: no CREATE TABLE found in {path}")
    if table_exists(database, sentinel):
        print(f"[OK] {label}: {database}.{sentinel} already exists")
        return
    import_sql(database, path, label)
    if not table_exists(database, sentinel):
        raise ToolError(f"{label}: sentinel table {database}.{sentinel} is still missing")


def ensure_reagent_character_auxiliary(world_sql: Path | None) -> None:
    """Keep every reagent-bank state table in characters, where the module reads it."""
    if not world_sql:
        return
    text = world_sql.read_text()
    statements = [statement.strip() for statement in text.split(";")
                  if "mod_reagent_bank_" in statement and
                  ("CREATE TABLE" in statement or "INSERT INTO" in statement)]
    tables = sorted(set(re.findall(r"CREATE TABLE IF NOT EXISTS `([^`]+)`", text)))
    missing = [name for name in tables if not table_exists("acore_characters", name)]
    if not missing:
        return
    with tempfile.NamedTemporaryFile("w", suffix=".sql", delete=False) as handle:
        handle.write(";\n".join(statements) + ";\n")
        path = Path(handle.name)
    try:
        import_sql("acore_characters", path, "mod-reagent-bank-account auxiliary characters")
    finally:
        path.unlink(missing_ok=True)
    missing = [name for name in tables if not table_exists("acore_characters", name)]
    if missing:
        raise ToolError("mod-reagent-bank-account character tables still missing: " + ", ".join(missing))
    print("[OK] mod-reagent-bank-account auxiliary character tables present")


def ensure_world_data(path: Path | None, label: str, probe: str, minimum: int = 1) -> None:
    if not path:
        print(f"[WARN] {label}: SQL file not found")
        return
    count = int(scalar(probe, "acore_world", "0"))
    if count >= minimum:
        print(f"[OK] {label}: world data already present ({count})")
        return
    import_sql("acore_world", path, label)
    count = int(scalar(probe, "acore_world", "0"))
    if count < minimum:
        raise ToolError(f"{label}: import completed but probe returned {count}")


def ensure_dungeon_questgivers() -> None:
    sql_dir = MODULES_DIR / "mod-dungeon-questgivers/data/sql/db-world"
    sql_files = sorted(sql_dir.glob("*.sql"))
    path = sql_files[-1] if sql_files else None
    complete_probe = (
        "SELECT IF("
        "(SELECT COUNT(*) FROM creature_template WHERE entry BETWEEN 92000 AND 92099)>=49 "
        "AND (SELECT COUNT(*) FROM creature WHERE guid BETWEEN 5400000 AND 5400099)>=49 "
        "AND (SELECT COUNT(*) FROM creature_queststarter WHERE id BETWEEN 92000 AND 92099)>=325,"
        "1,0)"
    )
    ensure_world_data(path, "mod-dungeon-questgivers", complete_probe)
    templates = int(
        scalar(
            "SELECT COUNT(*) FROM creature_template WHERE entry BETWEEN 92000 AND 92099",
            "acore_world",
            "0",
        )
    )
    spawns = int(
        scalar(
            "SELECT COUNT(*) FROM creature WHERE guid BETWEEN 5400000 AND 5400099",
            "acore_world",
            "0",
        )
    )
    quest_links = int(
        scalar(
            "SELECT COUNT(*) FROM creature_queststarter WHERE id BETWEEN 92000 AND 92099",
            "acore_world",
            "0",
        )
    )
    print(
        "[OK] mod-dungeon-questgivers: "
        f"{templates} emissaries, {spawns} spawns and {quest_links} quest links installed"
    )


def ensure_transmog_characters_schema() -> None:
    path = MODULES_DIR / "mod-transmog-plus/data/sql/characters/mod_transmog_plus_characters.sql"
    if not path.is_file():
        print("[WARN] mod-transmog-plus characters SQL not found")
        return
    required = ("mod_transmog_plus", "mod_transmog_plus_appearances")
    if all(table_exists("acore_characters", table) for table in required):
        print("[OK] mod-transmog-plus characters schema already present")
        return
    import_sql("acore_characters", path, "mod-transmog-plus characters")
    missing = [table for table in required if not table_exists("acore_characters", table)]
    if missing:
        raise ToolError(f"mod-transmog-plus characters tables missing: {', '.join(missing)}")


def ensure_starter_boost_schema() -> None:
    """Persist one successful starter boost claim per character."""
    mysql(
        "CREATE TABLE IF NOT EXISTS custom_starter_boost_claims ("
        "guid int unsigned NOT NULL PRIMARY KEY, "
        "claim_token varchar(96) NOT NULL DEFAULT '', "
        "claimed_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP"
        ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 "
        "COMMENT='AzerothCore-Container: permanent .starterboost claims'",
        "acore_characters",
    )
    if not table_exists("acore_characters", "custom_starter_boost_claims"):
        raise ToolError("starter boost claim table is missing after schema initialization")
    # Upgrade installations created before claim ownership tokens existed.
    # MySQL 8.4 does not support ADD COLUMN IF NOT EXISTS; probe first.
    claim_token_exists = scalar(
        "SELECT COUNT(*) FROM information_schema.columns "
        "WHERE table_schema=DATABASE() AND table_name='custom_starter_boost_claims' "
        "AND column_name='claim_token'",
        "acore_characters",
        "0",
    )
    if claim_token_exists != "1":
        mysql(
            "ALTER TABLE custom_starter_boost_claims "
            "ADD COLUMN claim_token varchar(96) NOT NULL DEFAULT '' AFTER guid",
            "acore_characters",
        )
    mysql(
        "UPDATE item_template SET ContainerSlots=22 WHERE entry=41600",
        "acore_world",
    )
    bag_slots = scalar(
        "SELECT ContainerSlots FROM item_template WHERE entry=41600 LIMIT 1",
        "acore_world",
        "0",
    )
    if bag_slots != "22":
        raise ToolError(f"starter boost bag 41600 has {bag_slots or 'no'} slots; expected 22")
    print("[OK] starter boost claim tracking schema present")


def ensure_transmog_capital_npcs() -> None:
    """Spawn one upstream Warpweaver near the portal trainer in each capital."""
    template = scalar(
        "SELECT COUNT(*) FROM creature_template "
        "WHERE entry=190012 AND ScriptName='npc_transmogrifier'",
        "acore_world",
        "0",
    )
    if template != "1":
        raise ToolError("mod-transmog-plus capital NPCs: creature template 190012 is unavailable")

    guid_list = ",".join(str(spawn[0]) for spawn in TRANSMOG_CAPITAL_SPAWNS)
    conflicts = mysql(
        "SELECT CONCAT(guid, ':', id) FROM creature "
        f"WHERE guid IN ({guid_list}) "
        "AND (id NOT IN (190012,190010) OR Comment NOT LIKE 'AzerothCore-Container transmog:%')",
        "acore_world",
    )
    if conflicts:
        raise ToolError(f"mod-transmog-plus capital NPC GUID conflict(s): {conflicts.replace(chr(10), ', ')}")

    current = int(
        scalar(
            "SELECT COUNT(*) FROM creature "
            f"WHERE guid IN ({guid_list}) AND id=190012 "
            "AND Comment LIKE 'AzerothCore-Container transmog: v2:%'",
            "acore_world",
            "0",
        )
    )
    if current == len(TRANSMOG_CAPITAL_SPAWNS):
        print(f"[OK] mod-transmog-plus: {current} capital NPCs already present")
        return

    rows = ",".join(
        "("
        f"{guid},190012,{map_id},0,0,1,1,0,{x},{y},{z},{orientation},"
        f"120,0,0,1,0,0,0,0,0,'',NULL,0,'AzerothCore-Container transmog: v2: {capital}'"
        ")"
        for guid, map_id, x, y, z, orientation, capital in TRANSMOG_CAPITAL_SPAWNS
    )
    mysql_transaction(
        f"DELETE FROM creature WHERE guid IN ({guid_list}); "
        "INSERT INTO creature "
        "(guid,id,map,zoneId,areaId,spawnMask,phaseMask,equipment_id,"
        "position_x,position_y,position_z,orientation,spawntimesecs,wander_distance,"
        "currentwaypoint,curhealth,curmana,MovementType,npcflag,unit_flags,dynamicflags,"
        "ScriptName,VerifiedBuild,CreateObject,Comment) VALUES "
        f"{rows}",
        "acore_world",
    )
    imported = int(
        scalar(
            "SELECT COUNT(*) FROM creature "
            f"WHERE guid IN ({guid_list}) AND id=190012 "
            "AND Comment LIKE 'AzerothCore-Container transmog: v2:%'",
            "acore_world",
            "0",
        )
    )
    if imported != len(TRANSMOG_CAPITAL_SPAWNS):
        raise ToolError(f"mod-transmog-plus capital NPC import returned {imported}")
    print(f"[OK] mod-transmog-plus: {imported} capital NPCs installed")


def ensure_transmog_greeting_locale_cleanup() -> None:
    """Remove legacy mod-transmog translations for the shared greeting ID.

    mod-transmog-plus owns npc_text 601084 but currently ships only the base
    English greeting.  Old mod-transmog locale rows otherwise override it and
    make Immersion display the retired set-management dialogue.
    """
    mysql_transaction(
        "DELETE FROM npc_text_locale WHERE ID=601084;",
        "acore_world",
    )
    print("[OK] mod-transmog-plus: legacy greeting locales removed")


def ensure_smartscript_talk_target() -> None:
    """Make the Shattered Hand Berserker yell as itself.

    Upstream's target type 7 resolves a different creature (15438), which has
    no creature_text group 0. AzerothCore then logs and ignores the action.
    Restrict the update to the exact upstream row so unrelated SmartScripts are
    untouched.
    """
    mysql_transaction(
        "UPDATE smart_scripts SET target_type=1 "
        "WHERE entryorguid=16878 AND source_type=0 AND id=4 "
        "AND event_type=61 AND action_type=1 AND action_param1=0 "
        "AND target_type=7;",
        "acore_world",
    )
    print("[OK] SmartScript Shattered Hand Berserker talk target normalized")


def ensure_freed_crusader_text_cleanup() -> None:
    """Remove an upstream say-line whose creature_text group is absent."""
    mysql_transaction(
        "DELETE FROM smart_scripts "
        "WHERE entryorguid=3027400 AND source_type=9 AND id=1 "
        "AND event_type=0 AND action_type=1 AND action_param1=0 "
        "AND target_type=7;",
        "acore_world",
    )
    print("[OK] Freed Crusader invalid say-line removed")


def ensure_reagent_bank_city_npcs() -> None:
    """Remove legacy NPC rows when the current module has no NPC script.

    mod-reagent-bank-account is addon/API based and no longer registers the
    historical ``npc_reagent_banker`` creature script.  Keeping the old
    template/spawns makes worldserver report "script ... has no code" and
    leaves unusable NPCs in every capital.  Only rows owned by this project
    are removed; unrelated/custom creature data is preserved.
    """
    template = scalar(
        "SELECT COUNT(*) FROM creature_template "
        "WHERE entry=290011 AND ScriptName='npc_reagent_banker'",
        "acore_world",
        "0",
    )
    if template != "1":
        print("[OK] mod-reagent-bank-account: no legacy NPC script binding")
        return

    guid_list = ",".join(str(spawn[0]) for spawn in REAGENT_BANK_CITY_SPAWNS)
    conflicts = mysql(
        "SELECT CONCAT(guid, ':', id) FROM creature "
        f"WHERE guid IN ({guid_list}) "
        "AND (id<>290011 OR Comment NOT LIKE 'AzerothCore-Container reagent bank%')",
        "acore_world",
    )
    if conflicts:
        raise ToolError(
            f"mod-reagent-bank-account city NPC GUID conflict(s): {conflicts.replace(chr(10), ', ')}"
        )

    current = int(
        scalar(
            "SELECT COUNT(*) FROM creature "
            f"WHERE guid IN ({guid_list}) AND id=290011 "
            "AND Comment LIKE 'AzerothCore-Container reagent bank v2:%'",
            "acore_world",
            "0",
        )
    )
    if current:
        mysql(
            "DELETE FROM creature WHERE id=290011 "
            "AND Comment LIKE 'AzerothCore-Container reagent bank v2:%'",
            "acore_world",
        )
        print(f"[OK] mod-reagent-bank-account: removed {current} legacy city NPCs")
    mysql(
        "UPDATE creature_template SET ScriptName='' "
        "WHERE entry=290011 AND ScriptName='npc_reagent_banker'",
        "acore_world",
    )


def ensure_enchanter_capital_npcs() -> None:
    """Spawn one upstream enchanter beside the profession trainers in each capital."""
    template = scalar(
        "SELECT COUNT(*) FROM creature_template "
        "WHERE entry=601015 AND ScriptName='npc_enchantment'",
        "acore_world",
        "0",
    )
    if template != "1":
        raise ToolError("mod-npc-enchanter capital NPCs: creature template 601015 is unavailable")

    guid_list = ",".join(str(spawn[0]) for spawn in ENCHANTER_CAPITAL_SPAWNS)
    conflicts = mysql(
        "SELECT CONCAT(guid, ':', id) FROM creature "
        f"WHERE guid IN ({guid_list}) "
        "AND (id<>601015 OR Comment NOT LIKE 'AzerothCore-Container enchanter:%')",
        "acore_world",
    )
    if conflicts:
        raise ToolError(f"mod-npc-enchanter GUID conflict(s): {conflicts.replace(chr(10), ', ')}")

    current = int(
        scalar(
            "SELECT COUNT(*) FROM creature "
            f"WHERE guid IN ({guid_list}) AND id=601015 "
            "AND Comment LIKE 'AzerothCore-Container enchanter: v1:%'",
            "acore_world",
            "0",
        )
    )
    if current == len(ENCHANTER_CAPITAL_SPAWNS):
        print(f"[OK] mod-npc-enchanter: {current} capital NPCs already present")
        return

    rows = ",".join(
        "("
        f"{guid},601015,{map_id},0,0,1,1,0,{x},{y},{z},{orientation},"
        f"120,0,0,1,0,0,0,0,0,'',NULL,0,'AzerothCore-Container enchanter: v1: {capital}'"
        ")"
        for guid, map_id, x, y, z, orientation, capital in ENCHANTER_CAPITAL_SPAWNS
    )
    mysql_transaction(
        f"DELETE FROM creature WHERE guid IN ({guid_list}); "
        "INSERT INTO creature "
        "(guid,id,map,zoneId,areaId,spawnMask,phaseMask,equipment_id,"
        "position_x,position_y,position_z,orientation,spawntimesecs,wander_distance,"
        "currentwaypoint,curhealth,curmana,MovementType,npcflag,unit_flags,dynamicflags,"
        "ScriptName,VerifiedBuild,CreateObject,Comment) VALUES "
        f"{rows}",
        "acore_world",
    )
    imported = int(
        scalar(
            "SELECT COUNT(*) FROM creature "
            f"WHERE guid IN ({guid_list}) AND id=601015 "
            "AND Comment LIKE 'AzerothCore-Container enchanter: v1:%'",
            "acore_world",
            "0",
        )
    )
    if imported != len(ENCHANTER_CAPITAL_SPAWNS):
        raise ToolError(f"mod-npc-enchanter capital NPC import returned {imported}")
    print(f"[OK] mod-npc-enchanter: {imported} capital NPCs installed")


def ensure_all_mounts_capital_npcs() -> None:
    """Spawn the upstream mount teacher in each faction capital."""
    template = scalar(
        "SELECT COUNT(*) FROM creature_template "
        "WHERE entry=601014 AND ScriptName='All_Mounts_NPC'",
        "acore_world",
        "0",
    )
    if template != "1":
        raise ToolError("mod-npc-all-mounts capital NPCs: creature template 601014 is unavailable")

    guid_list = ",".join(str(spawn[0]) for spawn in ALL_MOUNTS_CAPITAL_SPAWNS)
    conflicts = mysql(
        "SELECT CONCAT(guid, ':', id) FROM creature "
        f"WHERE guid IN ({guid_list}) "
        "AND (id<>601014 OR Comment NOT LIKE 'AzerothCore-Container all mounts:%')",
        "acore_world",
    )
    if conflicts:
        raise ToolError(f"mod-npc-all-mounts GUID conflict(s): {conflicts.replace(chr(10), ', ')}")

    current = int(
        scalar(
            "SELECT COUNT(*) FROM creature "
            f"WHERE guid IN ({guid_list}) AND id=601014 "
            "AND Comment LIKE 'AzerothCore-Container all mounts: v1:%'",
            "acore_world",
            "0",
        )
    )
    if current == len(ALL_MOUNTS_CAPITAL_SPAWNS):
        print(f"[OK] mod-npc-all-mounts: {current} capital NPCs already present")
        return

    rows = ",".join(
        "("
        f"{guid},601014,{map_id},0,0,1,1,0,{x},{y},{z},{orientation},"
        f"120,0,0,1,0,0,0,0,0,'',NULL,0,'AzerothCore-Container all mounts: v1: {capital}'"
        ")"
        for guid, map_id, x, y, z, orientation, capital in ALL_MOUNTS_CAPITAL_SPAWNS
    )
    mysql_transaction(
        f"DELETE FROM creature WHERE guid IN ({guid_list}); "
        "INSERT INTO creature "
        "(guid,id,map,zoneId,areaId,spawnMask,phaseMask,equipment_id,"
        "position_x,position_y,position_z,orientation,spawntimesecs,wander_distance,"
        "currentwaypoint,curhealth,curmana,MovementType,npcflag,unit_flags,dynamicflags,"
        "ScriptName,VerifiedBuild,CreateObject,Comment) VALUES "
        f"{rows}",
        "acore_world",
    )
    imported = int(
        scalar(
            "SELECT COUNT(*) FROM creature "
            f"WHERE guid IN ({guid_list}) AND id=601014 "
            "AND Comment LIKE 'AzerothCore-Container all mounts: v1:%'",
            "acore_world",
            "0",
        )
    )
    if imported != len(ALL_MOUNTS_CAPITAL_SPAWNS):
        raise ToolError(f"mod-npc-all-mounts capital NPC import returned {imported}")
    print(f"[OK] mod-npc-all-mounts: {imported} capital NPCs installed")


def ensure_guildhouse_capital_npcs() -> None:
    """Place the Guild House seller in every faction capital near portal trainers."""
    template = scalar(
        "SELECT COUNT(*) FROM creature_template "
        "WHERE entry=500030 AND ScriptName='GuildHouseSeller'",
        "acore_world",
        "0",
    )
    if template != "1":
        raise ToolError("mod-guildhouse capital NPCs: creature template 500030 is unavailable")

    guid_list = ",".join(str(spawn[0]) for spawn in GUILDHOUSE_CAPITAL_SPAWNS)
    conflicts = mysql(
        "SELECT CONCAT(guid, ':', id) FROM creature "
        f"WHERE guid IN ({guid_list}) "
        "AND (id<>500030 OR Comment NOT LIKE 'AzerothCore-Container guildhouse:%')",
        "acore_world",
    )
    if conflicts:
        raise ToolError(f"mod-guildhouse GUID conflict(s): {conflicts.replace(chr(10), ', ')}")

    current = int(
        scalar(
            "SELECT COUNT(*) FROM creature "
            f"WHERE guid IN ({guid_list}) AND id=500030 "
            "AND Comment LIKE 'AzerothCore-Container guildhouse: v1:%'",
            "acore_world",
            "0",
        )
    )
    if current == len(GUILDHOUSE_CAPITAL_SPAWNS):
        print(f"[OK] mod-guildhouse: {current} capital sellers already present")
        return

    rows = ",".join(
        "("
        f"{guid},500030,{map_id},0,0,1,1,0,{x},{y},{z},{orientation},"
        f"120,0,0,1,0,0,0,0,0,'',NULL,0,'AzerothCore-Container guildhouse: v1: {capital}'"
        ")"
        for guid, map_id, x, y, z, orientation, capital in GUILDHOUSE_CAPITAL_SPAWNS
    )
    mysql_transaction(
        f"DELETE FROM creature WHERE guid IN ({guid_list}); "
        "INSERT INTO creature "
        "(guid,id,map,zoneId,areaId,spawnMask,phaseMask,equipment_id,"
        "position_x,position_y,position_z,orientation,spawntimesecs,wander_distance,"
        "currentwaypoint,curhealth,curmana,MovementType,npcflag,unit_flags,dynamicflags,"
        "ScriptName,VerifiedBuild,CreateObject,Comment) VALUES "
        f"{rows}",
        "acore_world",
    )
    imported = int(
        scalar(
            "SELECT COUNT(*) FROM creature "
            f"WHERE guid IN ({guid_list}) AND id=500030 "
            "AND Comment LIKE 'AzerothCore-Container guildhouse: v1:%'",
            "acore_world",
            "0",
        )
    )
    if imported != len(GUILDHOUSE_CAPITAL_SPAWNS):
        raise ToolError(f"mod-guildhouse capital NPC import returned {imported}")
    print(f"[OK] mod-guildhouse: {imported} capital sellers installed")


def ensure_mount_scaling_data() -> None:
    """Apply the module's SQL against the current AzerothCore schema.

    Upstream still references the retired trainer_spell table, while the
    Playerbot branch stores trainer requirements in npc_trainer.
    """
    mysql(
        "UPDATE npc_trainer SET ReqLevel=1 WHERE SpellID=33388; "
        "UPDATE item_template SET RequiredLevel=1 "
        "WHERE RequiredSkill=762 AND RequiredSkillRank=75 AND RequiredLevel<=20",
        "acore_world",
    )
    trainer_level = scalar(
        "SELECT ReqLevel FROM npc_trainer WHERE SpellID=33388 LIMIT 1",
        "acore_world",
    )
    if trainer_level != "1":
        raise ToolError(f"mod-mount-scaling: Apprentice Riding ReqLevel is {trainer_level or 'missing'}")
    print("[OK] mod-mount-scaling: Apprentice Riding available from level 1")


def ensure_level_one_mounts_data() -> None:
    """Apply and verify the standalone Level One Mounts SQL."""
    sql_path = (
        MODULES_DIR
        / "mod-level-one-mounts/data/sql/db-world/base/level-one-mounts.sql"
    )
    if not sql_path.is_file():
        raise ToolError(f"mod-level-one-mounts SQL is missing: {sql_path}")

    mysql(database="acore_world", input_file=sql_path, capture=False)

    mount_entries = (
        "1132,2411,2414,5655,5656,5665,5668,5864,5872,5873,8563,8588,"
        "8591,8592,8595,8629,8631,8632,13321,13322,13331,13332,13333,"
        "15277,15290,28481,28927,29220,29221,29222,29743,29744,33224,"
        "33976,43599,46099,46100,46308,47100,49283"
    )
    updated_mounts = int(
        scalar(
            "SELECT COUNT(*) FROM item_template "
            f"WHERE entry IN ({mount_entries}) "
            "AND RequiredLevel=1 AND BuyPrice=10 AND SellPrice=4",
            "acore_world",
            "0",
        )
    )
    npc_trainers = int(
        scalar(
            "SELECT COUNT(*) FROM npc_trainer "
            "WHERE ReqSkillLine=762 AND ReqSkillRank=0 "
            "AND ReqLevel=1 AND MoneyCost=4",
            "acore_world",
            "0",
        )
    )
    if updated_mounts != 40 or npc_trainers < 1:
        raise ToolError(
            "mod-level-one-mounts verification failed: "
            f"mounts={updated_mounts}/40 npc_trainers={npc_trainers}"
        )
    print(
        "[OK] mod-level-one-mounts: 40 mounts and riding trainers "
        "available from level 1"
    )


def density_multiplier(name: str) -> int:
    raw = os.getenv(name, "3").strip()
    try:
        value = int(raw)
    except ValueError as error:
        raise ToolError(f"{name} must be an integer between 1 and 10") from error
    if not 1 <= value <= 10:
        raise ToolError(f"{name} must be between 1 and 10 (received {value})")
    return value


def ensure_better_professions_density() -> None:
    """Apply deterministic resource density from an immutable baseline.

    The first run snapshots each affected pool's imported AzerothCore value.
    Later runs always calculate from that baseline, so multipliers never stack.
    Setting a multiplier back to 1 restores the original density.
    """
    mysql(
        "CREATE TABLE IF NOT EXISTS custom_better_professions_pool_baseline ("
        "pool_entry int unsigned NOT NULL PRIMARY KEY, "
        "base_max_limit int unsigned NOT NULL, "
        "captured_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP"
        ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4",
        "acore_world",
    )

    seen: dict[int, tuple[str, int]] = {}
    for resource, names in BETTER_PROFESSIONS_RESOURCES.items():
        multiplier = density_multiplier(f"BETTER_PROFESSIONS_{resource.upper()}_MULTIPLIER")
        name_list = ",".join("'" + name.replace("'", "''") + "'" for name in names)
        pool_query = (
            "SELECT DISTINCT pt.entry FROM pool_template pt "
            "JOIN pool_gameobject pgo ON pgo.pool_entry=pt.entry "
            "JOIN gameobject g ON g.guid=pgo.guid "
            "JOIN gameobject_template got ON got.entry=g.id "
            f"WHERE got.type=3 AND got.name IN ({name_list})"
        )
        pools = [int(value) for value in mysql(pool_query, "acore_world").splitlines() if value]
        if not pools:
            raise ToolError(f"Better Professions: no {resource} pools matched the current world database")
        conflicting = sorted(
            pool for pool in pools if pool in seen and seen[pool][1] != multiplier
        )
        if conflicting:
            previous_resource, previous_multiplier = seen[conflicting[0]]
            raise ToolError(
                f"Better Professions: shared pool {conflicting[0]} has conflicting "
                f"multipliers ({previous_resource}=x{previous_multiplier}, "
                f"{resource}=x{multiplier})"
            )
        shared = sorted(pool for pool in pools if pool in seen)
        pools = [pool for pool in pools if pool not in seen]
        seen.update((pool, (resource, multiplier)) for pool in pools)
        if not pools:
            print(
                f"[OK] Better Professions: {resource} uses {len(shared)} shared "
                f"pools already set to x{multiplier}"
            )
            continue
        pool_list = ",".join(str(pool) for pool in pools)
        mysql_transaction(
            "INSERT IGNORE INTO custom_better_professions_pool_baseline (pool_entry,base_max_limit) "
            f"SELECT entry,max_limit FROM pool_template WHERE entry IN ({pool_list}); "
            "UPDATE pool_template pt "
            "JOIN custom_better_professions_pool_baseline bp ON bp.pool_entry=pt.entry "
            "SET pt.max_limit=CASE "
            "WHEN bp.base_max_limit=0 THEN 0 "
            f"ELSE LEAST(65535,GREATEST(1,ROUND(bp.base_max_limit*{multiplier}))) END "
            f"WHERE pt.entry IN ({pool_list})",
            "acore_world",
        )
        shared_note = f" ({len(shared)} shared)" if shared else ""
        print(
            f"[OK] Better Professions: {len(pools)} {resource} pools set to "
            f"x{multiplier}{shared_note}"
        )


def ensure_soap_account() -> None:
    """Keep the database account used by SOAP aligned with Compose secrets."""
    username = os.environ.get("SOAP_USER", "").strip()
    password = os.environ.get("SOAP_PASSWORD", "")
    if not username or not password:
        raise ToolError("SOAP_USER and SOAP_PASSWORD are required")
    create_account(username, password)
    set_gm(username, 3, -1)


def main() -> int:
    ready_file = Path(os.getenv("DATABASE_POST_IMPORT_READY_FILE", "/azerothcore/env/dist/etc/.database-post-import.ready"))
    ready_file.unlink(missing_ok=True)
    reagent = MODULES_DIR / "mod-reagent-bank-account/data/sql"
    reagent_char = first_existing(
        reagent / "db-characters",
        (
            "base/create_table.sql",
            "create_table.sql",
            "base/mod_reagent_bank_account_create_table.sql",
            "mod_reagent_bank_account_create_table.sql",
            "base/reagent_bank_account_characters.sql",
            "reagent_bank_account_characters.sql",
        ),
    )
    reagent_world = first_existing(
        reagent / "db-world",
        (
            "base/reagent_bank_NPC.sql",
            "reagent_bank_NPC.sql",
            "base/mod_reagent_bank_account_NPC.sql",
            "mod_reagent_bank_account_NPC.sql",
            "base/reagent_bank_account_world.sql",
            "reagent_bank_account_world.sql",
        ),
    )
    transmog_world = first_existing(
        MODULES_DIR / "mod-transmog-plus/data/sql/world",
        ("mod_transmog_plus_world.sql",),
    )
    enchanter_world = first_existing(
        MODULES_DIR / "mod-npc-enchanter/data/sql/db-world",
        ("npc_enchanter.sql",),
    )
    all_mounts_world = first_existing(
        MODULES_DIR / "mod-npc-all-mounts/data/sql/db-world",
        ("npc_allmounts.sql",),
    )
    assistant_world = first_existing(
        MODULES_DIR / "mod-assistant/data/sql/db-world",
        ("mod_assistant.sql",),
    )
    flightpath_board_world = first_existing(
        MODULES_DIR / "mod-flightpath-discovery/data/sql/db-world",
        ("2026_10_11_00_flightpath_board.sql",),
    )
    capitals_portals = first_existing(
        MODULES_DIR / "portals-in-all-capitals",
        ("portals-in-all-capitals.up.sql",),
    )

    ensure_transmog_characters_schema()
    ensure_starter_boost_schema()
    ensure_schema("acore_characters", reagent_char, "mod-reagent-bank-account characters")
    ensure_reagent_character_auxiliary(reagent_world)
    ensure_world_data(
        reagent_world,
        "mod-reagent-bank-account world",
        "SELECT COUNT(*) FROM creature_template WHERE ScriptName LIKE '%reagent%' OR name LIKE '%Reagent%'",
    )
    ensure_reagent_bank_city_npcs()
    ensure_world_data(
        transmog_world,
        "mod-transmog-plus NPC",
        "SELECT COUNT(*) FROM creature_template WHERE entry=190012 AND ScriptName='npc_transmogrifier'",
    )
    # Keep the module's template available for manual GM placement, but do not
    # auto-spawn capital NPCs; the addon `/transmog` flow is the preferred UI.
    # Existing project-owned spawns are removed by the one-time cleanup below.
    mysql_transaction(
        "DELETE FROM creature WHERE guid BETWEEN 8000100 AND 8000107 "
        "AND id=190012 AND Comment LIKE 'AzerothCore-Container transmog:%';",
        "acore_world",
    )
    ensure_transmog_greeting_locale_cleanup()
    ensure_smartscript_talk_target()
    ensure_freed_crusader_text_cleanup()
    ensure_world_data(
        enchanter_world,
        "mod-npc-enchanter world",
        "SELECT COUNT(*) FROM creature_template WHERE entry=601015 AND ScriptName='npc_enchantment'",
    )
    ensure_enchanter_capital_npcs()
    ensure_world_data(
        all_mounts_world,
        "mod-npc-all-mounts world",
        "SELECT COUNT(*) FROM creature_template "
        "WHERE entry=601014 AND ScriptName='All_Mounts_NPC'",
    )
    ensure_all_mounts_capital_npcs()
    ensure_world_data(
        assistant_world,
        "mod-assistant world",
        "SELECT COUNT(*) FROM creature_template "
        "WHERE entry=9000000 AND ScriptName='npc_assistant'",
    )
    ensure_world_data(
        flightpath_board_world,
        "mod-flightpath-discovery board",
        "SELECT COUNT(*) FROM gameobject_template WHERE entry=900100",
    )
    ensure_guildhouse_capital_npcs()
    ensure_world_data(
        capitals_portals,
        "portals-in-all-capitals",
        "SELECT COUNT(*) FROM gameobject WHERE guid BETWEEN 2000000 AND 2000023",
        minimum=24,
    )
    ensure_dungeon_questgivers()
    ensure_mount_scaling_data()
    ensure_level_one_mounts_data()
    ensure_better_professions_density()
    ensure_soap_account()

    try:
        mysql(
            "INSERT INTO module_string (module,id,string) VALUES "
            "('mod-aoe-loot',1,'Aoe Loot') ON DUPLICATE KEY UPDATE string=VALUES(string)",
            "acore_world",
        )
        print("[OK] mod-aoe-loot module string present")
    except ToolError as error:
        print(f"[WARN] mod-aoe-loot module string synchronization skipped: {error}")

    print("[OK] Database post-import initialization completed.")
    ready_file.touch()
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except ToolError as error:
        print(f"[ERROR] {error}")
        raise SystemExit(1)
