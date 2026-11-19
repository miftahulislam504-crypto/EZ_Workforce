# EZ Workforce

All-in-one HR management and workforce operations platform for Android, iOS and
Web, built from a single Flutter codebase on top of Supabase.

> Empower Your Workforce. Accelerate Your Growth.

This repository is the **Phase 1 - Core HRM Foundation** delivery. The full
product plan has 31 sections across 5 phases; `docs/ROADMAP.md` maps every
section to the phase that delivers it.

## What Phase 1 includes

| Area | What you get |
| --- | --- |
| Organization | Self-service registration, 14 day trial, company profile (logo, contact, address, regional settings, employee ID prefix), plan and usage overview |
| Structure | Branches, departments (with head), designations, onboarding checklist template |
| Access | System roles (Owner, HR Admin, Branch Manager, Department Manager, Employee), custom roles, per-role permission matrix, data scope (organization, branch, department, own records) |
| Employees | Profile with employment details, sensitive tab (bank, ID numbers) with masking, documents, onboarding checklist, archive, invite codes, directory with search, filters, grid and list views, CSV export |
| Sign-in | E-mail and password, organization registration, invite-code join, password reset, activation screen, same app on mobile and web |
| Dashboards | Admin (headcount, joiners, distribution charts, attention list, activity), manager (team), employee (onboarding progress, notices, celebrations) |
| Communication | Notice board with audiences, scheduling, pinning, expiry, attachments, read receipts, acknowledgements, reach statistics |
| Notifications | In-app inbox, realtime delivery, unread badge, per-category preferences |
| Security | Row level security on every table, permission-checked RPCs, audit trail with field-level changes, masking of sensitive values |
| Experience | Responsive web sidebar and mobile bottom navigation, light and dark theme, skeleton loading, empty and error states |

## Tech stack

- Flutter (Dart 3.7+), Material 3 with a custom design system
- Riverpod for state, go_router for navigation
- Supabase: Postgres, Auth, Storage, Realtime
- fl_chart for charts

## Quick start

```bash
./setup.sh                 # generates android/ios/web folders, installs packages
```

Then follow [docs/SETUP.md](docs/SETUP.md) to create the Supabase project,
apply the migrations and run the app with your project keys.

## Repository layout

```
lib/
  core/        theme, shared widgets, utilities, routing
  data/        models, repositories, Riverpod providers
  features/    auth, dashboard, employees, notices, notifications,
               organization, access, audit, settings, shell
supabase/migrations/   9 ordered SQL files (schema, RLS, functions, storage)
tool/                  SQL test harness (runs the migrations in PGlite)
test/                  Flutter unit tests
docs/                  SETUP, ARCHITECTURE, ROADMAP
```

## Verification status

Please read this before you rely on the build.

- The SQL layer (schema, triggers, RLS, RPCs, storage policies) is checked by
  `tool/sql_smoke_test.mjs`, which applies all migrations to an in-memory
  Postgres and runs 95 assertions. Run it with `cd tool && npm install && npm test`.
- The Dart code was written without a Flutter SDK in the build environment.
  Every file was syntax-checked with `dart format`, and all relative imports
  were checked to resolve, but **`flutter analyze` and `flutter test` have not
  been run**. Expect to fix a small number of type or API mismatches on the
  first analyze. See the "First run checklist" in docs/SETUP.md.
