import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/errors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/display.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/states.dart';
import '../../data/models/options.dart';
import '../../data/models/org_models.dart';
import '../../data/providers.dart';

class CompanyProfileScreen extends ConsumerStatefulWidget {
  const CompanyProfileScreen({super.key});

  @override
  ConsumerState<CompanyProfileScreen> createState() =>
      _CompanyProfileScreenState();
}

class _CompanyProfileScreenState extends ConsumerState<CompanyProfileScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _legalName = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _website = TextEditingController();
  final TextEditingController _address = TextEditingController();
  final TextEditingController _city = TextEditingController();
  final TextEditingController _state = TextEditingController();
  final TextEditingController _postal = TextEditingController();
  final TextEditingController _country = TextEditingController();
  final TextEditingController _prefix = TextEditingController();

  String? _businessType;
  String _timezone = 'Asia/Dhaka';
  String _currency = 'BDT';
  String _dateFormat = 'dd MMM yyyy';
  String _timeFormat = '12h';
  int _fiscalMonth = 1;

  bool _populated = false;
  bool _saving = false;
  bool _uploadingLogo = false;

  @override
  void dispose() {
    for (final c in [
      _name,
      _legalName,
      _email,
      _phone,
      _website,
      _address,
      _city,
      _state,
      _postal,
      _country,
      _prefix,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _populate(Organization o) {
    _populated = true;
    _name.text = o.name;
    _legalName.text = o.legalName ?? '';
    _email.text = o.email ?? '';
    _phone.text = o.phone ?? '';
    _website.text = o.website ?? '';
    _address.text = o.addressLine ?? '';
    _city.text = o.city ?? '';
    _state.text = o.stateRegion ?? '';
    _postal.text = o.postalCode ?? '';
    _country.text = o.country ?? '';
    _prefix.text = o.employeeIdPrefix;
    _businessType = o.businessType;
    _timezone = o.timezone;
    _currency = o.currency;
    _dateFormat = o.dateFormat;
    _timeFormat = o.timeFormat;
    _fiscalMonth = o.fiscalYearStartMonth;
  }

  Future<void> _afterChange() async {
    ref.invalidate(organizationProvider);
    // Reloading the context refreshes the sidebar name and date formats.
    await ref.read(appContextProvider.notifier).reload();
  }

  Future<void> _save(Organization org) async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      showAppSnack(context, 'Please fix the highlighted fields.', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(organizationRepositoryProvider).updateOrganization(
        org.id,
        {
          'name': _name.text.trim(),
          'legal_name': Validators.clean(_legalName.text),
          'business_type': _businessType,
          'email': Validators.clean(_email.text),
          'phone': Validators.clean(_phone.text),
          'website': Validators.clean(_website.text),
          'address_line': Validators.clean(_address.text),
          'city': Validators.clean(_city.text),
          'state_region': Validators.clean(_state.text),
          'postal_code': Validators.clean(_postal.text),
          'country': Validators.clean(_country.text),
          'timezone': _timezone,
          'currency': _currency,
          'date_format': _dateFormat,
          'time_format': _timeFormat,
          'fiscal_year_start_month': _fiscalMonth,
          'employee_id_prefix': _prefix.text.trim().toUpperCase(),
        },
      );
      await _afterChange();
      if (mounted) showAppSnack(context, 'Company profile saved.');
    } catch (error) {
      if (mounted) showAppSnack(context, friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changeLogo(Organization org) async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 90,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    if (bytes.length > 3 * 1024 * 1024) {
      showAppSnack(context, 'Choose a logo smaller than 3 MB.', error: true);
      return;
    }
    setState(() => _uploadingLogo = true);
    try {
      await ref
          .read(organizationRepositoryProvider)
          .uploadLogo(
            organizationId: org.id,
            bytes: bytes,
            fileName: file.name,
          );
      await _afterChange();
      if (mounted) showAppSnack(context, 'Logo updated.');
    } catch (error) {
      if (mounted) showAppSnack(context, friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _uploadingLogo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orgAsync = ref.watch(organizationProvider);
    return orgAsync.when(
      loading: () => const LoadingView(),
      error: (error, _) => ErrorState(
        error: error,
        onRetry: () => ref.invalidate(organizationProvider),
      ),
      data: (org) {
        if (org == null) return const LoadingView();
        if (!_populated) _populate(org);
        return _buildForm(org);
      },
    );
  }

  Widget _buildForm(Organization org) {
    final colors = context.colors;
    final people = ref.watch(employeePickerProvider).valueOrNull;
    final branches = ref.watch(branchesProvider).valueOrNull;
    final repository = ref.read(organizationRepositoryProvider);
    final logoUrl = repository.logoUrl(org.logoPath);

    return Form(
      key: _formKey,
      child: PageScroll(
        maxWidth: 940,
        children: [
          const PageHeader(
            title: 'Company profile',
            subtitle: 'Your organization details and regional settings.',
          ),
          Reveal(
            child: AppCard(
              padding: const EdgeInsets.all(24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: colors.surfaceAlt,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(color: colors.border),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: logoUrl == null
                            ? const Center(child: BrandMark(size: 44))
                            : Image.network(
                                logoUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stack) =>
                                    const Center(child: BrandMark(size: 44)),
                              ),
                      ),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Material(
                          color: context.scheme.primary,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: _uploadingLogo
                                ? null
                                : () => _changeLogo(org),
                            child: Padding(
                              padding: const EdgeInsets.all(7),
                              child: _uploadingLogo
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.photo_camera_outlined,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          org.name,
                          style: context.text.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          org.businessType ?? 'Business type not set',
                          style: TextStyle(color: colors.mutedText),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            StatusChip(
                              label: '${Options.label(org.plan)} plan',
                              tone: StatusTone.brand,
                            ),
                            StatusChip(
                              label: Options.label(org.subscriptionStatus),
                              tone: org.subscriptionStatus == 'active'
                                  ? StatusTone.success
                                  : org.subscriptionStatus == 'trialing'
                                  ? StatusTone.info
                                  : StatusTone.danger,
                            ),
                            if (org.trialEndsAt != null &&
                                org.subscriptionStatus == 'trialing')
                              StatusChip(
                                label:
                                    'Trial ends ${Fmt.date(org.trialEndsAt)}',
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Reveal(
            index: 1,
            child: ResponsiveGrid(
              minTileWidth: 280,
              maxColumns: 2,
              children: [
                _UsageCard(
                  label: 'Employees',
                  icon: Icons.groups_outlined,
                  used: people?.length,
                  limit: org.maxEmployees,
                ),
                _UsageCard(
                  label: 'Branches',
                  icon: Icons.location_city_outlined,
                  used: branches?.length,
                  limit: org.maxBranches,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Reveal(
            index: 2,
            child: _FormCard(
              title: 'General',
              icon: Icons.business_outlined,
              children: [
                AppTextField(
                  controller: _name,
                  label: 'Company name *',
                  validator: Validators.requiredField('Company name'),
                ),
                AppTextField(controller: _legalName, label: 'Legal name'),
                AppSelectField<String>(
                  label: 'Business type',
                  value: _businessType,
                  options: [
                    for (final t in Options.businessTypes) SelectOption(t, t),
                  ],
                  onChanged: (v) => setState(() => _businessType = v),
                ),
                AppTextField(
                  controller: _prefix,
                  label: 'Employee ID prefix',
                  hint: 'EMP',
                  textCapitalization: TextCapitalization.characters,
                  validator: (v) =>
                      RegExp(r'^[A-Za-z0-9]{2,8}$').hasMatch((v ?? '').trim())
                      ? null
                      : 'Use 2 to 8 letters or digits',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Reveal(
            index: 3,
            child: _FormCard(
              title: 'Contact',
              icon: Icons.contact_mail_outlined,
              children: [
                AppTextField(
                  controller: _email,
                  label: 'Company email',
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.optionalEmail,
                ),
                AppTextField(
                  controller: _phone,
                  label: 'Phone',
                  keyboardType: TextInputType.phone,
                  validator: Validators.optionalPhone,
                ),
                AppTextField(
                  controller: _website,
                  label: 'Website',
                  keyboardType: TextInputType.url,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Reveal(
            index: 4,
            child: _FormCard(
              title: 'Address',
              icon: Icons.place_outlined,
              children: [
                AppTextField(controller: _address, label: 'Street address'),
                AppTextField(controller: _city, label: 'City'),
                AppTextField(controller: _state, label: 'State or region'),
                AppTextField(controller: _postal, label: 'Postal code'),
                AppTextField(controller: _country, label: 'Country'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Reveal(
            index: 5,
            child: _FormCard(
              title: 'Regional settings',
              icon: Icons.public_outlined,
              children: [
                AppSelectField<String>(
                  label: 'Time zone',
                  value: _timezone,
                  allowClear: false,
                  options: [
                    for (final t in Options.timezones) SelectOption(t, t),
                  ],
                  onChanged: (v) => setState(() => _timezone = v ?? _timezone),
                ),
                AppSelectField<String>(
                  label: 'Currency',
                  value: _currency,
                  allowClear: false,
                  options: [
                    for (final c in Options.currencies) SelectOption(c, c),
                  ],
                  onChanged: (v) => setState(() => _currency = v ?? _currency),
                ),
                AppSelectField<String>(
                  label: 'Date format',
                  value: _dateFormat,
                  allowClear: false,
                  options: [
                    for (final f in Options.dateFormats)
                      SelectOption(f, f, subtitle: Fmt.sampleDate(f)),
                  ],
                  onChanged: (v) =>
                      setState(() => _dateFormat = v ?? _dateFormat),
                ),
                AppSelectField<String>(
                  label: 'Time format',
                  value: _timeFormat,
                  allowClear: false,
                  options: const [
                    SelectOption('12h', '12-hour', subtitle: '3:30 PM'),
                    SelectOption('24h', '24-hour', subtitle: '15:30'),
                  ],
                  onChanged: (v) =>
                      setState(() => _timeFormat = v ?? _timeFormat),
                ),
                AppSelectField<int>(
                  label: 'Fiscal year starts in',
                  value: _fiscalMonth,
                  allowClear: false,
                  options: [
                    for (var i = 0; i < Options.months.length; i++)
                      SelectOption(i + 1, Options.months[i]),
                  ],
                  onChanged: (v) =>
                      setState(() => _fiscalMonth = v ?? _fiscalMonth),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Align(
            alignment: Alignment.centerRight,
            child: AppButton(
              label: 'Save changes',
              icon: Icons.check,
              loading: _saving,
              onPressed: () => _save(org),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: context.colors.brandSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: context.scheme.primary),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: context.text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ResponsiveGrid(minTileWidth: 280, maxColumns: 2, children: children),
        ],
      ),
    );
  }
}

class _UsageCard extends StatelessWidget {
  const _UsageCard({
    required this.label,
    required this.icon,
    required this.used,
    required this.limit,
  });

  final String label;
  final IconData icon;
  final int? used;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ratio = used == null || limit == 0
        ? 0.0
        : (used! / limit).clamp(0.0, 1.0);
    final nearLimit = ratio >= 0.9;
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: colors.mutedText),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: colors.mutedText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                used == null ? '- / $limit' : '$used / $limit',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              color: nearLimit ? colors.warning : context.scheme.primary,
              backgroundColor: colors.surfaceAlt,
            ),
          ),
          if (nearLimit)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'You are close to the plan limit.',
                style: TextStyle(color: colors.warning, fontSize: 12.5),
              ),
            ),
        ],
      ),
    );
  }
}
