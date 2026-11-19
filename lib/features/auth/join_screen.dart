import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/errors.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/banner.dart';
import '../../core/widgets/display.dart';
import '../../data/providers.dart';
import 'widgets/auth_layout.dart';

/// Employee sign-up with the invitation code shared by HR.
class JoinScreen extends ConsumerStatefulWidget {
  const JoinScreen({super.key});

  @override
  ConsumerState<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends ConsumerState<JoinScreen> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  bool _checkEmail = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_code, _email, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await ref
          .read(authRepositoryProvider)
          .registerWithInvite(
            email: _email.text,
            password: _password.text,
            inviteCode: _code.text,
          );
      // The invitation is linked automatically once a session exists. With
      // e-mail confirmation enabled it happens on the first sign-in.
      if (response.session == null && mounted) {
        setState(() => _checkEmail = true);
      }
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkEmail) {
      return AuthLayout(
        title: 'Check your email',
        subtitle: 'We sent a confirmation link to ${_email.text.trim()}.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const InlineBanner(
              message:
                  'Confirm your email address, then sign in. Your account will be '
                  'linked to your company automatically.',
              tone: StatusTone.success,
            ),
            const SizedBox(height: 24),
            AppButton(
              label: 'Go to sign in',
              expand: true,
              onPressed: () => context.go('/login'),
            ),
          ],
        ),
      );
    }

    final colors = context.colors;
    return AuthLayout(
      title: 'Join your company',
      subtitle: 'Use the invitation code you received from HR.',
      footer: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Already have an account?',
            style: TextStyle(color: colors.mutedText),
          ),
          TextButton(
            onPressed: () => context.go('/login'),
            child: const Text('Sign in'),
          ),
        ],
      ),
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_error != null) ...[
                InlineBanner(message: _error!, tone: StatusTone.danger),
                const SizedBox(height: 16),
              ],
              AppTextField(
                controller: _code,
                label: 'Invitation code',
                prefixIcon: Icons.vpn_key_outlined,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  final text = (value ?? '').trim();
                  if (text.isEmpty) return 'Invitation code is required';
                  if (text.length < 6) return 'This code looks too short';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _email,
                label: 'Email address',
                prefixIcon: Icons.mail_outline,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                validator: Validators.email,
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _password,
                label: 'Create a password',
                prefixIcon: Icons.lock_outline,
                obscureText: _obscure,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                helper: 'At least 8 characters',
                validator: Validators.password,
                suffix: IconButton(
                  tooltip: _obscure ? 'Show password' : 'Hide password',
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _confirm,
                label: 'Confirm password',
                prefixIcon: Icons.lock_outline,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                validator: Validators.matches(
                  () => _password.text,
                  'Passwords do not match',
                ),
              ),
              const SizedBox(height: 24),
              AppButton(
                label: 'Activate my account',
                expand: true,
                loading: _loading,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
