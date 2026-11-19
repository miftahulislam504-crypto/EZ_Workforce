import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/errors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/back_button.dart';
import '../../core/widgets/banner.dart';
import '../../core/widgets/display.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/states.dart';
import '../../data/models/communication_models.dart';
import '../../data/models/permissions.dart';
import '../../data/providers.dart';
import '../../data/repositories/notice_repository.dart';
import 'notice_providers.dart';
import 'notice_widgets.dart';

class NoticeDetailScreen extends ConsumerStatefulWidget {
  const NoticeDetailScreen({super.key, required this.noticeId});

  final String noticeId;

  @override
  ConsumerState<NoticeDetailScreen> createState() => _NoticeDetailScreenState();
}

class _NoticeDetailScreenState extends ConsumerState<NoticeDetailScreen> {
  bool _markedRead = false;
  bool _acknowledging = false;

  String get _id => widget.noticeId;

  /// Records the first time the notice is opened and clears its alert.
  Future<void> _markRead(Notice notice) async {
    if (_markedRead) return;
    _markedRead = true;
    final appContext = ref.read(currentContextProvider);
    if (appContext == null) return;

    try {
      if (!notice.isRead) {
        await ref
            .read(noticeRepositoryProvider)
            .markRead(
              noticeId: notice.id,
              employeeId: appContext.employee.id,
              organizationId: appContext.organization.id,
            );
      }
      final alerts = ref.read(notificationsProvider).valueOrNull ?? const [];
      final controller = ref.read(notificationsProvider.notifier);
      for (final alert in alerts) {
        if (!alert.isRead && alert.route == '/notices/${notice.id}') {
          await controller.markRead(alert.id);
        }
      }
    } catch (_) {
      // Reading must never fail because of bookkeeping.
    }
  }

  Future<void> _acknowledge(Notice notice) async {
    final appContext = ref.read(currentContextProvider);
    if (appContext == null) return;
    setState(() => _acknowledging = true);
    try {
      await ref
          .read(noticeRepositoryProvider)
          .acknowledge(
            noticeId: notice.id,
            employeeId: appContext.employee.id,
            organizationId: appContext.organization.id,
          );
      ref.invalidate(noticeDetailProvider(_id));
      if (mounted)
        showAppSnack(context, 'Thank you. Your acknowledgement was recorded.');
    } catch (error) {
      if (mounted) showAppSnack(context, friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _acknowledging = false);
    }
  }

  Future<void> _delete(Notice notice) async {
    final confirmed = await confirmAction(
      context,
      title: 'Delete notice',
      message:
          '"${notice.title}" and its attachments will be removed for '
          'everyone. This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await ref.read(noticeRepositoryProvider).delete(notice);
      if (!mounted) return;
      showAppSnack(context, 'Notice deleted.');
      context.go('/notices');
    } catch (error) {
      if (mounted) showAppSnack(context, friendlyError(error), error: true);
    }
  }

  Future<void> _openAttachment(NoticeAttachment attachment) async {
    try {
      final url = await ref
          .read(noticeRepositoryProvider)
          .attachmentUrl(attachment);
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        showAppSnack(context, 'Could not open this file.', error: true);
      }
    } catch (error) {
      if (mounted) showAppSnack(context, friendlyError(error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appContext = ref.watch(currentContextProvider);
    if (appContext == null) return const LoadingView();
    final canManage = appContext.can(Perm.noticesManage);
    final notice = ref.watch(noticeDetailProvider(_id));

    return notice.when(
      loading: () => const LoadingView(),
      error: (error, _) => ErrorState(
        error: error,
        onRetry: () => ref.invalidate(noticeDetailProvider(_id)),
      ),
      data: (data) {
        if (data == null) {
          return EmptyState(
            icon: Icons.campaign_outlined,
            title: 'Notice not found',
            message: 'It may have been removed or has expired.',
            action: AppButton(
              label: 'Back to notices',
              variant: AppButtonVariant.secondary,
              onPressed: () => context.go('/notices'),
            ),
          );
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _markRead(data);
        });
        return _buildNotice(data, canManage);
      },
    );
  }

  Widget _buildNotice(Notice notice, bool canManage) {
    final colors = context.colors;
    return PageScroll(
      maxWidth: 860,
      onRefresh: () async {
        ref.invalidate(noticeDetailProvider(_id));
        ref.invalidate(noticeStatsProvider(_id));
      },
      children: [
        PageHeader(
          title: 'Notice',
          leading: const PageBackButton(fallback: '/notices'),
          actions: [
            if (canManage)
              AppButton(
                label: 'Edit',
                icon: Icons.edit_outlined,
                variant: AppButtonVariant.secondary,
                onPressed: () => context.push('/notices/${notice.id}/edit'),
              ),
            if (canManage)
              AppButton(
                label: 'Delete',
                icon: Icons.delete_outline,
                variant: AppButtonVariant.secondary,
                onPressed: () => _delete(notice),
              ),
          ],
        ),
        Reveal(
          child: AppCard(
            padding: EdgeInsets.all(context.isMobile ? 20 : 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    NoticeCategoryChip(notice.category),
                    if (notice.isPinned)
                      const StatusChip(
                        label: 'Pinned',
                        icon: Icons.push_pin_outlined,
                        tone: StatusTone.brand,
                      ),
                    if (canManage && notice.status == 'draft')
                      const StatusChip(label: 'Draft'),
                    if (canManage && notice.isScheduled)
                      const StatusChip(
                        label: 'Scheduled',
                        tone: StatusTone.info,
                      ),
                    if (canManage && notice.isExpired)
                      const StatusChip(label: 'Expired'),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  notice.title,
                  style: context.text.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  [
                    if (notice.createdByName != null) notice.createdByName!,
                    Fmt.dateTime(notice.publishAt ?? notice.createdAt),
                    if (notice.expiresAt != null)
                      'Expires ${Fmt.date(notice.expiresAt)}',
                  ].join('  |  '),
                  style: TextStyle(color: colors.mutedText, fontSize: 13.5),
                ),
                const SizedBox(height: 22),
                Divider(color: colors.border),
                const SizedBox(height: 18),
                SelectableText(
                  notice.body,
                  style: context.text.bodyLarge?.copyWith(height: 1.65),
                ),
                if (notice.attachments.isNotEmpty) ...[
                  const SizedBox(height: 26),
                  Text(
                    'Attachments',
                    style: context.text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (final file in notice.attachments)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        onTap: () => _openAttachment(file),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: colors.surfaceAlt,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.attach_file,
                                size: 20,
                                color: context.scheme.primary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  file.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const Icon(Icons.open_in_new, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
        if (notice.requiresAck && notice.status == 'published') ...[
          const SizedBox(height: 20),
          Reveal(
            index: 1,
            child: _AcknowledgeCard(
              notice: notice,
              busy: _acknowledging,
              onAcknowledge: () => _acknowledge(notice),
            ),
          ),
        ],
        if (canManage && notice.status == 'published') ...[
          const SizedBox(height: 20),
          Reveal(
            index: 2,
            child: _StatsCard(
              noticeId: notice.id,
              requiresAck: notice.requiresAck,
            ),
          ),
        ],
      ],
    );
  }
}

class _AcknowledgeCard extends StatelessWidget {
  const _AcknowledgeCard({
    required this.notice,
    required this.busy,
    required this.onAcknowledge,
  });

  final Notice notice;
  final bool busy;
  final VoidCallback onAcknowledge;

  @override
  Widget build(BuildContext context) {
    if (notice.isAcknowledged) {
      return InlineBanner(
        tone: StatusTone.success,
        message:
            'You acknowledged this notice on '
            '${Fmt.dateTime(notice.acknowledgedAt)}.',
      );
    }
    return AppCard(
      borderColor: context.colors.warning.withValues(alpha: 0.5),
      padding: const EdgeInsets.all(22),
      child: Row(
        children: [
          Icon(
            Icons.fact_check_outlined,
            color: context.colors.warning,
            size: 28,
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Acknowledgement required',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                SizedBox(height: 2),
                Text('Confirm that you have read and understood this notice.'),
              ],
            ),
          ),
          const SizedBox(width: 12),
          AppButton(
            label: 'I acknowledge',
            icon: Icons.check,
            loading: busy,
            onPressed: onAcknowledge,
          ),
        ],
      ),
    );
  }
}

class _StatsCard extends ConsumerWidget {
  const _StatsCard({required this.noticeId, required this.requiresAck});

  final String noticeId;
  final bool requiresAck;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(noticeStatsProvider(noticeId));
    return AppCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Reach'),
          stats.when(
            loading: () => const SkeletonBox(height: 80, radius: 14),
            error: (error, _) => ErrorState(
              error: error,
              onRetry: () => ref.invalidate(noticeStatsProvider(noticeId)),
            ),
            data: (NoticeStats s) => Column(
              children: [
                _Meter(
                  label: 'Read',
                  value: s.read,
                  total: s.audience,
                  color: context.scheme.primary,
                ),
                if (requiresAck) ...[
                  const SizedBox(height: 16),
                  _Meter(
                    label: 'Acknowledged',
                    value: s.acknowledged,
                    total: s.audience,
                    color: context.colors.success,
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

class _Meter extends StatelessWidget {
  const _Meter({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
  });

  final String label;
  final int value;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : (value / total).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              '$value of $total',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 9,
            color: color,
            backgroundColor: context.colors.surfaceAlt,
          ),
        ),
      ],
    );
  }
}
