#!/usr/bin/env python3
"""Shared helpers for Docker-side AzerothCore maintenance tools."""

from __future__ import annotations

import hashlib
import os
import re
import socket
import subprocess
import base64
import urllib.error
import urllib.request
from pathlib import Path
from typing import Iterable
from xml.sax.saxutils import escape

DB_HOST = os.getenv("DB_HOST", "database")
DB_PORT = os.getenv("DB_PORT", "3306")
DB_USER = os.getenv("DB_USER", "acore")
DB_PASSWORD = os.environ.get("DB_PASSWORD", "")
MODULES_DIR = Path("/azerothcore/modules")


class ToolError(RuntimeError):
    pass


def mysql(
    sql: str | None = None,
    database: str | None = None,
    *,
    input_file: Path | None = None,
    capture: bool = True,
) -> str:
    command = [
        "mysql",
        "--protocol=tcp",
        "--batch",
        "--skip-column-names",
        "-h",
        DB_HOST,
        "-P",
        DB_PORT,
        "-u",
        DB_USER,
    ]
    if database:
        command.append(database)
    if sql is not None:
        command.extend(["-e", sql])
    environment = os.environ.copy()
    environment["MYSQL_PWD"] = DB_PASSWORD
    handle = input_file.open("rb") if input_file else None
    try:
        result = subprocess.run(
            command,
            env=environment,
            stdin=handle,
            text=input_file is None,
            stdout=subprocess.PIPE if capture else None,
            stderr=subprocess.PIPE,
            check=False,
        )
    finally:
        if handle:
            handle.close()
    if result.returncode:
        stderr = result.stderr.decode() if isinstance(result.stderr, bytes) else result.stderr
        raise ToolError((stderr or "mysql command failed").strip())
    stdout = result.stdout.decode() if isinstance(result.stdout, bytes) else result.stdout
    return (stdout or "").strip()


def scalar(sql: str, database: str | None = None, default: str = "") -> str:
    value = mysql(sql, database)
    return value.splitlines()[0].strip() if value else default


def sql_literal(value: str) -> str:
    return "'" + value.replace("\\", "\\\\").replace("'", "''") + "'"


def table_exists(database: str, table: str) -> bool:
    query = (
        "SELECT COUNT(*) FROM information_schema.TABLES "
        f"WHERE TABLE_SCHEMA={sql_literal(database)} AND TABLE_NAME={sql_literal(table)}"
    )
    return int(scalar(query, default="0")) > 0


def first_created_table(path: Path) -> str | None:
    text = path.read_text(errors="replace")
    # Ignore documentation such as "Uses CREATE TABLE IF NOT EXISTS and...".
    # Otherwise the first word following that sentence ("and") is mistaken
    # for the schema sentinel.
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.DOTALL)
    text = re.sub(r"^[ \t]*(?:--|#).*$", "", text, flags=re.MULTILINE)
    match = re.search(
        r"CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?`?([A-Za-z0-9_]+)`?",
        text,
        re.IGNORECASE,
    )
    return match.group(1) if match else None


def first_existing(base: Path, candidates: Iterable[str]) -> Path | None:
    for candidate in candidates:
        path = base / candidate
        if path.is_file():
            return path
    return None


def target_world_sql_files() -> list[Path]:
    files: list[Path] = []
    for module in ("portals-in-all-capitals", "mod-rare-drops"):
        root = MODULES_DIR / module
        if root.is_dir():
            files.extend(sorted(root.rglob("*.sql")))
    return files


def world_sql_digest() -> str:
    digest = hashlib.sha256()
    for path in target_world_sql_files():
        digest.update(str(path.relative_to(MODULES_DIR)).encode())
        digest.update(b"\0")
        digest.update(path.read_bytes())
        digest.update(b"\0")
    return digest.hexdigest()


def tcp_open(host: str, port: int, timeout: float = 2.0) -> bool:
    try:
        with socket.create_connection((host, port), timeout=timeout):
            return True
    except OSError:
        return False


def soap_execute(command: str, timeout: float = 8.0) -> str:
    host = os.getenv("SOAP_HOST", "worldserver")
    port = os.getenv("SOAP_PORT", "7878")
    user = os.environ.get("SOAP_USER", "")
    password = os.environ.get("SOAP_PASSWORD", "")
    payload = (
        '<?xml version="1.0" encoding="utf-8"?>'
        '<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" '
        'xmlns:ns1="urn:AC"><SOAP-ENV:Body><ns1:executeCommand><command>'
        f"{escape(command)}</command></ns1:executeCommand></SOAP-ENV:Body></SOAP-ENV:Envelope>"
    ).encode()
    request = urllib.request.Request(f"http://{host}:{port}/", data=payload)
    token = base64.b64encode(f"{user}:{password}".encode()).decode()
    request.add_header("Authorization", f"Basic {token}")
    request.add_header("Content-Type", "text/xml; charset=utf-8")
    request.add_header("SOAPAction", '"urn:AC#executeCommand"')
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return response.read().decode(errors="replace")
    except (OSError, urllib.error.URLError) as error:
        raise ToolError(f"SOAP command failed ({command}): {error}") from error


def ensure_conf_value(path: Path, key: str, value: str) -> None:
    text = path.read_text()
    pattern = re.compile(rf"^[ \t]*{re.escape(key)}[ \t]*=.*$", re.MULTILINE)
    replacement = f"{key} = {value}"
    if pattern.search(text):
        text = pattern.sub(replacement, text)
    else:
        text += f"\n{replacement}\n"
    path.write_text(text)
