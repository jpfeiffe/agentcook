# agentcook

Build multi-agent projects with Claude Code using opinionated orchestrator behavior, not just prompt templates.

---

## What it is

agentcook is a CLAUDE.md + reference patterns that teach Claude how to build multi-agent software systems from a specification. There's no CLI, no `pip install`, no runtime to maintain. You open Claude Code in this directory, describe what you want, and it builds it.

The real value isn't code generation — it's **encoded knowledge**: tmux+worktree architecture, orchestrator loop patterns, dispatch models, state file conventions, pre-commit security setup, and orchestrator personality traits (curiosity, skepticism, human-in-the-loop gates, graduated autonomy).

---

## Why this is different

Generated orchestrators aren't just task dispatchers. They include four behavioral layers that shape how work gets done:

**Curiosity** — After merging a PR: "What surprised me?" After completing a phase: "What assumptions haven't been tested?" When an agent fails: "Is this the agent's bug or my misunderstanding?"

**Skepticism** — Post-merge smoke checks are mandatory. Maker-checker pattern: audit_agent reviews, then red_agent attacks. "The agent said tests pass — let me verify."

**Human gates** — The orchestrator knows what decisions require a human: spending money, publishing releases, legal agreements, data handling. It creates labeled issues with consequence previews: "If approved: X happens. If rejected: Y instead."

**Graduated autonomy** — Code formatting? Agent decides. Architecture within a component? Agent decides + documents. External API design? Orchestrator evaluates. Infrastructure spending? Human decides. The right level of oversight for each decision type.

---

## Quickstart

```bash
cd /path/to/agentcook

# Option A: Point Claude at an existing SPEC.md
claude "Read my spec at ~/projects/myapp/SPEC.md and bootstrap a multi-agent project at ~/projects/myapp"

# Option B: Describe your project
claude "I want to build a multi-agent system for a recipe recommendation app. React Native frontend, Python backend, PostgreSQL. Create it at ~/projects/recipebot"

# Option C: Use the spec template
claude "Help me write a SPEC.md for my project, then generate it"
```

---

## What you get

A complete, runnable multi-agent project:

```
myapp/
├── run.sh                     # Start the orchestrator loop
├── scripts/
│   ├── setup.sh               # Dependency + env checker
│   ├── run_orchestrator.sh    # Single orchestrator cycle
│   ├── run_agent.sh           # Agent lifecycle: worktree → claude → PR
│   └── dispatch_agent.sh      # tmux window + timeout watchdog
├── agents/
│   ├── orchestrator.md        # Lead agent prompt (adapted to your domain)
│   └── <agent>.md             # One prompt per agent role
├── SPEC.md                    # Your specification (source of truth)
├── PROGRESS.md                # Phase tracker (orchestrator maintains)
├── OPEN_QUESTIONS.md          # Unresolved decisions
├── CLAUDE.md                  # Dev guide
├── .pre-commit-config.yaml    # Security hooks (gitleaks, shellcheck, etc.)
└── .gitleaks.toml             # Secret detection config
```

---

## How it works

```
GitHub Issues  ←  work queue (source of truth)
     │
HOST  (run.sh — while-true loop, sleep between cycles)
     │
     └── tmux session
           │
           ├── Orchestrator cycle (foreground — reviews, dispatches, merges)
           │
           ├── [window: agent_1]   feature branch → PR
           ├── [window: agent_2]   feature branch → PR
           └── ...
```

**Key properties:**
- The orchestrator is the only infinite loop — agents run once and exit
- GitHub Issues (or ISSUES.md) are the work queue — agents comment as they work
- Each agent gets an isolated git worktree — no merge conflicts
- Every agent has an external timeout — no hung sessions
- Pre-commit hooks catch secrets, merge conflicts, and shell bugs

---

## Writing a spec

See `SPEC_TEMPLATE.md` for the full format. At minimum:

```markdown
# Project Name

What you're building and who it's for.

## Phases
- Phase 1: Core functionality
- Phase 2: Polish and release

## Tech stack
- Language, framework, database

## Agents needed (optional — Claude can infer these)
- agent_one: what it does
- agent_two: what it does
```

The richer the spec, the better the generated agents. But a minimal spec works — Claude fills in the gaps.

---

## Modes

**GitHub mode** (default) — Uses GitHub Issues as the work queue, PRs as delivery. Requires `gh` CLI.

**Local mode** — Uses `ISSUES.md` as the work queue, local branches as delivery. No network needed.

---

## Requirements

- `claude` CLI installed and authenticated
- `git`, `tmux`
- `gh` CLI (GitHub mode only)
- That's it. No Python, no Node, no package manager.

---

## Examples

- `examples/neutral-saas-spec-excerpt.md` — neutral B2B SaaS example for first-time visitors
- `examples/fooapp/SPEC.md` — minimal task management app
- `examples/aegis-spec-excerpt.md` — real trust/security project excerpt
- `examples/bishopbuddy-spec-excerpt.md` — real consumer product excerpt

---

## Archive

The original template-based scaffolding tool is preserved in `archive/` for reference. The current approach (prompt-as-package) replaces it — Claude reads the patterns directly and adapts them per project, rather than filling in placeholder templates.
