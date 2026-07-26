#!/usr/bin/env python3
"""Account, GM and AuctionHouseBot administration for Docker deployments."""

from __future__ import annotations

import argparse
import base64
import hashlib
import os
import re
import secrets
import urllib.error
import urllib.request
from pathlib import Path
from xml.sax.saxutils import escape

from common import ToolError, ensure_conf_value, mysql, scalar, sql_literal

USERNAME = re.compile(r"^[A-Za-z0-9_]{1,16}$")


def validate_username(username: str) -> str:
    if not USERNAME.fullmatch(username):
        raise ToolError("username must match [A-Za-z0-9_]{1,16}")
    return username.upper()


def account_id(username: str) -> str:
    normalized = validate_username(username)
    return scalar(
        f"SELECT id FROM account WHERE username={sql_literal(normalized)} LIMIT 1",
        "acore_auth",
    )


def create_account(username: str, password: str) -> None:
    normalized = validate_username(username)
    if not 1 <= len(password) <= 64 or any(ord(char) < 32 for char in password):
        raise ToolError("password must contain 1-64 printable characters")

    has_legacy = int(
        scalar(
            "SELECT COUNT(*) FROM information_schema.COLUMNS WHERE "
            "TABLE_SCHEMA='acore_auth' AND TABLE_NAME='account' AND COLUMN_NAME='sha_pass_hash'",
            default="0",
        )
    )
    has_srp = int(
        scalar(
            "SELECT COUNT(*) FROM information_schema.COLUMNS WHERE "
            "TABLE_SCHEMA='acore_auth' AND TABLE_NAME='account' AND COLUMN_NAME IN ('salt','verifier')",
            default="0",
        )
    )

    if has_legacy:
        digest = hashlib.sha1(f"{normalized}:{password.upper()}".encode()).hexdigest().upper()
        mysql(
            "INSERT INTO account (username,sha_pass_hash,reg_mail,email) VALUES "
            f"({sql_literal(normalized)},{sql_literal(digest)},'','') "
            "ON DUPLICATE KEY UPDATE sha_pass_hash=VALUES(sha_pass_hash)",
            "acore_auth",
        )
    elif has_srp >= 2:
        modulus = int("894B645E89E1535BBDAD5B8B290650530801B18EBFBF5E8FAB3C82872A3E9BB7", 16)
        inner = hashlib.sha1(f"{normalized}:{password.upper()}".encode()).digest()
        salt = secrets.token_bytes(32)
        exponent = int.from_bytes(hashlib.sha1(salt + inner).digest(), "little")
        verifier = pow(7, exponent, modulus).to_bytes(32, "little")
        mysql(
            "INSERT INTO account (username,salt,verifier,reg_mail,email) VALUES "
            f"({sql_literal(normalized)},UNHEX('{salt.hex()}'),UNHEX('{verifier.hex()}'),'','') "
            "ON DUPLICATE KEY UPDATE salt=VALUES(salt),verifier=VALUES(verifier)",
            "acore_auth",
        )
    else:
        raise ToolError("unsupported account schema: SHA1 and SRP6 columns are missing")
    print(f"[OK] Account created or updated: {normalized}")


def set_gm(username: str, level: int, realm: int) -> None:
    if level < 0:
        raise ToolError("GM level must be >= 0")
    identifier = account_id(username)
    if not identifier:
        raise ToolError(f"account not found: {username}")
    mysql(
        "INSERT INTO account_access (id,gmlevel,RealmID) VALUES "
        f"({int(identifier)},{level},{realm}) ON DUPLICATE KEY UPDATE "
        "gmlevel=VALUES(gmlevel),RealmID=VALUES(RealmID)",
        "acore_auth",
    )
    print(f"[OK] GM rights applied: account={username} level={level} realm={realm}")


def ahbot_config() -> Path:
    directory = Path("/azerothcore/env/dist/etc/modules")
    candidates = ("mod_ahbot.conf", "AuctionHouseBot.conf", "ahbot.conf")
    for candidate in candidates:
        path = directory / candidate
        if path.is_file():
            return path
    lowered = {candidate.lower() for candidate in candidates}
    for path in directory.glob("*.conf"):
        if path.name.lower() in lowered:
            return path
    raise ToolError(f"AHBot configuration not found in {directory}")


def soap(command: str) -> bool:
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
        with urllib.request.urlopen(request, timeout=8) as response:
            response.read()
        print(f"[OK] SOAP command executed: {command}")
        return True
    except (OSError, urllib.error.URLError) as error:
        print(f"[WARN] SOAP command unavailable ({command}): {error}")
        return False


def setup_ahbot(guids: str) -> None:
    if not re.fullmatch(r"[0-9]+(?:,[0-9]+)*", guids):
        raise ToolError("GUID list must look like 123 or 123,456")
    identifiers = [int(value) for value in guids.split(",")]
    existing = scalar(
        "SELECT COUNT(*) FROM characters WHERE guid IN (" + ",".join(map(str, identifiers)) + ")",
        "acore_characters",
        "0",
    )
    if int(existing) != len(set(identifiers)):
        raise ToolError("one or more AHBot GUIDs do not exist in acore_characters.characters")
    config = ahbot_config()
    ensure_conf_value(config, "AuctionHouseBot.GUIDs", guids)
    ensure_conf_value(config, "AuctionHouseBot.EnableSeller", "true")
    print(f"[OK] AHBot GUIDs written to {config}: {guids}")
    soap(".ahbot reload")
    for _ in range(3):
        soap(".ahbot update")


def bootstrap_ahbot(username: str, password: str) -> None:
    create_account(username, password)
    identifier = account_id(username)
    characters = mysql(
        f"SELECT guid,name FROM characters WHERE account={int(identifier)} ORDER BY guid",
        "acore_characters",
    )
    if characters:
        print("[INFO] AHBot account characters:\n" + characters)
    else:
        print("[INFO] Account has no character. Create one with the WoW client, then run setup-ahbot.")


def parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser()
    commands = root.add_subparsers(dest="command", required=True)
    create = commands.add_parser("create-account")
    create.add_argument("username")
    create.add_argument("password")
    gm = commands.add_parser("set-gm")
    gm.add_argument("username")
    gm.add_argument("level", type=int)
    gm.add_argument("realm", type=int, nargs="?", default=-1)
    ahbot = commands.add_parser("setup-ahbot")
    ahbot.add_argument("guids")
    bootstrap = commands.add_parser("bootstrap-ahbot")
    bootstrap.add_argument("username")
    bootstrap.add_argument("password")
    return root


def main() -> int:
    args = parser().parse_args()
    if args.command == "create-account":
        create_account(args.username, args.password)
    elif args.command == "set-gm":
        set_gm(args.username, args.level, args.realm)
    elif args.command == "setup-ahbot":
        setup_ahbot(args.guids)
    elif args.command == "bootstrap-ahbot":
        bootstrap_ahbot(args.username, args.password)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except ToolError as error:
        print(f"[ERROR] {error}")
        raise SystemExit(1)
