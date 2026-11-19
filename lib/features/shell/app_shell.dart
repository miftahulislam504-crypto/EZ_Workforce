import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/nav_items.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_mode_provider.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/banner.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/display.dart';
import '../../data/models/app_context.dart';
import '../../data/providers.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appContext = ref.watch(currentContextProvider);
    // Keeps the realtime notification subscription alive for the session.
    ref.watch(notificationsProvider);

    if (appContext == null) {
      return Scaffold(body: child);
    }

    final content = Column(
      children: [
        _PlanBanner(context: appContext),
        Expanded(child: child),
      ],
    );

    if (context.isMobile) {
      return _MobileShell(
        appContext: appContext,
        location: location,
        child: content,
      );
    }
    return _WideShell(
      appContext: appContext,
      location: location,
      collapsed: context.isTablet,
      child: content,
    );
  }
}

// ---------------------------------------------------------------- wide
class _WideShell extends StatelessWidget {
  const _WideShell({
    required this.appContext,
    required this.location,
    required this.collapsed,
    required this.child,
  });

  final AppContext appContext;
  final String location;
  final bool collapsed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.pageBackground,
      body: Row(
        children: [
          _Sidebar(
            appContext: appContext,
            location: location,
            collapsed: collapsed,
          ),
          Expanded(
            child: Column(
              children: [
                _TopBar(appContext: appContext),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

bool _isActive(String location, String route) =>
    location == route || location.startsWith('$route/');

class _Sidebar extends ConsumerStatefulWidget {
  const _Sidebar({
    required this.appContext,
    required this.location,
    required this.collapsed,
  });

  final AppContext appContext;
  final String location;
  final bool collapsed;

  @override
  ConsumerState<_Sidebar> createState() => _SidebarState();
}

class _SidebarState extends ConsumerState<_Sidebar> {
  bool _upcomingOpen = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final collapsed = widget.collapsed;
    final sections = AppNav.sectionsFor(widget.appContext);
    final upcomingActive =
        widget.location.startsWith('/coming-soon') ||
        widget.location.startsWith('/more');

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: collapsed ? 76 : 272,
      color: colors.sidebar,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              collapsed ? 0 : 20,
              24,
              collapsed ? 0 : 20,
              16,
            ),
            child: collapsed
                ? const Center(child: BrandMark(size: 40))
                : const Align(
                    alignment: Alignment.centerLeft,
                    child: BrandWordmark(size: 36, color: Colors.white),
                  ),
          ),
          if (!collapsed)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.business_outlined,
                      size: 18,
                      color: colors.sidebarMuted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.appContext.organization.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.sidebarText,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: collapsed ? 12 : 12),
              children: [
                for (final section in sections) ...[
                  if (section.title != null && !collapsed)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 18, 12, 8),
                      child: Text(
                        section.title!.toUpperCase(),
                        style: TextStyle(
                          color: colors.sidebarMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    )
                  else if (section.title != null)
                    const SizedBox(height: 12),
                  for (final item in section.items)
                    _NavTile(
                      item: item,
                      selected: _isActive(widget.location, item.route),
                      collapsed: collapsed,
                    ),
                ],
                if (collapsed)
                  _NavTile(
                    item: const NavItem(
                      label: 'More',
                      icon: Icons.apps_outlined,
                      route: '/more',
                    ),
                    selected: upcomingActive,
                    collapsed: true,
                  )
                else ...[
                  const SizedBox(height: 8),
                  _UpcomingHeader(
                    open: _upcomingOpen,
                    onTap: () => setState(() => _upcomingOpen = !_upcomingOpen),
                  ),
                  if (_upcomingOpen)
                    for (final module in AppNav.upcoming)
                      _NavTile(
                        item: NavItem(
                          label: module.label,
                          icon: module.icon,
                          route: module.route,
                          soon: true,
                        ),
                        selected: _isActive(widget.location, module.route),
                        collapsed: false,
                      ),
                ],
              ],
            ),
          ),
          Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: _NavTile(
              item: AppNav.settings,
              selected: _isActive(widget.location, AppNav.settings.route),
              collapsed: collapsed,
            ),
          ),
          _UserTile(appContext: widget.appContext, collapsed: collapsed),
        ],
      ),
    );
  }
}

class _UpcomingHeader extends StatelessWidget {
  const _UpcomingHeader({required this.open, required this.onTap});

  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'COMING NEXT',
                style: TextStyle(
                  color: colors.sidebarMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            Icon(
              open ? Icons.expand_less : Icons.expand_more,
              size: 18,
              color: colors.sidebarMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.item,
    required this.selected,
    required this.collapsed,
  });

  final NavItem item;
  final bool selected;
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final foreground = selected
        ? Colors.white
        : colors.sidebarText.withValues(alpha: 0.82);

    final tile = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        hoverColor: Colors.white.withValues(alpha: 0.06),
        onTap: () => context.go(item.route),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: EdgeInsets.symmetric(
            horizontal: collapsed ? 0 : 12,
            vertical: 11,
          ),
          decoration: BoxDecoration(
            color: selected
                ? Palette.brand.withValues(alpha: 0.55)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: collapsed
              ? Center(child: Icon(item.icon, size: 22, color: foreground))
              : Row(
                  children: [
                    Icon(item.icon, size: 20, color: foreground),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: foreground,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (item.soon)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Soon',
                          style: TextStyle(
                            color: colors.sidebarMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: collapsed ? Tooltip(message: item.label, child: tile) : tile,
    );
  }
}

class _UserTile extends ConsumerWidget {
  const _UserTile({required this.appContext, required this.collapsed});

  final AppContext appContext;
  final bool collapsed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final employee = appContext.employee;
    final avatar = UserAvatar(
      name: employee.fullName,
      imageUrl: ref
          .read(employeeRepositoryProvider)
          .photoUrl(employee.photoPath),
      size: 38,
    );

    return Padding(
      padding: const EdgeInsets.all(12),
      child: UserMenu(
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: collapsed ? 0 : 10,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: collapsed
              ? Center(child: avatar)
              : Row(
                  children: [
                    avatar,
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            employee.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.sidebarText,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            appContext.role.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.sidebarMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.unfold_more,
                      size: 18,
                      color: colors.sidebarMuted,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Account menu with profile, settings and sign out.
class UserMenu extends ConsumerWidget {
  const UserMenu({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      tooltip: 'Account',
      offset: const Offset(0, -140),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      onSelected: (value) {
        switch (value) {
          case 'profile':
            context.go('/profile');
          case 'settings':
            context.go('/settings');
          case 'signout':
            ref.read(authRepositoryProvider).signOut();
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'profile',
          child: ListTile(
            leading: Icon(Icons.person_outline),
            title: Text('My profile'),
            dense: true,
          ),
        ),
        PopupMenuItem(
          value: 'settings',
          child: ListTile(
            leading: Icon(Icons.settings_outlined),
            title: Text('Settings'),
            dense: true,
          ),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: 'signout',
          child: ListTile(
            leading: Icon(Icons.logout),
            title: Text('Sign out'),
            dense: true,
          ),
        ),
      ],
      child: child,
    );
  }
}

// ------------------------------------------------------------- top bar
class _TopBar extends ConsumerStatefulWidget {
  const _TopBar({required this.appContext});

  final AppContext appContext;

  @override
  ConsumerState<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends ConsumerState<_TopBar> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _submit(String value) {
    final text = value.trim();
    context.go(
      text.isEmpty
          ? '/employees'
          : '/employees?q=${Uri.encodeQueryComponent(text)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: colors.pageBackground,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SizedBox(
              height: 44,
              child: TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                onSubmitted: _submit,
                decoration: const InputDecoration(
                  hintText: 'Search people by name, ID or phone',
                  prefixIcon: Icon(Icons.search, size: 20),
                  contentPadding: EdgeInsets.symmetric(
                    vertical: 0,
                    horizontal: 14,
                  ),
                ),
              ),
            ),
          ),
          const Spacer(),
          const ThemeToggleButton(),
          const SizedBox(width: 4),
          const NotificationBell(),
        ],
      ),
    );
  }
}

class ThemeToggleButton extends ConsumerWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      tooltip: isDark ? 'Switch to light theme' : 'Switch to dark theme',
      icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
      onPressed: () => ref
          .read(themeModeProvider.notifier)
          .set(isDark ? ThemeMode.light : ThemeMode.dark),
    );
  }
}

class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationsProvider);
    return IconButton(
      tooltip: 'Notifications',
      onPressed: () => context.go('/notifications'),
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text(unread > 99 ? '99+' : '$unread'),
        child: const Icon(Icons.notifications_none_rounded),
      ),
    );
  }
}

// -------------------------------------------------------------- mobile
class _MobileShell extends ConsumerWidget {
  const _MobileShell({
    required this.appContext,
    required this.location,
    required this.child,
  });

  final AppContext appContext;
  final String location;
  final Widget child;

  int get _index {
    if (_isActive(location, '/dashboard')) return 0;
    if (_isActive(location, '/employees')) return 1;
    if (_isActive(location, '/notices')) return 2;
    if (_isActive(location, '/notifications')) return 3;
    return 4;
  }

  static const List<String> _routes = [
    '/dashboard',
    '/employees',
    '/notices',
    '/notifications',
    '/more',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationsProvider);
    return Scaffold(
      backgroundColor: context.colors.pageBackground,
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            const BrandMark(size: 32),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                appContext.organization.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        actions: const [ThemeToggleButton(), SizedBox(width: 4)],
      ),
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: context.colors.border)),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (index) => context.go(_routes[index]),
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            const NavigationDestination(
              icon: Icon(Icons.groups_outlined),
              selectedIcon: Icon(Icons.groups_rounded),
              label: 'People',
            ),
            const NavigationDestination(
              icon: Icon(Icons.campaign_outlined),
              selectedIcon: Icon(Icons.campaign_rounded),
              label: 'Notices',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: unread > 0,
                label: Text(unread > 99 ? '99+' : '$unread'),
                child: const Icon(Icons.notifications_none_rounded),
              ),
              selectedIcon: Badge(
                isLabelVisible: unread > 0,
                label: Text(unread > 99 ? '99+' : '$unread'),
                child: const Icon(Icons.notifications_rounded),
              ),
              label: 'Alerts',
            ),
            const NavigationDestination(
              icon: Icon(Icons.menu_rounded),
              selectedIcon: Icon(Icons.menu_open_rounded),
              label: 'More',
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------- plan banner
class _PlanBanner extends StatelessWidget {
  const _PlanBanner({required this.context});

  final AppContext context;

  @override
  Widget build(BuildContext buildContext) {
    final org = context.organization;
    if (org.subscriptionStatus == 'suspended') {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: InlineBanner(
          message: 'This organization is suspended. Contact support to reactivate it.',
          tone: StatusTone.danger,
        ),
      );
    }
    if (org.subscriptionStatus == 'trialing' && org.trialEndsAt != null) {
      final days = org.trialEndsAt!.difference(DateTime.now()).inDays;
      if (days < 0) {
        return const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: InlineBanner(
            message:
                'Your free trial has ended. Upgrade to keep adding employees.',
            tone: StatusTone.warning,
          ),
        );
      }
      if (days <= 5) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: InlineBanner(
            message: days == 0
                ? 'Your free trial ends today.'
                : 'Your free trial ends in $days ${days == 1 ? 'day' : 'days'}.',
            tone: StatusTone.warning,
          ),
        );
      }
    }
    return const SizedBox.shrink();
  }
}
