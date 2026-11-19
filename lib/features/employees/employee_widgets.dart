import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/display.dart';
import '../../core/widgets/feedback.dart';

StatusChip onboardingChip(String status) => switch (status) {
  'completed' => const StatusChip(
    label: 'Onboarding complete',
    tone: StatusTone.success,
    icon: Icons.check_circle_outline,
  ),
  'in_progress' => const StatusChip(
    label: 'Onboarding in progress',
    tone: StatusTone.info,
    icon: Icons.pending_outlined,
  ),
  _ => const StatusChip(
    label: 'Onboarding not started',
    tone: StatusTone.neutral,
    icon: Icons.radio_button_unchecked,
  ),
};

/// Shows the one-time login invitation code with a copy button.
Future<void> showInviteCodeDialog(
  BuildContext context, {
  required String employeeName,
  required String code,
  bool created = false,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final colors = dialogContext.colors;
      return AlertDialog(
        title: Text(created ? 'Employee added' : 'New invitation code'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Share this code with $employeeName. They enter it on the '
                'Join screen of the app to create their own login.',
                style: TextStyle(color: colors.mutedText, height: 1.4),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: colors.brandSoft,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: SelectableText(
                  code.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 4,
                    color: dialogContext.scheme.primary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'The code works once. You can generate a new one from the '
                'employee profile at any time.',
                style: TextStyle(color: colors.mutedText, fontSize: 13),
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          AppButton(
            label: 'Copy code',
            icon: Icons.copy_outlined,
            variant: AppButtonVariant.secondary,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code.toUpperCase()));
              if (dialogContext.mounted) {
                showAppSnack(dialogContext, 'Invitation code copied.');
              }
            },
          ),
          AppButton(
            label: 'Done',
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      );
    },
  );
}
