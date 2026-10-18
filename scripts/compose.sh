#!/usr/bin/env bash
set -Eeuo pipefail

# Use Docker when its Compose plugin is available; otherwise use Podman.
# COMPOSE_COMMAND can override detection (for example: "podman compose").
if [[ -n "${COMPOSE_COMMAND:-}" ]]; then
  read -r -a compose_cmd <<<"$COMPOSE_COMMAND"
elif command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  compose_cmd=(docker compose)
elif command -v podman >/dev/null 2>&1; then
  compose_cmd=(podman compose)
else
  echo "Neither Docker Compose nor Podman Compose is available." >&2
  exit 127
fi

exec "${compose_cmd[@]}" "$@"
