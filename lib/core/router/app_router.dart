import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../features/access/role_detail_screen.dart';
import '../../features/access/roles_screen.dart';
import '../../features/audit/audit_screen.dart';
import '../../features/auth/activate_screen.dart';
import '../../features/auth/join_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/password_screens.dart';
import '../../features/auth/register_organization_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/employees/employee_form_screen.dart';
import '../../features/employees/employee_profile_screen.dart';
import '../../features/employees/employees_screen.dart';
import '../../features/notices/notice_detail_screen.dart';
import '../../features/notices/notice_form_screen.dart';
import '../../features/notices/notices_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/organization/company_profile_screen.dart';
import '../../features/organization/onboarding_template_screen.dart';
import '../../features/organization/structure_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../features/shell/coming_soon_screen.dart';
import '../../features/shell/more_screen.dart';
import 'nav_items.dart';

const Set<String> _publicPaths = {
  '/login',
  '/register',
  '/join',
  '/forgot-password',
};

class _RouterRefresh extends ChangeNotifier {
  void ping() => notifyListeners();
}

Page<void> _page(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 220),
    reverseTransitionDuration: const Duration(milliseconds: 160),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.012),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  ref.listen(authControllerProvider, (previous, next) => refresh.ping());
  ref.listen(appContextProvider, (previous, next) => refresh.ping());
  ref.onDispose(refresh.dispose);

  String? redirect(BuildContext context, GoRouterState state) {
    final auth = ref.read(authControllerProvider);
    final contextState = ref.read(appContextProvider);
    final location = state.matchedLocation;
    final isPublic = _publicPaths.contains(location);

    if (!auth.isSignedIn) return isPublic ? null : '/login';
    if (auth.recovering)
      return location == '/reset-password' ? null : '/reset-password';

    if (contextState.hasError) return location == '/splash' ? null : '/splash';
    if (!contextState.hasValue) return location == '/splash' ? null : '/splash';

    final appContext = contextState.value;
    if (appContext == null) return location == '/activate' ? null : '/activate';

    const entryPaths = {'/splash', '/activate', '/reset-password', '/'};
    if (isPublic || entryPaths.contains(location)) return '/dashboard';

    final required = AppNav.requiredPermissions(location);
    if (required != null && !appContext.canAny(required)) return '/dashboard';
    return null;
  }

  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: redirect,
    routes: [
      GoRoute(
        path: '/splash',
        pageBuilder: (c, s) => _page(s, const SplashScreen()),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (c, s) => _page(s, const LoginScreen()),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (c, s) => _page(s, const RegisterOrganizationScreen()),
      ),
      GoRoute(
        path: '/join',
        pageBuilder: (c, s) => _page(s, const JoinScreen()),
      ),
      GoRoute(
        path: '/forgot-password',
        pageBuilder: (c, s) => _page(s, const ForgotPasswordScreen()),
      ),
      GoRoute(
        path: '/reset-password',
        pageBuilder: (c, s) => _page(s, const ResetPasswordScreen()),
      ),
      GoRoute(
        path: '/activate',
        pageBuilder: (c, s) => _page(s, const ActivateScreen()),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            pageBuilder: (c, s) => _page(s, const DashboardScreen()),
          ),
          GoRoute(
            path: '/employees',
            pageBuilder: (c, s) => _page(
              s,
              EmployeesScreen(initialQuery: s.uri.queryParameters['q'] ?? ''),
            ),
          ),
          GoRoute(
            path: '/employees/new',
            pageBuilder: (c, s) => _page(s, const EmployeeFormScreen()),
          ),
          GoRoute(
            path: '/employees/:id',
            pageBuilder: (c, s) => _page(
              s,
              EmployeeProfileScreen(employeeId: s.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: '/employees/:id/edit',
            pageBuilder: (c, s) => _page(
              s,
              EmployeeFormScreen(employeeId: s.pathParameters['id']),
            ),
          ),
          GoRoute(
            path: '/notices',
            pageBuilder: (c, s) => _page(s, const NoticesScreen()),
          ),
          GoRoute(
            path: '/notices/new',
            pageBuilder: (c, s) => _page(s, const NoticeFormScreen()),
          ),
          GoRoute(
            path: '/notices/:id',
            pageBuilder: (c, s) =>
                _page(s, NoticeDetailScreen(noticeId: s.pathParameters['id']!)),
          ),
          GoRoute(
            path: '/notices/:id/edit',
            pageBuilder: (c, s) =>
                _page(s, NoticeFormScreen(noticeId: s.pathParameters['id'])),
          ),
          GoRoute(
            path: '/notifications',
            pageBuilder: (c, s) => _page(s, const NotificationsScreen()),
          ),
          GoRoute(
            path: '/organization/company',
            pageBuilder: (c, s) => _page(s, const CompanyProfileScreen()),
          ),
          GoRoute(
            path: '/organization/structure',
            pageBuilder: (c, s) => _page(s, const StructureScreen()),
          ),
          GoRoute(
            path: '/organization/onboarding',
            pageBuilder: (c, s) => _page(s, const OnboardingTemplateScreen()),
          ),
          GoRoute(
            path: '/access/roles',
            pageBuilder: (c, s) => _page(s, const RolesScreen()),
          ),
          GoRoute(
            path: '/access/roles/:id',
            pageBuilder: (c, s) =>
                _page(s, RoleDetailScreen(roleId: s.pathParameters['id']!)),
          ),
          GoRoute(
            path: '/audit',
            pageBuilder: (c, s) => _page(s, const AuditScreen()),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (c, s) => _page(s, const MyProfileScreen()),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (c, s) => _page(s, const SettingsScreen()),
          ),
          GoRoute(
            path: '/more',
            pageBuilder: (c, s) => _page(s, const MoreScreen()),
          ),
          GoRoute(
            path: '/coming-soon/:slug',
            pageBuilder: (c, s) => _page(
              s,
              ComingSoonScreen(slug: s.pathParameters['slug'] ?? ''),
            ),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
