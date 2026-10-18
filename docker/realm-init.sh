#!/usr/bin/env bash
set -Eeuo pipefail

: "${DB_USER:?DB_USER is required}"
: "${DB_PASSWORD:?DB_PASSWORD is required}"
REALMLIST_IP="${REALMLIST_IP:-127.0.0.1}"
WORLD_PORT="${WORLD_PORT:-8085}"
STATE_DIR="${STATE_DIR:-/state}"
if [[ ! "$REALMLIST_IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
  echo "REALMLIST_IP must be an IPv4 address" >&2
  exit 2
fi
IFS=. read -r o1 o2 o3 o4 <<<"$REALMLIST_IP"
for octet in "$o1" "$o2" "$o3" "$o4"; do
  if ((10#$octet > 255)); then
    echo "Invalid IPv4 address: $REALMLIST_IP" >&2
    exit 2
  fi
done
if [[ ! "$WORLD_PORT" =~ ^[0-9]+$ ]] || (( WORLD_PORT < 1 || WORLD_PORT > 65535 )); then
  echo "WORLD_PORT must be an integer between 1 and 65535" >&2
  exit 2
fi
mkdir -p "$STATE_DIR"
rm -f "$STATE_DIR/.realm-init.ready"

# Migration jobs are one-shot containers.  Waiting on their shared marker is
# reliable with both Docker Compose and Podman, unlike a
# service_completed_successfully dependency which Podman may try to restart.
elapsed=0
until [[ -e "$STATE_DIR/.database-post-import.ready" ]]; do
  if (( elapsed >= 3600 )); then
    echo "Timed out waiting for database post-import" >&2
    exit 1
  fi
  (( elapsed % 30 == 0 )) && echo "[INFO] Waiting for database post-import..."
  sleep 2
  (( elapsed += 2 ))
done

# The marker is persistent across restarts; it does not prove that the
# database/user grant is ready during a fresh repair.
elapsed=0
until MYSQL_PWD="$DB_PASSWORD" mysql --protocol=tcp -h database -u"$DB_USER" \
  acore_auth -e "SELECT 1" >/dev/null 2>&1; do
  if (( elapsed >= 300 )); then
    echo "Timed out waiting for acore_auth access" >&2
    exit 1
  fi
  (( elapsed % 10 == 0 )) && echo "[INFO] Waiting for acore_auth access..."
  sleep 2
  (( elapsed += 2 ))
done

MYSQL_PWD="$DB_PASSWORD" mysql --protocol=tcp -h database -u"$DB_USER" acore_auth \
  -e "UPDATE realmlist SET address='${REALMLIST_IP}', port=${WORLD_PORT}, localAddress='127.0.0.1', localSubnetMask='255.255.255.0' WHERE id=1; DELETE FROM realmlist WHERE id<>1;"

echo "[OK] Realm address configured: $REALMLIST_IP:$WORLD_PORT"
touch "$STATE_DIR/.realm-init.ready"
