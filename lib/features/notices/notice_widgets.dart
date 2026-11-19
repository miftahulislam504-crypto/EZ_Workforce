import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/display.dart';
import '../../data/models/communication_models.dart';
import '../../data/models/options.dart';

StatusTone noticeTone(String category) => switch (category) {
  'urgent' => StatusTone.danger,
  'hr' => StatusTone.info,
  'policy' => StatusTone.warning,
  'event' => StatusTone.brand,
  _ => StatusTone.neutral,
};

IconData noticeIcon(String category) => switch (category) {
  'urgent' => Icons.priority_high_rounded,
  'hr' => Icons.badge_outlined,
  'policy' => Icons.gavel_outlined,
  'event' => Icons.celebration_outlined,
  _ => Icons.campaign_outlined,
};

class NoticeCategoryChip extends StatelessWidget {
  const NoticeCategoryChip(this.category, {super.key});

  final String category;

  @override
  Widget build(BuildContext context) =>
      StatusChip(label: Options.label(category), tone: noticeTone(category));
}

/// One row in a notice list. Used on the dashboard and the notice board.
class NoticeTile extends StatelessWidget {
  const NoticeTile({
    super.key,
    required this.notice,
    required this.onTap,
    this.showStatus = false,
  });

  final Notice notice;
  final VoidCallback onTap;

  /// Managers see drafts, scheduled and expired notices as well.
  final bool showStatus;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final palette = toneColors(context, noticeTone(notice.category));
    final unread = !notice.isRead && !showStatus;

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
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
              child: Icon(
                notice.isPinned
                    ? Icons.push_pin_outlined
                    : noticeIcon(notice.category),
                color: palette.foreground,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (unread)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: context.scheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      Expanded(
                        child: Text(
                          notice.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: unread
                                ? FontWeight.w800
                                : FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notice.body.replaceAll(RegExp(r'\s+'), ' '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.mutedText,
                      height: 1.35,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      NoticeCategoryChip(notice.category),
                      if (showStatus && notice.status == 'draft')
                        const StatusChip(label: 'Draft'),
                      if (showStatus && notice.isScheduled)
                        const StatusChip(
                          label: 'Scheduled',
                          tone: StatusTone.info,
                        ),
                      if (showStatus && notice.isExpired)
                        const StatusChip(
                          label: 'Expired',
                          tone: StatusTone.neutral,
                        ),
                      if (notice.requiresAck && !notice.isAcknowledged)
                        const StatusChip(
                          label: 'Acknowledgement required',
                          tone: StatusTone.warning,
                        ),
                      Text(
                        [
                          if (notice.createdByName != null)
                            notice.createdByName!,
                          Fmt.relative(notice.publishAt ?? notice.createdAt),
                        ].join('  |  '),
                        style: TextStyle(color: colors.mutedText, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
