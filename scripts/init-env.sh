#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"

secret() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 24
  else
    od -An -N24 -tx1 /dev/urandom | tr -d '[:space:]'
  fi
}

if [[ ! -e "$ENV_FILE" ]]; then
  cp "$ROOT_DIR/.env.example" "$ENV_FILE"
  echo "[INFO] Creating $ENV_FILE"
else
  echo "[INFO] Completing missing secrets in existing $ENV_FILE"
fi

mysql_root_password="$(secret)"
db_password="$(secret)"
db_migration_password="$(secret)"
soap_password="$(secret)"
tmp_file="${ENV_FILE}.tmp.$$"
trap 'rm -f "$tmp_file"' EXIT
seen_mysql_root=0 seen_db=0 seen_migration=0 seen_soap=0
while IFS= read -r line || [[ -n "$line" ]]; do
  case "$line" in
    MYSQL_ROOT_PASSWORD=*)
      seen_mysql_root=1
      if [[ "$line" == "MYSQL_ROOT_PASSWORD=" ]]; then
        printf 'MYSQL_ROOT_PASSWORD=%s\n' "$mysql_root_password"
      else
        printf '%s\n' "$line"
      fi ;;
    DB_PASSWORD=*)
      seen_db=1
      if [[ "$line" == "DB_PASSWORD=" ]]; then
        printf 'DB_PASSWORD=%s\n' "$db_password"
      else
        printf '%s\n' "$line"
      fi ;;
    DB_MIGRATION_PASSWORD=*)
      seen_migration=1
      if [[ "$line" == "DB_MIGRATION_PASSWORD=" ]]; then
        printf 'DB_MIGRATION_PASSWORD=%s\n' "$db_migration_password"
      else
        printf '%s\n' "$line"
      fi ;;
    SOAP_PASSWORD=*)
      seen_soap=1
      if [[ "$line" == "SOAP_PASSWORD=" ]]; then
        printf 'SOAP_PASSWORD=%s\n' "$soap_password"
      else
        printf '%s\n' "$line"
      fi ;;
    *) printf '%s\n' "$line" ;;
  esac
done < "$ENV_FILE" > "$tmp_file"
(( seen_mysql_root )) || printf 'MYSQL_ROOT_PASSWORD=%s\n' "$mysql_root_password" >> "$tmp_file"
(( seen_db )) || printf 'DB_PASSWORD=%s\n' "$db_password" >> "$tmp_file"
(( seen_migration )) || printf 'DB_MIGRATION_PASSWORD=%s\n' "$db_migration_password" >> "$tmp_file"
(( seen_soap )) || printf 'SOAP_PASSWORD=%s\n' "$soap_password" >> "$tmp_file"
mv "$tmp_file" "$ENV_FILE"
trap - EXIT
chmod 600 "$ENV_FILE"

echo "[OK] Secure Docker environment ready: $ENV_FILE"
echo "[INFO] Review BIND_ADDRESS and REALMLIST_IP before starting the server."
