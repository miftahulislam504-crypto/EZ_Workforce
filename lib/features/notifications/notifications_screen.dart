import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/errors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/display.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/states.dart';
import '../../data/models/communication_models.dart';
import '../../data/providers.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _unreadOnly = false;

  static IconData _icon(String category) => switch (category) {
    'notice' => Icons.campaign_outlined,
    'employee' => Icons.person_outline,
    'onboarding' => Icons.checklist_rtl_outlined,
    'security' => Icons.shield_outlined,
    _ => Icons.notifications_none_rounded,
  };

  static StatusTone _tone(String category) => switch (category) {
    'notice' => StatusTone.brand,
    'employee' => StatusTone.info,
    'onboarding' => StatusTone.success,
    'security' => StatusTone.danger,
    _ => StatusTone.neutral,
  };

  static String _dayLabel(DateTime? value) {
    if (value == null) return 'Earlier';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(value.year, value.month, value.day);
    final diff = today.difference(day).inDays;
    if (diff <= 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return 'This week';
    return 'Earlier';
  }

  Future<void> _open(AppNotification item) async {
    final controller = ref.read(notificationsProvider.notifier);
    try {
      if (!item.isRead) await controller.markRead(item.id);
    } catch (error) {
      if (mounted) showAppSnack(context, friendlyError(error), error: true);
    }
    if (!mounted) return;
    final route = item.route;
    if (route != null && route.startsWith('/')) context.push(route);
  }

  Future<void> _markAll() async {
    try {
      await ref.read(notificationsProvider.notifier).markAllRead();
    } catch (error) {
      if (mounted) showAppSnack(context, friendlyError(error), error: true);
    }
  }

  Future<void> _remove(AppNotification item) async {
    try {
      await ref.read(notificationsProvider.notifier).remove(item.id);
    } catch (error) {
      if (mounted) showAppSnack(context, friendlyError(error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(notificationsProvider);
    final unread = ref.watch(unreadNotificationsProvider);

    return PageScroll(
      maxWidth: 820,
      onRefresh: () => ref.read(notificationsProvider.notifier).refresh(),
      children: [
        PageHeader(
          title: 'Notifications',
          subtitle: unread == 0
              ? 'You are all caught up.'
              : '$unread unread ${unread == 1 ? 'notification' : 'notifications'}',
          actions: [
            AppButton(
              label: 'Mark all as read',
              icon: Icons.done_all,
              variant: AppButtonVariant.secondary,
              onPressed: unread == 0 ? null : _markAll,
            ),
          ],
        ),
        Row(
          children: [
            ChoiceChip(
              label: const Text('All'),
              selected: !_unreadOnly,
              onSelected: (_) => setState(() => _unreadOnly = false),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: Text(unread > 0 ? 'Unread ($unread)' : 'Unread'),
              selected: _unreadOnly,
              onSelected: (_) => setState(() => _unreadOnly = true),
            ),
          ],
        ),
        const SizedBox(height: 18),
        notifications.when(
          loading: () => const SkeletonList(count: 5, itemHeight: 76),
          error: (error, _) => ErrorState(
            error: error,
            onRetry: () => ref.read(notificationsProvider.notifier).refresh(),
          ),
          data: (all) {
            final items = _unreadOnly
                ? all.where((n) => !n.isRead).toList()
                : all;
            if (items.isEmpty) {
              return EmptyState(
                icon: Icons.notifications_off_outlined,
                title: _unreadOnly ? 'Nothing unread' : 'No notifications yet',
                message: _unreadOnly
                    ? 'New alerts will show up here as they arrive.'
                    : 'Notices, onboarding updates and account alerts '
                          'will appear here.',
              );
            }
            return _GroupedList(
              items: items,
              iconFor: _icon,
              toneFor: _tone,
              dayLabel: _dayLabel,
              onOpen: _open,
              onRemove: _remove,
            );
          },
        ),
      ],
    );
  }
}

class _GroupedList extends StatelessWidget {
  const _GroupedList({
    required this.items,
    required this.iconFor,
    required this.toneFor,
    required this.dayLabel,
    required this.onOpen,
    required this.onRemove,
  });

  final List<AppNotification> items;
  final IconData Function(String) iconFor;
  final StatusTone Function(String) toneFor;
  final String Function(DateTime?) dayLabel;
  final ValueChanged<AppNotification> onOpen;
  final ValueChanged<AppNotification> onRemove;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<AppNotification>>{};
    for (final item in items) {
      groups.putIfAbsent(dayLabel(item.createdAt), () => []).add(item);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10, top: 6),
            child: Text(
              entry.key.toUpperCase(),
              style: TextStyle(
                color: context.colors.mutedText,
                fontWeight: FontWeight.w700,
                fontSize: 12,
                letterSpacing: 1.1,
              ),
            ),
          ),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < entry.value.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: context.colors.border),
                  _NotificationTile(
                    item: entry.value[i],
                    icon: iconFor(entry.value[i].category),
                    tone: toneFor(entry.value[i].category),
                    onTap: () => onOpen(entry.value[i]),
                    onRemove: () => onRemove(entry.value[i]),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.item,
    required this.icon,
    required this.tone,
    required this.onTap,
    required this.onRemove,
  });

  final AppNotification item;
  final IconData icon;
  final StatusTone tone;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final palette = toneColors(context, tone);

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onRemove(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 22),
        color: colors.danger.withValues(alpha: 0.12),
        child: Icon(Icons.delete_outline, color: colors.danger),
      ),
      child: InkWell(
        onTap: onTap,
        child: Container(
          color: item.isRead
              ? null
              : context.scheme.primary.withValues(alpha: 0.05),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: palette.background,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, color: palette.foreground, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        fontWeight: item.isRead
                            ? FontWeight.w600
                            : FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    if (item.body != null && item.body!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        item.body!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.mutedText,
                          height: 1.35,
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      Fmt.relative(item.createdAt),
                      style: TextStyle(color: colors.mutedText, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (!item.isRead)
                Padding(
                  padding: const EdgeInsets.only(left: 10, top: 6),
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: context.scheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
