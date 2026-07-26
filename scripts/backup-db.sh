#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
env_backup_dir=""
if [[ -f "$ROOT_DIR/.env" ]]; then
  env_backup_dir="$(sed -n 's/^DB_BACKUP_DIR=//p' "$ROOT_DIR/.env" | tail -n 1)"
  if [[ -z "${DB_BACKUP_RETENTION:-}" ]]; then
    DB_BACKUP_RETENTION="$(sed -n 's/^DB_BACKUP_RETENTION=//p' "$ROOT_DIR/.env" | tail -n 1)"
  fi
fi
BACKUP_ROOT="${DB_BACKUP_DIR:-${env_backup_dir:-$ROOT_DIR/backups}}"
if [[ "$BACKUP_ROOT" != /* ]]; then
  BACKUP_ROOT="$ROOT_DIR/$BACKUP_ROOT"
fi
DB_BACKUP_RETENTION="${DB_BACKUP_RETENTION:-7}"
if [[ ! "$DB_BACKUP_RETENTION" =~ ^[0-9]+$ ]]; then
  echo "[ERROR] DB_BACKUP_RETENTION must be a non-negative integer." >&2
  exit 2
fi

FINAL_DIR="$BACKUP_ROOT/$TIMESTAMP"
TEMP_DIR="$BACKUP_ROOT/.tmp-$TIMESTAMP-$$"
mkdir -p "$TEMP_DIR"
chmod 700 "$BACKUP_ROOT" "$TEMP_DIR"
trap 'rm -rf "$TEMP_DIR"' EXIT

for database in acore_auth acore_characters acore_world acore_playerbots; do
  echo "[INFO] Backing up $database"
  docker compose -f "$ROOT_DIR/docker-compose.yml" exec -T database \
    sh -c 'exec mysqldump --single-transaction --quick --routines --triggers -uroot -p"$MYSQL_ROOT_PASSWORD" "$1"' \
    sh "$database" | gzip -9 >"$TEMP_DIR/$database.sql.gz"
  gzip -t "$TEMP_DIR/$database.sql.gz"
done

mv "$TEMP_DIR" "$FINAL_DIR"
trap - EXIT

if (( DB_BACKUP_RETENTION > 0 )); then
  old_backups=()
  while IFS= read -r old; do
    [[ -n "$old" ]] && old_backups+=("$old")
  done < <(
    shopt -s nullglob
    for path in "$BACKUP_ROOT"/20??????_??????; do
      [[ -d "$path" ]] && basename "$path"
    done | sort -r | tail -n "+$((DB_BACKUP_RETENTION + 1))"
  )
  for old in "${old_backups[@]}"; do
    rm -rf "$BACKUP_ROOT/$old"
    echo "[INFO] Removed expired backup: $old"
  done
fi

echo "[OK] Atomic backup created in $FINAL_DIR"
