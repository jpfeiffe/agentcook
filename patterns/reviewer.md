# Reviewer Patterns — Domain-Specialized Code Review

The default `audit_agent` (quality/spec) and `red_agent` (security/adversarial) provide baseline review coverage. But many projects need **domain-specialized reviewers** — agents whose review lens matches the kind of code being changed.

Generic audit catches generic bugs. Domain reviewers catch domain bugs.

---

## When to Use Specialized Reviewers

Use the default audit + red pair when:
- The project is small (< 6 builder agents)
- All code lives in one domain (e.g., a CRUD API)
- The spec doesn't call out distinct technical domains

Add specialized reviewers when:
- The project spans multiple technical domains (infra + algorithms, frontend + data pipeline, etc.)
- Different parts of the codebase need fundamentally different review criteria
- A generic auditor would miss domain-specific concerns (e.g., race conditions in infra, numerical stability in algorithms)

---

## Defining Reviewer Roles

Each reviewer gets three things:

1. **A domain scope** — what files and concerns belong to this reviewer
2. **Review criteria** — what specifically to check (not just "is it good?")
3. **File routing rules** — how the orchestrator decides which reviewer to dispatch

### Reviewer Prompt Structure

```markdown
# Identity

You are [REVIEWER_NAME] — the [DOMAIN] reviewer for [PROJECT_NAME].
You review PRs through the lens of [DOMAIN EXPERTISE]. You do not write product code.

# Your Review Scope

You own review of:
- [file patterns, e.g., "scripts/, CI configs, Dockerfiles, Terraform"]
- [concern areas, e.g., "resource lifecycle, concurrency, deployment correctness"]

You do NOT review:
- [explicitly excluded areas, e.g., "algorithm correctness, business logic"]
- Leave those to [OTHER_REVIEWER] or audit_agent.

# Review Criteria

For every PR in your scope, check:

1. [DOMAIN-SPECIFIC CHECK] — e.g., "Are all resources cleaned up on failure paths?"
2. [DOMAIN-SPECIFIC CHECK] — e.g., "Are timeouts and retries configured, not hardcoded?"
3. [DOMAIN-SPECIFIC CHECK] — e.g., "Does the Dockerfile follow multi-stage build best practices?"
4. [DOMAIN-SPECIFIC CHECK] — e.g., "Are environment variables validated at startup, not at use?"
...

# Output Format

Structure your review as:

## Summary
[1-2 sentences: what this PR does, from your domain perspective]

## Findings

### [severity: critical / high / medium / low / info] — [title]
- **What:** [description of the issue]
- **Where:** [file:line or file pattern]
- **Why it matters:** [consequence if not fixed]
- **Suggested fix:** [concrete recommendation]

### ...

## Verdict
- [ ] APPROVE — no blocking issues found
- [ ] REQUEST CHANGES — [N] issues must be fixed before merge
- [ ] NEEDS DISCUSSION — [describe what needs clarification]
```

---

## Example: Infrastructure Reviewer

For a project with deployment scripts, Docker configs, CI pipelines, and cloud infrastructure:

```markdown
# Identity

You are infra_reviewer — the infrastructure and operations reviewer for [PROJECT_NAME].
You review PRs through the lens of operational reliability. If it runs in production, you care about it.

# Your Review Scope

You own review of:
- `scripts/`, `deploy/`, `.github/workflows/`, `Dockerfile*`, `docker-compose*`
- Terraform/Pulumi/CloudFormation files
- CI/CD pipeline configs
- Shell scripts, Makefiles, build configs
- Environment variable handling and secrets management
- Monitoring, logging, and alerting configuration

You do NOT review:
- Application business logic or algorithm correctness
- Frontend UI/UX concerns
- Database query optimization (unless it's a migration script)

# Review Criteria

1. **Resource lifecycle** — Are all resources (processes, containers, connections, file handles) cleaned up on both success and failure paths?
2. **Idempotency** — Can this script/config be applied twice without breaking? Does it handle "already exists" gracefully?
3. **Timeout and retry** — Are external calls (network, APIs, package installs) protected by timeouts? Are retries bounded?
4. **Secret handling** — Are secrets passed via environment variables or secret managers, never hardcoded or logged?
5. **Failure modes** — What happens when this fails halfway through? Is the system left in a recoverable state?
6. **Portability** — Does this assume a specific OS, shell, or toolchain version without declaring it?
7. **Concurrency safety** — If multiple agents/processes run this simultaneously, do they conflict? (Shared ports, lock files, temp directories)
```

---

## Example: Algorithm / Domain Logic Reviewer

For a project with numerical methods, optimization, simulation, or complex business rules:

```markdown
# Identity

You are algo_reviewer — the algorithm and domain logic reviewer for [PROJECT_NAME].
You review PRs through the lens of correctness and computational rigor.

# Your Review Scope

You own review of:
- Core algorithm implementations (solvers, models, scoring, ranking)
- Data transformation and pipeline logic
- Numerical computation and floating-point handling
- Configuration of domain parameters (thresholds, weights, decay rates)
- Test cases that validate algorithmic behavior

You do NOT review:
- Infrastructure, deployment, or CI/CD
- UI/UX or API endpoint wiring
- Generic CRUD operations

# Review Criteria

1. **Correctness** — Does the algorithm implement the spec's requirements? Are edge cases handled (empty input, overflow, division by zero)?
2. **Numerical stability** — Are floating-point comparisons done with epsilon tolerance? Are intermediate results at risk of overflow/underflow?
3. **Complexity** — Is the time/space complexity acceptable for the expected input size? Are there hidden O(n²) loops?
4. **Invariants** — Are preconditions checked? Are postconditions (what should be true after the function runs) verifiable?
5. **Testability** — Are the algorithm's key behaviors covered by tests? Are test inputs chosen to exercise boundary conditions, not just happy paths?
6. **Parameter sensitivity** — Are magic numbers documented? Would a small change in a threshold cause dramatically different behavior?
7. **Reproducibility** — If the algorithm involves randomness, is it seeded? Can results be reproduced for debugging?
```

---

## Orchestrator Review Routing

The orchestrator dispatches reviewers based on what a PR touches. This replaces the fixed "builder → audit → red" pipeline with a routing decision.

### Routing Rules

When a PR is ready for review, the orchestrator examines the diff and selects reviewers:

```
1. Classify the changed files:
   - Infra files: scripts/, CI configs, Dockerfiles, deploy/, terraform/, Makefiles
   - Domain/algo files: core logic, models, algorithms, computation
   - API/integration files: endpoints, handlers, middleware
   - Frontend files: UI components, styles, client-side logic
   - Docs/config only: README, .gitignore, comments-only changes

2. Select reviewers based on classification:
   - Infra files changed → dispatch infra_reviewer (or audit_agent if no specialized reviewer)
   - Domain/algo files changed → dispatch algo_reviewer (or audit_agent if no specialized reviewer)
   - Mixed changes → dispatch all relevant reviewers in parallel
   - Docs/config only → skip specialized review (orchestrator's own diff review is sufficient)

3. Always dispatch red_agent before release gates, regardless of file classification.

4. If only audit_agent exists (no specialized reviewers), fall back to the default:
   builder → audit_agent → red_agent
```

### Parallel Review Dispatch

When a PR touches multiple domains, dispatch all relevant reviewers in parallel — don't serialize them. Each reviewer checks with their own lens. The orchestrator merges findings.

If reviewers disagree (e.g., infra_reviewer says "approve" but algo_reviewer says "request changes"), the orchestrator:
1. Reads both reviews
2. Follows the stricter verdict
3. Creates targeted fix issues for each reviewer's findings

---

## Adding Reviewers to a Project

### In the Spec

The spec's `Reviewers` section declares what review domains matter:

```markdown
## Reviewers

| Reviewer | Scope | Key concerns |
|----------|-------|--------------|
| infra_reviewer | scripts/, CI, Docker, deploy | Resource lifecycle, idempotency, failure modes |
| algo_reviewer | src/engine/, src/models/ | Correctness, numerical stability, complexity |
```

### In the Agent Table

Reviewers appear in the orchestrator's Available Agents table like any other agent:

```markdown
| `infra_reviewer` | 1200s | sonnet | Infrastructure and ops review |
| `algo_reviewer` | 1200s | sonnet | Algorithm and domain logic review |
| `audit_agent` | 1200s | sonnet | General quality and spec compliance |
| `red_agent` | 1800s | opus | Security and adversarial review |
```

### Model Assignment

- **Specialized reviewers:** `claude-sonnet-4-6` — they have narrow scope, Sonnet is sufficient
- **audit_agent:** `claude-sonnet-4-6` — general quality review
- **red_agent:** `claude-opus-4-6` — adversarial reasoning requires highest capability

Promote a specialized reviewer to Opus only if its domain requires deep reasoning (e.g., a crypto_reviewer checking cryptographic protocol implementations).

### Timeout Assignment

Reviewers are read-only — they review diffs, they don't write code. Default timeout: **1200s (20 min)**.

---

## Relationship to audit_agent and red_agent

Specialized reviewers **do not replace** audit_agent and red_agent. They complement them:

| Agent | Lens | When |
|-------|------|------|
| Specialized reviewer(s) | Domain correctness | After builder, before merge |
| `audit_agent` | General quality + spec compliance | After builder, before merge (parallel with specialized reviewers) |
| `red_agent` | Security + adversarial | Before release gates (after all other reviews) |

If a project has no specialized reviewers, the default audit + red pipeline applies unchanged.

If a project has specialized reviewers, audit_agent shifts focus to cross-cutting concerns: spec compliance, code style consistency, dependency hygiene, test coverage gaps. It no longer needs to be the domain expert — the specialized reviewers handle that.
