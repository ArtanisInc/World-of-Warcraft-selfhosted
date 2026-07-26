#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"

if [[ -e "$ENV_FILE" ]]; then
  echo "[ERROR] $ENV_FILE already exists; refusing to overwrite it." >&2
  exit 1
fi

secret() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 24
  else
    od -An -N24 -tx1 /dev/urandom | tr -d '[:space:]'
  fi
}

cp "$ROOT_DIR/.env.example" "$ENV_FILE"
mysql_root_password="$(secret)"
db_password="$(secret)"
soap_password="$(secret)"
tmp_file="${ENV_FILE}.tmp.$$"
trap 'rm -f "$tmp_file"' EXIT
while IFS= read -r line || [[ -n "$line" ]]; do
  case "$line" in
    MYSQL_ROOT_PASSWORD=) printf 'MYSQL_ROOT_PASSWORD=%s\n' "$mysql_root_password" ;;
    DB_PASSWORD=) printf 'DB_PASSWORD=%s\n' "$db_password" ;;
    SOAP_PASSWORD=) printf 'SOAP_PASSWORD=%s\n' "$soap_password" ;;
    *) printf '%s\n' "$line" ;;
  esac
done < "$ENV_FILE" > "$tmp_file"
mv "$tmp_file" "$ENV_FILE"
trap - EXIT
chmod 600 "$ENV_FILE"

echo "[OK] Secure Docker environment created: $ENV_FILE"
echo "[INFO] Review BIND_ADDRESS and REALMLIST_IP before starting the server."
