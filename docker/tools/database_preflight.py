#!/usr/bin/env python3
"""Block module SQL imports when their world IDs already belong to other data."""

from __future__ import annotations

import os
import re
import time
from collections import defaultdict
from pathlib import Path

from common import ToolError, mysql, scalar, table_exists, target_world_sql_files, world_sql_digest

STATE_FILE = Path(os.getenv("DATABASE_MIGRATION_STATE_FILE", "/azerothcore/env/dist/etc/.database-preflight.sha256"))
READY_FILE = STATE_FILE.with_name(".database-preflight.ready")
TABLE_ID_COLUMN = {
    "gameobject": "guid",
    "creature": "guid",
    "gossip_menu": "entry",
    "npc_text": "ID",
    "creature_template": "entry",
    "gameobject_template": "entry",
}


def candidates(path: Path):
    content = path.read_text(errors="replace")
    insert = re.compile(
        r"INSERT\s+INTO\s+`?([A-Za-z0-9_]+)`?[^;]*?VALUES\s*(.+?);",
        re.IGNORECASE | re.DOTALL,
    )
    for match in insert.finditer(content):
        table = match.group(1).lower()
        if table not in TABLE_ID_COLUMN:
            continue
        for row in re.finditer(r"\(([^()]*)\)", match.group(2)):
            first = row.group(1).split(",", 1)[0].strip().strip("`\"'")
            if re.fullmatch(r"-?\d+", first):
                yield table, int(first)


def main() -> int:
    READY_FILE.unlink(missing_ok=True)
    for attempt in range(120):
        try:
            mysql("SELECT 1", "acore_world")
            break
        except ToolError:
            if attempt == 119:
                raise
            if attempt % 10 == 0:
                print("[INFO] Waiting for database initialization...")
            time.sleep(2)

    digest = world_sql_digest()
    if STATE_FILE.is_file() and STATE_FILE.read_text().strip() == digest:
        READY_FILE.touch()
        print("[OK] World SQL precheck already validated for the current module sources.")
        return 0
    found: dict[tuple[str, int], list[str]] = defaultdict(list)
    for path in target_world_sql_files():
        for table, identifier in candidates(path):
            found[(table, identifier)].append(str(path))

    conflicts = 0
    existing_tables = {table for table in TABLE_ID_COLUMN if table_exists("acore_world", table)}
    for (table, identifier), sources in sorted(found.items()):
        if table not in existing_tables:
            continue
        column = TABLE_ID_COLUMN[table]
        exists = scalar(
            f"SELECT 1 FROM `{table}` WHERE `{column}`={identifier} LIMIT 1",
            "acore_world",
        )
        if exists == "1":
            print(
                f"[ERROR] World ID conflict: table={table} id={identifier} "
                f"source={sources[0]}"
            )
            conflicts += 1

    if conflicts:
        print(f"[ERROR] SQL world ID precheck failed with {conflicts} conflict(s).")
        return 1
    READY_FILE.touch()
    print(f"[OK] SQL world ID precheck passed ({len(found)} unique IDs checked).")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except ToolError as error:
        print(f"[ERROR] {error}")
        raise SystemExit(1)
