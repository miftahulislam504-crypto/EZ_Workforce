import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/errors.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/banner.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/display.dart';
import '../../core/widgets/states.dart';
import '../../data/providers.dart';
import 'widgets/auth_layout.dart';

/// Shown to a signed-in account that is not linked to an employee record.
class ActivateScreen extends ConsumerStatefulWidget {
  const ActivateScreen({super.key});

  @override
  ConsumerState<ActivateScreen> createState() => _ActivateScreenState();
}

class _ActivateScreenState extends ConsumerState<ActivateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).claimInvite(_code.text);
      await ref.read(appContextProvider.notifier).reload();
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = ref.read(authRepositoryProvider).pendingInviteCode;
    final email = ref.watch(authControllerProvider).session?.user.email ?? '';

    return AuthLayout(
      title: 'Activate your account',
      subtitle:
          'You are signed in as $email, but this account is not linked to a company yet.',
      footer: Row(
        children: [
          TextButton.icon(
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Sign out'),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () => ref.read(appContextProvider.notifier).reload(),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Check again'),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (pending != null) ...[
              InlineBanner(
                message:
                    'The invitation code $pending could not be used. It may have been '
                    'used already or entered incorrectly. Enter a valid code below or ask HR for a new one.',
                tone: StatusTone.warning,
              ),
              const SizedBox(height: 16),
            ],
            if (_error != null) ...[
              InlineBanner(message: _error!, tone: StatusTone.danger),
              const SizedBox(height: 16),
            ],
            AppTextField(
              controller: _code,
              label: 'Invitation code',
              prefixIcon: Icons.vpn_key_outlined,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _activate(),
              validator: (value) => (value ?? '').trim().isEmpty
                  ? 'Invitation code is required'
                  : null,
            ),
            const SizedBox(height: 20),
            AppButton(
              label: 'Activate',
              expand: true,
              loading: _loading,
              onPressed: _activate,
            ),
            const SizedBox(height: 16),
            Text(
              'If your access was removed, contact your HR administrator.',
              style: TextStyle(color: context.colors.mutedText, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown while the app context loads, or when loading it failed.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appContextProvider);
    return Scaffold(
      body: Center(
        child: state.hasError
            ? ErrorState(
                error: state.error!,
                onRetry: () => ref.read(appContextProvider.notifier).reload(),
              )
            : const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BrandMark(size: 64),
                  SizedBox(height: 28),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                ],
              ),
      ),
    );
  }
}
