# AEGIS — Spec Excerpt

This is a real excerpt from a complex trust/security domain project, showing the level of detail that produces excellent agent prompts.

---

## Overview

AEGIS is a five-layer protocol stack for agent identity, interaction, communication, trust, and policy. The core objective:

> **Make scaling dishonesty harder than scaling honesty.**
> Expected Cost of Sustained Abuse > Expected Value of Abuse

```
Layer 5 — Policy    Sentinel: sovereign policy engine per agent
Layer 4 — Trust     Flow control system (make dishonesty expensive)
Layer 3 — Comms     libp2p native + HTTP/SSE bridge for enterprise
Layer 2 — Receipts  Bilateral interaction records, batched on-chain
Layer 1 — Identity  Self-sovereign DID anchored on-chain (ERC-8004)
```

## Success Properties

AEGIS succeeds if and only if five properties hold simultaneously:

1. **Honest agents can compound trust predictably.** Good behavior accrues reputation through a known, stable curve.
2. **Malicious agents face increasing marginal cost for scaling abuse.** The second fake identity costs more than the first.
3. **Collusion requires capital, coordination, and time that exceed expected payoff.** Rings are possible. Profitable rings are not.
4. **There is no cheap, infinite trust mint.** No closed-loop vouching. No stake-free reputation farming.
5. **The system degrades gracefully under attack instead of catastrophically.** 5% attack ≠ 50% collapse.

## Agents

| Agent | Role | Timeout | Model |
|-------|------|---------|-------|
| `receipt_agent` | Receipt processing pipeline | 1800s | Sonnet |
| `decay_agent` | Decay model calibration | 1800s | Sonnet |
| `collusion_agent` | Anti-collusion mechanisms | 1800s | Sonnet |
| `sim_agent` | Adversarial simulation framework | 3600s | Sonnet |
| `econ_agent` | L1/L4 economic parameter calibration | 1800s | Sonnet |
| `audit_agent` | Code quality review | 1200s | Sonnet |
| `red_agent` | Adversarial attacker (tries to break L4) | 1800s | Opus |

## Orchestrator

Named **Vimes** — the watchman who watches the watchmen. Personality: watchful, skeptical. "You do not detect evil. You make dishonesty expensive."

## What makes this spec effective

- **Clear success criteria** — five testable properties, not vague goals
- **Domain-specific design constraints** — the Three Axes focus every decision
- **Simulation requirements** — parameters are not validated until they survive simulation
- **Red Agent is first-class** — not an afterthought, it's a core part of the development cycle

## Phases

| Phase | Objective | Gate |
|-------|-----------|------|
| 1 | Foundation: Sim + Receipt pipeline | Sim runs 6 attack types |
| 2 | Economics: Decay + L1 calibration | Honest agents reach Tier 2 in 30 days |
| 3 | Collusion: Graph diversity + vouching | 10-node ring < 30% of 10 honest agents |
| 4 | Red Team: Full adversarial review | All 8 attack classes fail |
| 5 | Hardening: Fix findings + regressions | Red Agent passes second run |
| 6 | Documentation: Specs + APIs | 100% coverage on public interfaces |
