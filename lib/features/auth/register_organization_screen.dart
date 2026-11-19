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
import '../../data/models/options.dart';
import '../../data/providers.dart';
import 'widgets/auth_layout.dart';

class RegisterOrganizationScreen extends ConsumerStatefulWidget {
  const RegisterOrganizationScreen({super.key});

  @override
  ConsumerState<RegisterOrganizationScreen> createState() =>
      _RegisterOrganizationScreenState();
}

class _RegisterOrganizationScreenState
    extends ConsumerState<RegisterOrganizationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _company = TextEditingController();
  final _country = TextEditingController(text: 'Bangladesh');

  String? _businessType;
  String _timezone = 'Asia/Dhaka';
  String _currency = 'BDT';
  bool _obscure = true;
  bool _loading = false;
  bool _checkEmail = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [
      _fullName,
      _email,
      _phone,
      _password,
      _confirm,
      _company,
      _country,
    ]) {
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
          .registerOrganization(
            email: _email.text,
            password: _password.text,
            fullName: _fullName.text,
            organizationName: _company.text,
            businessType: _businessType,
            country: Validators.clean(_country.text),
            phone: Validators.clean(_phone.text),
            timezone: _timezone,
            currency: _currency,
          );
      // With e-mail confirmation enabled there is no session yet.
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
                  'Your organization has been created. Confirm your email address, '
                  'then sign in to start setting up your company.',
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
      title: 'Create your organization',
      subtitle: 'Set up your company in a few minutes. You become the owner.',
      maxWidth: 520,
      footer: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Already registered?',
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
              Text(
                'Your account',
                style: context.text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _fullName,
                label: 'Full name',
                prefixIcon: Icons.person_outline,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                validator: Validators.requiredField('Full name'),
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _email,
                label: 'Work email',
                prefixIcon: Icons.mail_outline,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                validator: Validators.email,
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _phone,
                label: 'Phone (optional)',
                prefixIcon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.telephoneNumber],
                validator: Validators.optionalPhone,
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _password,
                label: 'Password',
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
                textInputAction: TextInputAction.next,
                validator: Validators.matches(
                  () => _password.text,
                  'Passwords do not match',
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Your company',
                style: context.text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _company,
                label: 'Company name',
                prefixIcon: Icons.business_outlined,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                validator: Validators.requiredField('Company name'),
              ),
              const SizedBox(height: 14),
              AppSelectField<String>(
                label: 'Business type',
                value: _businessType,
                options: Options.businessTypes
                    .map((t) => SelectOption<String>(t, t))
                    .toList(),
                onChanged: (value) => setState(() => _businessType = value),
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _country,
                label: 'Country',
                prefixIcon: Icons.public,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),
              AppSelectField<String>(
                label: 'Time zone',
                value: _timezone,
                allowClear: false,
                options: Options.timezones
                    .map((t) => SelectOption<String>(t, t))
                    .toList(),
                onChanged: (value) =>
                    setState(() => _timezone = value ?? _timezone),
              ),
              const SizedBox(height: 14),
              AppSelectField<String>(
                label: 'Currency',
                value: _currency,
                allowClear: false,
                options: Options.currencies
                    .map((c) => SelectOption<String>(c, c))
                    .toList(),
                onChanged: (value) =>
                    setState(() => _currency = value ?? _currency),
              ),
              const SizedBox(height: 28),
              AppButton(
                label: 'Create organization',
                expand: true,
                loading: _loading,
                onPressed: _submit,
              ),
              const SizedBox(height: 12),
              Text(
                'Your free trial includes up to 50 employees and 5 branches.',
                style: TextStyle(color: colors.mutedText, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
