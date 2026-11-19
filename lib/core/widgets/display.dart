import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/responsive.dart';
import 'app_card.dart';

enum StatusTone { neutral, success, warning, danger, info, brand }

/// Background and foreground colours for a [StatusTone].
({Color background, Color foreground}) toneColors(
  BuildContext context,
  StatusTone tone,
) {
  final colors = context.colors;
  return switch (tone) {
    StatusTone.success => (
      background: colors.successSoft,
      foreground: colors.success,
    ),
    StatusTone.warning => (
      background: colors.warningSoft,
      foreground: colors.warning,
    ),
    StatusTone.danger => (
      background: colors.dangerSoft,
      foreground: colors.danger,
    ),
    StatusTone.info => (background: colors.infoSoft, foreground: colors.info),
    StatusTone.brand => (
      background: colors.brandSoft,
      foreground: context.scheme.primary,
    ),
    StatusTone.neutral => (
      background: colors.surfaceAlt,
      foreground: colors.mutedText,
    ),
  };
}

class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    this.tone = StatusTone.neutral,
    this.icon,
  });

  final String label;
  final StatusTone tone;
  final IconData? icon;

  factory StatusChip.employeeStatus(String status) {
    final tone = switch (status) {
      'active' => StatusTone.success,
      'probation' => StatusTone.info,
      'on_leave' => StatusTone.warning,
      'suspended' => StatusTone.danger,
      'resigned' => StatusTone.neutral,
      'terminated' => StatusTone.danger,
      _ => StatusTone.neutral,
    };
    return StatusChip(label: Fmt.humanize(status), tone: tone);
  }

  @override
  Widget build(BuildContext context) {
    final palette = toneColors(context, tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: palette.foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: palette.foreground,
            ),
          ),
        ],
      ),
    );
  }
}

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 40,
  });

  final String name;
  final String? imageUrl;
  final double size;

  static const List<Color> _palette = [
    Color(0xFF4F46E5),
    Color(0xFF0EA5A4),
    Color(0xFFDB2777),
    Color(0xFFD97706),
    Color(0xFF2563EB),
    Color(0xFF7C3AED),
    Color(0xFF16A34A),
  ];

  @override
  Widget build(BuildContext context) {
    final color =
        _palette[name.codeUnits.fold<int>(0, (a, b) => a + b) %
            _palette.length];
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.14),
      ),
      child: Text(
        Fmt.initials(name),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.36,
        ),
      ),
    );

    final url = imageUrl;
    if (url == null || url.isEmpty) return fallback;
    return ClipOval(
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => fallback,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : fallback,
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.tone = StatusTone.brand,
    this.caption,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final StatusTone tone;
  final String? caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = toneColors(context, tone);
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: palette.background,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: palette.foreground, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: context.text.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodyMedium?.copyWith(
                    color: context.colors.mutedText,
                  ),
                ),
                if (caption != null)
                  Text(
                    caption!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySmall?.copyWith(
                      color: palette.foreground,
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

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.leading,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style:
              (context.isMobile
                      ? context.text.headlineSmall
                      : context.text.headlineMedium)
                  ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.4),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: context.text.bodyMedium?.copyWith(
              color: context.colors.mutedText,
            ),
          ),
        ],
      ],
    );

    final lead = leading == null
        ? titleBlock
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              leading!,
              const SizedBox(width: 12),
              Expanded(child: titleBlock),
            ],
          );

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: context.isMobile || actions.isEmpty
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                lead,
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(spacing: 8, runSpacing: 8, children: actions),
                ],
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: lead),
                const SizedBox(width: 16),
                Wrap(spacing: 8, runSpacing: 8, children: actions),
              ],
            ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(
    this.title, {
    super.key,
    this.subtitle,
    this.trailing,
    this.padding,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Expanded(
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
                      style: TextStyle(
                        color: context.colors.mutedText,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class DetailItem {
  const DetailItem(this.label, this.value, {this.widget});

  final String label;
  final String? value;
  final Widget? widget;
}

/// Label and value pairs laid out in responsive columns.
class DetailGrid extends StatelessWidget {
  const DetailGrid({super.key, required this.items, this.minColumnWidth = 220});

  final List<DetailItem> items;
  final double minColumnWidth;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 20.0;
        final columns =
            ((constraints.maxWidth + spacing) / (minColumnWidth + spacing))
                .floor()
                .clamp(1, 4);
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: 18,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: context.text.bodySmall?.copyWith(
                        color: colors.mutedText,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    item.widget ??
                        Text(
                          (item.value == null || item.value!.isEmpty)
                              ? '-'
                              : item.value!,
                          style: context.text.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
