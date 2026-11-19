import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/errors.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/display.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/states.dart';
import '../../core/widgets/tab_strip.dart';
import '../../data/models/org_models.dart';
import '../../data/models/permissions.dart';
import '../../data/providers.dart';

enum _StructureTab { branches, departments, designations }

class StructureScreen extends ConsumerStatefulWidget {
  const StructureScreen({super.key});

  @override
  ConsumerState<StructureScreen> createState() => _StructureScreenState();
}

class _StructureScreenState extends ConsumerState<StructureScreen> {
  _StructureTab? _tab;

  static String _label(_StructureTab tab) => switch (tab) {
    _StructureTab.branches => 'Branches',
    _StructureTab.departments => 'Departments',
    _StructureTab.designations => 'Designations',
  };

  @override
  Widget build(BuildContext context) {
    final appContext = ref.watch(currentContextProvider);
    if (appContext == null) return const LoadingView();

    final tabs = [
      if (appContext.can(Perm.branchesManage)) _StructureTab.branches,
      if (appContext.can(Perm.departmentsManage)) _StructureTab.departments,
      if (appContext.can(Perm.designationsManage)) _StructureTab.designations,
    ];
    if (tabs.isEmpty) {
      return const EmptyState(
        icon: Icons.lock_outline,
        title: 'No access',
        message: 'You do not have permission to manage the company structure.',
      );
    }
    final tab = tabs.contains(_tab) ? _tab! : tabs.first;

    return PageScroll(
      maxWidth: 980,
      onRefresh: () async {
        ref.invalidate(branchesProvider);
        ref.invalidate(departmentsProvider);
        ref.invalidate(designationsProvider);
      },
      children: [
        const PageHeader(
          title: 'Company structure',
          subtitle:
              'Branches, departments and designations used across the app.',
        ),
        if (tabs.length > 1) ...[
          TabStrip<_StructureTab>(
            tabs: tabs,
            selected: tab,
            labelOf: _label,
            onChanged: (value) => setState(() => _tab = value),
          ),
          const SizedBox(height: 20),
        ],
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: KeyedSubtree(
            key: ValueKey(tab),
            child: switch (tab) {
              _StructureTab.branches => const _BranchesTab(),
              _StructureTab.departments => const _DepartmentsTab(),
              _StructureTab.designations => const _DesignationsTab(),
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- shared UI
class _ListCard extends StatelessWidget {
  const _ListCard({
    required this.title,
    required this.addLabel,
    required this.onAdd,
    required this.rows,
    required this.emptyTitle,
    required this.emptyMessage,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final String addLabel;
  final VoidCallback onAdd;
  final List<Widget> rows;
  final String emptyTitle;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            title,
            subtitle: subtitle,
            trailing: AppButton(
              label: addLabel,
              icon: Icons.add,
              compact: true,
              onPressed: onAdd,
            ),
          ),
          if (rows.isEmpty)
            EmptyState(
              icon: Icons.folder_open_outlined,
              title: emptyTitle,
              message: emptyMessage,
            )
          else
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) Divider(height: 1, color: context.colors.border),
              rows[i],
            ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.onEdit,
    required this.onDelete,
    this.subtitle,
    this.chips = const [],
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final List<Widget> chips;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: onEdit,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: colors.brandSoft,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, size: 21, color: context.scheme.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      ...chips,
                    ],
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: colors.mutedText, fontSize: 13),
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: onEdit,
            ),
            IconButton(
              tooltip: 'Delete',
              icon: Icon(Icons.delete_outline, size: 20, color: colors.danger),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _confirmDelete({
  required BuildContext context,
  required String what,
  required String name,
  required Future<void> Function() action,
  required VoidCallback onDone,
}) async {
  final confirmed = await confirmAction(
    context,
    title: 'Delete $what',
    message:
        '"$name" will be removed. People assigned to it keep their records '
        'but will no longer have a $what.',
    confirmLabel: 'Delete',
    destructive: true,
  );
  if (!confirmed) return;
  try {
    await action();
    onDone();
    if (context.mounted) showAppSnack(context, '${_cap(what)} deleted.');
  } catch (error) {
    if (context.mounted) {
      showAppSnack(context, friendlyError(error), error: true);
    }
  }
}

String _cap(String value) =>
    value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);

// ------------------------------------------------------------------ branches
class _BranchesTab extends ConsumerWidget {
  const _BranchesTab();

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    Branch? branch,
  ) async {
    final appContext = ref.read(currentContextProvider);
    if (appContext == null) return;
    final saved = await showAdaptiveForm<bool>(
      context,
      title: branch == null ? 'Add branch' : 'Edit branch',
      child: _BranchForm(
        branch: branch,
        organizationId: appContext.organization.id,
      ),
    );
    if (saved == true) ref.invalidate(branchesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branches = ref.watch(branchesProvider);
    final org = ref.watch(organizationProvider).valueOrNull;
    return branches.when(
      loading: () => const SkeletonList(count: 4, itemHeight: 66),
      error: (error, _) => ErrorState(
        error: error,
        onRetry: () => ref.invalidate(branchesProvider),
      ),
      data: (list) => _ListCard(
        title: 'Branches',
        subtitle: org == null
            ? null
            : '${list.length} of ${org.maxBranches} used on your plan',
        addLabel: 'Add branch',
        onAdd: () => _edit(context, ref, null),
        emptyTitle: 'No branches yet',
        emptyMessage: 'Add your head office and other work locations.',
        rows: [
          for (final b in list)
            _Row(
              icon: b.isHeadOffice
                  ? Icons.apartment_outlined
                  : Icons.location_city_outlined,
              title: b.name,
              subtitle: [
                b.code,
                b.city,
                b.phone,
              ].whereType<String>().where((e) => e.isNotEmpty).join('  |  '),
              chips: [
                if (b.isHeadOffice)
                  const StatusChip(
                    label: 'Head office',
                    tone: StatusTone.brand,
                  ),
                if (!b.isActive) const StatusChip(label: 'Inactive'),
              ],
              onEdit: () => _edit(context, ref, b),
              onDelete: () => _confirmDelete(
                context: context,
                what: 'branch',
                name: b.name,
                action: () =>
                    ref.read(organizationRepositoryProvider).deleteBranch(b.id),
                onDone: () => ref.invalidate(branchesProvider),
              ),
            ),
        ],
      ),
    );
  }
}

class _BranchForm extends ConsumerStatefulWidget {
  const _BranchForm({required this.branch, required this.organizationId});

  final Branch? branch;
  final String organizationId;

  @override
  ConsumerState<_BranchForm> createState() => _BranchFormState();
}

class _BranchFormState extends ConsumerState<_BranchForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(
    text: widget.branch?.name,
  );
  late final TextEditingController _code = TextEditingController(
    text: widget.branch?.code,
  );
  late final TextEditingController _address = TextEditingController(
    text: widget.branch?.addressLine,
  );
  late final TextEditingController _city = TextEditingController(
    text: widget.branch?.city,
  );
  late final TextEditingController _phone = TextEditingController(
    text: widget.branch?.phone,
  );
  late final TextEditingController _email = TextEditingController(
    text: widget.branch?.email,
  );
  late String? _managerId = widget.branch?.managerEmployeeId;
  late bool _headOffice = widget.branch?.isHeadOffice ?? false;
  late bool _active = widget.branch?.isActive ?? true;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _code, _address, _city, _phone, _email]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(organizationRepositoryProvider)
          .saveBranch(
            id: widget.branch?.id,
            organizationId: widget.organizationId,
            values: {
              'name': _name.text.trim(),
              'code': Validators.clean(_code.text),
              'address_line': Validators.clean(_address.text),
              'city': Validators.clean(_city.text),
              'phone': Validators.clean(_phone.text),
              'email': Validators.clean(_email.text),
              'manager_employee_id': _managerId,
              'is_head_office': _headOffice,
              'is_active': _active,
            },
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppSnack(context, friendlyError(error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final people = ref.watch(employeePickerProvider).valueOrNull ?? const [];
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: _name,
            label: 'Branch name *',
            autofocus: true,
            validator: Validators.requiredField('Branch name'),
          ),
          const SizedBox(height: 16),
          AppTextField(controller: _code, label: 'Code', hint: 'e.g. DHK-01'),
          const SizedBox(height: 16),
          AppTextField(controller: _address, label: 'Address'),
          const SizedBox(height: 16),
          AppTextField(controller: _city, label: 'City'),
          const SizedBox(height: 16),
          AppTextField(
            controller: _phone,
            label: 'Phone',
            keyboardType: TextInputType.phone,
            validator: Validators.optionalPhone,
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _email,
            label: 'Email',
            keyboardType: TextInputType.emailAddress,
            validator: Validators.optionalEmail,
          ),
          const SizedBox(height: 16),
          AppSelectField<String>(
            label: 'Branch manager',
            value: _managerId,
            options: [
              for (final p in people)
                SelectOption(p.id, p.fullName, subtitle: p.designationTitle),
            ],
            onChanged: (v) => setState(() => _managerId = v),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Head office'),
            value: _headOffice,
            onChanged: (v) => setState(() => _headOffice = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Active'),
            subtitle: const Text(
              'Inactive branches cannot be picked for new people.',
            ),
            value: _active,
            onChanged: (v) => setState(() => _active = v),
          ),
          FormActions(
            submitLabel: widget.branch == null ? 'Add branch' : 'Save',
            loading: _saving,
            onSubmit: _submit,
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------- departments
class _DepartmentsTab extends ConsumerWidget {
  const _DepartmentsTab();

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    Department? department,
  ) async {
    final appContext = ref.read(currentContextProvider);
    if (appContext == null) return;
    final saved = await showAdaptiveForm<bool>(
      context,
      title: department == null ? 'Add department' : 'Edit department',
      child: _DepartmentForm(
        department: department,
        organizationId: appContext.organization.id,
      ),
    );
    if (saved == true) ref.invalidate(departmentsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final departments = ref.watch(departmentsProvider);
    return departments.when(
      loading: () => const SkeletonList(count: 4, itemHeight: 66),
      error: (error, _) => ErrorState(
        error: error,
        onRetry: () => ref.invalidate(departmentsProvider),
      ),
      data: (list) {
        final names = {for (final d in list) d.id: d.name};
        return _ListCard(
          title: 'Departments',
          subtitle: '${list.length} in total',
          addLabel: 'Add department',
          onAdd: () => _edit(context, ref, null),
          emptyTitle: 'No departments yet',
          emptyMessage:
              'Group your people into departments such as HR or Sales.',
          rows: [
            for (final d in list)
              _Row(
                icon: Icons.account_tree_outlined,
                title: d.name,
                subtitle: [
                  d.code,
                  if (d.parentDepartmentId != null)
                    'Under ${names[d.parentDepartmentId] ?? 'another department'}',
                  d.description,
                ].whereType<String>().where((e) => e.isNotEmpty).join('  |  '),
                chips: [if (!d.isActive) const StatusChip(label: 'Inactive')],
                onEdit: () => _edit(context, ref, d),
                onDelete: () => _confirmDelete(
                  context: context,
                  what: 'department',
                  name: d.name,
                  action: () => ref
                      .read(organizationRepositoryProvider)
                      .deleteDepartment(d.id),
                  onDone: () {
                    ref.invalidate(departmentsProvider);
                    ref.invalidate(designationsProvider);
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DepartmentForm extends ConsumerStatefulWidget {
  const _DepartmentForm({
    required this.department,
    required this.organizationId,
  });

  final Department? department;
  final String organizationId;

  @override
  ConsumerState<_DepartmentForm> createState() => _DepartmentFormState();
}

class _DepartmentFormState extends ConsumerState<_DepartmentForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(
    text: widget.department?.name,
  );
  late final TextEditingController _code = TextEditingController(
    text: widget.department?.code,
  );
  late final TextEditingController _description = TextEditingController(
    text: widget.department?.description,
  );
  late String? _headId = widget.department?.headEmployeeId;
  late String? _parentId = widget.department?.parentDepartmentId;
  late bool _active = widget.department?.isActive ?? true;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(organizationRepositoryProvider)
          .saveDepartment(
            id: widget.department?.id,
            organizationId: widget.organizationId,
            values: {
              'name': _name.text.trim(),
              'code': Validators.clean(_code.text),
              'description': Validators.clean(_description.text),
              'head_employee_id': _headId,
              'parent_department_id': _parentId,
              'is_active': _active,
            },
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppSnack(context, friendlyError(error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final people = ref.watch(employeePickerProvider).valueOrNull ?? const [];
    final departments = ref.watch(departmentsProvider).valueOrNull ?? const [];
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: _name,
            label: 'Department name *',
            autofocus: true,
            validator: Validators.requiredField('Department name'),
          ),
          const SizedBox(height: 16),
          AppTextField(controller: _code, label: 'Code'),
          const SizedBox(height: 16),
          AppTextField(
            controller: _description,
            label: 'Description',
            minLines: 2,
            maxLines: 4,
          ),
          const SizedBox(height: 16),
          AppSelectField<String>(
            label: 'Parent department',
            value: _parentId,
            options: [
              for (final d in departments)
                if (d.id != widget.department?.id) SelectOption(d.id, d.name),
            ],
            onChanged: (v) => setState(() => _parentId = v),
          ),
          const SizedBox(height: 16),
          AppSelectField<String>(
            label: 'Department head',
            value: _headId,
            options: [
              for (final p in people)
                SelectOption(p.id, p.fullName, subtitle: p.designationTitle),
            ],
            onChanged: (v) => setState(() => _headId = v),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Active'),
            value: _active,
            onChanged: (v) => setState(() => _active = v),
          ),
          FormActions(
            submitLabel: widget.department == null ? 'Add department' : 'Save',
            loading: _saving,
            onSubmit: _submit,
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------- designations
class _DesignationsTab extends ConsumerWidget {
  const _DesignationsTab();

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    Designation? designation,
  ) async {
    final appContext = ref.read(currentContextProvider);
    if (appContext == null) return;
    final saved = await showAdaptiveForm<bool>(
      context,
      title: designation == null ? 'Add designation' : 'Edit designation',
      child: _DesignationForm(
        designation: designation,
        organizationId: appContext.organization.id,
      ),
    );
    if (saved == true) ref.invalidate(designationsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final designations = ref.watch(designationsProvider);
    final departments = ref.watch(departmentsProvider).valueOrNull ?? const [];
    final names = {for (final d in departments) d.id: d.name};

    return designations.when(
      loading: () => const SkeletonList(count: 4, itemHeight: 66),
      error: (error, _) => ErrorState(
        error: error,
        onRetry: () => ref.invalidate(designationsProvider),
      ),
      data: (list) => _ListCard(
        title: 'Designations',
        subtitle: '${list.length} in total, highest level first',
        addLabel: 'Add designation',
        onAdd: () => _edit(context, ref, null),
        emptyTitle: 'No designations yet',
        emptyMessage: 'Create job titles such as Manager or Sales Executive.',
        rows: [
          for (final d in list)
            _Row(
              icon: Icons.workspace_premium_outlined,
              title: d.title,
              subtitle: [
                'Level ${d.level}',
                if (d.departmentId != null) names[d.departmentId],
                d.description,
              ].whereType<String>().where((e) => e.isNotEmpty).join('  |  '),
              chips: [if (!d.isActive) const StatusChip(label: 'Inactive')],
              onEdit: () => _edit(context, ref, d),
              onDelete: () => _confirmDelete(
                context: context,
                what: 'designation',
                name: d.title,
                action: () => ref
                    .read(organizationRepositoryProvider)
                    .deleteDesignation(d.id),
                onDone: () => ref.invalidate(designationsProvider),
              ),
            ),
        ],
      ),
    );
  }
}

class _DesignationForm extends ConsumerStatefulWidget {
  const _DesignationForm({
    required this.designation,
    required this.organizationId,
  });

  final Designation? designation;
  final String organizationId;

  @override
  ConsumerState<_DesignationForm> createState() => _DesignationFormState();
}

class _DesignationFormState extends ConsumerState<_DesignationForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _title = TextEditingController(
    text: widget.designation?.title,
  );
  late final TextEditingController _description = TextEditingController(
    text: widget.designation?.description,
  );
  late int _level = widget.designation?.level ?? 1;
  late String? _departmentId = widget.designation?.departmentId;
  late bool _active = widget.designation?.isActive ?? true;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(organizationRepositoryProvider)
          .saveDesignation(
            id: widget.designation?.id,
            organizationId: widget.organizationId,
            values: {
              'title': _title.text.trim(),
              'level': _level,
              'department_id': _departmentId,
              'description': Validators.clean(_description.text),
              'is_active': _active,
            },
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppSnack(context, friendlyError(error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final departments = ref.watch(departmentsProvider).valueOrNull ?? const [];
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: _title,
            label: 'Title *',
            autofocus: true,
            validator: Validators.requiredField('Title'),
          ),
          const SizedBox(height: 16),
          AppSelectField<int>(
            label: 'Level',
            value: _level,
            allowClear: false,
            options: [
              for (var i = 1; i <= 10; i++)
                SelectOption(
                  i,
                  'Level $i',
                  subtitle: i == 1
                      ? 'Entry'
                      : i == 10
                      ? 'Top leadership'
                      : null,
                ),
            ],
            onChanged: (v) => setState(() => _level = v ?? _level),
          ),
          const SizedBox(height: 16),
          AppSelectField<String>(
            label: 'Department (optional)',
            value: _departmentId,
            options: [for (final d in departments) SelectOption(d.id, d.name)],
            onChanged: (v) => setState(() => _departmentId = v),
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _description,
            label: 'Description',
            minLines: 2,
            maxLines: 4,
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Active'),
            value: _active,
            onChanged: (v) => setState(() => _active = v),
          ),
          FormActions(
            submitLabel: widget.designation == null
                ? 'Add designation'
                : 'Save',
            loading: _saving,
            onSubmit: _submit,
          ),
        ],
      ),
    );
  }
}
