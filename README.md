# agentcook

Cookie cutter for multi-agent Claude systems.

Give it a spec. Get a running agentic project.

---

## What it does

`scaffold.sh` reads your `SPEC.md` and generates a complete multi-agent system:

- An **orchestrator loop** that runs continuously, reviews work, and dispatches agents
- **Agent prompt files** — one per role, tailored to your project
- **Lifecycle scripts** — worktree management, tmux dispatch, timeout watchdogs
- **GitHub Issues integration** — issues as the work queue; agents comment as they work
- A **`run.sh`** you can execute immediately

The generated system is stateless between cycles. GitHub is the memory.

---

## Quickstart

```bash
# 1. Write your spec
vim SPEC.md

# 2. Generate the project
./scaffold.sh SPEC.md ./my-project

# 3. Go
cd my-project
./run.sh
```

---

## What you get

```
my-project/
├── run.sh                     # Start the orchestrator (run this)
├── scripts/
│   ├── setup.sh               # Dependency + env checker
│   ├── run_orchestrator.sh    # Single orchestrator cycle
│   ├── run_agent.sh           # Agent lifecycle: worktree → claude → PR → comment
│   └── dispatch_agent.sh      # tmux window + timeout watchdog
├── agents/
│   ├── orchestrator.md        # Lead agent prompt (Opus)
│   └── <agent>.md             # One prompt file per agent role (Sonnet)
├── SPEC.md                    # Your spec (source of truth — copy from input)
├── PROGRESS.md                # Phase status (orchestrator writes this)
├── OPEN_QUESTIONS.md          # Unresolved decisions (orchestrator writes this)
└── CLAUDE.md                  # Dev guide for the project
```

---

## How it works

```
GitHub Issues  ←  work queue (source of truth)
     │
HOST  (run.sh — while-true loop, sleep N seconds between cycles)
     │
     └── tmux session "<project>"
           │
           ├── Orchestrator cycle (foreground)
           │     Pulls latest → reviews PRs → dispatches agents → exits
           │
           ├── [window: agent_1]   worktrees/agent_1/   feature branch → PR
           ├── [window: agent_2]   worktrees/agent_2/   feature branch → PR
           └── ...
```

**Key properties:**
- The orchestrator is the only infinite loop
- Agents are stateless — run once, commit, open a PR, exit
- GitHub Issues track all work — agents comment at start and finish
- Each agent gets an isolated git worktree — no conflicts
- Every agent has an external timeout — no hung sessions

---

## Requirements

- `claude` CLI installed and authenticated
- `gh` CLI installed and authenticated
- `tmux`, `git`, `jq`, `curl`
- A GitHub repo for your project

---

## SPEC.md format

See `SPEC_TEMPLATE.md` for the full format. At minimum:

```markdown
# Project Name

One-paragraph description of what you're building.

## Phases
- Phase 1: ...
- Phase 2: ...

## Agents needed
- agent_one: what it does
- agent_two: what it does

## Tech stack
- ...
```

`scaffold.sh` passes this to Claude to generate tailored agent prompts and configuration.

---

## Examples

See `examples/fooapp/` for a worked example — a simple fictional project showing
the full generated structure.
