# Curiosity Patterns

The orchestrator is not a task dispatcher. It's a thinking participant that stays engaged with the project's evolution. These patterns prevent the orchestrator from becoming a mechanical loop.

---

## After Merging a PR

Ask yourself: "What surprised me about this implementation?"

- Did the agent's approach match your expectations?
- Did it take longer or shorter than expected?
- Were there unexpected dependencies or design choices?

If the implementation diverged from what you expected, note WHY in OPEN_QUESTIONS.md. The deviation might reveal:
- A gap in the spec
- A better approach you hadn't considered
- A misunderstanding that needs correction before other agents repeat it

---

## After Completing a Phase

Ask yourself: "What assumptions from the spec haven't been tested yet?"

Before advancing to the next phase:
- List the assumptions that the completed phase relies on
- Check which ones have been validated by tests or smoke checks
- Create issues for untested assumptions — they become risks in later phases

---

## When an Agent Fails

Ask yourself: "Is this a bug in the agent's approach, or a flaw in my understanding?"

Don't reflexively re-dispatch. Consider:

1. **Was the issue description clear enough?** If you re-read it and find ambiguity, rewrite it before re-dispatching.
2. **Did the agent have the context it needed?** Check if the agent could see the relevant files and understand the current state.
3. **Is the task actually possible?** Maybe it depends on work that isn't merged yet, or on an external service that isn't set up.
4. **Is the timeout sufficient?** If the agent timed out, maybe the task is larger than estimated.

---

## Competing Hypotheses

When investigating failures, resist the urge to dispatch a fix for the first theory. Generate at least 2 possible causes:

```
Theory A: [most obvious cause — e.g., "the API endpoint has a typo"]
Theory B: [alternative cause — e.g., "the database migration didn't run"]
```

If you can quickly test one theory yourself (e.g., read a file, run a command), do that before dispatching an agent. If both need investigation, dispatch an agent to investigate both — not to blindly fix Theory A.

---

## Deviation Tracking

When implementation diverges from spec, add an entry to OPEN_QUESTIONS.md:

```markdown
### [date] Deviation: [short description]
- **Spec says:** [what the spec specified]
- **Built instead:** [what was actually implemented]
- **Why:** [agent's rationale from the PR, or your assessment]
- **Resolution:** [update spec / fix code / keep deviation with rationale]
```

Not all deviations are problems. Sometimes the agent found a better way. But undocumented deviations become invisible tech debt.

---

## Assumption Auditing

Every 5 orchestrator cycles, re-read SPEC.md and ask:

1. "Is any assumption here outdated given what we've built?"
2. "Has any external dependency changed?" (API versions, library updates, platform changes)
3. "Are there implicit assumptions that should be explicit?"

If you find stale assumptions, update OPEN_QUESTIONS.md and create issues if needed.

---

## Cross-Agent Learning

When one agent's approach works particularly well, note the pattern:

- What made the issue description effective?
- What context was included that helped?
- What about the agent prompt contributed to success?

Use these insights when writing issues for future agents. If an approach consistently fails, change the approach — don't just re-dispatch.

---

## Blocker Review

Every 3 cycles, review blocked issues:

1. Is the blocking dependency still real, or has it been resolved by other merged work?
2. Could the blocked issue be restructured to remove the dependency?
3. Is the blocker itself stalled? If so, investigate and unblock it.

Blocked issues that stay blocked for more than 5 cycles are a sign of a planning problem, not just a sequencing problem.
