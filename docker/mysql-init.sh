#!/usr/bin/env bash
set -Eeuo pipefail

: "${MYSQL_ROOT_PASSWORD:?MYSQL_ROOT_PASSWORD is required}"
: "${DB_USER:?DB_USER is required}"
: "${DB_PASSWORD:?DB_PASSWORD is required}"
: "${DB_MIGRATION_PASSWORD:?DB_MIGRATION_PASSWORD is required}"
DB_MIGRATION_USER="${DB_MIGRATION_USER:-acore_migrator}"

case "$DB_USER" in
  (*[!A-Za-z0-9_]*|'') echo "Invalid DB_USER" >&2; exit 2 ;;
esac
case "$DB_MIGRATION_USER" in
  (*[!A-Za-z0-9_]*|'') echo "Invalid DB_MIGRATION_USER" >&2; exit 2 ;;
esac
if [[ "$DB_MIGRATION_USER" == "$DB_USER" ]]; then
  echo "DB_MIGRATION_USER must differ from DB_USER" >&2
  exit 2
fi
for secret_name in DB_PASSWORD DB_MIGRATION_PASSWORD; do
  secret_value="${!secret_name}"
  case "$secret_value" in
    (*[!A-Za-z0-9._~-]*|'')
      echo "$secret_name may only contain letters, digits and ._~-" >&2
      exit 2
      ;;
  esac
done

escape_sql() { printf '%s' "$1" | sed "s/'/''/g"; }
password_sql="$(escape_sql "$DB_PASSWORD")"
migration_password_sql="$(escape_sql "$DB_MIGRATION_PASSWORD")"

# MySQL's global REVOKE does not remove database-level grants. Revoke each
# legacy schema grant only when it exists, so fresh installations stay idempotent.
for database_name in acore_auth acore_characters acore_world acore_playerbots; do
  has_schema_grant="$(MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql --protocol=tcp -h database -uroot -Nse     "SELECT EXISTS(SELECT 1 FROM mysql.db WHERE Host='%' AND User='${DB_USER}' AND Db='${database_name}')")"
  if [[ "$has_schema_grant" == "1" ]]; then
    MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql --protocol=tcp -h database -uroot       -e "REVOKE ALL PRIVILEGES ON \`${database_name}\`.* FROM '${DB_USER}'@'%';"
  fi
done

mysql --protocol=tcp -h database -uroot -p"$MYSQL_ROOT_PASSWORD" <<SQL
CREATE DATABASE IF NOT EXISTS acore_auth CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS acore_characters CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS acore_world CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS acore_playerbots CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${password_sql}';
CREATE USER IF NOT EXISTS '${DB_MIGRATION_USER}'@'%' IDENTIFIED BY '${migration_password_sql}';
ALTER USER '${DB_USER}'@'%' IDENTIFIED BY '${password_sql}';
ALTER USER '${DB_MIGRATION_USER}'@'%' IDENTIFIED BY '${migration_password_sql}';
-- Runtime only needs data access. Revoking here also upgrades existing installs
-- which previously granted this account schema-administration privileges.
REVOKE ALL PRIVILEGES, GRANT OPTION FROM '${DB_USER}'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE, EXECUTE, CREATE TEMPORARY TABLES, LOCK TABLES ON acore_auth.* TO '${DB_USER}'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE, EXECUTE, CREATE TEMPORARY TABLES, LOCK TABLES ON acore_characters.* TO '${DB_USER}'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE, EXECUTE, CREATE TEMPORARY TABLES, LOCK TABLES ON acore_world.* TO '${DB_USER}'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE, EXECUTE, CREATE TEMPORARY TABLES, LOCK TABLES ON acore_playerbots.* TO '${DB_USER}'@'%';
-- Playerbots and a few enabled legacy modules perform non-destructive schema
-- checks at runtime.  Grant only the DDL verbs needed; DROP is deliberately
-- excluded from world/characters so runtime code cannot delete player data.
GRANT CREATE, ALTER, DROP, INDEX ON acore_playerbots.* TO '${DB_USER}'@'%';
GRANT CREATE, ALTER, INDEX ON acore_world.* TO '${DB_USER}'@'%';
GRANT CREATE, ALTER, INDEX ON acore_characters.* TO '${DB_USER}'@'%';
-- Import/preflight/post-import are short-lived migration jobs and retain DDL.
GRANT ALL PRIVILEGES ON acore_auth.* TO '${DB_MIGRATION_USER}'@'%';
GRANT ALL PRIVILEGES ON acore_characters.* TO '${DB_MIGRATION_USER}'@'%';
GRANT ALL PRIVILEGES ON acore_world.* TO '${DB_MIGRATION_USER}'@'%';
GRANT ALL PRIVILEGES ON acore_playerbots.* TO '${DB_MIGRATION_USER}'@'%';
FLUSH PRIVILEGES;
SQL

echo "[OK] AzerothCore databases and application user initialized."
