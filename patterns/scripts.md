# Runtime Scripts — Reference Implementations

These scripts are battle-tested across multiple production projects (AEGIS, BishopBuddy). They handle edge cases that are easy to miss: SIGTTIN from nested Claude sessions, worktree cleanup after crashes, remote branch resume, shell injection prevention, and timeout watchdogs.

**Do not rewrite these from scratch.** Copy them into the generated project and adapt only what's necessary: session name, prompt path, model defaults, project-specific env vars.

---

## 1. `run.sh` — Orchestrator Loop

The main entry point. Runs the orchestrator in a while-true loop. Each iteration ensures the tmux session exists, runs one orchestrator cycle, then sleeps.

**Adapt:** `PROJECT_NAME`, `TMUX_SESSION`, `MODE`, `GITHUB_REPO`

```bash
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
```

**Why nohup?** When launched from inside a Claude Code session, the process can receive SIGTTIN when the parent terminal loses foreground control. `nohup` prevents this.

**Why `env -u CLAUDECODE`?** Nested Claude sessions inherit `CLAUDECODE` env var from the parent, which causes conflicts. Unsetting it ensures clean sessions.

---

## 2. `scripts/setup.sh` — Dependency Validation

Checks that all required tools and environment variables are present. Auto-installs `uv`. Installs pre-commit hooks.

**Adapt:** `PROJECT_NAME`, `MODE`, `PROJECT_NAME_UPPER` (for env var naming)

```bash
#!/bin/bash
# {{PROJECT_NAME}} — Setup validation
# Checks that all required tools and environment variables are present.
set -euo pipefail

MODE="${MODE:-{{MODE}}}"

echo "=== {{PROJECT_NAME}} Setup (mode: ${MODE}) ==="
echo ""

PASS=0
FAIL=0

check_cmd() {
    local name="$1"
    local cmd="${2:-$1}"
    if command -v "$cmd" &>/dev/null; then
        echo "  [OK]      $name ($(command -v "$cmd"))"
        PASS=$((PASS + 1))
    else
        echo "  [MISSING] $name — install it and retry"
        FAIL=$((FAIL + 1))
    fi
}

check_env() {
    local name="$1"
    local required="${2:-true}"
    if [ -n "${!name:-}" ]; then
        echo "  [OK]      $name is set"
        PASS=$((PASS + 1))
    elif [ "$required" = "false" ]; then
        echo "  [INFO]    $name not set — optional"
    else
        echo "  [MISSING] $name — set this environment variable"
        FAIL=$((FAIL + 1))
    fi
}

echo "Checking dependencies..."
check_cmd "git"
check_cmd "tmux"
check_cmd "claude"
if [ "$MODE" = "github" ]; then
    check_cmd "gh"
    check_cmd "jq"
    check_cmd "curl"
fi

echo ""
echo "Checking uv..."
if command -v uv &>/dev/null; then
    echo "  [OK]      uv ($(command -v uv))"
    PASS=$((PASS + 1))
else
    echo "  [INSTALL] uv — installing..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
    if command -v uv &>/dev/null; then
        echo "  [OK]      uv installed ($(command -v uv))"
        PASS=$((PASS + 1))
    else
        echo "  [MISSING] uv — install manually: curl -LsSf https://astral.sh/uv/install.sh | sh"
        FAIL=$((FAIL + 1))
    fi
fi

if [ "$MODE" = "github" ]; then
    echo ""
    echo "Checking environment..."
    check_env "GITHUB_REPO"
    check_env "GITHUB_TOKEN_{{PROJECT_NAME_UPPER}}"
fi

echo ""
echo "Checking git config..."
GIT_NAME=$(git config user.name 2>/dev/null || echo "")
GIT_EMAIL=$(git config user.email 2>/dev/null || echo "")
if [ -n "$GIT_NAME" ] && [ -n "$GIT_EMAIL" ]; then
    echo "  [OK]      git identity configured"
    PASS=$((PASS + 1))
else
    echo "  [MISSING] git user.name / user.email — run: git config --global user.name 'Name' && git config --global user.email 'email'"
    FAIL=$((FAIL + 1))
fi

if [ "$MODE" = "github" ]; then
    echo ""
    echo "Checking gh auth..."
    if gh auth status &>/dev/null; then
        echo "  [OK]      gh is authenticated"
        PASS=$((PASS + 1))
        git config --global credential.helper "$(gh auth git-credential)" 2>/dev/null || true
    else
        echo "  [MISSING] gh not authenticated — run: gh auth login"
        FAIL=$((FAIL + 1))
    fi
fi

echo ""
echo "Setting up directories..."
mkdir -p agent_logs worktrees
echo "  [OK]      agent_logs/"
echo "  [OK]      worktrees/"

echo ""
echo "Installing pre-commit hooks..."
REPO_ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel 2>/dev/null || pwd)"
if [ -f "${REPO_ROOT}/.pre-commit-config.yaml" ]; then
    if (cd "$REPO_ROOT" && uvx pre-commit install --install-hooks) 2>/dev/null; then
        echo "  [OK]      pre-commit hooks installed"
    else
        echo "  [WARN]    pre-commit install failed — hooks will not run"
    fi
else
    echo "  [INFO]    No .pre-commit-config.yaml — skipping"
fi

echo ""
echo "=== Setup Complete ==="
echo "  Passed: $PASS  Failed: $FAIL"
if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
echo "Ready to run: ./run.sh"
```

---

## 3. `scripts/run_orchestrator.sh` — Single Orchestrator Cycle

Sets up a persistent worktree on main, runs one Claude session with the orchestrator prompt, pushes state files, exits. The outer loop (`run.sh`) calls this repeatedly.

**Adapt:** `PROJECT_NAME`, orchestrator prompt path (`agents/orchestrator.md` or project-specific like `agents/vimes.md`)

```bash
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
# Ensure child Claude runs independently (no inherited Claude Code session state)
unset CLAUDECODE CLAUDE_CODE_SSE_PORT CLAUDE_CODE_ENTRYPOINT CLAUDE_CODE_SESSION_ACCESS_TOKEN 2>/dev/null || true
timeout --foreground --signal=TERM --kill-after=30 "${SESSION_TIMEOUT}" \
    claude --dangerously-skip-permissions \
           -p "$(cat "${REPO_ROOT}/agents/orchestrator.md")" \
           --model "$ORCHESTRATOR_MODEL" \
           --output-format stream-json \
           --verbose \
           --include-partial-messages \
           </dev/null \
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
```

**Why `resolve_repo_root()`?** When scripts run from inside a worktree, `git rev-parse --show-toplevel` returns the worktree root, not the main repo. This function follows `--git-common-dir` to find the real root.

**Why `</dev/null`?** Prevents Claude from waiting for stdin, which would cause it to hang in the non-interactive tmux environment.

**Why `--include-partial-messages`?** Ensures the log file captures incremental output, not just the final result.

---

## 4. `scripts/run_agent.sh` — Agent Lifecycle

Creates a git worktree on a feature branch, runs one Claude session with the agent's prompt, then cleans up. Claude commits, pushes, and opens a PR from inside the session.

**Adapt:** `PROJECT_NAME`, `PROJECT_NAME_UPPER`, `GITHUB_REPO`, model selection cases (add project-specific "senior" agents to the Opus list)

```bash
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

# Validate inputs to prevent path traversal and shell injection
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

# Alias project-specific GitHub token so gh/git use the right credentials
export GITHUB_TOKEN="${GITHUB_TOKEN_{{PROJECT_NAME_UPPER}}:-}"

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
           </dev/null \
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
```

**Key edge cases this handles:**
- **Shell injection prevention:** Agent name is validated against `^[a-z_][a-z0-9_]*$`. Timeout and issue number are validated as integers. These flow into `tmux` and `git` commands — untrusted input is dangerous.
- **Remote branch resume:** If a previous agent run was interrupted, the remote branch may already exist. The script detects this and resumes from it instead of creating a conflicting branch.
- **Stale worktree cleanup:** If a previous run crashed without cleaning up, the worktree directory exists but may be in a broken state. The script removes it before creating a fresh one.
- **Per-project GitHub tokens:** Uses `GITHUB_TOKEN_{{PROJECT_NAME_UPPER}}` to support multiple projects with different repos on the same machine.

---

## 5. `scripts/dispatch_agent.sh` — tmux Window Dispatch

Creates a tmux window in the project session, runs `run_agent.sh` inside it, and starts a background watchdog that kills the window if it exceeds the timeout.

**Adapt:** `PROJECT_NAME`, `TMUX_SESSION`

```bash
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
```

**Why two timeouts?** `run_agent.sh` uses `timeout` to kill the Claude process after N seconds. But if the shell around it hangs (e.g., git cleanup), the tmux window stays open forever. The dispatch watchdog is a safety net that kills the entire window after timeout+60s.

**Why `printf '%q'`?** Properly escapes arguments for the tmux command string. Without this, agent names or extra prompts containing special characters would break the tmux command.

**Why check for existing window?** The orchestrator might accidentally dispatch the same agent twice in one cycle. The double-dispatch check prevents this from causing conflicts (two worktrees on the same branch).

---

## Adaptation Checklist

When generating scripts for a new project, replace these placeholders:

| Placeholder | Example | Where |
|---|---|---|
| `{{PROJECT_NAME}}` | `AEGIS`, `BishopBuddy` | All scripts |
| `{{PROJECT_NAME_UPPER}}` | `AEGIS`, `BISHOPBUDDY` | setup.sh, run_agent.sh (env var naming) |
| `{{TMUX_SESSION}}` | `aegis`, `bishopbuddy` | run.sh, dispatch_agent.sh |
| `{{MODE}}` | `github`, `local` | run.sh, setup.sh |
| `{{GITHUB_REPO}}` | `Org/Repo` | run.sh, run_agent.sh |
| Orchestrator prompt path | `agents/vimes.md` | run_orchestrator.sh |
| Model selection cases | Add project-specific Opus agents | run_agent.sh |
