import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/errors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/back_button.dart';
import '../../core/widgets/banner.dart';
import '../../core/widgets/display.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/states.dart';
import '../../data/models/access_models.dart';
import '../../data/models/permissions.dart';
import '../../data/providers.dart';
import 'roles_screen.dart';

class RoleDetailScreen extends ConsumerStatefulWidget {
  const RoleDetailScreen({super.key, required this.roleId});

  final String roleId;

  @override
  ConsumerState<RoleDetailScreen> createState() => _RoleDetailScreenState();
}

class _RoleDetailScreenState extends ConsumerState<RoleDetailScreen> {
  /// Unsaved selection. Null means "same as the saved role".
  Set<String>? _draft;
  bool _saving = false;

  static const Map<String, String> _scopeHelp = {
    'organization':
        'Can reach records across every branch and department of the '
        'organization.',
    'branch': 'Can reach records of people in their own branch.',
    'department': 'Can reach records of people in their own department.',
    'self': 'Can reach only their own records.',
  };

  Role? _find(List<Role> roles) {
    for (final role in roles) {
      if (role.id == widget.roleId) return role;
    }
    return null;
  }

  bool _isDirty(Role role) {
    final draft = _draft;
    if (draft == null) return false;
    return draft.length != role.permissionCodes.length ||
        !draft.containsAll(role.permissionCodes);
  }

  void _toggle(Role role, String code, bool enabled) {
    final next = {...(_draft ?? role.permissionCodes)};
    if (enabled) {
      next.add(code);
    } else {
      next.remove(code);
    }
    setState(() => _draft = next);
  }

  void _toggleModule(Role role, List<PermissionDef> items, bool enabled) {
    final next = {...(_draft ?? role.permissionCodes)};
    for (final item in items) {
      if (enabled) {
        next.add(item.code);
      } else {
        next.remove(item.code);
      }
    }
    setState(() => _draft = next);
  }

  Future<void> _reloadOwnContextIfNeeded() async {
    final current = ref.read(currentContextProvider);
    if (current != null && current.role.id == widget.roleId) {
      await ref.read(appContextProvider.notifier).reload();
    }
  }

  Future<void> _save(Role role) async {
    final draft = _draft;
    if (draft == null || _saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(accessRepositoryProvider).setPermissions(role.id, draft);
      await ref.refresh(rolesProvider.future);
      await _reloadOwnContextIfNeeded();
      if (!mounted) return;
      setState(() {
        _draft = null;
        _saving = false;
      });
      showAppSnack(context, 'Permissions saved.');
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppSnack(context, friendlyError(error), error: true);
    }
  }

  Future<void> _editDetails(Role role) async {
    final appContext = ref.read(currentContextProvider);
    if (appContext == null) return;
    final saved = await showRoleForm(
      context,
      organizationId: appContext.organization.id,
      role: role,
    );
    if (saved != true) return;
    ref.invalidate(rolesProvider);
    await _reloadOwnContextIfNeeded();
  }

  Future<void> _delete(Role role) async {
    final confirmed = await confirmAction(
      context,
      title: 'Delete role',
      message:
          '"${role.name}" will be removed permanently. This cannot be '
          'undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await ref.read(accessRepositoryProvider).deleteRole(role.id);
      ref.invalidate(rolesProvider);
      if (!mounted) return;
      showAppSnack(context, 'Role deleted.');
      context.go('/access/roles');
    } catch (error) {
      if (mounted) showAppSnack(context, friendlyError(error), error: true);
    }
  }

  Future<void> _discard(Role role) async {
    final confirmed = await confirmAction(
      context,
      title: 'Discard changes',
      message: 'Your unsaved permission changes will be lost.',
      confirmLabel: 'Discard',
      destructive: true,
    );
    if (confirmed && mounted) setState(() => _draft = null);
  }

  @override
  Widget build(BuildContext context) {
    final rolesAsync = ref.watch(rolesProvider);
    final catalogAsync = ref.watch(permissionCatalogProvider);
    final appContext = ref.watch(currentContextProvider);
    final canManage = appContext?.can(Perm.rolesManage) ?? false;

    final roles = rolesAsync.valueOrNull;
    final catalog = catalogAsync.valueOrNull;

    if (roles == null || catalog == null) {
      final error = rolesAsync.error ?? catalogAsync.error;
      return PageScroll(
        maxWidth: 980,
        children: [
          const PageHeader(
            title: 'Role',
            leading: PageBackButton(fallback: '/access/roles'),
          ),
          if (error != null)
            ErrorState(
              error: error,
              onRetry: () {
                ref.invalidate(rolesProvider);
                ref.invalidate(permissionCatalogProvider);
              },
            )
          else ...const [
            SkeletonBox(height: 110, radius: 20),
            SizedBox(height: 16),
            SkeletonBox(height: 360, radius: 20),
          ],
        ],
      );
    }

    final role = _find(roles);
    if (role == null) {
      return PageScroll(
        maxWidth: 980,
        children: [
          const PageHeader(
            title: 'Role',
            leading: PageBackButton(fallback: '/access/roles'),
          ),
          EmptyState(
            icon: Icons.admin_panel_settings_outlined,
            title: 'Role not found',
            message: 'It may have been deleted.',
            action: AppButton(
              label: 'Back to roles',
              variant: AppButtonVariant.secondary,
              onPressed: () => context.go('/access/roles'),
            ),
          ),
        ],
      );
    }

    final editable = canManage && !role.isOwner;
    final dirty = _isDirty(role);
    final selected = _draft ?? role.permissionCodes;
    final canDelete = canManage && !role.isSystem && role.employeeCount == 0;

    final modules = <String, List<PermissionDef>>{};
    final sorted = [...catalog]
      ..sort((a, b) {
        final byOrder = a.sortOrder.compareTo(b.sortOrder);
        return byOrder != 0 ? byOrder : a.code.compareTo(b.code);
      });
    for (final def in sorted) {
      modules.putIfAbsent(def.module, () => []).add(def);
    }

    return PageScroll(
      maxWidth: 980,
      onRefresh: () async {
        ref.invalidate(rolesProvider);
        ref.invalidate(permissionCatalogProvider);
      },
      children: [
        PageHeader(
          title: role.name,
          subtitle: role.description,
          leading: const PageBackButton(fallback: '/access/roles'),
          actions: [
            if (canManage)
              AppButton(
                label: 'Edit details',
                icon: Icons.edit_outlined,
                variant: AppButtonVariant.secondary,
                onPressed: () => _editDetails(role),
              ),
            if (canDelete)
              AppButton(
                label: 'Delete',
                icon: Icons.delete_outline,
                variant: AppButtonVariant.danger,
                onPressed: () => _delete(role),
              ),
          ],
        ),
        _Summary(role: role, totalPermissions: catalog.length),
        if (canManage &&
            !role.isOwner &&
            !role.isSystem &&
            role.employeeCount > 0)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: InlineBanner(
              message:
                  'This role is assigned to people, so it cannot be deleted. '
                  'Move them to another role first.',
            ),
          ),
        const SizedBox(height: 20),
        if (role.isOwner)
          const InlineBanner(
            tone: StatusTone.brand,
            icon: Icons.workspace_premium_outlined,
            message:
                'The Owner role always has every permission and reaches the '
                'whole organization. It cannot be restricted.',
          )
        else if (!canManage)
          const InlineBanner(
            message: 'You can view this role but you cannot change it.',
          ),
        if (role.isOwner || !canManage) const SizedBox(height: 20),
        AppCard(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle(
                'Permissions',
                subtitle: role.isOwner
                    ? 'Every permission is granted.'
                    : '${selected.length} of ${catalog.length} granted',
                trailing: dirty
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppButton(
                            label: 'Discard',
                            variant: AppButtonVariant.ghost,
                            compact: true,
                            onPressed: _saving ? null : () => _discard(role),
                          ),
                          const SizedBox(width: 8),
                          AppButton(
                            label: 'Save',
                            compact: true,
                            loading: _saving,
                            onPressed: () => _save(role),
                          ),
                        ],
                      )
                    : null,
              ),
              for (final entry in modules.entries)
                _ModuleBlock(
                  module: entry.key,
                  items: entry.value,
                  selected: role.isOwner
                      ? {for (final d in catalog) d.code}
                      : selected,
                  editable: editable && !_saving,
                  onToggle: (code, value) => _toggle(role, code, value),
                  onToggleAll: (value) =>
                      _toggleModule(role, entry.value, value),
                ),
              if (dirty) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        AppButton(
                          label: 'Discard',
                          variant: AppButtonVariant.ghost,
                          onPressed: _saving ? null : () => _discard(role),
                        ),
                        AppButton(
                          label: 'Save permissions',
                          loading: _saving,
                          onPressed: () => _save(role),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.role, required this.totalPermissions});

  final Role role;
  final int totalPermissions;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final help = _RoleDetailScreenState._scopeHelp[role.dataScope] ?? '';
    return AppCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (role.isOwner)
                const StatusChip(label: 'Owner', tone: StatusTone.brand)
              else if (role.isSystem)
                const StatusChip(label: 'System role', tone: StatusTone.info)
              else
                const StatusChip(label: 'Custom role'),
              if (role.isDefault)
                const StatusChip(
                  label: 'Default for new people',
                  tone: StatusTone.success,
                ),
            ],
          ),
          const SizedBox(height: 18),
          DetailGrid(
            minColumnWidth: 200,
            items: [
              DetailItem('Data scope', Role.scopeLabel(role.dataScope)),
              DetailItem('Assigned to', peopleLabel(role.employeeCount)),
              DetailItem(
                'Permissions',
                role.isOwner
                    ? 'All permissions'
                    : '${role.permissionCodes.length} of $totalPermissions',
              ),
            ],
          ),
          if (help.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(help, style: TextStyle(color: colors.mutedText, height: 1.4)),
          ],
        ],
      ),
    );
  }
}

class _ModuleBlock extends StatelessWidget {
  const _ModuleBlock({
    required this.module,
    required this.items,
    required this.selected,
    required this.editable,
    required this.onToggle,
    required this.onToggleAll,
  });

  final String module;
  final List<PermissionDef> items;
  final Set<String> selected;
  final bool editable;
  final void Function(String code, bool enabled) onToggle;
  final ValueChanged<bool> onToggleAll;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final granted = items.where((i) => selected.contains(i.code)).length;
    final bool? groupValue = granted == 0
        ? false
        : (granted == items.length ? true : null);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surfaceAlt,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      Fmt.humanize(module),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Text(
                    '$granted / ${items.length}',
                    style: TextStyle(
                      color: colors.mutedText,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Tooltip(
                    message: groupValue == true ? 'Clear all' : 'Select all',
                    child: Checkbox(
                      tristate: true,
                      value: groupValue,
                      onChanged: editable
                          ? (_) => onToggleAll(groupValue != true)
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            for (var i = 0; i < items.length; i++) ...[
              Divider(height: 1, color: colors.border),
              InkWell(
                onTap: editable
                    ? () => onToggle(
                        items[i].code,
                        !selected.contains(items[i].code),
                      )
                    : null,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              items[i].label,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (items[i].description != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  items[i].description!,
                                  style: TextStyle(
                                    color: colors.mutedText,
                                    fontSize: 12.5,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Switch(
                        value: selected.contains(items[i].code),
                        onChanged: editable
                            ? (v) => onToggle(items[i].code, v)
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
