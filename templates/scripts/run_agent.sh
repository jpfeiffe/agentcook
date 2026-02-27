#!/bin/bash
# {{PROJECT_NAME}} — Sub-agent lifecycle
# Creates a git worktree, runs one Claude session on a feature branch,
# then cleans up. Claude commits, pushes, and opens a PR from inside the session.
#
# Usage: run_agent.sh <agent_name> <timeout_seconds> [issue_number] [extra_prompt]
set -euo pipefail

AGENT_NAME="${1:?Usage: run_agent.sh <agent_name> <timeout_seconds> [issue_number] [extra_prompt]}"
TIMEOUT="${2:?Usage: run_agent.sh <agent_name> <timeout_seconds> [issue_number] [extra_prompt]}"
ISSUE_NUMBER="${3:-}"
EXTRA_PROMPT="${4:-}"

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
WORKTREE_DIR="${REPO_ROOT}/worktrees/${AGENT_NAME}"

# Model selection: orchestrator and any "senior" agents get Opus, everyone else Sonnet
case "$AGENT_NAME" in
    orchestrator|red_agent|security_agent) AGENT_MODEL="claude-opus-4-6" ;;
    *)                                     AGENT_MODEL="claude-sonnet-4-6" ;;
esac

echo "=== {{PROJECT_NAME}} Agent: ${AGENT_NAME} ==="
echo "Model:     ${AGENT_MODEL}"
echo "Timeout:   ${TIMEOUT}s"
echo "Issue:     ${ISSUE_NUMBER:-none}"
echo "Worktree:  ${WORKTREE_DIR}"
echo "Time:      $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "==="

# Determine branch name
if [ -n "$ISSUE_NUMBER" ]; then
    BRANCH="feature/issue-${ISSUE_NUMBER}-${AGENT_NAME}"
else
    BRANCH="feature/${AGENT_NAME}-$(date +%s)"
fi

# Clean up stale worktree from a previous crashed run
if [ -d "$WORKTREE_DIR" ]; then
    echo "[${AGENT_NAME}] Cleaning up stale worktree at ${WORKTREE_DIR}"
    git -C "$REPO_ROOT" worktree remove --force "$WORKTREE_DIR" 2>/dev/null || rm -rf "$WORKTREE_DIR"
fi
git -C "$REPO_ROOT" worktree prune

# Fetch latest
git -C "$REPO_ROOT" fetch origin main 2>/dev/null || true

# Delete stale local branch if it exists
git -C "$REPO_ROOT" branch -D "$BRANCH" 2>/dev/null || true

# Create worktree: resume remote branch if it exists, otherwise branch from main
if git -C "$REPO_ROOT" ls-remote --heads origin "$BRANCH" | grep -q .; then
    echo "[${AGENT_NAME}] Remote branch ${BRANCH} exists — resuming"
    git -C "$REPO_ROOT" fetch origin "$BRANCH"
    git -C "$REPO_ROOT" worktree add "$WORKTREE_DIR" -b "$BRANCH" "origin/${BRANCH}"
else
    echo "[${AGENT_NAME}] Creating new branch ${BRANCH} from origin/main"
    git -C "$REPO_ROOT" worktree add "$WORKTREE_DIR" -b "$BRANCH" origin/main
fi

# Resolve the agent prompt file (from main repo, not the worktree)
AGENT_PROMPT="${REPO_ROOT}/agents/${AGENT_NAME}.md"
if [ ! -f "$AGENT_PROMPT" ]; then
    echo "ERROR: No prompt found at ${AGENT_PROMPT}"
    git -C "$REPO_ROOT" worktree remove --force "$WORKTREE_DIR" 2>/dev/null || true
    exit 1
fi

# Build the full prompt
PROMPT="$(cat "$AGENT_PROMPT")"

if [ -n "$EXTRA_PROMPT" ]; then
    PROMPT="${PROMPT}

---
# Additional Context from Orchestrator
${EXTRA_PROMPT}"
fi

# Post start comment on GitHub issue
if [ -n "$ISSUE_NUMBER" ] && [ -n "${GITHUB_TOKEN:-}" ]; then
    gh issue comment "$ISSUE_NUMBER" \
      --body "$(printf ':robot: **Agent dispatched:** \`%s\`\n**Branch:** \`%s\`\n**Started:** %s\n**Timeout:** %ss' \
        "$AGENT_NAME" "$BRANCH" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$TIMEOUT")" \
      --repo "${GITHUB_REPO:-{{GITHUB_REPO}}}" 2>/dev/null || true
    gh issue edit "$ISSUE_NUMBER" \
      --add-label "in-progress" --remove-label "ready" \
      --repo "${GITHUB_REPO:-{{GITHUB_REPO}}}" 2>/dev/null || true
fi

if [ -n "${GITHUB_TOKEN:-}" ]; then
PROMPT="${PROMPT}

---
# GitHub Instructions

Repository: ${GITHUB_REPO:-{{GITHUB_REPO}}}
Your working branch: ${BRANCH}
$([ -n "$ISSUE_NUMBER" ] && echo "You are working on issue #${ISSUE_NUMBER}." || echo "No specific issue assigned.")

When your work is complete:
1. Stage and commit all changes:
   git add -A
   git commit -m \"feat(${AGENT_NAME}): <description>\"

2. Push your branch:
   git push origin ${BRANCH}

3. Open a pull request:
   gh pr create \\
     --title \"feat(${AGENT_NAME}): <short description>\" \\
     --body \"$([ -n "$ISSUE_NUMBER" ] && echo "Closes #${ISSUE_NUMBER}" || true)

## Summary
- <bullet points of what you built>

## Test plan
- <how to verify this works>\" \\
     --base main

4. Comment on your GitHub issue with a completion summary:
   gh issue comment ${ISSUE_NUMBER:-0} \\
     --body \":white_check_mark: **Work complete**

**PR:** #<pr-number>
**What was built:**
- <bullet>
- <bullet>

**Files created/modified:**
- <list>\"

Do not push directly to main. Always use the feature branch and PR.
"
else
PROMPT="${PROMPT}

---
# Local Mode Instructions

Your working branch: ${BRANCH}
$([ -n "$ISSUE_NUMBER" ] && echo "You are working on item #${ISSUE_NUMBER}." || echo "No specific item assigned.")

When your work is complete:
1. Stage and commit all changes:
   git add -A
   git commit -m \"feat(${AGENT_NAME}): <description>\"

Do NOT push or open a PR — local-only mode. The orchestrator will review and merge your branch directly.
"
fi

# Run one Claude session
TIMESTAMP=$(date -u +%Y%m%d_%H%M%S)
LOGFILE="${REPO_ROOT}/agent_logs/${AGENT_NAME}_${TIMESTAMP}.log"

echo "[${AGENT_NAME}] Starting Claude session (timeout: ${TIMEOUT}s)"
echo "[${AGENT_NAME}] Log: ${LOGFILE}"

cd "$WORKTREE_DIR"

# Ensure child claude sessions run independently
unset CLAUDECODE CLAUDE_CODE_SSE_PORT CLAUDE_CODE_ENTRYPOINT CLAUDE_CODE_SESSION_ACCESS_TOKEN 2>/dev/null || true

timeout --foreground --signal=TERM --kill-after=30 "$TIMEOUT" \
    claude --dangerously-skip-permissions \
           -p "$PROMPT" \
           --model "$AGENT_MODEL" \
           --verbose \
    2>&1 | tee "$LOGFILE" || true

EXIT_CODE=${PIPESTATUS[0]}
if [ "$EXIT_CODE" -eq 124 ]; then
    echo "[${AGENT_NAME}] Session TIMED OUT after ${TIMEOUT}s"
else
    echo "[${AGENT_NAME}] Session complete (exit: ${EXIT_CODE})"
fi
echo "[${AGENT_NAME}] Log: ${LOGFILE}"

# Clean up worktree (branch preserved for PR)
cd "$REPO_ROOT"
git worktree remove --force "$WORKTREE_DIR" 2>/dev/null || true
git worktree prune

echo "[${AGENT_NAME}] Worktree cleaned up. Done."
exit "${EXIT_CODE:-0}"
