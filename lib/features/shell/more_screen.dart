import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/nav_items.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/display.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/layout.dart';
import '../../data/providers.dart';

/// Navigation hub for phones, where the bottom bar only holds five items.
/// On wider screens the sidebar covers this, but the page still works there.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appContext = ref.watch(currentContextProvider);
    if (appContext == null) return const SizedBox.shrink();

    final employee = appContext.employee;
    final sections = AppNav.sectionsFor(appContext)
        .where((s) => s.title != null)
        .toList();

    return PageScroll(
      maxWidth: 720,
      children: [
        Reveal(
          child: AppCard(
            onTap: () => context.go('/profile'),
            child: Row(
              children: [
                UserAvatar(
                  name: employee.fullName,
                  imageUrl: ref
                      .read(employeeRepositoryProvider)
                      .photoUrl(employee.photoPath),
                  size: 56,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employee.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          appContext.role.name,
                          employee.designationTitle,
                        ].whereType<String>().join('  |  '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: context.colors.mutedText),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: context.colors.mutedText),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        for (var i = 0; i < sections.length; i++) ...[
          Reveal(
            index: i + 1,
            child: _MenuGroup(
              title: sections[i].title!,
              rows: [
                for (final item in sections[i].items)
                  _MenuRow(
                    icon: item.icon,
                    label: item.label,
                    onTap: () => context.go(item.route),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        Reveal(
          index: sections.length + 1,
          child: _MenuGroup(
            title: 'Account',
            rows: [
              _MenuRow(
                icon: Icons.person_outline,
                label: 'My profile',
                onTap: () => context.go('/profile'),
              ),
              _MenuRow(
                icon: Icons.settings_outlined,
                label: 'Settings',
                onTap: () => context.go('/settings'),
              ),
              _MenuRow(
                icon: Icons.logout,
                label: 'Sign out',
                destructive: true,
                onTap: () async {
                  final confirmed = await confirmAction(
                    context,
                    title: 'Sign out',
                    message: 'You will need to sign in again to continue.',
                    confirmLabel: 'Sign out',
                  );
                  if (confirmed) {
                    await ref.read(authRepositoryProvider).signOut();
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Reveal(
          index: sections.length + 2,
          child: _MenuGroup(
            title: 'Coming next',
            rows: [
              for (final module in AppNav.upcoming)
                _MenuRow(
                  icon: module.icon,
                  label: module.label,
                  trailing: StatusChip(
                    label: 'Phase ${module.phase}',
                    tone: StatusTone.neutral,
                  ),
                  onTap: () => context.go(module.route),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.title, required this.rows});

  final String title;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              color: context.colors.mutedText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) Divider(height: 1, color: context.colors.border),
                rows[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? context.colors.danger : null;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        child: Row(
          children: [
            Icon(icon, size: 22, color: color ?? context.scheme.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontWeight: FontWeight.w600, color: color),
              ),
            ),
            trailing ??
                Icon(Icons.chevron_right, color: context.colors.mutedText),
          ],
        ),
      ),
    );
  }
}
