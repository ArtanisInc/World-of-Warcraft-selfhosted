#!/usr/bin/env python3
"""Application-aware health probe for the complete Compose stack."""

from __future__ import annotations

from common import ToolError, mysql, tcp_open


def main() -> int:
    checks: list[tuple[str, bool]] = []
    checks.append(("mysql tcp", tcp_open("database", 3306)))
    try:
        checks.append(("mysql query", mysql("SELECT 1") == "1"))
    except ToolError:
        checks.append(("mysql query", False))
    checks.extend(
        (
            ("authserver tcp/3724", tcp_open("authserver", 3724)),
            ("worldserver tcp/8085", tcp_open("worldserver", 8085)),
            ("worldserver SOAP tcp/7878", tcp_open("worldserver", 7878)),
        )
    )
    failed = False
    for label, healthy in checks:
        print(f"[{'OK' if healthy else 'FAIL'}] {label}")
        failed |= not healthy
    print(f"Healthcheck: {'FAIL' if failed else 'OK'}")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
