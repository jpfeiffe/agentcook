# SPEC_TEMPLATE.md — How to write a spec for agentcook

`scaffold.sh` reads your spec to generate agent prompts and project configuration.
The richer your spec, the better the generated agents.

---

## Minimal spec (scaffold.sh will infer the rest)

```markdown
# MyProject

One paragraph describing what this project does and who it's for.

## Phases
- Phase 1: Core backend
- Phase 2: Frontend
- Phase 3: Launch

## Tech stack
- Node.js, TypeScript
- PostgreSQL
- React
```

---

## Full spec (recommended)

```markdown
# Project Name

## What it does
Describe the product clearly. What problem does it solve? Who uses it?

## Phases

### Phase 1: <name>
- What gets built in this phase
- What the gate is to move to Phase 2 (e.g. "audit clean, no Critical security findings")

### Phase 2: <name>
- ...

## Agents needed

List each agent role. scaffold.sh creates one prompt file per agent.

| Agent | Role | Timeout |
|-------|------|---------|
| schema_agent | Database schema + migrations | 1200s |
| api_agent | REST API endpoints | 1800s |
| frontend_agent | Web or mobile UI | 3600s |
| ... | ... | ... |

## Tech stack

- Language/runtime: ...
- Database: ...
- Queue/cache: ...
- Auth: ...
- Hosting: ...

## Key data models

Describe the main entities. Agents use this to stay consistent.

## API surface (optional)

List the main endpoints if you have them designed.

## What NOT to build (Phase 1 scope limits)

Explicitly list what is out of scope for Phase 1 to keep agents focused.

## Open questions

Things not yet decided. Agents will add to this list as they work.
```

---

## Tips

- Be specific about the tech stack. Agents default to what they know if unspecified.
- List agents explicitly. scaffold.sh can infer roles but explicit is better.
- Define phase gates. The orchestrator uses them to decide when to advance.
- Keep it in one file. Agents read `SPEC.md` on every run — long is fine.
