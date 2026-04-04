#!/usr/bin/env bash
# agentcook — Setup validation
# Verify deps, install hooks.
# Idempotent — safe to re-run.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

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

echo "=== agentcook — Setup ==="
echo ""

# ── Check required tools ───────────────────────────────────────────────────

echo "Checking dependencies..."
check_cmd "git"
check_cmd "claude"
check_cmd "shellcheck"

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

echo ""

# ── Check git identity ────────────────────────────────────────────────────

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

# ── Install pre-commit hooks ──────────────────────────────────────────────

echo ""
echo "Installing pre-commit hooks..."
if [ -f "${REPO_ROOT}/.pre-commit-config.yaml" ]; then
    if (cd "$REPO_ROOT" && uvx pre-commit install --install-hooks) 2>/dev/null; then
        echo "  [OK]      pre-commit hooks installed"
    else
        echo "  [WARN]    pre-commit install failed — hooks will not run"
    fi
else
    echo "  [INFO]    No .pre-commit-config.yaml — skipping"
fi

# ── Validate shell scripts ────────────────────────────────────────────────

echo ""
echo "Checking shell scripts..."
SHELL_FAIL=0
for f in $(find "$REPO_ROOT/archive/templates/scripts" -name '*.sh' 2>/dev/null); do
    if ! shellcheck -e SC1091,SC2034,SC2153,SC2016 "$f" >/dev/null 2>&1; then
        echo "  [WARN]    shellcheck issues in $(basename "$f")"
        SHELL_FAIL=1
    fi
done
if [ "$SHELL_FAIL" -eq 0 ]; then
    echo "  [OK]      All template scripts pass shellcheck"
fi

# ── Summary ────────────────────────────────────────────────────────────────

echo ""
echo "=== Setup Complete ==="
echo "  Passed: ${PASS}  Failed: ${FAIL}"
if [ "$FAIL" -gt 0 ]; then
    echo ""
    echo "Fix the items marked [MISSING] above, then re-run this script."
    exit 1
fi
echo "Ready to go."
