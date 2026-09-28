# quartel.ia — Student Platform

Modular, AI-native management platform for schools: from the first WhatsApp message of a
lead to enrollment, billing, classes, and student progress. Each module can be sold on its
own; together they form a complete system with a WhatsApp agent acting across all of them.

> Status: **Core module done** (schema, RLS, tests). Other modules in progress.
> All data in this repository is fictional.

## Naming

The quartel-ia Supabase project hosts two demos side by side. Every database object is
prefixed by demo: `e_` for educational (this repo) and `m_` for membership.

## Architecture

- **Multi-tenant Postgres (Supabase).** Every table carries `tenant_id`; isolation is
  enforced by Row Level Security, not by the application.
- **Modules gated in the database.** `e_tenant_modules` records what each school bought.
  Every non-core table's policy calls `app.e_module_enabled(tenant_id, '<module>')`, so a
  school without a module gets no rows even if the UI or the agent asks for them.
- **One person, many roles.** `e_people` exists independently of logins: a lead, a payer,
  a guardian and a student are the same record in different roles. Login (`e_user_roles`)
  is optional and only for portal users.
- **Cross-tenant references are impossible by construction.** Composite foreign keys
  `(tenant_id, person_id) → e_people(tenant_id, id)` guarantee a guardianship, role or
  future enrollment can never point to a person from another school — even from
  service-role code that bypasses RLS.

See [docs/module-map.md](docs/module-map.md) for modules, dependencies and packages.

## Core module

| Table | Purpose |
|---|---|
| `e_tenants` | schools |
| `e_tenant_modules` | purchased modules (written only by quartel.ia via service role) |
| `e_people` | every human the school deals with; unique phone per school (agent lookup) |
| `e_user_roles` | login ↔ person ↔ role (`admin`, `staff`, `teacher`, `student`, `guardian`) |
| `e_guardianships` | guardian ↔ student |
| `e_courses` | catalog shared by Capture, Finance and Academic |

### Access rules

| Role | People visible | Can write |
|---|---|---|
| admin | whole school | people, courses, guardianships, **roles** |
| staff | whole school | people, courses, guardianships |
| teacher | whole school | — |
| student | self | — |
| guardian | self + wards | — |
| anon | nothing | nothing |

### Design decisions & trade-offs

- **Helpers are `security definer` in a private `app` schema.** Policies on `e_user_roles`
  need to read `e_user_roles`; running the lookup as the function owner avoids infinite
  RLS recursion. `set search_path = ''` prevents a caller from shadowing tables. The
  `app` schema is not exposed through the Data API.
- **Only admins grant roles.** Staff can manage people but cannot escalate themselves.
- **Teachers see the whole school for now.** Narrowing to "students in my classes"
  depends on the Academic module and will be added there.
- **Money as integer cents** (upcoming modules) to avoid floating-point rounding.

## Running the tests

RLS is tested against plain Postgres with a small Supabase stand-in (`auth.uid()`,
roles, default grants) — no Docker required:

```bash
./scripts/test-local.sh
# migrate: 20260928000000_core.sql
# ALL CORE RLS TESTS PASSED
```

Covered: tenant isolation, per-role visibility, guardian → ward access, write
permissions, privilege escalation, cross-tenant FK guarantees, module entitlement,
anonymous access.

## Stack

Supabase (Postgres, Auth, RLS, Edge Functions) · WhatsApp Cloud API / provider TBD ·
LLM agent with tool calling · pgvector for the school knowledge base.

## Membership demo (`m_*`)

Generic subscription / membership business (base example: a club), Brazil (BRL; Pix,
boleto and card via Asaas). Lives in the same Supabase project with its own tables,
roles and helpers; the two demos never see each other's data.

- **Roles:** `admin`, `staff`, `attendant` (team) and `member` (portal).
- **Modules** (`m_tenant_modules`): capture, members, billing, health, portal, dashboard,
  tasks, agent. Plans and benefits are an ungated catalog.
- **Portal rules:** holders see their subscription, dependents and invoices; dependents see
  the subscription but not invoices; members never see each other, leads, tasks or CPF.
- **CPF** lives in `m_people_private`, readable only by admin and staff.
- **Plan capacity** (holder + dependents ≤ `max_people`) is enforced by a trigger.
- Connector and channel secrets never go in tables — use Supabase Vault.

Screen map: Claude Project doc `membership/mapa-de-telas.md`.
Tests: `tests/membership_rls.sql` (run by `scripts/test-local.sh`).
