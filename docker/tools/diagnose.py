#!/usr/bin/env python3
"""Detailed database, configuration and module diagnostic report."""

from __future__ import annotations

from pathlib import Path

from common import MODULES_DIR, ToolError, mysql, soap_execute, tcp_open


def section(title: str) -> None:
    print(f"\n==== {title} ====")


def query(title: str, sql: str, database: str | None = None) -> None:
    print(f"-- {title}")
    try:
        print(mysql(sql, database) or "(empty)")
    except ToolError as error:
        print(f"[FAIL] {error}")


def main() -> int:
    section("Network")
    for label, host, port in (
        ("mysql", "database", 3306),
        ("authserver", "authserver", 3724),
        ("worldserver", "worldserver", 8085),
        ("SOAP", "worldserver", 7878),
    ):
        print(f"[{'OK' if tcp_open(host, port) else 'FAIL'}] {label} {host}:{port}")

    section("Realm")
    query("realmlist", "SELECT id,name,address,localAddress,port FROM realmlist", "acore_auth")

    section("Database sizes")
    query(
        "sizes MiB",
        "SELECT table_schema,ROUND(SUM(data_length+index_length)/1024/1024,1) "
        "FROM information_schema.TABLES WHERE table_schema IN "
        "('acore_auth','acore_characters','acore_world','acore_playerbots') GROUP BY table_schema",
    )
    query(
        "table counts",
        "SELECT table_schema,COUNT(*) FROM information_schema.TABLES WHERE table_schema IN "
        "('acore_auth','acore_characters','acore_world','acore_playerbots') GROUP BY table_schema",
    )
    query("accounts", "SELECT COUNT(*) FROM account", "acore_auth")
    query("characters", "SELECT COUNT(*) FROM characters", "acore_characters")
    query(
        "orphaned item templates",
        "SELECT ii.itemEntry,COUNT(*) AS instances "
        "FROM acore_characters.item_instance ii "
        "LEFT JOIN acore_world.item_template it ON it.entry=ii.itemEntry "
        "WHERE it.entry IS NULL GROUP BY ii.itemEntry ORDER BY instances DESC LIMIT 50",
    )

    section("SOAP runtime")
    try:
        response = soap_execute(".server info")
        print(f"[OK] authenticated SOAP response ({len(response)} bytes)")
        daily = soap_execute(".help daily")
        print(f"[{'OK' if 'daily reset' in daily.lower() else 'WARN'}] mod-daily-reset command detection")
    except ToolError as error:
        print(f"[FAIL] {error}")

    section("Modules in image")
    modules = sorted(path.name for path in MODULES_DIR.iterdir() if path.is_dir())
    print("\n".join(modules) if modules else "[WARN] no module source directory")

    section("Build revisions")
    manifest = Path("/azerothcore/env/dist/build-manifest.tsv")
    print(manifest.read_text().strip() if manifest.is_file() else "[WARN] build manifest missing")

    section("Active module configurations")
    conf = Path("/azerothcore/env/dist/etc/modules")
    files = sorted(path.name for path in conf.glob("*.conf")) if conf.is_dir() else []
    print("\n".join(files) if files else "[WARN] no module configuration")

    section("Database migration markers")
    marker = Path("/azerothcore/env/dist/etc/.database-preflight.sha256")
    print(marker.read_text().strip() if marker.is_file() else "[WARN] SQL precheck marker missing")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
