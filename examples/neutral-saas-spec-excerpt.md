# Neutral SaaS Project — Spec Excerpt

This neutral excerpt demonstrates the level of specificity that helps agent generation, without requiring domain background.

---

## Overview

Build a web-based customer support workspace for small teams. The product helps teams triage inbound tickets, collaborate on responses, and track resolution quality.

**Core loop:**
1. Customer submits a ticket
2. System categorizes and prioritizes it
3. Agent drafts or sends a response
4. Team lead reviews escalations
5. Resolution metrics update dashboards

## Target Users

- **Support agents** — handle day-to-day ticket replies
- **Team leads** — manage escalations and SLA breaches
- **Operations managers** — monitor queue health and outcomes

## Tech Stack

- **Frontend:** Next.js, TypeScript, Tailwind
- **Backend:** FastAPI, Python 3.12
- **Database:** PostgreSQL
- **Auth:** OAuth (Google + Microsoft)
- **Infra:** Docker + managed cloud deployment

## Agents

| Agent | Role | Timeout | Model |
|-------|------|---------|-------|
| `frontend_agent` | Queue UI, ticket details, filters | 2400s | Sonnet |
| `backend_agent` | Ticket API, assignment rules, SLA logic | 2400s | Sonnet |
| `domain_agent` | Categorization and prioritization heuristics | 1800s | Sonnet |
| `infra_agent` | Docker, deployment, environment config | 1800s | Sonnet |
| `audit_agent` | Code quality and test coverage review | 1200s | Sonnet |
| `red_agent` | Security and abuse-path testing | 1800s | Opus |

## Orchestrator

Named **Navigator** — practical, risk-aware, and delivery-focused. Personality: curious, skeptical, and explicit about human approval gates.

## What makes this spec effective

- **Clear delivery scope** — one product loop with measurable outcomes
- **Distinct agent boundaries** — frontend/backend/domain/infra split is explicit
- **Decision boundaries** — escalation and SLA ownership are clearly assigned
- **Testable goals** — queue latency, SLA compliance, and resolution quality are measurable

## Phases

| Phase | Objective | Gate |
|-------|-----------|------|
| 1 | Foundations: auth, schema, ticket CRUD | Users can create and view tickets end-to-end |
| 2 | Operations: triage, assignment, SLA tracking | Priority and ownership flow works correctly |
| 3 | Collaboration: notes, escalations, review flow | Team lead can resolve escalations |
| 4 | Hardening: security review and regression checks | No critical findings; smoke tests pass |
