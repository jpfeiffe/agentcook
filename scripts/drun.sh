#!/usr/bin/env bash
# drun.sh — Run a command inside the dev container.
# Usage: scripts/drun.sh <command> [args...]
#
# Examples:
#   scripts/drun.sh shellcheck archive/templates/scripts/*.sh
#   scripts/drun.sh bash -c "find archive -name '*.sh' -exec shellcheck {} +"
#
# The container mounts the repo at /workspace, so file edits on the host
# are immediately visible inside. Agents edit files on the host (tmux)
# and use this script to execute code in Docker.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

# Start container if not running
if ! docker compose ps --status running 2>/dev/null | grep -q dev; then
    echo "[drun] Starting dev container..."
    docker compose up -d --build 2>&1
fi

# Run the command
exec docker compose exec dev "$@"
