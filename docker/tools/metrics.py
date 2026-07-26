#!/usr/bin/env python3
"""Emit a single, machine-readable JSON metrics snapshot."""

from __future__ import annotations

import json
from datetime import datetime, timezone

from common import ToolError, scalar, tcp_open


def integer(sql: str, database: str | None = None) -> int | None:
    try:
        return int(scalar(sql, database, "0"))
    except (ToolError, ValueError):
        return None


def main() -> int:
    metrics = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "tcp": {
            "mysql": tcp_open("database", 3306),
            "authserver": tcp_open("authserver", 3724),
            "worldserver": tcp_open("worldserver", 8085),
            "soap": tcp_open("worldserver", 7878),
        },
        "database": {
            "accounts": integer("SELECT COUNT(*) FROM account", "acore_auth"),
            "characters": integer("SELECT COUNT(*) FROM characters", "acore_characters"),
            "world_tables": integer(
                "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA='acore_world'"
            ),
            "character_tables": integer(
                "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA='acore_characters'"
            ),
            "playerbot_tables": integer(
                "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA='acore_playerbots'"
            ),
            "size_mib": integer(
                "SELECT COALESCE(ROUND(SUM(data_length+index_length)/1024/1024),0) "
                "FROM information_schema.TABLES WHERE TABLE_SCHEMA LIKE 'acore_%'"
            ),
        },
    }
    print(json.dumps(metrics, ensure_ascii=False, separators=(",", ":")))
    return 0 if all(metrics["tcp"].values()) else 1


if __name__ == "__main__":
    raise SystemExit(main())
