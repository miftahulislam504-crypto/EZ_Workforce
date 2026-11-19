import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_mode_provider.dart';
import '../../core/utils/errors.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/display.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/states.dart';
import '../../data/models/communication_models.dart';
import '../../data/providers.dart';

final _preferencesProvider =
    FutureProvider.autoDispose<List<NotificationPreference>>(
      (ref) => ref.watch(notificationRepositoryProvider).preferences(),
    );

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appContext = ref.watch(currentContextProvider);

    return PageScroll(
      maxWidth: 820,
      children: [
        const PageHeader(
          title: 'Settings',
          subtitle: 'Appearance, notifications and account security.',
        ),
        if (appContext != null) ...[
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                UserAvatar(name: appContext.employee.fullName, size: 52),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appContext.employee.fullName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          appContext.role.name,
                          appContext.organization.name,
                        ].join('  -  '),
                        style: TextStyle(color: context.colors.mutedText),
                      ),
                      if (appContext.employee.workEmail != null)
                        Text(
                          appContext.employee.workEmail!,
                          style: TextStyle(
                            color: context.colors.mutedText,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        const _AppearanceCard(),
        const SizedBox(height: 20),
        const _NotificationsCard(),
        const SizedBox(height: 20),
        const _PasswordCard(),
        const SizedBox(height: 20),
        AppCard(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sign out',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 2),
                    Text('End your session on this device.'),
                  ],
                ),
              ),
              AppButton(
                label: 'Sign out',
                icon: Icons.logout,
                variant: AppButtonVariant.secondary,
                onPressed: () async {
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
      ],
    );
  }
}

class _AppearanceCard extends ConsumerWidget {
  const _AppearanceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return AppCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            'Appearance',
            subtitle: 'Saved on this device only.',
          ),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text('System'),
                  icon: Icon(Icons.brightness_auto_outlined),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text('Light'),
                  icon: Icon(Icons.light_mode_outlined),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text('Dark'),
                  icon: Icon(Icons.dark_mode_outlined),
                ),
              ],
              selected: {mode},
              onSelectionChanged: (value) =>
                  ref.read(themeModeProvider.notifier).set(value.first),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationsCard extends ConsumerWidget {
  const _NotificationsCard();

  static const Map<String, ({String title, String subtitle})> _labels = {
    'notice': (
      title: 'Notices',
      subtitle: 'New announcements and acknowledgement requests.',
    ),
    'employee': (
      title: 'People',
      subtitle: 'Changes to your profile and employment details.',
    ),
    'onboarding': (
      title: 'Onboarding',
      subtitle: 'Checklist tasks assigned to you.',
    ),
    'system': (
      title: 'System',
      subtitle: 'Updates about the platform and your organization.',
    ),
    'security': (
      title: 'Security',
      subtitle: 'Sign-in and account protection alerts.',
    ),
  };

  Future<void> _update(
    BuildContext context,
    WidgetRef ref,
    NotificationPreference next,
  ) async {
    final appContext = ref.read(currentContextProvider);
    if (appContext == null) return;
    try {
      await ref
          .read(notificationRepositoryProvider)
          .savePreference(
            employeeId: appContext.employee.id,
            organizationId: appContext.organization.id,
            preference: next,
          );
      ref.invalidate(_preferencesProvider);
    } catch (error) {
      if (context.mounted) {
        showAppSnack(context, friendlyError(error), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(_preferencesProvider);
    final colors = context.colors;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            'Notifications',
            subtitle: 'Choose what reaches you, per category.',
          ),
          prefs.when(
            loading: () => const SkeletonList(count: 4, itemHeight: 52),
            error: (error, _) => ErrorState(
              error: error,
              onRetry: () => ref.invalidate(_preferencesProvider),
            ),
            data: (list) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Spacer(),
                      SizedBox(
                        width: 64,
                        child: Text(
                          'In app',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: colors.mutedText,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 64,
                        child: Text(
                          'Push',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: colors.mutedText,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                for (final pref in list) ...[
                  Divider(height: 1, color: colors.border),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _labels[pref.category]?.title ?? pref.category,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                _labels[pref.category]?.subtitle ?? '',
                                style: TextStyle(
                                  color: colors.mutedText,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 64,
                          child: Switch(
                            value: pref.inApp,
                            onChanged: (v) => _update(
                              context,
                              ref,
                              NotificationPreference(
                                category: pref.category,
                                inApp: v,
                                push: pref.push,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 64,
                          child: Switch(
                            value: pref.push,
                            onChanged: (v) => _update(
                              context,
                              ref,
                              NotificationPreference(
                                category: pref.category,
                                inApp: pref.inApp,
                                push: v,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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

class _PasswordCard extends ConsumerStatefulWidget {
  const _PasswordCard();

  @override
  ConsumerState<_PasswordCard> createState() => _PasswordCardState();
}

class _PasswordCardState extends ConsumerState<_PasswordCard> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref.read(authRepositoryProvider).updatePassword(_password.text);
      if (!mounted) return;
      _password.clear();
      _confirm.clear();
      setState(() => _saving = false);
      showAppSnack(context, 'Password updated.');
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppSnack(context, friendlyError(error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(22),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle(
              'Change password',
              subtitle: 'Use at least 8 characters.',
            ),
            AppTextField(
              controller: _password,
              label: 'New password',
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              validator: Validators.password,
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _confirm,
              label: 'Confirm new password',
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              validator: Validators.matches(
                () => _password.text,
                'Passwords do not match',
              ),
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: AppButton(
                label: 'Update password',
                loading: _saving,
                onPressed: _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
