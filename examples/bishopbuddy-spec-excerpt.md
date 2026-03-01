# BishopBuddy — Spec Excerpt

This is a real excerpt from a consumer product domain project, showing how a product-focused spec drives agent generation.

---

## Overview

BishopBuddy is a mobile-first AI chess coaching application for novice and beginner chess players (unrated to ~1400). It bridges the gap between "you blundered" (what chess.com tells you) and "here's how to think differently" (what a real coach would say).

**Core loop:**
1. User plays on chess.com
2. BishopBuddy imports the game
3. Stockfish identifies critical moments (blunders, mistakes)
4. Claude explains those moments in plain language with actionable coaching
5. A persistent user profile tracks patterns over time so coaching improves

**The key insight:** Engine evaluation bars mean nothing to a beginner. Plain-language coaching with a thinking checklist does.

## Target Users

- **Primary: The Eager Beginner** — Unrated to 1200, plays 3-10 games/week, frustrated by engine analysis they can't interpret, cannot afford a human coach ($50-150/hr)
- **Secondary: The Returning Player** — Rating 800-1400, played years ago, has gaps in fundamentals

## Tech Stack

- **Mobile:** React Native + Expo, TypeScript
- **Backend:** Node.js 20, Azure Functions v4
- **Chess engine:** Stockfish 16+ (Docker on Azure)
- **Database:** Azure PostgreSQL Flexible Server v16
- **Auth:** Azure AD B2C or Auth0
- **LLM:** Anthropic Claude (primary), OpenAI GPT-4o (fallback)

## Agents

| Agent | Role | Timeout | Model |
|-------|------|---------|-------|
| `schema_agent` | PostgreSQL schema + migrations | 1200s | Sonnet |
| `import_agent` | Chess.com API + PGN parsing | 1800s | Sonnet |
| `stockfish_agent` | Stockfish container + analysis pipeline | 3600s | Sonnet |
| `coaching_agent` | LLM coaching engine | 1800s | Sonnet |
| `api_agent` | REST API endpoints | 1800s | Sonnet |
| `mobile_agent` | React Native app (all screens) | 3600s | Sonnet |
| `progress_agent` | Progress tracking + metrics | 1800s | Sonnet |
| `audit_agent` | Code quality review | 1200s | Sonnet |
| `red_agent` | Security review | 1800s | Opus |

## Orchestrator

Named **Bishop** — strategic, planning ahead. Personality: methodical, chess-aware.

## What makes this spec effective

- **Clear user persona** — not "everyone", but a specific player type with specific frustrations
- **Concrete tech stack** — agents know exactly what to build with
- **Well-scoped agents** — each agent owns a distinct service boundary
- **Third-party API constraints documented** — chess.com rate limits, public API only, no webhooks
- **Performance targets** — analysis pipeline has specific latency and throughput requirements

## Phases

| Phase | Objective | Gate |
|-------|-----------|------|
| 1 | Foundation: Schema + Import + Analysis | Games import and analyze correctly |
| 2 | Coaching: LLM integration + coaching cards | Coaching cards generate for blunders |
| 3 | Mobile: React Native app | All screens functional |
| 4 | Polish: Progress tracking + UX refinement | End-to-end flow works |
| 5 | Security: Audit + Red Team | No critical findings |
| 6 | Launch prep: Infrastructure + monitoring | Ready for TestFlight |
