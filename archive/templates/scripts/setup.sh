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
