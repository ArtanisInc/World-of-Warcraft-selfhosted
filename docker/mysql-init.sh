#!/usr/bin/env bash
set -Eeuo pipefail

: "${MYSQL_ROOT_PASSWORD:?MYSQL_ROOT_PASSWORD is required}"
: "${DB_USER:?DB_USER is required}"
: "${DB_PASSWORD:?DB_PASSWORD is required}"

case "$DB_USER" in
  (*[!A-Za-z0-9_]*|'') echo "Invalid DB_USER" >&2; exit 2 ;;
esac
case "$DB_PASSWORD" in
  (*[!A-Za-z0-9._~-]*|'')
    echo "DB_PASSWORD may only contain letters, digits and ._~-" >&2
    exit 2
    ;;
esac

escape_sql() { printf '%s' "$1" | sed "s/'/''/g"; }
password_sql="$(escape_sql "$DB_PASSWORD")"

mysql --protocol=tcp -h database -uroot -p"$MYSQL_ROOT_PASSWORD" <<SQL
CREATE DATABASE IF NOT EXISTS acore_auth CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS acore_characters CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS acore_world CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS acore_playerbots CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${password_sql}';
ALTER USER '${DB_USER}'@'%' IDENTIFIED BY '${password_sql}';
GRANT ALL PRIVILEGES ON acore_auth.* TO '${DB_USER}'@'%';
GRANT ALL PRIVILEGES ON acore_characters.* TO '${DB_USER}'@'%';
GRANT ALL PRIVILEGES ON acore_world.* TO '${DB_USER}'@'%';
GRANT ALL PRIVILEGES ON acore_playerbots.* TO '${DB_USER}'@'%';
FLUSH PRIVILEGES;
SQL

echo "[OK] AzerothCore databases and application user initialized."
