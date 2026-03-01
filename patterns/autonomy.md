# Graduated Autonomy Framework

Not every decision needs human approval. Not every decision should be made by an agent alone. This framework defines who decides what.

---

## The Autonomy Spectrum

| Decision Type | Autonomy Level | Action |
|---|---|---|
| Code within spec | Full autonomy | Agent decides, commits, opens PR |
| Architecture within a component | Decide + document | Agent decides, documents rationale in PR description |
| Cross-component interface changes | Propose + review | Agent proposes in PR, orchestrator evaluates impact |
| External dependencies or API choices | Orchestrator decides | Orchestrator evaluates, may create human gate |
| Spending / legal / release / data | Human decides | Always create human-labeled issue with consequence preview |

---

## Safe Defaults

These always apply, regardless of autonomy level:

- Agents commit to **feature branches**. Never push to main.
- PRs require **orchestrator review** before merge.
- State files (PROGRESS.md, OPEN_QUESTIONS.md) are **orchestrator-only**.
- The work queue (GitHub Issues or ISSUES.md) is **orchestrator-only**.

---

## Low-Risk (Agent Decides Freely)

No review overhead needed. These are internal, reversible, and don't affect other components:

- Code formatting and style choices
- Test structure and organization
- Internal variable and function naming
- Choice between standard library alternatives
- Comment and documentation wording
- Build script tweaks (within existing framework)

---

## Medium-Risk (Decide + Document)

Agent makes the call but explains it in the PR description. Orchestrator reviews the rationale, not just the code:

- Architectural patterns within a single component
- Dependency choices within spec constraints (e.g., choosing between two logging libraries)
- Error handling strategy within a service
- File organization within the agent's scope
- Performance optimization approaches
- Test coverage priorities

The PR description must include: **what was decided, why, and what alternatives were considered.**

---

## High-Risk (Create Human Gate)

These need human judgment because they have consequences beyond the codebase:

- Infrastructure spending commitments
- External API design that others will consume
- Data model changes affecting multiple components or external systems
- Security architecture decisions
- Choosing between architecturally different approaches with long-term implications
- Any decision that can't easily be reversed after deployment

See `@patterns/human-gates.md` for the issue template.

---

## Emergency Escalation

If an agent discovers a security vulnerability during normal work:

1. Create a `critical` + `human` labeled issue **immediately**
2. Include: what was found, severity assessment, recommended fix
3. Do not attempt to fix security issues silently — visibility matters more than speed
4. Do not continue dispatching other agents until the human has reviewed

If a smoke check reveals data corruption or loss:

1. Stop all agent dispatches
2. Document the state in PROGRESS.md
3. Create a `critical` + `human` labeled issue
4. Wait for human review before proceeding
