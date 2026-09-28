# Module map

Each module depends only on **Core**. Links between modules are optional enrichment
(e.g. Finance works with manually registered students; with Enrollment active, billing
is created from the contract). This is what allows modules to be sold separately.

| # | Module | Owns | Depends on | What the agent does |
|---|---|---|---|---|
| 0 | Core (always included) | tenants, users, roles, people, course catalog | — | identifies who is talking |
| 1 | Capture & Enrollment | leads, activities, pipeline stages, enrollments, contracts | Core | qualifies leads, answers course/price questions, books trial class, sends enrollment link |
| 2 | Finance | plans, subscriptions, invoices, payment promises | Core (Enrollment optional) | duplicate invoice, due-date reminders, payment promises |
| 3 | Academic | classes, lessons, attendance, assessments, materials | Core | schedules, absence notices, sends materials |
| 4 | Student / teacher portal | none (view over other modules) | Academic | — |
| 5 | Performance (AI) | snapshots, risk alerts, progress reports | Academic (Finance enriches) | progress summaries to students/guardians; churn-risk alerts to managers |
| 6 | WhatsApp agent | conversations, messages, tool calls, knowledge base | Core; tools switch on per active module | alone: FAQ + human handoff; with modules: runs each module's actions |
| 7 | Management dashboard | none (aggregates active modules) | any module | answers the manager's questions |

## Packages
- **Starter:** Agent + Capture
- **Operations:** Finance + Academic
- **Complete:** everything, including Performance and Dashboard
