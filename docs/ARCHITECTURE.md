# Architecture

## Principles

1. **One codebase, three platforms.** Flutter renders the web workspace and the
   Android and iOS apps. The layout adapts: a sidebar on wide screens, a bottom
   navigation bar on phones.
2. **The database enforces the rules.** Permissions, data scope and integrity
   live in Postgres (RLS, triggers, RPCs). The app hides what a person cannot
   use, but never relies on hiding for security.
3. **Multi-tenant from the first table.** Every business row carries
   `organization_id`; RLS isolates organizations from each other.
4. **Auditable.** Row changes are written to `audit_logs` by triggers, so the
   trail cannot be skipped by a client.
5. **Configurable.** Roles, permissions, onboarding checklist, date format,
   currency and ID prefix are data, not code.

## Layers

```
UI (features/*)           screens and feature widgets
  |  reads/writes via
Providers (data/providers.dart)     Riverpod: auth, app context, lookups
  |
Repositories (data/repositories)    one class per area, thin over Supabase
  |
Supabase (Postgres + Auth + Storage + Realtime)
```

- `lib/core` has no knowledge of Supabase: theme, widgets, formatters,
  validators, router.
- `lib/data/models` are plain immutable classes with `fromJson`.
- Repositories return models and throw `PostgrestException`; the UI turns those
  into messages with `friendlyError`.
- Screens never talk to Supabase directly.

## Navigation and access

`go_router` with a `ShellRoute` for the signed-in area. The redirect logic
sends signed-out users to sign-in, users without an employee record to the
activation screen, and everyone else to the dashboard. Navigation items declare
the permissions they need (`core/router/nav_items.dart`); a route guard uses the
same list so a typed URL cannot open a page the person is not allowed to see.

## Access model

- **Permissions** are rows in `permissions` (code, module, label). The app
  mirrors the codes in `data/models/permissions.dart`.
- **Roles** group permissions. Five system roles are seeded per organization:
  Owner (all permissions, cannot be restricted), HR Admin, Branch Manager,
  Department Manager and Employee (default for new people). Custom roles can be
  created and edited in **Roles & Permissions**.
- **Data scope** is a property of the role: `organization`, `branch`,
  `department` or `self`. Helper functions (`in_scope`, `employee_in_scope`)
  apply it inside RLS policies.
- SECURITY DEFINER helpers (`auth_org_id`, `has_permission`, `auth_data_scope`)
  read the caller's context once per statement and are the only place that
  logic lives.
- Guard triggers protect the rules RLS cannot express: the Owner role cannot be
  renamed, restricted or deleted; system roles cannot be deleted; role flags are
  immutable; plan limits (employees, branches) are enforced on insert.

## Data model (Phase 1)

| Table | Purpose |
| --- | --- |
| organizations | Tenant, regional settings, plan, limits, trial |
| branches, departments, designations | Structure; one head-office branch is seeded |
| permissions, roles, role_permissions | Access model |
| employees | Profile and employment record, linked to `auth.users` once activated |
| employee_private | Bank and identity details, separate table for tighter policy |
| employee_documents | Metadata for files in the private bucket |
| onboarding_template_items, onboarding_items | Checklist template and each person's copy |
| notices, notice_receipts | Announcements, audience, read and acknowledgement state |
| notifications, notification_preferences | Inbox and per-category choices |
| audit_logs | Who changed what and when, with field-level diffs |

Notable behavior implemented in the database:

- Employee codes are generated from the organization prefix.
- A new employee automatically receives a copy of the active onboarding items
  and a one-time invite code; `onboarding_status` is derived from the checklist.
- Publishing a notice creates notifications for its audience; scheduled notices
  are dispatched when due.
- Changing someone's role notifies that employee.

## Frontend design system

- Material 3 with a `ThemeExtension` (`AppColors`) for semantic colors; light and
  dark themes; Inter via `google_fonts`.
- Reusable building blocks in `core/widgets`: cards, buttons, text and select
  fields, date fields, status chips, avatars, stat cards, tab strip, banners,
  skeletons, empty and error states, adaptive form sheets (dialog on desktop,
  bottom sheet on phones), confirmation dialogs.
- Responsive helpers in `core/utils/responsive.dart` (`context.isMobile`,
  `isTablet`, `isDesktop`).
- Forms use custom select and date fields instead of `DropdownButtonFormField`,
  which keeps the look consistent and avoids its layout quirks.

## Security notes

- Only the anon key ships in the client. The service role key is never used.
- RLS is enabled on every table; storage policies check the organization
  folder in the object path.
- Sensitive fields (bank, national ID) live in `employee_private`. Only the
  person themselves and holders of `employees.view_private` can read them, and
  the UI keeps the values masked until the viewer chooses Show.
- CSV export neutralizes spreadsheet formula injection.
- Not yet in Phase 1: two-factor authentication, session and device management
  (planned for Phase 5).

## Extending for the next phases

Each later module follows the same recipe: migration (tables, RLS using the same
helpers, triggers for audit), repository, providers, feature folder, nav item
and permission codes. The sidebar already lists upcoming modules as "Coming
next" with the planned feature list, driven by `UpcomingModule` in
`nav_items.dart`; replacing one with a real route is a two-line change.
