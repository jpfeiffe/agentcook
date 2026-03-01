# Human-in-the-Loop Gates

When the orchestrator encounters a decision that requires human authorization, it creates a labeled issue (GitHub mode) or a `human`-status item (local mode). This document defines when to gate and how to format the request.

---

## When to Gate

### Always gate (human decides)

These decisions are irreversible, involve real money, or create external commitments:

- **Spending money** — provisioning cloud infrastructure, purchasing API keys with billing, paid services, domains, certificates
- **Publishing or releasing** — app store submissions, package registry publishing, production deployments, mainnet/testnet launches
- **Legal agreements** — signing contracts, choosing jurisdiction, licensing decisions, terms of service changes
- **PII and data decisions** — data retention policies, data sharing agreements, GDPR scope determinations, user data deletion policies

### Gate if unclear (orchestrator proposes, human confirms)

These decisions are hard to reverse and affect things outside the current codebase:

- External API design (once published and consumed by others, hard to change)
- Data model changes that affect multiple agents or external consumers
- Dependency choices with licensing implications (GPL contamination, etc.)
- Choosing between architecturally different approaches with long-term implications

### Never gate (orchestrator or agent decides)

These decisions are internal, reversible, and low-stakes:

- Internal code structure, patterns, and naming
- Test organization and coverage strategy
- Refactoring and code cleanup
- Internal documentation and comments
- Development tooling and local environment choices
- Build configuration and CI tweaks

---

## Issue Template — Consequence Preview

Every human-labeled issue must include a consequence preview. This lets the human make an informed decision quickly without needing to understand the full project state.

### GitHub Mode

```bash
gh issue create \
  --title "decision: [short description]" \
  --body "$(cat <<'GATE_EOF'
## Decision needed: [title]
**Category**: spending / release / legal / data

### Context
[Why this decision is needed now. What work is blocked. 2-3 sentences max.]

### If approved
1. [Immediate next agent action]
2. [Downstream consequence — what gets unblocked]
3. [Timeline: what happens next and roughly when]

### If rejected
1. [Alternative path the project will take]
2. [What gets delayed or dropped]
3. [Any permanent consequences of not doing this]

### Deadline
[When this blocks further progress. Which phase/issue is waiting on this decision.]
GATE_EOF
)" \
  --label "human"
```

### Local Mode

Add a row to `ISSUES.md` with status `human` and include the same consequence preview in the Notes column or as a separate section below the table.

---

## Timeout Escalation

Human gates can stall the project if the human doesn't respond. The orchestrator handles this:

**After 3 cycles with an unresolved human gate:**
1. Re-read the issue — is the ask still accurate given current project state?
2. Update the issue body with fresh context (things may have changed)
3. If the project has advanced past the need, close the gate with explanation

**After 5 cycles:**
1. Check if there's a non-gated alternative path that could make progress
2. If so, create work items for the alternative and note the tradeoff
3. Keep the human gate open but don't let it block everything

**Never do:**
- Silently proceed with a gated decision
- Close a human gate without explanation
- Create duplicate gates for the same decision
