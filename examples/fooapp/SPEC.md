# FooApp

A simple task management web app. Users create accounts, add tasks, and mark them complete.
This is a minimal fictional example to illustrate the agentcook scaffold structure.

---

## Phases

### Phase 1: Core (MVP)
- User registration and login (JWT auth)
- Create, read, update, delete tasks
- REST API + basic web UI
- **Gate:** Audit clean, no Critical security findings

### Phase 2: Polish
- Task categories and due dates
- Email reminders
- **Gate:** All Phase 1 issues closed

---

## Agents

| Agent | Role | Timeout |
|-------|------|---------|
| `schema_agent` | PostgreSQL schema + migrations | 1200s |
| `api_agent` | REST API endpoints + JWT auth | 1800s |
| `ui_agent` | HTML/CSS/JS frontend | 1800s |
| `audit_agent` | Read-only code quality review | 1200s |

---

## Tech stack

- **Backend:** Node.js 20, TypeScript, Express
- **Database:** PostgreSQL 16
- **Frontend:** Vanilla HTML/CSS/JS (no framework — keep it simple)
- **Auth:** JWT (HS256, signed with `JWT_SECRET` env var)

---

## Data model

```
users
  id          UUID PRIMARY KEY
  email       TEXT UNIQUE NOT NULL
  password_hash TEXT NOT NULL
  created_at  TIMESTAMPTZ DEFAULT now()

tasks
  id          UUID PRIMARY KEY
  user_id     UUID REFERENCES users(id) ON DELETE CASCADE
  title       TEXT NOT NULL
  done        BOOLEAN DEFAULT false
  created_at  TIMESTAMPTZ DEFAULT now()
```

---

## API surface

```
POST   /auth/register   { email, password } → { token }
POST   /auth/login      { email, password } → { token }

GET    /tasks           → [{ id, title, done, created_at }]
POST   /tasks           { title } → { id, title, done }
PATCH  /tasks/:id       { done } → { id, title, done }
DELETE /tasks/:id       → 204
```

All `/tasks` endpoints require `Authorization: Bearer <token>`.

---

## Out of scope (Phase 1)

- Email verification
- Password reset
- Task sharing between users
- Mobile app
