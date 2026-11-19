import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/audit_text.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/display.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/states.dart';
import '../../data/models/app_context.dart';
import '../../data/models/communication_models.dart';
import '../../data/models/dashboard_models.dart';
import '../../data/models/employee_models.dart';
import '../../data/models/options.dart';
import '../../data/models/permissions.dart';
import '../../data/providers.dart';
import '../notices/notice_widgets.dart';

// ---------------------------------------------------------------- providers
final _adminStatsProvider = FutureProvider.autoDispose<AdminStats>(
  (ref) => ref.watch(dashboardRepositoryProvider).adminStats(),
);

final _teamStatsProvider = FutureProvider.autoDispose<TeamStats>(
  (ref) => ref.watch(dashboardRepositoryProvider).teamStats(),
);

final _celebrationsProvider = FutureProvider.autoDispose<List<Celebration>>(
  (ref) => ref.watch(dashboardRepositoryProvider).celebrations(days: 30),
);

final _latestNoticesProvider = FutureProvider.autoDispose<List<Notice>>((
  ref,
) async {
  final context = ref.watch(currentContextProvider);
  if (context == null) return const [];
  final notices = await ref
      .watch(noticeRepositoryProvider)
      .list(employeeId: context.employee.id, status: 'published', limit: 12);
  return notices.where((n) => !n.isScheduled && !n.isExpired).take(4).toList();
});

final _myOnboardingProvider = FutureProvider.autoDispose<List<OnboardingItem>>((
  ref,
) async {
  final context = ref.watch(currentContextProvider);
  if (context == null) return const [];
  return ref
      .watch(employeeRepositoryProvider)
      .onboardingItems(context.employee.id);
});

const List<Color> _chartColors = [
  Color(0xFF4F46E5),
  Color(0xFF0EA5A4),
  Color(0xFFD97706),
  Color(0xFFDB2777),
  Color(0xFF2563EB),
  Color(0xFF7C3AED),
  Color(0xFF16A34A),
  Color(0xFF64748B),
];

// ------------------------------------------------------------------- screen
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appContext = ref.watch(currentContextProvider);
    if (appContext == null) return const LoadingView();

    final isAdmin = appContext.can(Perm.dashboardAdmin);
    final isTeam = !isAdmin && appContext.can(Perm.dashboardTeam);

    Future<void> refresh() async {
      ref.invalidate(_adminStatsProvider);
      ref.invalidate(_teamStatsProvider);
      ref.invalidate(_celebrationsProvider);
      ref.invalidate(_latestNoticesProvider);
      ref.invalidate(_myOnboardingProvider);
      await ref.read(notificationsProvider.notifier).refresh();
    }

    return PageScroll(
      onRefresh: refresh,
      children: [
        Reveal(child: _Hero(appContext: appContext)),
        const SizedBox(height: 24),
        if (isAdmin)
          const _AdminSection()
        else if (isTeam)
          const _TeamSection()
        else
          _SelfSection(appContext: appContext),
        const SizedBox(height: 20),
        const Reveal(
          index: 4,
          child: SplitRow(
            primary: _LatestNoticesCard(),
            secondary: _CelebrationsCard(),
            secondaryWidth: 360,
          ),
        ),
      ],
    );
  }
}

// --------------------------------------------------------------------- hero
class _Hero extends ConsumerWidget {
  const _Hero({required this.appContext});

  final AppContext appContext;

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employee = appContext.employee;
    final actions = <Widget>[
      if (appContext.can(Perm.employeesCreate))
        _HeroAction(
          icon: Icons.person_add_alt_1_outlined,
          label: 'Add employee',
          onTap: () => context.push('/employees/new'),
        ),
      if (appContext.can(Perm.noticesManage))
        _HeroAction(
          icon: Icons.campaign_outlined,
          label: 'Post a notice',
          onTap: () => context.push('/notices/new'),
        ),
      _HeroAction(
        icon: Icons.person_outline,
        label: 'My profile',
        onTap: () => context.go('/profile'),
      ),
    ];

    return AppCard(
      gradient: context.colors.heroGradient,
      borderColor: Colors.transparent,
      padding: EdgeInsets.all(context.isMobile ? 22 : 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontWeight: FontWeight.w600,
              fontSize: 13,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$_greeting, ${employee.firstName}',
            style: context.text.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            [
              employee.designationTitle,
              employee.departmentName,
              appContext.organization.name,
            ].whereType<String>().join('  |  '),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 22),
          Wrap(spacing: 10, runSpacing: 10, children: actions),
        ],
      ),
    );
  }
}

class _HeroAction extends StatelessWidget {
  const _HeroAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        hoverColor: Colors.white.withValues(alpha: 0.12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------- admin
class _AdminSection extends ConsumerWidget {
  const _AdminSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(_adminStatsProvider);
    return AsyncValueView<AdminStats>(
      value: stats,
      onRetry: () => ref.invalidate(_adminStatsProvider),
      loading: const _SectionSkeleton(),
      data: (s) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Reveal(
            index: 1,
            child: ResponsiveGrid(
              minTileWidth: 230,
              children: [
                StatCard(
                  label: 'Total employees',
                  value: '${s.total}',
                  icon: Icons.groups_outlined,
                  caption: s.joinedThisMonth > 0
                      ? '${s.joinedThisMonth} joined this month'
                      : null,
                  onTap: () => context.go('/employees'),
                ),
                StatCard(
                  label: 'Active',
                  value: '${s.active}',
                  icon: Icons.verified_user_outlined,
                  tone: StatusTone.success,
                ),
                StatCard(
                  label: 'On probation',
                  value: '${s.probation}',
                  icon: Icons.hourglass_bottom_outlined,
                  tone: StatusTone.info,
                ),
                StatCard(
                  label: 'On leave',
                  value: '${s.onLeave}',
                  icon: Icons.beach_access_outlined,
                  tone: StatusTone.warning,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Reveal(
            index: 2,
            child: SplitRow(
              primary: _ChartCard(
                title: 'New joiners',
                subtitle: 'Last 6 months',
                child: s.joiningTrend.isEmpty
                    ? const _NoData()
                    : _TrendChart(points: s.joiningTrend),
              ),
              secondary: _AttentionCard(stats: s),
              secondaryWidth: 360,
            ),
          ),
          const SizedBox(height: 20),
          Reveal(
            index: 3,
            child: ResponsiveGrid(
              minTileWidth: 340,
              maxColumns: 3,
              children: [
                _ChartCard(
                  title: 'By department',
                  child: _DistributionBars(items: s.byDepartment),
                ),
                _ChartCard(
                  title: 'By branch',
                  child: _DistributionBars(items: s.byBranch),
                ),
                _ChartCard(
                  title: 'Employment type',
                  child: _DonutWithLegend(
                    items: [
                      for (final item in s.byType)
                        CountItem(
                          name: Options.label(item.name),
                          count: item.count,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Reveal(
            index: 3,
            child: SplitRow(
              primary: _ChartCard(
                title: 'Top designations',
                child: _DistributionBars(items: s.byDesignation, limit: 6),
              ),
              secondary: _ChartCard(
                title: 'Gender',
                child: _DonutWithLegend(
                  items: [
                    for (final item in s.byGender)
                      CountItem(
                        name: Options.label(item.name),
                        count: item.count,
                      ),
                  ],
                ),
              ),
              secondaryWidth: 360,
            ),
          ),
          const SizedBox(height: 20),
          Reveal(index: 4, child: _ActivityCard(items: s.recentActivity)),
        ],
      ),
    );
  }
}

class _SectionSkeleton extends StatelessWidget {
  const _SectionSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Row(
          children: [
            Expanded(child: SkeletonBox(height: 86, radius: 20)),
            SizedBox(width: 16),
            Expanded(child: SkeletonBox(height: 86, radius: 20)),
          ],
        ),
        SizedBox(height: 16),
        SkeletonBox(height: 260, radius: 20),
      ],
    );
  }
}

class _NoData extends StatelessWidget {
  const _NoData();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Center(
        child: Text(
          'Nothing to show yet',
          style: TextStyle(color: context.colors.mutedText),
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: context.text.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                subtitle!,
                style: TextStyle(color: context.colors.mutedText, fontSize: 13),
              ),
            ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.points});

  final List<TrendPoint> points;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final labelStyle = TextStyle(color: colors.mutedText, fontSize: 12);
    final maxValue = points.fold<int>(0, (m, p) => p.joined > m ? p.joined : m);
    final top = (maxValue < 4 ? 4 : maxValue + 1).toDouble();
    final interval = (top / 4).ceilToDouble();

    return SizedBox(
      height: 230,
      child: BarChart(
        BarChartData(
          maxY: top,
          alignment: BarChartAlignment.spaceAround,
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: interval,
            getDrawingHorizontalLine: (value) =>
                FlLine(color: colors.border, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: interval,
                getTitlesWidget: (value, meta) =>
                    Text(value.toInt().toString(), style: labelStyle),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= points.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(points[index].label, style: labelStyle),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < points.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: points[i].joined.toDouble(),
                    width: 20,
                    color: context.scheme.primary,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(6),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _DistributionBars extends StatelessWidget {
  const _DistributionBars({required this.items, this.limit = 5});

  final List<CountItem> items;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final visible = items.where((i) => i.count > 0).take(limit).toList();
    if (visible.isEmpty) return const _NoData();
    final maxCount = visible.fold<int>(1, (m, i) => i.count > m ? i.count : m);

    return Column(
      children: [
        for (var i = 0; i < visible.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == visible.length - 1 ? 0 : 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        visible[i].name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      '${visible[i].count}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(
                      begin: 0,
                      end: visible[i].count / maxCount,
                    ),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => LinearProgressIndicator(
                      value: value,
                      minHeight: 8,
                      backgroundColor: context.colors.surfaceAlt,
                      color: _chartColors[i % _chartColors.length],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DonutWithLegend extends StatelessWidget {
  const _DonutWithLegend({required this.items});

  final List<CountItem> items;

  @override
  Widget build(BuildContext context) {
    final visible = items.where((i) => i.count > 0).toList();
    final total = visible.fold<int>(0, (sum, i) => sum + i.count);
    if (total == 0) return const _NoData();

    return Column(
      children: [
        SizedBox(
          height: 160,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 52,
                  sections: [
                    for (var i = 0; i < visible.length; i++)
                      PieChartSectionData(
                        value: visible[i].count.toDouble(),
                        color: _chartColors[i % _chartColors.length],
                        radius: 22,
                        showTitle: false,
                      ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$total',
                    style: context.text.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Total',
                    style: TextStyle(
                      color: context.colors.mutedText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            for (var i = 0; i < visible.length; i++)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _chartColors[i % _chartColors.length],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${visible[i].name}  ${visible[i].count}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({required this.stats});

  final AdminStats stats;

  @override
  Widget build(BuildContext context) {
    final rows = <({IconData icon, String label, int count, StatusTone tone})>[
      (
        icon: Icons.checklist_rtl_outlined,
        label: 'Onboarding in progress',
        count: stats.onboardingPending,
        tone: StatusTone.info,
      ),
      (
        icon: Icons.vpn_key_outlined,
        label: 'Invitations not yet used',
        count: stats.invitesPending,
        tone: StatusTone.warning,
      ),
      (
        icon: Icons.hourglass_bottom_outlined,
        label: 'Probation ending in 30 days',
        count: stats.probationEndingSoon,
        tone: StatusTone.warning,
      ),
      (
        icon: Icons.event_busy_outlined,
        label: 'Contracts ending in 30 days',
        count: stats.contractsExpiringSoon,
        tone: StatusTone.danger,
      ),
    ];
    final allClear = rows.every((r) => r.count == 0);

    return _ChartCard(
      title: 'Needs attention',
      child: allClear
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: context.colors.success,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(child: Text('Everything is up to date.')),
                ],
              ),
            )
          : Column(
              children: [
                for (final row in rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: toneColors(context, row.tone).background,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Icon(
                            row.icon,
                            size: 20,
                            color: toneColors(context, row.tone).foreground,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            row.label,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                        Text(
                          '${row.count}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: row.count == 0
                                ? context.colors.mutedText
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.items});

  final List<ActivityItem> items;

  IconData _icon(String action) => switch (action) {
    'insert' || 'create' => Icons.add_circle_outline,
    'delete' => Icons.remove_circle_outline,
    _ => Icons.edit_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            'Recent activity',
            trailing: TextButton(
              onPressed: () => context.go('/audit'),
              child: const Text('View audit trail'),
            ),
          ),
          if (items.isEmpty)
            const _NoData()
          else
            for (final item in items.take(8))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _icon(item.action),
                      size: 20,
                      color: context.colors.mutedText,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AuditText.describe(
                              action: item.action,
                              entityType: item.entityType,
                              summary: item.summary,
                            ),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            [
                              if (item.actorName != null) item.actorName!,
                              Fmt.relative(item.createdAt),
                            ].join('  |  '),
                            style: TextStyle(
                              color: context.colors.mutedText,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------- team
class _TeamSection extends ConsumerWidget {
  const _TeamSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(_teamStatsProvider);
    return AsyncValueView<TeamStats>(
      value: stats,
      onRetry: () => ref.invalidate(_teamStatsProvider),
      loading: const _SectionSkeleton(),
      data: (s) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Reveal(
            index: 1,
            child: ResponsiveGrid(
              minTileWidth: 230,
              children: [
                StatCard(
                  label: 'People in your team',
                  value: '${s.total}',
                  icon: Icons.groups_outlined,
                  caption: s.joinedThisMonth > 0
                      ? '${s.joinedThisMonth} joined this month'
                      : null,
                  onTap: () => context.go('/employees'),
                ),
                StatCard(
                  label: 'Active',
                  value: '${s.active}',
                  icon: Icons.verified_user_outlined,
                  tone: StatusTone.success,
                ),
                StatCard(
                  label: 'On probation',
                  value: '${s.probation}',
                  icon: Icons.hourglass_bottom_outlined,
                  tone: StatusTone.info,
                ),
                StatCard(
                  label: 'On leave',
                  value: '${s.onLeave}',
                  icon: Icons.beach_access_outlined,
                  tone: StatusTone.warning,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Reveal(
            index: 2,
            child: AppCard(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionTitle(
                    'Your team',
                    trailing: TextButton(
                      onPressed: () => context.go('/employees'),
                      child: const Text('See everyone'),
                    ),
                  ),
                  if (s.members.isEmpty)
                    const _NoData()
                  else
                    ResponsiveGrid(
                      minTileWidth: 280,
                      spacing: 8,
                      children: [
                        for (final member in s.members.take(12))
                          _MemberTile(member: member),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberTile extends ConsumerWidget {
  const _MemberTile({required this.member});

  final TeamMember member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: () => context.push('/employees/${member.id}'),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            UserAvatar(
              name: member.fullName,
              imageUrl: ref
                  .read(employeeRepositoryProvider)
                  .photoUrl(member.photoPath),
              size: 42,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    member.designationTitle ?? 'No designation',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.colors.mutedText,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            StatusChip.employeeStatus(member.status),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------- self
class _SelfSection extends ConsumerWidget {
  const _SelfSection({required this.appContext});

  final AppContext appContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employee = appContext.employee;
    final showOnboarding = employee.onboardingStatus != 'completed';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Reveal(
          index: 1,
          child: ResponsiveGrid(
            minTileWidth: 230,
            children: [
              StatCard(
                label: 'Employee ID',
                value: employee.employeeCode,
                icon: Icons.badge_outlined,
                onTap: () => context.go('/profile'),
              ),
              StatCard(
                label: 'Department',
                value: employee.departmentName ?? 'Not set',
                icon: Icons.account_tree_outlined,
                tone: StatusTone.info,
              ),
              StatCard(
                label: 'Branch',
                value: employee.branchName ?? 'Not set',
                icon: Icons.location_on_outlined,
                tone: StatusTone.success,
              ),
              StatCard(
                label: 'Status',
                value: Fmt.humanize(employee.status),
                icon: Icons.verified_user_outlined,
                tone: StatusTone.warning,
              ),
            ],
          ),
        ),
        if (showOnboarding) ...[
          const SizedBox(height: 20),
          const Reveal(index: 2, child: _OnboardingProgressCard()),
        ],
      ],
    );
  }
}

class _OnboardingProgressCard extends ConsumerWidget {
  const _OnboardingProgressCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(_myOnboardingProvider);
    return AppCard(
      padding: const EdgeInsets.all(22),
      child: items.when(
        loading: () => const SkeletonBox(height: 90, radius: 14),
        error: (error, _) => ErrorState(
          error: error,
          onRetry: () => ref.invalidate(_myOnboardingProvider),
        ),
        data: (list) {
          if (list.isEmpty) return const SizedBox.shrink();
          final done = list.where((i) => i.isDone).length;
          final progress = done / list.length;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle(
                'Your onboarding',
                trailing: Text(
                  '$done of ${list.length} complete',
                  style: TextStyle(color: context.colors.mutedText),
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 10,
                  backgroundColor: context.colors.surfaceAlt,
                ),
              ),
              const SizedBox(height: 16),
              for (final item in list.where((i) => !i.isDone).take(3))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Icon(
                        Icons.radio_button_unchecked,
                        size: 18,
                        color: context.colors.mutedText,
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(item.title)),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.go('/profile'),
                child: const Text('Open my checklist'),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ------------------------------------------------------------------ notices
class _LatestNoticesCard extends ConsumerWidget {
  const _LatestNoticesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notices = ref.watch(_latestNoticesProvider);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            'Latest notices',
            trailing: TextButton(
              onPressed: () => context.go('/notices'),
              child: const Text('View all'),
            ),
          ),
          notices.when(
            loading: () => const SkeletonList(count: 3, itemHeight: 64),
            error: (error, _) => ErrorState(
              error: error,
              onRetry: () => ref.invalidate(_latestNoticesProvider),
            ),
            data: (list) => list.isEmpty
                ? const EmptyState(
                    icon: Icons.campaign_outlined,
                    title: 'No notices yet',
                    message: 'Company announcements will appear here.',
                  )
                : Column(
                    children: [
                      for (var i = 0; i < list.length; i++) ...[
                        if (i > 0)
                          Divider(height: 1, color: context.colors.border),
                        NoticeTile(
                          notice: list[i],
                          onTap: () async {
                            await context.push('/notices/${list[i].id}');
                            if (context.mounted) {
                              ref.invalidate(_latestNoticesProvider);
                            }
                          },
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ celebrations
class _CelebrationsCard extends ConsumerWidget {
  const _CelebrationsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final celebrations = ref.watch(_celebrationsProvider);
    return AppCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Birthdays and anniversaries'),
          celebrations.when(
            loading: () => const SkeletonList(count: 3, itemHeight: 48),
            error: (error, _) => ErrorState(
              error: error,
              onRetry: () => ref.invalidate(_celebrationsProvider),
            ),
            data: (list) {
              if (list.isEmpty) {
                return const EmptyState(
                  icon: Icons.cake_outlined,
                  title: 'Nothing coming up',
                  message: 'Celebrations in the next 30 days show here.',
                );
              }
              return Column(
                children: [
                  for (final item in list.take(6))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: _CelebrationRow(item: item),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CelebrationRow extends ConsumerWidget {
  const _CelebrationRow({required this.item});

  final Celebration item;

  String get _when {
    final today = DateTime.now();
    final date = DateTime(today.year, today.month, today.day);
    final days = item.eventDate.difference(date).inDays;
    if (days == 0) return 'Today';
    if (days == 1) return 'Tomorrow';
    return DateFormat('d MMM').format(item.eventDate);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return Row(
      children: [
        UserAvatar(
          name: item.fullName,
          imageUrl: ref
              .read(employeeRepositoryProvider)
              .photoUrl(item.photoPath),
          size: 40,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.fullName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                item.isBirthday
                    ? 'Birthday'
                    : '${Fmt.plural(item.years, 'year')} with the company',
                style: TextStyle(color: colors.mutedText, fontSize: 13),
              ),
            ],
          ),
        ),
        StatusChip(
          label: _when,
          tone: _when == 'Today' ? StatusTone.success : StatusTone.neutral,
          icon: item.isBirthday ? Icons.cake_outlined : Icons.workspace_premium,
        ),
      ],
    );
  }
}
