#!/bin/bash
# agentcook — scaffold.sh
#
# Reads a SPEC.md and generates a complete multi-agent project.
#
# Usage:
#   ./scaffold.sh <spec_file> <output_dir>            # GitHub mode (default)
#   ./scaffold.sh <spec_file> <output_dir> --local    # Local mode (no GitHub needed)
#
# Requirements (GitHub mode):
#   - claude CLI installed and authenticated
#   - gh CLI installed and authenticated
#   - git, jq
#
# Requirements (local mode):
#   - claude CLI installed and authenticated
#   - git
set -euo pipefail

SPEC_FILE="${1:?Usage: ./scaffold.sh <spec_file> <output_dir> [--local]}"
OUTPUT_DIR="${2:?Usage: ./scaffold.sh <spec_file> <output_dir> [--local]}"
MODE="github"
if [[ "${3:-}" == "--local" ]]; then
    MODE="local"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="${SCRIPT_DIR}/templates"

if [ ! -f "$SPEC_FILE" ]; then
    echo "Error: spec file not found: $SPEC_FILE"
    exit 1
fi

echo "=== agentcook scaffold ==="
echo "Spec:   $SPEC_FILE"
echo "Output: $OUTPUT_DIR"
echo "Mode:   $MODE"
echo ""

# ── Step 1: Parse the spec with Claude ────────────────────────────────────────

echo "Reading spec with Claude..."

SPEC_CONTENT="$(cat "$SPEC_FILE")"

PARSE_PROMPT="You are a project parser. Read this spec and output ONLY valid JSON with no other text.

Extract:
- project_name: short identifier (snake_case, e.g. fooapp)
- project_title: human-readable name
- tmux_session: short session name (lowercase, no spaces)
- github_repo: placeholder like 'org/project_name' (user fills this in)
- cycle_pause: seconds between orchestrator cycles (default 300)
- agents: array of { name, role, timeout_seconds, model }
  - Use 'claude-opus-4-6' only for orchestrator/security/adversarial roles
  - Use 'claude-sonnet-4-6' for everything else
  - Infer agents from the spec. Always include an orchestrator.

Output format:
{
  \"project_name\": \"fooapp\",
  \"project_title\": \"FooApp\",
  \"tmux_session\": \"fooapp\",
  \"github_repo\": \"your-org/fooapp\",
  \"cycle_pause\": 300,
  \"agents\": [
    { \"name\": \"orchestrator\", \"role\": \"Lead orchestrator\", \"timeout_seconds\": 1800, \"model\": \"claude-opus-4-6\" },
    { \"name\": \"schema_agent\", \"role\": \"Database schema\", \"timeout_seconds\": 1200, \"model\": \"claude-sonnet-4-6\" }
  ]
}

SPEC:
${SPEC_CONTENT}"

PARSED=$(env -u CLAUDECODE claude -p "$PARSE_PROMPT" --model claude-sonnet-4-6 2>/dev/null)

# Extract JSON (strip any surrounding text)
PARSED_JSON=$(echo "$PARSED" | python3 -c "
import sys, json, re
text = sys.stdin.read()
match = re.search(r'\{.*\}', text, re.DOTALL)
if match:
    obj = json.loads(match.group())
    print(json.dumps(obj))
else:
    sys.exit(1)
" 2>/dev/null) || {
    echo "Error: Claude did not return valid JSON. Check your spec file."
    exit 1
}

PROJECT_NAME=$(echo "$PARSED_JSON" | jq -r '.project_name')
PROJECT_TITLE=$(echo "$PARSED_JSON" | jq -r '.project_title')
TMUX_SESSION=$(echo "$PARSED_JSON"  | jq -r '.tmux_session')
GITHUB_REPO=$(echo "$PARSED_JSON"   | jq -r '.github_repo')
CYCLE_PAUSE=$(echo "$PARSED_JSON"   | jq -r '.cycle_pause')
PROJECT_NAME_UPPER=$(echo "$PROJECT_NAME" | tr '[:lower:]' '[:upper:]')

echo "  Project: $PROJECT_TITLE ($PROJECT_NAME)"
echo "  Session: $TMUX_SESSION"
echo "  Agents:  $(echo "$PARSED_JSON" | jq -r '[.agents[].name] | join(", ")')"
echo ""

# ── Step 2: Create output directory ───────────────────────────────────────────

mkdir -p "${OUTPUT_DIR}"/{scripts,agents,agent_logs,worktrees,db}

# ── Step 3: Copy and fill in scripts ──────────────────────────────────────────

echo "Generating scripts..."

QUEUE_SOURCE=$( [ "$MODE" = "github" ] && echo "GitHub Issues" || echo "\`ISSUES.md\`" )

fill_template() {
    local src="$1"
    local dst="$2"
    # Use Python for literal string replacement — avoids sed delimiter injection
    # when project names or other values contain special characters (|, /, &, \n, etc.)
    SCAFFOLD_PROJECT_TITLE="$PROJECT_TITLE" \
    SCAFFOLD_PROJECT_NAME_UPPER="$PROJECT_NAME_UPPER" \
    SCAFFOLD_TMUX_SESSION="$TMUX_SESSION" \
    SCAFFOLD_GITHUB_REPO="$GITHUB_REPO" \
    SCAFFOLD_CYCLE_PAUSE="$CYCLE_PAUSE" \
    SCAFFOLD_MODE="$MODE" \
    SCAFFOLD_QUEUE_SOURCE="$QUEUE_SOURCE" \
    python3 - "$src" "$dst" <<'PYEOF'
import sys, os
src, dst = sys.argv[1], sys.argv[2]
with open(src) as f:
    content = f.read()
for placeholder, envvar in [
    ('{{PROJECT_NAME}}',       'SCAFFOLD_PROJECT_TITLE'),
    ('{{PROJECT_NAME_UPPER}}', 'SCAFFOLD_PROJECT_NAME_UPPER'),
    ('{{TMUX_SESSION}}',       'SCAFFOLD_TMUX_SESSION'),
    ('{{GITHUB_REPO}}',        'SCAFFOLD_GITHUB_REPO'),
    ('{{CYCLE_PAUSE}}',        'SCAFFOLD_CYCLE_PAUSE'),
    ('{{MODE}}',               'SCAFFOLD_MODE'),
    ('{{QUEUE_SOURCE}}',       'SCAFFOLD_QUEUE_SOURCE'),
]:
    content = content.replace(placeholder, os.environ[envvar])
with open(dst, 'w') as f:
    f.write(content)
PYEOF
    chmod +x "$dst"
}

# Render conditional blocks {{#if GITHUB_MODE}} / {{#if LOCAL_MODE}} / {{/if}}
render_conditional() {
    local file="$1"
    python3 - "$file" "$MODE" <<'PYEOF'
import sys, re
path, mode = sys.argv[1], sys.argv[2]
with open(path) as f:
    content = f.read()
# Remove blocks that don't match current mode
if mode == "github":
    content = re.sub(r'\{\{#if LOCAL_MODE\}\}.*?\{\{/if\}\}\n?', '', content, flags=re.DOTALL)
    content = re.sub(r'\{\{#if GITHUB_MODE\}\}\n?', '', content)
    content = re.sub(r'\{\{/if\}\}\n?', '', content)
else:
    content = re.sub(r'\{\{#if GITHUB_MODE\}\}.*?\{\{/if\}\}\n?', '', content, flags=re.DOTALL)
    content = re.sub(r'\{\{#if LOCAL_MODE\}\}\n?', '', content)
    content = re.sub(r'\{\{/if\}\}\n?', '', content)
with open(path, 'w') as f:
    f.write(content)
PYEOF
}

fill_template "${TEMPLATES_DIR}/run.sh"                      "${OUTPUT_DIR}/run.sh"
fill_template "${TEMPLATES_DIR}/scripts/setup.sh"            "${OUTPUT_DIR}/scripts/setup.sh"
fill_template "${TEMPLATES_DIR}/scripts/run_orchestrator.sh" "${OUTPUT_DIR}/scripts/run_orchestrator.sh"
fill_template "${TEMPLATES_DIR}/scripts/run_agent.sh"        "${OUTPUT_DIR}/scripts/run_agent.sh"
fill_template "${TEMPLATES_DIR}/scripts/dispatch_agent.sh"   "${OUTPUT_DIR}/scripts/dispatch_agent.sh"

# In local mode, create ISSUES.md; in github mode it's not needed
if [ "$MODE" = "local" ]; then
    cp "${TEMPLATES_DIR}/ISSUES.md.tmpl" "${OUTPUT_DIR}/ISSUES.md"
fi

mkdir -p "${OUTPUT_DIR}/docs"

# ── Step 4: Generate orchestrator prompt ──────────────────────────────────────

echo "Generating orchestrator prompt..."

# Build agent table
AGENT_TABLE=$(echo "$PARSED_JSON" | jq -r '
  "| Agent | Timeout | Model | Role |\n|-------|---------|-------|------|\n" +
  ([.agents[] | "| `\(.name)` | \(.timeout_seconds)s | \(.model | split("-") | .[1]) | \(.role) |"] | join("\n"))
')

SCAFFOLD_PROJECT_TITLE="$PROJECT_TITLE" \
SCAFFOLD_PROJECT_NAME_UPPER="$PROJECT_NAME_UPPER" \
SCAFFOLD_TMUX_SESSION="$TMUX_SESSION" \
SCAFFOLD_AGENT_TABLE="$AGENT_TABLE" \
SCAFFOLD_MODE="$MODE" \
SCAFFOLD_QUEUE_SOURCE="$QUEUE_SOURCE" \
python3 - "${TEMPLATES_DIR}/agents/orchestrator.md" "${OUTPUT_DIR}/agents/orchestrator.md" <<'PYEOF'
import sys, os
src, dst = sys.argv[1], sys.argv[2]
with open(src) as f:
    content = f.read()
for placeholder, envvar in [
    ('{{PROJECT_NAME}}',       'SCAFFOLD_PROJECT_TITLE'),
    ('{{PROJECT_NAME_UPPER}}', 'SCAFFOLD_PROJECT_NAME_UPPER'),
    ('{{TMUX_SESSION}}',       'SCAFFOLD_TMUX_SESSION'),
    ('{{AGENT_TABLE}}',        'SCAFFOLD_AGENT_TABLE'),
    ('{{MODE}}',               'SCAFFOLD_MODE'),
    ('{{QUEUE_SOURCE}}',       'SCAFFOLD_QUEUE_SOURCE'),
]:
    content = content.replace(placeholder, os.environ[envvar])
with open(dst, 'w') as f:
    f.write(content)
PYEOF
render_conditional "${OUTPUT_DIR}/agents/orchestrator.md"

# ── Step 5: Generate per-agent prompts using Claude ───────────────────────────

echo "Generating agent prompts..."

echo "$PARSED_JSON" | jq -c '.agents[] | select(.name != "orchestrator")' | while read -r AGENT_JSON; do
    AGENT_NAME=$(echo "$AGENT_JSON" | jq -r '.name')
    AGENT_ROLE=$(echo "$AGENT_JSON" | jq -r '.role')

    echo "  Generating ${AGENT_NAME}.md..."

    AGENT_PROMPT="You are generating an agent prompt for a multi-agent system.

Project: ${PROJECT_TITLE}
Agent name: ${AGENT_NAME}
Agent role: ${AGENT_ROLE}

Here is the project spec:
${SPEC_CONTENT}

Write a concise agent prompt with these sections:
# Identity
# Your Mission
# What to Build  (detailed, specific to this agent's role)
# Dependencies   (libraries, services, shared types this agent needs)
# What NOT to Build  (scope boundary — what belongs to other agents)
# Success Criteria  (how to know the work is done)
# Files to Create   (exact file paths the agent should produce)

End with this exact block (do not change it):
# When Done

When your implementation is complete:

1. Verify your work compiles / passes basic checks.

2. Commit:
\`\`\`bash
git add -A
git commit -m \"feat(\${AGENT_NAME}): <description of what was built>\"
\`\`\`

3. Push and open a PR:
\`\`\`bash
git push origin \"\$(git branch --show-current)\"
gh pr create \\\\
  --title \"feat(\${AGENT_NAME}): <short description>\" \\\\
  --body \"Closes #\${ISSUE_NUMBER}

## Summary
- <what was built>

## Files
- <list>\" \\\\
  --base main
\`\`\`

4. Comment on your issue:
\`\`\`bash
gh issue comment \"\${ISSUE_NUMBER}\" \\\\
  --body \":white_check_mark: **Work complete**

**PR:** #<pr-number>
**What was built:**
- <bullet>

**Files created:**
- <list>\"
\`\`\`

Do not push to main directly. The orchestrator reviews and merges your PR.

Output only the agent prompt — no preamble, no explanation."

    env -u CLAUDECODE claude -p "$AGENT_PROMPT" --model claude-sonnet-4-6 2>/dev/null \
        > "${OUTPUT_DIR}/agents/${AGENT_NAME}.md" || {
        echo "  Warning: Claude failed for ${AGENT_NAME}, using template stub"
        cp "${TEMPLATES_DIR}/agents/agent.md.tmpl" "${OUTPUT_DIR}/agents/${AGENT_NAME}.md"
    }
done

# ── Step 6: Generate PROGRESS.md and OPEN_QUESTIONS.md ────────────────────────

echo "Generating state files..."

cat > "${OUTPUT_DIR}/PROGRESS.md" << EOF
# PROGRESS.md — ${PROJECT_TITLE} Status
**Only the orchestrator writes this file.**

---

## Current Phase

**Phase 1** — Not started

---

## Phase Status

| Phase | Status |
|-------|--------|
| Phase 1 | NOT STARTED |

---

## Component Status

| Component | Agent | Status | Notes |
|-----------|-------|--------|-------|
$(echo "$PARSED_JSON" | jq -r '.agents[] | select(.name != "orchestrator") | "| \(.role) | `\(.name)` | NOT STARTED | — |"')

---

## Last Updated

Initialized by scaffold.sh
EOF

cat > "${OUTPUT_DIR}/OPEN_QUESTIONS.md" << EOF
# OPEN_QUESTIONS.md — ${PROJECT_TITLE}
**Only the orchestrator writes this file.**

List unresolved design decisions here. Orchestrator makes a reasonable default and notes it.

---

*(none yet — add as they come up)*
EOF

# ── Step 7: Copy spec ──────────────────────────────────────────────────────────

cp "$SPEC_FILE" "${OUTPUT_DIR}/SPEC.md"

# ── Step 8: Generate CLAUDE.md ────────────────────────────────────────────────

cat > "${OUTPUT_DIR}/CLAUDE.md" << EOF
# CLAUDE.md — ${PROJECT_TITLE} Dev Guide

## Architecture

This project uses the agentcook multi-agent pattern:
- The **orchestrator** runs in a continuous loop (every ${CYCLE_PAUSE}s)
- **GitHub Issues** are the work queue — orchestrator creates, labels, and closes them
- Each agent runs in its own **tmux window** with an isolated **git worktree**
- Agents commit to feature branches and open PRs; orchestrator reviews and merges

## How to Run

\`\`\`bash
export GITHUB_REPO=${GITHUB_REPO}
./run.sh
\`\`\`

Attach to watch: \`tmux attach -t ${TMUX_SESSION}\`

## Agent Dispatch

\`\`\`bash
scripts/dispatch_agent.sh <agent_name> <timeout_seconds> <issue_number>
\`\`\`

## State Files

Only the orchestrator writes these:

| File | Purpose |
|------|---------|
| \`PROGRESS.md\` | Phase and component status |
| \`OPEN_QUESTIONS.md\` | Unresolved design decisions |
| GitHub Issues | Work queue |

## Notes for AI Assistants

- \`SPEC.md\` is the source of truth. If code contradicts the spec, fix the code.
- Check \`OPEN_QUESTIONS.md\` before implementing — the decision may not be made yet.
- Never push to main. Commit to your feature branch and open a PR.
EOF

# ── Step 9: Git init ───────────────────────────────────────────────────────────

echo ""
echo "Initializing git repo..."
cd "$OUTPUT_DIR"
git init -b main
git add .
git commit -m "chore: scaffold ${PROJECT_TITLE} — generated by agentcook"

echo ""
echo "=== Done ==="
echo ""
echo "Generated: ${OUTPUT_DIR}/"
echo "Mode:      ${MODE}"
echo ""
if [ "$MODE" = "github" ]; then
echo "Next steps:"
echo "  1. Set env vars:"
echo "       export GITHUB_REPO=${GITHUB_REPO}"
echo "       export GITHUB_TOKEN_${PROJECT_NAME_UPPER}=<your-github-token>"
echo "  2. Push to GitHub:  gh repo create ${GITHUB_REPO} && git push -u origin main"
echo "  3. Run:             cd ${OUTPUT_DIR} && nohup bash run.sh > /tmp/${TMUX_SESSION}.log 2>&1 &"
echo "  4. Watch:           tmux attach -t ${TMUX_SESSION}"
else
echo "Next steps (local mode — no GitHub needed):"
echo "  1. Run:  cd ${OUTPUT_DIR} && ./run.sh"
echo ""
echo "  The orchestrator will create ISSUES.md on first cycle and start dispatching agents."
echo "  All work stays local. Attach to watch: tmux attach -t ${TMUX_SESSION}"
fi
