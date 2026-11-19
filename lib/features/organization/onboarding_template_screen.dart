import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/errors.dart';
import '../../core/utils/responsive.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/banner.dart';
import '../../core/widgets/display.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/states.dart';
import '../../data/models/employee_models.dart';
import '../../data/providers.dart';

final _templateProvider =
    FutureProvider.autoDispose<List<OnboardingTemplateItem>>(
      (ref) => ref.watch(employeeRepositoryProvider).templateItems(),
    );

class OnboardingTemplateScreen extends ConsumerStatefulWidget {
  const OnboardingTemplateScreen({super.key});

  @override
  ConsumerState<OnboardingTemplateScreen> createState() =>
      _OnboardingTemplateScreenState();
}

class _OnboardingTemplateScreenState
    extends ConsumerState<OnboardingTemplateScreen> {
  bool _busy = false;

  Future<void> _edit(
    List<OnboardingTemplateItem> items,
    OnboardingTemplateItem? item,
  ) async {
    final appContext = ref.read(currentContextProvider);
    if (appContext == null) return;
    final nextOrder = items.isEmpty
        ? 10
        : items.map((i) => i.sortOrder).reduce((a, b) => a > b ? a : b) + 10;
    final saved = await showAdaptiveForm<bool>(
      context,
      title: item == null ? 'Add checklist item' : 'Edit checklist item',
      child: _ItemForm(
        item: item,
        organizationId: appContext.organization.id,
        sortOrder: nextOrder,
      ),
    );
    if (saved == true) ref.invalidate(_templateProvider);
  }

  Future<void> _delete(OnboardingTemplateItem item) async {
    final confirmed = await confirmAction(
      context,
      title: 'Remove item',
      message:
          '"${item.title}" will no longer be added to new employees. '
          'Existing checklists are not changed.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await ref.read(employeeRepositoryProvider).deleteTemplateItem(item.id);
      ref.invalidate(_templateProvider);
    } catch (error) {
      if (mounted) showAppSnack(context, friendlyError(error), error: true);
    }
  }

  Future<void> _move(
    List<OnboardingTemplateItem> items,
    int index,
    int delta,
  ) async {
    final target = index + delta;
    if (target < 0 || target >= items.length || _busy) return;
    final reordered = [...items];
    final moved = reordered.removeAt(index);
    reordered.insert(target, moved);

    setState(() => _busy = true);
    final appContext = ref.read(currentContextProvider);
    try {
      final repository = ref.read(employeeRepositoryProvider);
      for (var i = 0; i < reordered.length; i++) {
        if (reordered[i].sortOrder != (i + 1) * 10) {
          await repository.saveTemplateItem(
            id: reordered[i].id,
            organizationId: appContext?.organization.id ?? '',
            values: {'sort_order': (i + 1) * 10},
          );
        }
      }
      ref.invalidate(_templateProvider);
    } catch (error) {
      if (mounted) showAppSnack(context, friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleActive(OnboardingTemplateItem item, bool active) async {
    final appContext = ref.read(currentContextProvider);
    try {
      await ref
          .read(employeeRepositoryProvider)
          .saveTemplateItem(
            id: item.id,
            organizationId: appContext?.organization.id ?? '',
            values: {'is_active': active},
          );
      ref.invalidate(_templateProvider);
    } catch (error) {
      if (mounted) showAppSnack(context, friendlyError(error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final template = ref.watch(_templateProvider);
    final colors = context.colors;

    return PageScroll(
      maxWidth: 860,
      onRefresh: () async => ref.invalidate(_templateProvider),
      children: [
        const PageHeader(
          title: 'Onboarding template',
          subtitle: 'The checklist every new employee starts with.',
        ),
        const InlineBanner(
          message:
              'Active items are copied to the checklist of each new employee. '
              'Changes here do not affect people who were already added.',
        ),
        const SizedBox(height: 20),
        template.when(
          loading: () => const SkeletonList(count: 5, itemHeight: 64),
          error: (error, _) => ErrorState(
            error: error,
            onRetry: () => ref.invalidate(_templateProvider),
          ),
          data: (items) => AppCard(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionTitle(
                  'Checklist items',
                  subtitle: '${items.length} in total',
                  trailing: AppButton(
                    label: 'Add item',
                    icon: Icons.add,
                    compact: true,
                    onPressed: () => _edit(items, null),
                  ),
                ),
                if (items.isEmpty)
                  const EmptyState(
                    icon: Icons.checklist_rtl_outlined,
                    title: 'No items yet',
                    message:
                        'Add steps like "Collect documents" or "Issue '
                        'laptop".',
                  )
                else
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: colors.border),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: colors.brandSoft,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Text(
                              '${i + 1}',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: context.scheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Opacity(
                              opacity: items[i].isActive ? 1 : 0.55,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    items[i].title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (items[i].description != null)
                                    Text(
                                      items[i].description!,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: colors.mutedText,
                                        fontSize: 13,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          Switch(
                            value: items[i].isActive,
                            onChanged: (v) => _toggleActive(items[i], v),
                          ),
                          if (context.isMobile)
                            PopupMenuButton<String>(
                              tooltip: 'Actions',
                              onSelected: (value) {
                                switch (value) {
                                  case 'up':
                                    _move(items, i, -1);
                                  case 'down':
                                    _move(items, i, 1);
                                  case 'edit':
                                    _edit(items, items[i]);
                                  case 'remove':
                                    _delete(items[i]);
                                }
                              },
                              itemBuilder: (context) => [
                                if (i > 0)
                                  const PopupMenuItem(
                                    value: 'up',
                                    child: Text('Move up'),
                                  ),
                                if (i < items.length - 1)
                                  const PopupMenuItem(
                                    value: 'down',
                                    child: Text('Move down'),
                                  ),
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit'),
                                ),
                                const PopupMenuItem(
                                  value: 'remove',
                                  child: Text('Remove'),
                                ),
                              ],
                            )
                          else ...[
                            IconButton(
                              tooltip: 'Move up',
                              icon: const Icon(Icons.arrow_upward, size: 19),
                              onPressed: i == 0 || _busy
                                  ? null
                                  : () => _move(items, i, -1),
                            ),
                            IconButton(
                              tooltip: 'Move down',
                              icon: const Icon(Icons.arrow_downward, size: 19),
                              onPressed: i == items.length - 1 || _busy
                                  ? null
                                  : () => _move(items, i, 1),
                            ),
                            IconButton(
                              tooltip: 'Edit',
                              icon: const Icon(Icons.edit_outlined, size: 19),
                              onPressed: () => _edit(items, items[i]),
                            ),
                            IconButton(
                              tooltip: 'Remove',
                              icon: Icon(
                                Icons.delete_outline,
                                size: 19,
                                color: colors.danger,
                              ),
                              onPressed: () => _delete(items[i]),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ItemForm extends ConsumerStatefulWidget {
  const _ItemForm({
    required this.item,
    required this.organizationId,
    required this.sortOrder,
  });

  final OnboardingTemplateItem? item;
  final String organizationId;
  final int sortOrder;

  @override
  ConsumerState<_ItemForm> createState() => _ItemFormState();
}

class _ItemFormState extends ConsumerState<_ItemForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _title = TextEditingController(
    text: widget.item?.title,
  );
  late final TextEditingController _description = TextEditingController(
    text: widget.item?.description,
  );
  late bool _active = widget.item?.isActive ?? true;
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
          .read(employeeRepositoryProvider)
          .saveTemplateItem(
            id: widget.item?.id,
            organizationId: widget.organizationId,
            values: {
              'title': _title.text.trim(),
              'description': Validators.clean(_description.text),
              'is_active': _active,
              if (widget.item == null) 'sort_order': widget.sortOrder,
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
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: _title,
            label: 'Task *',
            autofocus: true,
            validator: Validators.requiredField('Task'),
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _description,
            label: 'Details',
            minLines: 2,
            maxLines: 4,
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Active'),
            subtitle: const Text(
              'Inactive items are skipped for new employees.',
            ),
            value: _active,
            onChanged: (v) => setState(() => _active = v),
          ),
          FormActions(
            submitLabel: widget.item == null ? 'Add item' : 'Save',
            loading: _saving,
            onSubmit: _submit,
          ),
        ],
      ),
    );
  }
}
