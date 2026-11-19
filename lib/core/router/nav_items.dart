import 'package:flutter/material.dart';

import '../../data/models/app_context.dart';
import '../../data/models/permissions.dart';

class NavItem {
  const NavItem({
    required this.label,
    required this.icon,
    required this.route,
    this.anyOf,
    this.soon = false,
  });

  final String label;
  final IconData icon;
  final String route;

  /// The item is shown when the person holds at least one of these
  /// permissions. Null means everyone.
  final List<String>? anyOf;
  final bool soon;
}

class NavSection {
  const NavSection(this.title, this.items);

  final String? title;
  final List<NavItem> items;
}

/// A module from the product plan that ships in a later phase.
class UpcomingModule {
  const UpcomingModule({
    required this.slug,
    required this.label,
    required this.icon,
    required this.phase,
    required this.summary,
    required this.features,
  });

  final String slug;
  final String label;
  final IconData icon;
  final int phase;
  final String summary;
  final List<String> features;

  String get route => '/coming-soon/$slug';
}

class AppNav {
  const AppNav._();

  static const List<NavSection> _core = [
    NavSection(null, [
      NavItem(
        label: 'Dashboard',
        icon: Icons.dashboard_outlined,
        route: '/dashboard',
      ),
      NavItem(
        label: 'Employees',
        icon: Icons.groups_outlined,
        route: '/employees',
      ),
      NavItem(
        label: 'Notice Board',
        icon: Icons.campaign_outlined,
        route: '/notices',
      ),
    ]),
    NavSection('Organization', [
      NavItem(
        label: 'Company Profile',
        icon: Icons.business_outlined,
        route: '/organization/company',
        anyOf: [Perm.orgManage],
      ),
      NavItem(
        label: 'Branches & Departments',
        icon: Icons.account_tree_outlined,
        route: '/organization/structure',
        anyOf: [
          Perm.branchesManage,
          Perm.departmentsManage,
          Perm.designationsManage,
        ],
      ),
      NavItem(
        label: 'Onboarding Template',
        icon: Icons.checklist_rtl_outlined,
        route: '/organization/onboarding',
        anyOf: [Perm.onboardingManage],
      ),
    ]),
    NavSection('Access & Security', [
      NavItem(
        label: 'Roles & Permissions',
        icon: Icons.admin_panel_settings_outlined,
        route: '/access/roles',
        anyOf: [Perm.rolesView, Perm.rolesManage],
      ),
      NavItem(
        label: 'Audit Trail',
        icon: Icons.history_outlined,
        route: '/audit',
        anyOf: [Perm.auditView],
      ),
    ]),
  ];

  /// Navigation sections the person is allowed to see.
  static List<NavSection> sectionsFor(AppContext context) {
    final result = <NavSection>[];
    for (final section in _core) {
      final items = section.items
          .where((item) => item.anyOf == null || context.canAny(item.anyOf!))
          .toList();
      if (items.isNotEmpty) result.add(NavSection(section.title, items));
    }
    return result;
  }

  static const NavItem settings = NavItem(
    label: 'Settings',
    icon: Icons.settings_outlined,
    route: '/settings',
  );

  static const List<UpcomingModule> upcoming = [
    UpcomingModule(
      slug: 'attendance',
      label: 'Attendance',
      icon: Icons.fingerprint,
      phase: 2,
      summary: 'Daily attendance for every branch and shift.',
      features: [
        'Mobile check-in and check-out',
        'GPS verification and geofencing',
        'QR code attendance',
        'Attendance rules, grace period, late and half-day',
        'Daily and monthly attendance records',
        'Attendance correction requests with approval',
      ],
    ),
    UpcomingModule(
      slug: 'shifts',
      label: 'Shift & Roster',
      icon: Icons.calendar_view_week_outlined,
      phase: 2,
      summary: 'Plan who works when.',
      features: [
        'Morning, day, evening, night and custom shifts',
        'Daily, weekly and monthly duty roster',
        'Bulk assignment and copy previous week',
        'Shift swap and change requests',
        'Conflict warnings',
      ],
    ),
    UpcomingModule(
      slug: 'leave',
      label: 'Leave & Holidays',
      icon: Icons.beach_access_outlined,
      phase: 2,
      summary: 'Leave policies, applications and approvals.',
      features: [
        'Leave types and entitlement policies',
        'Leave application and balance tracking',
        'Multi-level approval workflow',
        'Public, company and branch holiday calendar',
      ],
    ),
    UpcomingModule(
      slug: 'events',
      label: 'Events & Calendar',
      icon: Icons.event_outlined,
      phase: 2,
      summary: 'One calendar for holidays, meetings and celebrations.',
      features: [
        'Company events and meetings',
        'Birthday and work anniversary calendar',
        'Event participants and reminders',
      ],
    ),
    UpcomingModule(
      slug: 'payroll',
      label: 'Payroll',
      icon: Icons.payments_outlined,
      phase: 3,
      summary: 'Accurate salary processing from attendance to payslip.',
      features: [
        'Salary structure, allowances and deductions',
        'Attendance based salary and overtime',
        'Payroll approval, lock and payslips',
        'Salary advance and employee loans',
        'Payment records and payroll reports',
      ],
    ),
    UpcomingModule(
      slug: 'helpdesk',
      label: 'HR Helpdesk',
      icon: Icons.support_agent_outlined,
      phase: 3,
      summary: 'Employee requests and HR support in one place.',
      features: [
        'Profile update, certificate and NOC requests',
        'Request categories, priority and assignment',
        'Comments, attachments and full history',
      ],
    ),
    UpcomingModule(
      slug: 'tasks',
      label: 'Tasks',
      icon: Icons.task_alt_outlined,
      phase: 4,
      summary: 'Assign work and follow progress.',
      features: [
        'Task assignment with priority and deadline',
        'Team task board and overdue tracking',
        'Checklists, comments and attachments',
        'Daily work updates',
      ],
    ),
    UpcomingModule(
      slug: 'performance',
      label: 'Performance',
      icon: Icons.trending_up_outlined,
      phase: 4,
      summary: 'Goals, reviews and recognition.',
      features: [
        'Goals and KPIs',
        'Self, manager and HR reviews',
        'Recognition and achievements',
      ],
    ),
    UpcomingModule(
      slug: 'training',
      label: 'Training',
      icon: Icons.school_outlined,
      phase: 4,
      summary: 'Develop skills across the workforce.',
      features: [
        'Training programs and calendar',
        'Enrollment, attendance and certificates',
        'Skill records and gap tracking',
      ],
    ),
    UpcomingModule(
      slug: 'expenses',
      label: 'Expenses',
      icon: Icons.receipt_long_outlined,
      phase: 4,
      summary: 'Claims and reimbursements.',
      features: [
        'Expense requests with receipts',
        'Manager and finance approval',
        'Reimbursement tracking and reports',
      ],
    ),
    UpcomingModule(
      slug: 'assets',
      label: 'Assets',
      icon: Icons.devices_other_outlined,
      phase: 4,
      summary: 'Track equipment given to employees.',
      features: [
        'Asset registration and assignment',
        'Handover, return and condition',
        'Repair history and exit clearance',
      ],
    ),
    UpcomingModule(
      slug: 'recruitment',
      label: 'Recruitment',
      icon: Icons.person_search_outlined,
      phase: 5,
      summary: 'Hire with a structured process.',
      features: [
        'Job vacancies and applicants',
        'Interview scheduling and evaluation',
        'Convert selected applicants to employees',
      ],
    ),
    UpcomingModule(
      slug: 'reports',
      label: 'Reports & Analytics',
      icon: Icons.insights_outlined,
      phase: 5,
      summary: 'Management reports across every module.',
      features: [
        'HR, attendance, leave and payroll analytics',
        'Branch and department comparison',
        'PDF, Excel and CSV export',
      ],
    ),
  ];

  static UpcomingModule? moduleBySlug(String slug) {
    for (final module in upcoming) {
      if (module.slug == slug) return module;
    }
    return null;
  }

  /// Permissions required to open a route, or null when it is open to all.
  static List<String>? requiredPermissions(String location) {
    if (location.startsWith('/organization/company')) return [Perm.orgManage];
    if (location.startsWith('/organization/structure')) {
      return [
        Perm.branchesManage,
        Perm.departmentsManage,
        Perm.designationsManage,
      ];
    }
    if (location.startsWith('/organization/onboarding'))
      return [Perm.onboardingManage];
    if (location.startsWith('/access'))
      return [Perm.rolesView, Perm.rolesManage];
    if (location.startsWith('/audit')) return [Perm.auditView];
    if (location == '/employees/new') return [Perm.employeesCreate];
    if (RegExp(r'^/employees/[^/]+/edit$').hasMatch(location))
      return [Perm.employeesEdit];
    if (location == '/notices/new') return [Perm.noticesManage];
    if (RegExp(r'^/notices/[^/]+/edit$').hasMatch(location))
      return [Perm.noticesManage];
    return null;
  }
}
