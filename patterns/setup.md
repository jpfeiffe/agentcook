# Setup — Security and Tooling

Every generated project gets security hooks and tooling configured. These are non-negotiable defaults.

---

## Pre-commit Hooks

Every project gets a `.pre-commit-config.yaml` with these hooks:

```yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v6.0.0
    hooks:
      - id: check-merge-conflict
      - id: check-added-large-files
        args: ['--maxkb=500']
      - id: detect-private-key
      - id: check-yaml
        args: ['--allow-multiple-documents']
      - id: check-json
      - id: end-of-file-fixer
      - id: trailing-whitespace
        args: ['--markdown-linebreak-ext=md']

  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.30.0
    hooks:
      - id: gitleaks

  - repo: https://github.com/koalaman/shellcheck-precommit
    rev: v0.11.0
    hooks:
      - id: shellcheck
        args: ['-e', 'SC1091,SC2034,SC2153,SC2016']
```

**What these catch:**
- Accidental merge conflict markers left in files
- Large binaries committed by accident (>500KB)
- Private keys committed by accident
- Malformed YAML/JSON
- Secrets and credentials (gitleaks)
- Common shell script bugs (shellcheck)

---

## Gitleaks Configuration

Every project gets a `.gitleaks.toml` with allowlists for known false positives:

```toml
title = "project gitleaks config"

[allowlist]
description = "Global allowlist"
regexes = ['''(?i)\{\{[A-Z_]+\}\}''']
paths = [
  '''\.env\..*\.example$''',
  '''gitleaks\.toml$''',
  '''CLAUDE\.md$''',
]
```

The `{{PLACEHOLDER}}` regex allowlist prevents template placeholders from triggering secret detection. Add project-specific paths as needed (e.g., test fixtures with fake tokens).

---

## uv Installation

`setup.sh` auto-installs `uv` if missing. uv is used for:
- Running `pre-commit` via `uvx pre-commit install --install-hooks`
- Python dependency management (if the project uses Python)

The install is non-destructive — it checks first, installs only if needed.

---

## Credential Helper

In GitHub mode, `setup.sh` configures git to use `gh` as a credential helper:

```bash
git config --global credential.helper "$(gh auth git-credential)"
```

This ensures agents can push to the repo without being prompted for credentials, using the same auth that `gh` has.

---

## Directory Structure

`setup.sh` creates these directories:
- `agent_logs/` — timestamped Claude session logs from all agents
- `worktrees/` — git worktrees (one per active agent, cleaned up after each session)

Both should be gitignored in the generated project.

---

## Git Init

For new projects, the setup process:
1. `git init`
2. Create `.gitignore` with: `agent_logs/`, `worktrees/`, `node_modules/`, `.env`, etc.
3. Copy `.pre-commit-config.yaml` and `.gitleaks.toml`
4. Install pre-commit hooks via `uvx pre-commit install --install-hooks`
5. Initial commit with all generated files
6. If GitHub mode: `gh repo create` or push to existing repo
