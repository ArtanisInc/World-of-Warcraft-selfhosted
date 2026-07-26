#!/usr/bin/env bash
set -Eeuo pipefail

: "${DB_USER:?DB_USER is required}"
: "${DB_PASSWORD:?DB_PASSWORD is required}"
REALMLIST_IP="${REALMLIST_IP:-127.0.0.1}"
STATE_DIR="${STATE_DIR:-/state}"

for ((elapsed=0; elapsed<1800; elapsed+=2)); do
  [[ -e "$STATE_DIR/.database-post-import.ready" ]] && break
  (( elapsed % 30 == 0 )) && echo "[INFO] Waiting for post-import SQL initialization..."
  sleep 2
done
[[ -e "$STATE_DIR/.database-post-import.ready" ]] || { echo "Timed out waiting for post-import SQL initialization" >&2; exit 1; }

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

MYSQL_PWD="$DB_PASSWORD" mysql --protocol=tcp -h database -u"$DB_USER" acore_auth \
  -e "UPDATE realmlist SET address='${REALMLIST_IP}', localAddress='127.0.0.1', localSubnetMask='255.255.255.0' WHERE id=1; DELETE FROM realmlist WHERE id<>1;"

echo "[OK] Realm address configured: $REALMLIST_IP"
touch "$STATE_DIR/.realm-init.ready"
