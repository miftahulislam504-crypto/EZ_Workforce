import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/errors.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/display.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/states.dart';
import '../../data/models/access_models.dart';
import '../../data/models/options.dart';
import '../../data/models/permissions.dart';
import '../../data/providers.dart';

class RolesScreen extends ConsumerWidget {
  const RolesScreen({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final appContext = ref.read(currentContextProvider);
    if (appContext == null) return;
    final saved = await showRoleForm(
      context,
      organizationId: appContext.organization.id,
    );
    if (saved == true) ref.invalidate(rolesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appContext = ref.watch(currentContextProvider);
    final roles = ref.watch(rolesProvider);
    final catalog =
        ref.watch(permissionCatalogProvider).valueOrNull ?? const [];
    final canManage = appContext?.can(Perm.rolesManage) ?? false;

    return PageScroll(
      onRefresh: () async {
        ref.invalidate(rolesProvider);
        ref.invalidate(permissionCatalogProvider);
      },
      children: [
        PageHeader(
          title: 'Roles and access',
          subtitle:
              'Decide what each role can see and do, and whose records it '
              'can reach.',
          actions: [
            if (canManage)
              AppButton(
                label: 'New role',
                icon: Icons.add,
                onPressed: () => _create(context, ref),
              ),
          ],
        ),
        roles.when(
          loading: () => ResponsiveGrid(
            minTileWidth: 320,
            children: List.generate(
              4,
              (_) => const SkeletonBox(height: 170, radius: 20),
            ),
          ),
          error: (error, _) => ErrorState(
            error: error,
            onRetry: () => ref.invalidate(rolesProvider),
          ),
          data: (list) => ResponsiveGrid(
            minTileWidth: 320,
            maxColumns: 3,
            children: [
              for (final role in list)
                _RoleCard(role: role, totalPermissions: catalog.length),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.role, required this.totalPermissions});

  final Role role;
  final int totalPermissions;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final permissionText = role.isOwner
        ? 'All permissions'
        : '${role.permissionCodes.length} of $totalPermissions permissions';

    return AppCard(
      onTap: () => context.push('/access/roles/${role.id}'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.brandSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  role.isOwner
                      ? Icons.workspace_premium_outlined
                      : Icons.admin_panel_settings_outlined,
                  color: context.scheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  role.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16.5,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: colors.mutedText),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            role.description ?? 'No description',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: colors.mutedText, height: 1.35),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (role.isOwner)
                const StatusChip(label: 'Owner', tone: StatusTone.brand)
              else if (role.isSystem)
                const StatusChip(label: 'System', tone: StatusTone.info),
              if (role.isDefault)
                const StatusChip(label: 'Default', tone: StatusTone.success),
              StatusChip(label: Role.scopeLabel(role.dataScope)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.verified_outlined, size: 16, color: colors.mutedText),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  permissionText,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.groups_outlined, size: 16, color: colors.mutedText),
              const SizedBox(width: 6),
              Text(
                peopleLabel(role.employeeCount),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "1 person" or "N people". Shared by the roles screens.
String peopleLabel(int count) => count == 1 ? '1 person' : '$count people';

/// Opens the create or edit form for a role. Returns true when saved.
Future<bool?> showRoleForm(
  BuildContext context, {
  required String organizationId,
  Role? role,
}) {
  return showAdaptiveForm<bool>(
    context,
    title: role == null ? 'New role' : 'Edit role details',
    subtitle: role == null
        ? 'You can choose its permissions on the next screen.'
        : null,
    child: _RoleForm(role: role, organizationId: organizationId),
  );
}

class _RoleForm extends ConsumerStatefulWidget {
  const _RoleForm({required this.role, required this.organizationId});

  final Role? role;
  final String organizationId;

  @override
  ConsumerState<_RoleForm> createState() => _RoleFormState();
}

class _RoleFormState extends ConsumerState<_RoleForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(
    text: widget.role?.name,
  );
  late final TextEditingController _description = TextEditingController(
    text: widget.role?.description,
  );
  late String _scope = widget.role?.dataScope ?? 'self';
  bool _saving = false;

  bool get _locked => widget.role?.isOwner ?? false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(accessRepositoryProvider)
          .saveRole(
            id: widget.role?.id,
            organizationId: widget.organizationId,
            name: _name.text.trim(),
            description: Validators.clean(_description.text),
            dataScope: _scope,
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
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: _name,
            label: 'Role name *',
            autofocus: true,
            enabled: !_locked,
            validator: Validators.requiredField('Role name'),
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _description,
            label: 'Description',
            minLines: 2,
            maxLines: 4,
          ),
          const SizedBox(height: 16),
          AppSelectField<String>(
            label: 'Whose records can this role reach',
            value: _scope,
            allowClear: false,
            enabled: !_locked,
            options: [
              for (final s in Options.dataScopes)
                SelectOption(s, Role.scopeLabel(s)),
            ],
            onChanged: (v) => setState(() => _scope = v ?? _scope),
          ),
          FormActions(
            submitLabel: widget.role == null ? 'Create role' : 'Save',
            loading: _saving,
            onSubmit: _submit,
          ),
        ],
      ),
    );
  }
}
