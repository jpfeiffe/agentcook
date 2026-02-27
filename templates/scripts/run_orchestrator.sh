#!/bin/bash
# {{PROJECT_NAME}} — Orchestrator single cycle
# Sets up a persistent worktree on main, runs one Claude session, pushes state files, exits.
# The outer loop (run.sh) calls this repeatedly.
set -euo pipefail

ORCHESTRATOR_MODEL="${ORCHESTRATOR_MODEL:-claude-opus-4-6}"
SESSION_TIMEOUT="${ORCHESTRATOR_SESSION_TIMEOUT:-1800}"

# Resolve repo root (works from main repo or any worktree)
resolve_repo_root() {
    local git_common
    git_common="$(git -C "$1" rev-parse --git-common-dir 2>/dev/null)"
    if [ "$git_common" = ".git" ]; then
        (cd "$1" && pwd)
    else
        dirname "$(cd "$1" && realpath "$git_common")"
    fi
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(resolve_repo_root "$SCRIPT_DIR")"
WORKTREE_DIR="${REPO_ROOT}/worktrees/orchestrator"

echo "=== {{PROJECT_NAME}}: Orchestrator Cycle Starting ==="
echo "Model:     ${ORCHESTRATOR_MODEL}"
echo "Timeout:   ${SESSION_TIMEOUT}s"
echo "Worktree:  ${WORKTREE_DIR}"
echo "Time:      $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "==="

# Set up or refresh orchestrator's persistent worktree on main
if [ -d "$WORKTREE_DIR" ] && git -C "$WORKTREE_DIR" rev-parse --git-dir &>/dev/null; then
    cd "$WORKTREE_DIR"
    git checkout main 2>/dev/null || true
    git pull --rebase origin main 2>/dev/null || true
else
    if [ -d "$WORKTREE_DIR" ]; then
        git -C "$REPO_ROOT" worktree remove --force "$WORKTREE_DIR" 2>/dev/null || rm -rf "$WORKTREE_DIR"
    fi
    git -C "$REPO_ROOT" worktree prune
    git -C "$REPO_ROOT" fetch origin main 2>/dev/null || true
    if ! git -C "$REPO_ROOT" worktree add "$WORKTREE_DIR" main 2>/dev/null; then
        # main already checked out at repo root — use it directly
        WORKTREE_DIR="$REPO_ROOT"
    fi
    cd "$WORKTREE_DIR"
fi

COMMIT=$(git rev-parse --short=6 HEAD 2>/dev/null || echo "no-git")
TIMESTAMP=$(date -u +%Y%m%d_%H%M%S)
LOGFILE="${REPO_ROOT}/agent_logs/orchestrator_${TIMESTAMP}_${COMMIT}.log"

echo "[$(date -u +%H:%M:%S)] Orchestrator cycle — HEAD: ${COMMIT}"

# Run one Claude session
timeout --signal=TERM --kill-after=30 "${SESSION_TIMEOUT}" \
    claude --dangerously-skip-permissions \
           -p "$(cat "${REPO_ROOT}/agents/orchestrator.md")" \
           --model "$ORCHESTRATOR_MODEL" \
           --output-format stream-json \
           --verbose \
           --include-partial-messages \
    2>&1 | tee "$LOGFILE" || true

EXIT_CODE=${PIPESTATUS[0]}
if [ "$EXIT_CODE" -eq 124 ]; then
    echo "[$(date -u +%H:%M:%S)] Orchestrator cycle TIMED OUT after ${SESSION_TIMEOUT}s"
else
    echo "[$(date -u +%H:%M:%S)] Orchestrator cycle complete (exit: ${EXIT_CODE}) — log: ${LOGFILE}"
fi

# Push any state file updates the orchestrator made
cd "$WORKTREE_DIR"
git pull --rebase origin main 2>/dev/null || true
git push origin main 2>/dev/null || true

echo "=== Orchestrator cycle done ==="
