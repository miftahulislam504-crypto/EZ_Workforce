import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/errors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/back_button.dart';
import '../../core/widgets/banner.dart';
import '../../core/widgets/display.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/states.dart';
import '../../data/models/access_models.dart';
import '../../data/models/app_context.dart';
import '../../data/models/employee_models.dart';
import '../../data/models/options.dart';
import '../../data/models/permissions.dart';
import '../../data/providers.dart';
import 'employee_providers.dart';
import 'employee_widgets.dart';

class EmployeeFormScreen extends ConsumerStatefulWidget {
  const EmployeeFormScreen({super.key, this.employeeId});

  /// Null when adding a new employee.
  final String? employeeId;

  @override
  ConsumerState<EmployeeFormScreen> createState() => _EmployeeFormScreenState();
}

class _EmployeeFormScreenState extends ConsumerState<EmployeeFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _firstName = TextEditingController();
  final TextEditingController _lastName = TextEditingController();
  final TextEditingController _personalPhone = TextEditingController();
  final TextEditingController _personalEmail = TextEditingController();
  final TextEditingController _presentAddress = TextEditingController();
  final TextEditingController _permanentAddress = TextEditingController();
  final TextEditingController _emergencyName = TextEditingController();
  final TextEditingController _emergencyRelation = TextEditingController();
  final TextEditingController _emergencyPhone = TextEditingController();
  final TextEditingController _workEmail = TextEditingController();
  final TextEditingController _workPhone = TextEditingController();
  final TextEditingController _workLocation = TextEditingController();

  DateTime? _dob;
  String? _gender;
  String? _bloodGroup;
  String? _maritalStatus;
  DateTime? _joiningDate = DateTime.now();
  String _employeeType = 'full_time';
  String _status = 'active';
  String? _branchId;
  String? _departmentId;
  String? _designationId;
  String? _managerId;
  String? _roleId;
  String? _originalRoleId;
  DateTime? _probationEnd;
  DateTime? _confirmationDate;
  DateTime? _contractStart;
  DateTime? _contractEnd;

  bool _populated = false;
  bool _rolePreselected = false;
  bool _saving = false;

  bool get _editing => widget.employeeId != null;

  @override
  void dispose() {
    for (final controller in [
      _firstName,
      _lastName,
      _personalPhone,
      _personalEmail,
      _presentAddress,
      _permanentAddress,
      _emergencyName,
      _emergencyRelation,
      _emergencyPhone,
      _workEmail,
      _workPhone,
      _workLocation,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _populate(Employee e) {
    _populated = true;
    _firstName.text = e.firstName;
    _lastName.text = e.lastName ?? '';
    _personalPhone.text = e.personalPhone ?? '';
    _personalEmail.text = e.personalEmail ?? '';
    _presentAddress.text = e.presentAddress ?? '';
    _permanentAddress.text = e.permanentAddress ?? '';
    _emergencyName.text = e.emergencyContactName ?? '';
    _emergencyRelation.text = e.emergencyContactRelation ?? '';
    _emergencyPhone.text = e.emergencyContactPhone ?? '';
    _workEmail.text = e.workEmail ?? '';
    _workPhone.text = e.workPhone ?? '';
    _workLocation.text = e.workLocation ?? '';
    _dob = e.dateOfBirth;
    _gender = e.gender;
    _bloodGroup = e.bloodGroup;
    _maritalStatus = e.maritalStatus;
    _joiningDate = e.joiningDate;
    _employeeType = e.employeeType;
    _status = e.status;
    _branchId = e.branchId;
    _departmentId = e.departmentId;
    _designationId = e.designationId;
    _managerId = e.managerId;
    _roleId = e.roleId;
    _originalRoleId = e.roleId;
    _probationEnd = e.probationEndDate;
    _confirmationDate = e.confirmationDate;
    _contractStart = e.contractStartDate;
    _contractEnd = e.contractEndDate;
  }

  Map<String, dynamic> _values({required bool canAssignRole}) {
    String? date(DateTime? value) => value == null ? null : Fmt.isoDate(value);
    final values = <String, dynamic>{
      'first_name': _firstName.text.trim(),
      'last_name': Validators.clean(_lastName.text),
      'date_of_birth': date(_dob),
      'gender': _gender,
      'blood_group': _bloodGroup,
      'marital_status': _maritalStatus,
      'personal_phone': Validators.clean(_personalPhone.text),
      'personal_email': Validators.clean(_personalEmail.text),
      'present_address': Validators.clean(_presentAddress.text),
      'permanent_address': Validators.clean(_permanentAddress.text),
      'emergency_contact_name': Validators.clean(_emergencyName.text),
      'emergency_contact_relation': Validators.clean(_emergencyRelation.text),
      'emergency_contact_phone': Validators.clean(_emergencyPhone.text),
      'work_email': Validators.clean(_workEmail.text),
      'work_phone': Validators.clean(_workPhone.text),
      'work_location': Validators.clean(_workLocation.text),
      'joining_date': date(_joiningDate),
      'employee_type': _employeeType,
      'status': _status,
      'branch_id': _branchId,
      'department_id': _departmentId,
      'designation_id': _designationId,
      'manager_id': _managerId,
      'probation_end_date': date(_probationEnd),
      'confirmation_date': date(_confirmationDate),
      'contract_start_date': date(_contractStart),
      'contract_end_date': date(_contractEnd),
    };
    // Leaving the role out lets the database apply the default role.
    if (canAssignRole && _roleId != null && _roleId != _originalRoleId) {
      values['role_id'] = _roleId;
    }
    return values;
  }

  Future<void> _save() async {
    final appContext = ref.read(currentContextProvider);
    if (appContext == null) return;
    if (!(_formKey.currentState?.validate() ?? false)) {
      showAppSnack(context, 'Please fix the highlighted fields.', error: true);
      return;
    }

    setState(() => _saving = true);
    final repository = ref.read(employeeRepositoryProvider);
    final canAssignRole = appContext.can(Perm.rolesAssign);
    try {
      final values = _values(canAssignRole: canAssignRole);
      if (_editing) {
        final id = widget.employeeId!;
        await repository.update(id, values);
        ref.invalidate(employeeDetailProvider(id));
        ref.invalidate(directoryEntryProvider(id));
        ref.invalidate(employeePickerProvider);
        if (id == appContext.employee.id) {
          await ref.read(appContextProvider.notifier).reload();
        }
        if (!mounted) return;
        showAppSnack(context, 'Employee details saved.');
        context.goBack('/employees/$id');
      } else {
        values['organization_id'] = appContext.organization.id;
        final created = await repository.create(values);
        ref.invalidate(employeePickerProvider);
        if (!mounted) return;
        if (created.inviteCode != null) {
          await showInviteCodeDialog(
            context,
            employeeName: created.fullName,
            code: created.inviteCode!,
            created: true,
          );
        } else {
          showAppSnack(context, '${created.fullName} was added.');
        }
        if (!mounted) return;
        context.go('/employees/${created.id}');
      }
    } catch (error) {
      if (!mounted) return;
      showAppSnack(context, friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appContext = ref.watch(currentContextProvider);
    if (appContext == null) return const LoadingView();

    final fallback = _editing
        ? '/employees/${widget.employeeId}'
        : '/employees';
    final title = _editing ? 'Edit employee' : 'Add employee';

    if (_editing && !_populated) {
      final existing = ref.watch(employeeDetailProvider(widget.employeeId!));
      return existing.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorState(
          error: error,
          onRetry: () =>
              ref.invalidate(employeeDetailProvider(widget.employeeId!)),
        ),
        data: (employee) {
          if (employee == null) {
            return EmptyState(
              icon: Icons.person_off_outlined,
              title: 'Employee not found',
              message: 'This person does not exist or you cannot access them.',
              action: AppButton(
                label: 'Back to employees',
                variant: AppButtonVariant.secondary,
                onPressed: () => context.go('/employees'),
              ),
            );
          }
          _populate(employee);
          return _buildForm(appContext, title, fallback);
        },
      );
    }
    return _buildForm(appContext, title, fallback);
  }

  Widget _buildForm(AppContext appContext, String title, String fallback) {
    final branches = ref.watch(branchesProvider).valueOrNull ?? const [];
    final departments = ref.watch(departmentsProvider).valueOrNull ?? const [];
    final designations =
        ref.watch(designationsProvider).valueOrNull ?? const [];
    final people = ref.watch(employeePickerProvider).valueOrNull ?? const [];
    final roles = ref.watch(rolesProvider).valueOrNull ?? const [];

    final canAssignRole = appContext.can(Perm.rolesAssign);
    final editingSelf = _editing && widget.employeeId == appContext.employee.id;

    if (!_editing && canAssignRole && !_rolePreselected && roles.isNotEmpty) {
      _rolePreselected = true;
      for (final role in roles) {
        if (role.isDefault) {
          _roleId = role.id;
          break;
        }
      }
    }

    final assignableRoles = [
      for (final role in roles)
        if (!role.isOwner || appContext.role.isOwner || role.id == _roleId)
          SelectOption<String>(
            role.id,
            role.name,
            subtitle: Role.scopeLabel(role.dataScope),
          ),
    ];

    final designationOptions = [
      for (final d in designations)
        if (d.isActive &&
            (d.departmentId == null ||
                _departmentId == null ||
                d.departmentId == _departmentId))
          SelectOption<String>(d.id, d.title),
    ];

    return Form(
      key: _formKey,
      child: PageScroll(
        maxWidth: 940,
        children: [
          PageHeader(
            title: title,
            subtitle: _editing
                ? 'Update personal, job and access details.'
                : 'Create a profile. An invitation code is generated so the '
                      'person can log in from their phone.',
            leading: PageBackButton(fallback: fallback),
          ),
          Reveal(
            child: _Section(
              title: 'Personal information',
              icon: Icons.person_outline,
              fields: [
                AppTextField(
                  controller: _firstName,
                  label: 'First name *',
                  textCapitalization: TextCapitalization.words,
                  validator: Validators.requiredField('First name'),
                ),
                AppTextField(
                  controller: _lastName,
                  label: 'Last name',
                  textCapitalization: TextCapitalization.words,
                ),
                AppDateField(
                  label: 'Date of birth',
                  value: _dob,
                  lastDate: DateTime.now(),
                  onChanged: (v) => setState(() => _dob = v),
                  validator: (v) => v != null && v.isAfter(DateTime.now())
                      ? 'Date of birth cannot be in the future'
                      : null,
                ),
                AppSelectField<String>(
                  label: 'Gender',
                  value: _gender,
                  options: Options.select(Options.genders),
                  onChanged: (v) => setState(() => _gender = v),
                ),
                AppSelectField<String>(
                  label: 'Blood group',
                  value: _bloodGroup,
                  options: Options.select(Options.bloodGroups),
                  onChanged: (v) => setState(() => _bloodGroup = v),
                ),
                AppSelectField<String>(
                  label: 'Marital status',
                  value: _maritalStatus,
                  options: Options.select(Options.maritalStatuses),
                  onChanged: (v) => setState(() => _maritalStatus = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Reveal(
            index: 1,
            child: _Section(
              title: 'Contact and emergency',
              icon: Icons.contact_phone_outlined,
              fields: [
                AppTextField(
                  controller: _personalPhone,
                  label: 'Personal phone',
                  keyboardType: TextInputType.phone,
                  validator: Validators.optionalPhone,
                ),
                AppTextField(
                  controller: _personalEmail,
                  label: 'Personal email',
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.optionalEmail,
                ),
                AppTextField(
                  controller: _emergencyName,
                  label: 'Emergency contact name',
                  textCapitalization: TextCapitalization.words,
                ),
                AppTextField(
                  controller: _emergencyRelation,
                  label: 'Relationship',
                ),
                AppTextField(
                  controller: _emergencyPhone,
                  label: 'Emergency contact phone',
                  keyboardType: TextInputType.phone,
                  validator: Validators.optionalPhone,
                ),
              ],
              wide: [
                AppTextField(
                  controller: _presentAddress,
                  label: 'Present address',
                  maxLines: 2,
                  minLines: 2,
                ),
                AppTextField(
                  controller: _permanentAddress,
                  label: 'Permanent address',
                  maxLines: 2,
                  minLines: 2,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Reveal(
            index: 2,
            child: _Section(
              title: 'Job details',
              icon: Icons.work_outline,
              fields: [
                AppDateField(
                  label: 'Joining date *',
                  value: _joiningDate,
                  allowClear: false,
                  onChanged: (v) => setState(() => _joiningDate = v),
                  validator: (v) =>
                      v == null ? 'Joining date is required' : null,
                ),
                AppSelectField<String>(
                  label: 'Employment type',
                  value: _employeeType,
                  allowClear: false,
                  options: Options.select(Options.employeeTypes),
                  onChanged: (v) =>
                      setState(() => _employeeType = v ?? _employeeType),
                ),
                AppSelectField<String>(
                  label: 'Status',
                  value: _status,
                  allowClear: false,
                  options: Options.select(Options.employeeStatuses),
                  onChanged: (v) => setState(() => _status = v ?? _status),
                ),
                AppSelectField<String>(
                  label: 'Branch',
                  value: _branchId,
                  options: [
                    for (final b in branches)
                      if (b.isActive || b.id == _branchId)
                        SelectOption(b.id, b.name),
                  ],
                  onChanged: (v) => setState(() => _branchId = v),
                ),
                AppSelectField<String>(
                  label: 'Department',
                  value: _departmentId,
                  options: [
                    for (final d in departments)
                      if (d.isActive || d.id == _departmentId)
                        SelectOption(d.id, d.name),
                  ],
                  onChanged: (v) => setState(() {
                    _departmentId = v;
                    final stillValid = designations.any(
                      (d) =>
                          d.id == _designationId &&
                          (d.departmentId == null ||
                              v == null ||
                              d.departmentId == v),
                    );
                    if (!stillValid) _designationId = null;
                  }),
                ),
                AppSelectField<String>(
                  label: 'Designation',
                  value: _designationId,
                  options: designationOptions,
                  onChanged: (v) => setState(() => _designationId = v),
                ),
                AppSelectField<String>(
                  label: 'Reporting manager',
                  value: _managerId,
                  options: [
                    for (final p in people)
                      if (p.id != widget.employeeId)
                        SelectOption(
                          p.id,
                          p.fullName,
                          subtitle: p.designationTitle,
                        ),
                  ],
                  onChanged: (v) => setState(() => _managerId = v),
                ),
                AppTextField(
                  controller: _workLocation,
                  label: 'Work location',
                  hint: 'e.g. Floor 3, Gulshan office',
                ),
                AppTextField(
                  controller: _workEmail,
                  label: 'Work email',
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.optionalEmail,
                ),
                AppTextField(
                  controller: _workPhone,
                  label: 'Work phone',
                  keyboardType: TextInputType.phone,
                  validator: Validators.optionalPhone,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Reveal(
            index: 3,
            child: _Section(
              title: 'Probation and contract',
              icon: Icons.event_note_outlined,
              fields: [
                AppDateField(
                  label: 'Probation end date',
                  value: _probationEnd,
                  onChanged: (v) => setState(() => _probationEnd = v),
                  validator: (v) =>
                      v != null &&
                          _joiningDate != null &&
                          v.isBefore(_joiningDate!)
                      ? 'Must be on or after the joining date'
                      : null,
                ),
                AppDateField(
                  label: 'Confirmation date',
                  value: _confirmationDate,
                  onChanged: (v) => setState(() => _confirmationDate = v),
                ),
                AppDateField(
                  label: 'Contract start',
                  value: _contractStart,
                  onChanged: (v) => setState(() => _contractStart = v),
                ),
                AppDateField(
                  label: 'Contract end',
                  value: _contractEnd,
                  onChanged: (v) => setState(() => _contractEnd = v),
                  validator: (v) =>
                      v != null &&
                          _contractStart != null &&
                          v.isBefore(_contractStart!)
                      ? 'Must be on or after the contract start'
                      : null,
                ),
              ],
            ),
          ),
          if (canAssignRole) ...[
            const SizedBox(height: 20),
            Reveal(
              index: 4,
              child: _Section(
                title: 'Access',
                icon: Icons.admin_panel_settings_outlined,
                fields: [
                  AppSelectField<String>(
                    label: 'Role',
                    value: _roleId,
                    allowClear: false,
                    options: assignableRoles,
                    onChanged: editingSelf
                        ? null
                        : (v) => setState(() => _roleId = v),
                  ),
                ],
                wide: [
                  if (editingSelf)
                    const InlineBanner(
                      message: 'You cannot change your own role.',
                    )
                  else
                    const InlineBanner(
                      message:
                          'The role decides which menus the person sees and '
                          'whose records they can open.',
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AppButton(
                label: 'Cancel',
                variant: AppButtonVariant.ghost,
                onPressed: _saving ? null : () => context.goBack(fallback),
              ),
              const SizedBox(width: 10),
              AppButton(
                label: _editing ? 'Save changes' : 'Add employee',
                icon: Icons.check,
                loading: _saving,
                onPressed: _save,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.fields,
    this.wide = const [],
  });

  final String title;
  final IconData icon;
  final List<Widget> fields;
  final List<Widget> wide;

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
          ResponsiveGrid(minTileWidth: 280, maxColumns: 2, children: fields),
          for (final child in wide) ...[const SizedBox(height: 16), child],
        ],
      ),
    );
  }
}
