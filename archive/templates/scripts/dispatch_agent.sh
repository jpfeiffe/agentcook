#!/bin/bash
# {{PROJECT_NAME}} — Dispatch a sub-agent into a tmux window
#
# Usage: dispatch_agent.sh <agent_name> [timeout_seconds] [issue_number] [extra_prompt]
#
# Creates a tmux window in the "{{TMUX_SESSION}}" session, runs run_agent.sh inside it,
# and starts a background watchdog that kills the window if it exceeds the timeout.
set -euo pipefail

AGENT_NAME="${1:?Usage: dispatch_agent.sh <agent_name> [timeout_seconds] [issue_number] [extra_prompt]}"
TIMEOUT="${2:-1800}"
ISSUE_NUMBER="${3:-}"
EXTRA_PROMPT="${4:-}"
TMUX_SESSION="{{TMUX_SESSION}}"

# Validate inputs to prevent shell injection via the tmux command string
if [[ ! "$AGENT_NAME" =~ ^[a-z_][a-z0-9_]*$ ]]; then
    echo "ERROR: Invalid agent name '${AGENT_NAME}'. Must match [a-z_][a-z0-9_]* (lowercase letters, digits, underscores)."
    exit 1
fi
if [[ ! "$TIMEOUT" =~ ^[0-9]+$ ]]; then
    echo "ERROR: Invalid timeout '${TIMEOUT}'. Must be a positive integer."
    exit 1
fi
if [[ -n "$ISSUE_NUMBER" && ! "$ISSUE_NUMBER" =~ ^[0-9]+$ ]]; then
    echo "ERROR: Invalid issue number '${ISSUE_NUMBER}'. Must be a positive integer."
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check for existing window (avoid double-dispatch)
if tmux list-windows -t "$TMUX_SESSION" 2>/dev/null | grep -q "^[0-9]*: ${AGENT_NAME}"; then
    echo "[dispatch] ${AGENT_NAME} already has a tmux window — skipping"
    exit 0
fi

# Build the agent command with properly quoted arguments
AGENT_CMD="bash $(printf '%q' "${SCRIPT_DIR}/run_agent.sh") $(printf '%q' "${AGENT_NAME}") $(printf '%q' "${TIMEOUT}") $(printf '%q' "${ISSUE_NUMBER}") $(printf '%q' "${EXTRA_PROMPT}")"

echo "[dispatch] Creating tmux window '${AGENT_NAME}' in session '${TMUX_SESSION}'"

tmux new-window -t "$TMUX_SESSION" -n "$AGENT_NAME" \
    "echo '[dispatch] ${AGENT_NAME} window started'; unset CLAUDECODE CLAUDE_CODE_SSE_PORT CLAUDE_CODE_ENTRYPOINT CLAUDE_CODE_SESSION_ACCESS_TOKEN; ${AGENT_CMD}; echo '[dispatch] ${AGENT_NAME} finished (exit: \$?)'; sleep 5"

# Background timeout watchdog (safety net — run_agent.sh has its own timeout too)
(
    sleep "$((TIMEOUT + 60))"
    if tmux list-windows -t "$TMUX_SESSION" 2>/dev/null | grep -q "^[0-9]*: ${AGENT_NAME}"; then
        echo "[watchdog] ${AGENT_NAME} exceeded timeout+60s — killing window"
        tmux kill-window -t "${TMUX_SESSION}:${AGENT_NAME}" 2>/dev/null || true
    fi
) &

echo "[dispatch] ${AGENT_NAME} dispatched (timeout: ${TIMEOUT}s, issue: ${ISSUE_NUMBER:-none})"
