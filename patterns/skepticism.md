# Skepticism Patterns

The orchestrator maintains healthy skepticism about agent results without becoming a bottleneck. The goal is verification, not distrust.

---

## Result Validation

"The agent said tests pass. Let me verify."

After an agent reports success, the orchestrator independently verifies:

1. **Run the tests** — post-merge smoke check, every time, no exceptions
2. **Check the diff matches the issue** — does the PR actually address what was asked?
3. **Look for omissions** — new dependencies added? Interfaces changed? Tests deleted? Files the agent didn't mention?

The agent's self-report is a starting point, not a conclusion.

---

## Maker-Checker

Every implementation gets reviewers with different lenses. This is not redundant — it's defense in depth.

### Review Routing

When a PR is ready for review, select reviewers based on what changed:

1. **Classify the changed files** by examining the diff:
   - Infra/ops files (scripts/, CI, Dockerfiles, deploy/, terraform/) → `infra_reviewer`
   - Algorithm/model code (core logic, computation, domain models) → `algo_reviewer`
   - Mixed changes → dispatch all relevant reviewers in parallel
   - Docs/config only → skip specialized review (orchestrator's own diff review is sufficient)

2. **Fall back gracefully:** If no specialized reviewer exists for a domain, route to `audit_agent`.

3. **Always dispatch `red_agent`** before release gates, regardless of file classification.

### Default Pipeline (no specialized reviewers)

If the project defines only `audit_agent` and `red_agent`:

| Phase | Builder | First Reviewer | Second Reviewer |
|-------|---------|---------------|-----------------|
| Implementation | Builder agent | audit_agent (quality + spec compliance) | — |
| Pre-release | — | audit_agent | red_agent (security + adversarial) |

### Specialized Pipeline (project defines domain reviewers)

If the project defines domain-specific reviewers (see `@patterns/reviewer.md`):

| Phase | Builder | Domain Reviewers | General Review | Security |
|-------|---------|-----------------|----------------|----------|
| Implementation | Builder agent | Route by file type (parallel) | audit_agent (cross-cutting) | — |
| Pre-release | — | — | — | red_agent (adversarial) |

When reviewers disagree, follow the stricter verdict. Create targeted fix issues per reviewer.

### Reviewer Lenses

Each reviewer asks a different question:

- **Domain reviewers** ask: "Is this correct for this domain?" (infra: reliable? algo: numerically sound?)
- **audit_agent** asks: "Is this complete, spec-compliant, and well-structured?"
- **red_agent** asks: "How can I break this?"

Different questions, same code. All are necessary.

---

## Post-Merge Smoke Check

After merging one or more PRs, pull main and verify the code works. This is mandatory.

Determine the right commands by examining the repo:

| If you find... | Run... |
|----------------|--------|
| `package.json` with a `"test"` script | `npm install --prefer-offline && timeout 120 npm test` |
| `Cargo.toml` | `cargo test` |
| `pyproject.toml` or `requirements.txt` | `pip install -e . && pytest` |
| `Makefile` with a `test` target | `make test` |
| `go.mod` | `go test ./...` |

Time budget: 120 seconds. If nothing applies yet (e.g., first PR is just schema), skip.

- **Pass** → note in PROGRESS.md: `Smoke: PASS (date)`
- **Fail** → check for existing issue before creating duplicate, create fix issue, note in PROGRESS.md: `Smoke: FAIL (date) — issue #N`

Diff-reviewed code is not validated code.

---

## Red Agent Protocol

The red agent is dispatched after audit, before any release gate. Non-negotiable.

- **Model:** Always Opus — adversarial reasoning requires highest capability
- **Instruction:** "Break this. Find the cheapest attack that violates the spec or security requirements. Report: attack vector, cost, steps, expected payoff."
- **If red agent succeeds:** that finding becomes the highest priority. Create a `critical` or `high` issue.
- **If red agent fails:** document the attack attempt in `docs/ATTACKS.md` and move on.

Never skip the red agent review. Never let schedule pressure override this.

---

## Graduated Severity Response

Not all findings are equal. The orchestrator responds proportionally:

| Severity | Action | Blocks? |
|----------|--------|---------|
| **Info** | Note in PROGRESS.md | No |
| **Warning** | Create a follow-up issue, label `low` | No |
| **Error** | Create a fix issue, label `high`. Fix before continuing phase. | Current phase |
| **Critical** | Create a fix issue, label `critical` + `human`. Block everything. | All work |

---

## Self-Check

Before merging any PR, the orchestrator asks:

1. "Am I confident this PR does what the issue asked?"
2. "Did I review the diff, or just the description?"
3. "Are there changes outside the expected scope?"

If the answer to #1 is no, identify what would build confidence and request it.

---

## Anti-Patterns

These are common traps that slow the project without improving quality:

- **Cynicism is not skepticism.** If tests pass and the diff addresses the issue, merge it. Don't invent reasons to reject.
- **Don't re-dispatch for cosmetics.** If the code works but naming could be better, comment on the PR. Don't reject and re-dispatch.
- **Don't block a phase for one edge case.** If 95% of acceptance criteria are met and the remaining 5% is a genuine edge case, create a follow-up issue and advance.
- **Don't duplicate reviewer effort.** If audit_agent found an issue, red_agent doesn't need to find the same thing. They have different mandates.
- **Don't verify what's already verified.** If pre-commit hooks check formatting, the orchestrator doesn't need to check formatting.
