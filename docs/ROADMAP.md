# Roadmap and plan coverage

Source: `EZ_Workforce_Complete_Feature_Plan.md` (31 sections, 5 phases).
Status legend: **Done** = delivered in Phase 1, **Partial** = the Phase 1 part
is delivered and the rest is scheduled, **Phase N** = scheduled, nothing built
yet, **Reference** = describes the product rather than a deliverable.

## Phase overview

| Phase | Theme | Plan outcome | Status |
| --- | --- | --- | --- |
| 1 | Core HRM foundation | Complete basic management of the organization and its people | Delivered (this repository) |
| 2 | Attendance and scheduling | Daily attendance and workforce schedule | Planned |
| 3 | Payroll and self-service | Full HR administration and payroll | Planned |
| 4 | Productivity and performance | Productivity and employee development | Planned |
| 5 | Advanced enterprise | Enterprise-scale operations | Planned |

## Phase 1 checklist (plan section 28)

| Item | Status | Where |
| --- | --- | --- |
| Organization registration | Done | Register screen, `create_organization_for_user` |
| Company profile | Done | Organization -> Company Profile |
| Branch management | Done | Organization -> Branches and Departments |
| Department and designation | Done | Same screen, separate tabs |
| Role and permission | Done | Access -> Roles and Permissions |
| Employee profile | Done | Employees -> profile |
| Employee directory | Done | Employees (search, filters, grid and list, CSV export) |
| Employee onboarding | Done | Checklist per employee, editable template |
| Employee mobile app login | Done | Same Flutter app on Android and iOS, mobile navigation |
| Admin and employee dashboard | Done | Dashboard (admin, manager and employee views) |
| Notice board | Done | Notice Board |
| Basic notification | Done | Notification inbox, preferences, realtime |

## Coverage matrix: all 31 plan sections

| # | Plan section | Phase | Status | Notes |
| --- | --- | --- | --- | --- |
| 1 | Product Overview | - | Reference | Vision and goals |
| 2 | User Types and Access | 1 | Done | Owner, HR Admin, Branch Manager, Department Manager, Employee plus custom roles with per-role permissions and data scope |
| 3 | Main Dashboard | 1 | Partial | Admin, manager and employee dashboards with headcount, joiners, distribution, onboarding, notices, celebrations. Attendance, leave, payroll and task cards arrive with their modules (2, 3, 4) |
| 4 | Employee Management | 1 | Partial | Done: 4.1 profile and documents, 4.2 directory with search, filters, grid and list, CSV export, 4.3 onboarding checklist, archive, 4.5 branches, departments, designations, reporting manager. Later: bulk import and print (2), teams and org chart (2), probation and contract expiry reminders, promotion, transfer, salary revision, disciplinary records (3), resignation, exit interview, clearance, final settlement (3), digital ID card with QR (3) |
| 5 | Attendance Management | 2 | Phase 2 | Check-in and check-out, GPS, geofence, QR, rules, correction, reports |
| 6 | Shift and Roster | 2 | Phase 2 | Shifts, roster, swap and change requests |
| 7 | Leave and Holiday | 2 | Phase 2 | Leave types, policy, application, approval workflow, holiday calendar |
| 8 | Payroll and Salary | 3 | Phase 3 | Structure, processing, payslip, payment, bonus, advance and loan, reports |
| 9 | Employee Self-Service | 3 | Partial | Done: own profile, documents, notices, notification inbox, settings. Later: attendance, leave, payslip, requests, ID card |
| 10 | Task and Work Management | 4 | Phase 4 | |
| 11 | Performance Management | 4 | Phase 4 | |
| 12 | Recruitment and Hiring | 5 | Phase 5 | |
| 13 | Training and Development | 4 | Phase 4 | |
| 14 | Company Communication | 1 | Partial | Done: 14.1 notice board in full (audiences, schedule, pin, expiry, attachments, read and acknowledgement), 14.3 colleague directory with permission-gated contact details, birthday and anniversary celebrations on the dashboard. Later: 14.2 feedback and support requests (3) |
| 15 | HR Helpdesk and Requests | 3 | Phase 3 | |
| 16 | Asset and Equipment | 4 | Phase 4 | |
| 17 | Expense and Reimbursement | 4 | Phase 4 | |
| 18 | Company Events and Calendar | 2 | Phase 2 | Built together with the holiday calendar |
| 19 | Notifications and Reminders | 1 | Partial | Done: in-app inbox, realtime, unread badge, per-category preferences. Later: push delivery (2), reminders with each module |
| 20 | Reports and Analytics | 5 | Partial | Done: headcount and distribution charts, employee CSV export, audit trail view. Module reports ship with their modules; the reporting workspace with PDF and Excel export and scheduled delivery is Phase 5 |
| 21 | Web Application Experience | 1 | Partial | Responsive workspace with sidebar, top bar, search. Navigation lists upcoming modules. Grows with each phase |
| 22 | Android and iOS Experience | 1 | Partial | Bottom navigation, home, notices, notifications, profile. Attendance and My Work tabs fill in during Phases 2 and 3 |
| 23 | Settings and Configuration | 1 | Partial | Done: company name, logo, address, contact, business type, time zone, date and time format, currency, ID prefix, branches, departments, designations, role and permission management, theme, notification preferences. Later: leave, attendance, shift, payroll and approval settings with their modules |
| 24 | Security, Privacy and Audit | 1 | Partial | Done: role-based access, least privilege, row level security, sensitive data masking, document access control, export permission, organization data isolation, audit trail with field-level changes. Later: login activity, device and session management, two-factor authentication, retention policy (5) |
| 25 | Multi-Branch and Multi-Company | 1 | Partial | Done: multiple branches, branch-scoped access and managers, central HR control, transfer by editing the employee's branch. Later: branch-specific shift, holiday and attendance rules (2), branch payroll reporting (3), multi-company (5) |
| 26 | Subscription and SaaS | 1 | Partial | Done: organization registration, 14 day trial, plan, status and usage overview, employee and branch limits enforced in the database. Later: plan changes, billing history, invoices, renewal, suspension workflow (5) |
| 27 | Integrations and Future Extensions | 5 | Phase 5 | Biometric, ERP, e-mail, SMS, bank file export, API access |
| 28 | Development Roadmap | - | Reference | This document |
| 29 | Recommended MVP | 1-3 | Reference | Critical rows map to phases 1 and 2, High rows to phase 3 |
| 30 | Product Experience Principles | all | Reference | Applied throughout; see below |
| 31 | Final Product Vision | - | Reference | |

## How the Phase 1 build follows the product principles (section 30)

1. **Simple UX** - plain labels, empty states that say what to do next.
2. **Role-based experience** - navigation, dashboard and actions change by role.
3. **Mobile-first daily use** - bottom navigation and touch-sized controls.
4. **Approval transparency** - onboarding and notice acknowledgement show status; the approval engine arrives with leave in Phase 2.
5. **Accurate payroll** - not in this phase.
6. **Multi-branch ready** - branch is a first-class field and an access scope.
7. **Auditability** - database-level audit trail.
8. **Configurable policies** - roles, permissions, checklist and regional settings are data.
9. **Employee privacy** - private table, masked values, scoped RLS.
10. **Scalable product** - plan limits and tenant isolation from day one.

## Known gaps in the Phase 1 delivery

These were in the plan's wording for Phase 1 areas but are not built yet:

- Employee directory: bulk import, bulk update, print view and a quick-view
  drawer (the profile page is one tap away).
- Reminders for probation ending and contract expiry (the dates themselves are
  captured on the employee profile).
- Language setting (the UI is English only by project rule).
- Help and support page.
- Push notifications (in-app notifications are live).
- The Dart code has not been compiled or analyzed in the authoring
  environment; see docs/SETUP.md, "First run checklist".

## Suggested Phase 2 scope

Attendance engine (rules, check-in and check-out with GPS, geofence and QR),
shifts and roster, holiday calendar and events, leave types and policy with the
shared approval workflow, attendance correction, daily and monthly attendance
reports, and push notifications. Dashboard cards for attendance and leave
switch on as soon as the data exists.
