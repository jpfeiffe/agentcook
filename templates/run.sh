#!/bin/bash
# {{PROJECT_NAME}} — Orchestrator loop
#
# Runs the orchestrator in a while-true loop on the host. Each iteration:
#   1. Ensures tmux session "{{TMUX_SESSION}}" exists
#   2. Runs one orchestrator cycle (pull main, Claude session, push state files)
#   3. Waits CYCLE_PAUSE seconds
#   4. Repeat
#
# The orchestrator is stateless between cycles. GitHub is the memory.
#
# IMPORTANT: Run with nohup to avoid SIGTTIN if launched from inside another
# Claude Code session or a terminal that may lose its foreground process group:
#   nohup bash run.sh > /tmp/{{TMUX_SESSION}}.log 2>&1 &
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

CYCLE_PAUSE="${CYCLE_PAUSE:-300}"   # seconds between cycles (default 5 min)
TMUX_SESSION="{{TMUX_SESSION}}"
MODE="${MODE:-{{MODE}}}"            # github | local

echo "=== {{PROJECT_NAME}} ==="
echo "Mode:         ${MODE}"
if [ "$MODE" = "github" ]; then
echo "Repo:         ${GITHUB_REPO:-{{GITHUB_REPO}}}"
fi
echo "Cycle pause:  ${CYCLE_PAUSE}s"
echo "tmux session: ${TMUX_SESSION}"
echo "Time:         $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "==="

# Run setup checks
echo "Running setup validation..."
if ! bash scripts/setup.sh; then
    echo "Setup failed. Fix the issues above and try again."
    exit 1
fi

# Clean up any previous tmux session
tmux kill-session -t "$TMUX_SESSION" 2>/dev/null || true

# Create tmux session
tmux new-session -d -s "$TMUX_SESSION" -n "control"
tmux set-environment -t "$TMUX_SESSION" MODE "$MODE"
if [ "$MODE" = "github" ]; then
tmux set-environment -t "$TMUX_SESSION" GITHUB_REPO "${GITHUB_REPO:-{{GITHUB_REPO}}}"
fi
# Unset CLAUDECODE so nested claude sessions can spawn
tmux set-environment -u -t "$TMUX_SESSION" CLAUDECODE

echo "tmux session '${TMUX_SESSION}' created. Attach with: tmux attach -t ${TMUX_SESSION}"

mkdir -p agent_logs worktrees

# Clean shutdown on SIGINT/SIGTERM
cleanup() {
    echo ""
    echo "Shutting down {{PROJECT_NAME}}..."
    tmux kill-session -t "$TMUX_SESSION" 2>/dev/null || true
    exit 0
}
trap cleanup SIGINT SIGTERM

CYCLE=0
while true; do
    CYCLE=$((CYCLE + 1))
    echo ""
    echo "[$(date -u +%H:%M:%S)] ===== Orchestrator cycle ${CYCLE} ====="

    # Recreate tmux session if it was killed
    if ! tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
        echo "tmux session disappeared — recreating..."
        tmux new-session -d -s "$TMUX_SESSION" -n "control"
        tmux set-environment -t "$TMUX_SESSION" GITHUB_REPO "${GITHUB_REPO:-{{GITHUB_REPO}}}"
        tmux set-environment -u -t "$TMUX_SESSION" CLAUDECODE
    fi

    # Run one orchestrator cycle (blocks until done)
    env -u CLAUDECODE bash scripts/run_orchestrator.sh

    echo "[$(date -u +%H:%M:%S)] Cycle ${CYCLE} complete. Sleeping ${CYCLE_PAUSE}s..."
    sleep "$CYCLE_PAUSE"
done
