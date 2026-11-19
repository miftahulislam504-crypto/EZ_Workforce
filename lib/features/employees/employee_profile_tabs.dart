import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/errors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/banner.dart';
import '../../core/widgets/display.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/states.dart';
import '../../data/models/employee_models.dart';
import '../../data/models/options.dart';
import '../../data/providers.dart';
import 'employee_providers.dart';

String _fileSize(int? bytes) {
  if (bytes == null) return '';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

// ---------------------------------------------------------------- documents
class DocumentsTab extends ConsumerWidget {
  const DocumentsTab({
    super.key,
    required this.employeeId,
    required this.canManage,
  });

  final String employeeId;
  final bool canManage;

  IconData _icon(String type) => switch (type) {
    'cv' => Icons.description_outlined,
    'national_id' => Icons.badge_outlined,
    'photograph' => Icons.image_outlined,
    'education_certificate' => Icons.school_outlined,
    'experience_certificate' => Icons.work_history_outlined,
    'appointment_letter' => Icons.mail_outline,
    'employment_contract' => Icons.gavel_outlined,
    _ => Icons.insert_drive_file_outlined,
  };

  Future<void> _upload(BuildContext context, WidgetRef ref) async {
    final appContext = ref.read(currentContextProvider);
    if (appContext == null) return;
    final done = await showAdaptiveForm<bool>(
      context,
      title: 'Upload document',
      subtitle: 'PDF, image or Word file up to 15 MB.',
      child: _UploadDocumentForm(
        employeeId: employeeId,
        organizationId: appContext.organization.id,
      ),
    );
    if (done == true) {
      ref.invalidate(employeeDocumentsProvider(employeeId));
      if (context.mounted) showAppSnack(context, 'Document uploaded.');
    }
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    EmployeeDocument doc,
  ) async {
    try {
      final url = await ref.read(employeeRepositoryProvider).documentUrl(doc);
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && context.mounted) {
        showAppSnack(context, 'Could not open this file.', error: true);
      }
    } catch (error) {
      if (context.mounted) {
        showAppSnack(context, friendlyError(error), error: true);
      }
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    EmployeeDocument doc,
  ) async {
    final confirmed = await confirmAction(
      context,
      title: 'Delete document',
      message: '"${doc.title}" will be permanently removed.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await ref.read(employeeRepositoryProvider).deleteDocument(doc);
      ref.invalidate(employeeDocumentsProvider(employeeId));
      if (context.mounted) showAppSnack(context, 'Document deleted.');
    } catch (error) {
      if (context.mounted) {
        showAppSnack(context, friendlyError(error), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docs = ref.watch(employeeDocumentsProvider(employeeId));
    final colors = context.colors;
    return AppCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            'Documents',
            trailing: canManage
                ? AppButton(
                    label: 'Upload',
                    icon: Icons.upload_file_outlined,
                    compact: true,
                    onPressed: () => _upload(context, ref),
                  )
                : null,
          ),
          docs.when(
            loading: () => const SkeletonList(count: 3, itemHeight: 60),
            error: (error, _) => ErrorState(
              error: error,
              onRetry: () =>
                  ref.invalidate(employeeDocumentsProvider(employeeId)),
            ),
            data: (list) {
              if (list.isEmpty) {
                return EmptyState(
                  icon: Icons.folder_open_outlined,
                  title: 'No documents yet',
                  message: canManage
                      ? 'Upload CVs, certificates and contracts for this person.'
                      : 'Documents added by HR will appear here.',
                );
              }
              return Column(
                children: [
                  for (var i = 0; i < list.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: colors.border),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: colors.brandSoft,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _icon(list[i].docType),
                              color: context.scheme.primary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  list[i].title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  [
                                    Options.label(list[i].docType),
                                    _fileSize(list[i].fileSize),
                                    Fmt.date(list[i].createdAt),
                                  ].where((e) => e.isNotEmpty).join('  |  '),
                                  style: TextStyle(
                                    color: colors.mutedText,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Open',
                            icon: const Icon(Icons.open_in_new),
                            onPressed: () => _open(context, ref, list[i]),
                          ),
                          if (canManage)
                            IconButton(
                              tooltip: 'Delete',
                              icon: Icon(
                                Icons.delete_outline,
                                color: colors.danger,
                              ),
                              onPressed: () => _delete(context, ref, list[i]),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _UploadDocumentForm extends ConsumerStatefulWidget {
  const _UploadDocumentForm({
    required this.employeeId,
    required this.organizationId,
  });

  final String employeeId;
  final String organizationId;

  @override
  ConsumerState<_UploadDocumentForm> createState() =>
      _UploadDocumentFormState();
}

class _UploadDocumentFormState extends ConsumerState<_UploadDocumentForm> {
  static const int _maxBytes = 15 * 1024 * 1024;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _title = TextEditingController();
  String _type = 'other';
  PlatformFile? _file;
  String? _fileError;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: const [
        'pdf',
        'png',
        'jpg',
        'jpeg',
        'doc',
        'docx',
        'xls',
        'xlsx',
      ],
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    setState(() {
      _file = file;
      _fileError = null;
      if (_title.text.trim().isEmpty) {
        final dot = file.name.lastIndexOf('.');
        _title.text = dot > 0 ? file.name.substring(0, dot) : file.name;
      }
    });
  }

  Future<void> _submit() async {
    final valid = _formKey.currentState?.validate() ?? false;
    final file = _file;
    if (file == null || file.bytes == null) {
      setState(() => _fileError = 'Choose a file to upload');
      return;
    }
    if (file.size > _maxBytes) {
      setState(() => _fileError = 'The file is larger than 15 MB');
      return;
    }
    if (!valid) return;

    setState(() => _saving = true);
    try {
      await ref
          .read(employeeRepositoryProvider)
          .uploadDocument(
            organizationId: widget.organizationId,
            employeeId: widget.employeeId,
            docType: _type,
            title: _title.text.trim(),
            bytes: file.bytes!,
            fileName: file.name,
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
    final colors = context.colors;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSelectField<String>(
            label: 'Document type',
            value: _type,
            allowClear: false,
            options: Options.select(Options.documentTypes),
            onChanged: (v) => setState(() => _type = v ?? _type),
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _title,
            label: 'Title *',
            validator: Validators.requiredField('Title'),
          ),
          const SizedBox(height: 16),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _saving ? null : _pick,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _fileError != null ? colors.danger : colors.border,
                ),
                color: colors.surfaceAlt,
              ),
              child: Row(
                children: [
                  Icon(
                    _file == null
                        ? Icons.cloud_upload_outlined
                        : Icons.insert_drive_file_outlined,
                    color: context.scheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _file == null
                          ? 'Choose a file'
                          : '${_file!.name}  (${_fileSize(_file!.size)})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_fileError != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(
                _fileError!,
                style: TextStyle(color: colors.danger, fontSize: 12.5),
              ),
            ),
          FormActions(
            submitLabel: 'Upload',
            loading: _saving,
            onSubmit: _submit,
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------- onboarding
class OnboardingTab extends ConsumerWidget {
  const OnboardingTab({
    super.key,
    required this.employeeId,
    required this.canManage,
    required this.isSelf,
  });

  final String employeeId;
  final bool canManage;
  final bool isSelf;

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(employeeOnboardingProvider(employeeId));
    ref.invalidate(employeeDetailProvider(employeeId));
    if (isSelf) await ref.read(appContextProvider.notifier).reload();
  }

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    OnboardingItem item,
    bool done,
  ) async {
    try {
      await ref
          .read(employeeRepositoryProvider)
          .setOnboardingDone(item.id, done);
      await _refresh(ref);
    } catch (error) {
      if (context.mounted) {
        showAppSnack(context, friendlyError(error), error: true);
      }
    }
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final appContext = ref.read(currentContextProvider);
    if (appContext == null) return;
    final added = await showAdaptiveForm<bool>(
      context,
      title: 'Add checklist item',
      child: _AddItemForm(
        employeeId: employeeId,
        organizationId: appContext.organization.id,
      ),
    );
    if (added == true) await _refresh(ref);
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    OnboardingItem item,
  ) async {
    final confirmed = await confirmAction(
      context,
      title: 'Remove item',
      message: '"${item.title}" will be removed from this checklist.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await ref.read(employeeRepositoryProvider).deleteOnboardingItem(item.id);
      await _refresh(ref);
    } catch (error) {
      if (context.mounted) {
        showAppSnack(context, friendlyError(error), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(employeeOnboardingProvider(employeeId));
    final colors = context.colors;
    return AppCard(
      padding: const EdgeInsets.all(22),
      child: items.when(
        loading: () => const SkeletonList(count: 4, itemHeight: 52),
        error: (error, _) => ErrorState(
          error: error,
          onRetry: () => ref.invalidate(employeeOnboardingProvider(employeeId)),
        ),
        data: (list) {
          final done = list.where((i) => i.isDone).length;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle(
                'Onboarding checklist',
                trailing: canManage
                    ? AppButton(
                        label: 'Add item',
                        icon: Icons.add,
                        compact: true,
                        variant: AppButtonVariant.secondary,
                        onPressed: () => _add(context, ref),
                      )
                    : null,
              ),
              if (list.isEmpty)
                const EmptyState(
                  icon: Icons.checklist_rtl_outlined,
                  title: 'No checklist items',
                  message:
                      'Items from the onboarding template are added when an '
                      'employee is created.',
                )
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: done / list.length,
                          minHeight: 10,
                          backgroundColor: colors.surfaceAlt,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      '$done of ${list.length}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                if (!canManage)
                  const Padding(
                    padding: EdgeInsets.only(top: 14),
                    child: InlineBanner(
                      message:
                          'HR marks these items as done once they are '
                          'completed.',
                    ),
                  ),
                const SizedBox(height: 8),
                for (final item in list)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: item.isDone,
                    onChanged: canManage
                        ? (value) => _toggle(context, ref, item, value ?? false)
                        : null,
                    title: Text(
                      item.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        decoration: item.isDone
                            ? TextDecoration.lineThrough
                            : null,
                        color: item.isDone ? colors.mutedText : null,
                      ),
                    ),
                    subtitle: item.description == null && !item.isDone
                        ? null
                        : Text(
                            item.isDone
                                ? 'Completed ${Fmt.date(item.doneAt)}'
                                : item.description!,
                          ),
                    secondary: canManage
                        ? IconButton(
                            tooltip: 'Remove',
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () => _delete(context, ref, item),
                          )
                        : null,
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _AddItemForm extends ConsumerStatefulWidget {
  const _AddItemForm({required this.employeeId, required this.organizationId});

  final String employeeId;
  final String organizationId;

  @override
  ConsumerState<_AddItemForm> createState() => _AddItemFormState();
}

class _AddItemFormState extends ConsumerState<_AddItemForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _description = TextEditingController();
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
          .addOnboardingItem(
            organizationId: widget.organizationId,
            employeeId: widget.employeeId,
            title: _title.text.trim(),
            description: Validators.clean(_description.text),
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
            maxLines: 3,
            minLines: 2,
          ),
          FormActions(
            submitLabel: 'Add item',
            loading: _saving,
            onSubmit: _submit,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- sensitive
class SensitiveTab extends ConsumerStatefulWidget {
  const SensitiveTab({
    super.key,
    required this.employeeId,
    required this.canEdit,
  });

  final String employeeId;
  final bool canEdit;

  @override
  ConsumerState<SensitiveTab> createState() => _SensitiveTabState();
}

class _SensitiveTabState extends ConsumerState<SensitiveTab> {
  bool _revealed = false;

  Future<void> _edit(EmployeePrivate? current) async {
    final appContext = ref.read(currentContextProvider);
    if (appContext == null) return;
    final saved = await showAdaptiveForm<bool>(
      context,
      title: 'Edit sensitive details',
      subtitle: 'Identity, bank and mobile banking information.',
      child: _PrivateForm(
        employeeId: widget.employeeId,
        organizationId: appContext.organization.id,
        current: current,
      ),
    );
    if (saved == true) {
      ref.invalidate(employeePrivateProvider(widget.employeeId));
      if (mounted) showAppSnack(context, 'Sensitive details saved.');
    }
  }

  String _show(String? value) {
    if (value == null || value.isEmpty) return '-';
    return _revealed ? value : Fmt.mask(value);
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(employeePrivateProvider(widget.employeeId));
    return AppCard(
      padding: const EdgeInsets.all(22),
      child: data.when(
        loading: () => const SkeletonList(count: 3, itemHeight: 50),
        error: (error, _) => ErrorState(
          error: error,
          onRetry: () =>
              ref.invalidate(employeePrivateProvider(widget.employeeId)),
        ),
        data: (p) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(
              'Sensitive details',
              trailing: Wrap(
                spacing: 8,
                children: [
                  AppButton(
                    label: _revealed ? 'Hide' : 'Show',
                    icon: _revealed
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    compact: true,
                    variant: AppButtonVariant.ghost,
                    onPressed: () => setState(() => _revealed = !_revealed),
                  ),
                  if (widget.canEdit)
                    AppButton(
                      label: 'Edit',
                      icon: Icons.edit_outlined,
                      compact: true,
                      variant: AppButtonVariant.secondary,
                      onPressed: () => _edit(p),
                    ),
                ],
              ),
            ),
            const InlineBanner(
              message:
                  'Only this employee and authorized HR staff can see this '
                  'section. Values are masked until you choose Show.',
            ),
            const SizedBox(height: 20),
            DetailGrid(
              items: [
                DetailItem('National ID', _show(p?.nationalId)),
                DetailItem('Passport number', _show(p?.passportNo)),
                DetailItem('Bank name', p?.bankName),
                DetailItem('Account holder', p?.bankAccountName),
                DetailItem('Account number', _show(p?.bankAccountNumber)),
                DetailItem('Mobile banking provider', p?.mfsProvider),
                DetailItem('Mobile banking number', _show(p?.mfsNumber)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivateForm extends ConsumerStatefulWidget {
  const _PrivateForm({
    required this.employeeId,
    required this.organizationId,
    required this.current,
  });

  final String employeeId;
  final String organizationId;
  final EmployeePrivate? current;

  @override
  ConsumerState<_PrivateForm> createState() => _PrivateFormState();
}

class _PrivateFormState extends ConsumerState<_PrivateForm> {
  static const List<String> _providers = [
    'bKash',
    'Nagad',
    'Rocket',
    'Upay',
    'Other',
  ];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nationalId = TextEditingController(
    text: widget.current?.nationalId,
  );
  late final TextEditingController _passport = TextEditingController(
    text: widget.current?.passportNo,
  );
  late final TextEditingController _bankName = TextEditingController(
    text: widget.current?.bankName,
  );
  late final TextEditingController _accountName = TextEditingController(
    text: widget.current?.bankAccountName,
  );
  late final TextEditingController _accountNumber = TextEditingController(
    text: widget.current?.bankAccountNumber,
  );
  late final TextEditingController _mfsNumber = TextEditingController(
    text: widget.current?.mfsNumber,
  );
  late String? _mfsProvider = widget.current?.mfsProvider;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [
      _nationalId,
      _passport,
      _bankName,
      _accountName,
      _accountNumber,
      _mfsNumber,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(employeeRepositoryProvider)
          .savePrivateData(
            organizationId: widget.organizationId,
            employeeId: widget.employeeId,
            values: {
              'national_id': Validators.clean(_nationalId.text),
              'passport_no': Validators.clean(_passport.text),
              'bank_name': Validators.clean(_bankName.text),
              'bank_account_name': Validators.clean(_accountName.text),
              'bank_account_number': Validators.clean(_accountNumber.text),
              'mfs_provider': _mfsProvider,
              'mfs_number': Validators.clean(_mfsNumber.text),
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
          AppTextField(controller: _nationalId, label: 'National ID'),
          const SizedBox(height: 16),
          AppTextField(controller: _passport, label: 'Passport number'),
          const SizedBox(height: 16),
          AppTextField(controller: _bankName, label: 'Bank name'),
          const SizedBox(height: 16),
          AppTextField(controller: _accountName, label: 'Account holder name'),
          const SizedBox(height: 16),
          AppTextField(
            controller: _accountNumber,
            label: 'Account number',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          AppSelectField<String>(
            label: 'Mobile banking provider',
            value: _mfsProvider,
            options: [for (final p in _providers) SelectOption(p, p)],
            onChanged: (v) => setState(() => _mfsProvider = v),
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _mfsNumber,
            label: 'Mobile banking number',
            keyboardType: TextInputType.phone,
            validator: Validators.optionalPhone,
          ),
          FormActions(
            submitLabel: 'Save details',
            loading: _saving,
            onSubmit: _submit,
          ),
        ],
      ),
    );
  }
}
