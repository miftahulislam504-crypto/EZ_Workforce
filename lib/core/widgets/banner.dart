import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'display.dart';

/// Inline message block for form errors, hints and notices.
class InlineBanner extends StatelessWidget {
  const InlineBanner({
    super.key,
    required this.message,
    this.tone = StatusTone.info,
    this.icon,
    this.action,
  });

  final String message;
  final StatusTone tone;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final palette = toneColors(context, tone);
    final IconData resolvedIcon =
        icon ??
        switch (tone) {
          StatusTone.danger => Icons.error_outline,
          StatusTone.warning => Icons.warning_amber_rounded,
          StatusTone.success => Icons.check_circle_outline,
          _ => Icons.info_outline,
        };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(resolvedIcon, size: 20, color: palette.foreground),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: palette.foreground,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ),
          if (action != null) ...[const SizedBox(width: 8), action!],
        ],
      ),
    );
  }
}
