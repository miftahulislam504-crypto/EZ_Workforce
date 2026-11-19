import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/errors.dart';
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
import '../../data/models/communication_models.dart';
import '../../data/models/options.dart';
import '../../data/providers.dart';
import 'notice_providers.dart';

enum _PublishMode { now, schedule, draft }

class NoticeFormScreen extends ConsumerStatefulWidget {
  const NoticeFormScreen({super.key, this.noticeId});

  /// Null when writing a new notice.
  final String? noticeId;

  @override
  ConsumerState<NoticeFormScreen> createState() => _NoticeFormScreenState();
}

class _NoticeFormScreenState extends ConsumerState<NoticeFormScreen> {
  static const int _maxAttachments = 5;
  static const int _maxBytes = 15 * 1024 * 1024;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _body = TextEditingController();

  String _category = 'general';
  String _audience = 'all';
  String? _branchId;
  String? _departmentId;
  bool _pinned = false;
  bool _requiresAck = false;
  _PublishMode _mode = _PublishMode.now;
  DateTime? _publishAt;
  DateTime? _expiresAt;
  List<NoticeAttachment> _attachments = [];

  /// Attachments the notice had when the form opened.
  List<NoticeAttachment> _originalAttachments = const [];

  /// Files uploaded during this session that are not saved yet.
  final List<NoticeAttachment> _newFiles = [];

  bool _populated = false;
  bool _saved = false;
  bool _saving = false;
  bool _uploading = false;

  bool get _editing => widget.noticeId != null;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    // Uploaded files that were never saved with the notice are cleaned up.
    if (!_saved && _newFiles.isNotEmpty) {
      ref.read(noticeRepositoryProvider).removeAttachmentFiles(_newFiles);
    }
    super.dispose();
  }

  void _populate(Notice n) {
    _populated = true;
    _title.text = n.title;
    _body.text = n.body;
    _category = n.category;
    _audience = n.audience;
    _branchId = n.branchId;
    _departmentId = n.departmentId;
    _pinned = n.isPinned;
    _requiresAck = n.requiresAck;
    _attachments = [...n.attachments];
    _originalAttachments = [...n.attachments];
    _expiresAt = n.expiresAt;
    if (n.status == 'draft') {
      _mode = _PublishMode.draft;
    } else if (n.isScheduled) {
      _mode = _PublishMode.schedule;
      _publishAt = n.publishAt;
    } else {
      _mode = _PublishMode.now;
    }
  }

  Future<void> _addFile() async {
    final appContext = ref.read(currentContextProvider);
    if (appContext == null) return;
    if (_attachments.length >= _maxAttachments) {
      showAppSnack(
        context,
        'You can attach up to $_maxAttachments files.',
        error: true,
      );
      return;
    }
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
    if (file.bytes == null) return;
    if (file.size > _maxBytes) {
      if (mounted) {
        showAppSnack(context, 'Files can be up to 15 MB.', error: true);
      }
      return;
    }

    setState(() => _uploading = true);
    try {
      final uploaded = await ref
          .read(noticeRepositoryProvider)
          .uploadAttachment(
            organizationId: appContext.organization.id,
            bytes: file.bytes!,
            fileName: file.name,
          );
      if (!mounted) return;
      setState(() {
        _attachments = [..._attachments, uploaded];
        _newFiles.add(uploaded);
      });
    } catch (error) {
      if (mounted) showAppSnack(context, friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _removeFile(NoticeAttachment file) {
    setState(
      () => _attachments = _attachments
          .where((a) => a.path != file.path)
          .toList(),
    );
    // Files that came with the notice are only deleted once the edit is saved.
    final wasNew = _newFiles.any((a) => a.path == file.path);
    if (wasNew) {
      _newFiles.removeWhere((a) => a.path == file.path);
      ref.read(noticeRepositoryProvider).removeAttachmentFiles([file]);
    }
  }

  Future<void> _save() async {
    final appContext = ref.read(currentContextProvider);
    if (appContext == null) return;
    if (!(_formKey.currentState?.validate() ?? false)) {
      showAppSnack(context, 'Please fix the highlighted fields.', error: true);
      return;
    }
    if (_mode == _PublishMode.schedule && _publishAt == null) {
      showAppSnack(
        context,
        'Choose when the notice should go out.',
        error: true,
      );
      return;
    }
    if (_audience == 'branch' && _branchId == null) {
      showAppSnack(context, 'Choose a branch for this notice.', error: true);
      return;
    }
    if (_audience == 'department' && _departmentId == null) {
      showAppSnack(
        context,
        'Choose a department for this notice.',
        error: true,
      );
      return;
    }

    final publishAt = switch (_mode) {
      _PublishMode.schedule => _publishAt!,
      _ => DateTime.now(),
    };
    if (_expiresAt != null && !_expiresAt!.isAfter(publishAt)) {
      showAppSnack(
        context,
        'The expiry must be after the publish time.',
        error: true,
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final values = <String, dynamic>{
        'title': _title.text.trim(),
        'body': _body.text.trim(),
        'category': _category,
        'audience': _audience,
        'branch_id': _audience == 'branch' ? _branchId : null,
        'department_id': _audience == 'department' ? _departmentId : null,
        'is_pinned': _pinned,
        'requires_ack': _requiresAck,
        'status': _mode == _PublishMode.draft ? 'draft' : 'published',
        'publish_at': publishAt.toUtc().toIso8601String(),
        'expires_at': _expiresAt?.toUtc().toIso8601String(),
        'attachments': _attachments.map((a) => a.toJson()).toList(),
      };
      if (!_editing) values['organization_id'] = appContext.organization.id;

      final removed = _originalAttachments
          .where((a) => !_attachments.any((b) => b.path == a.path))
          .toList();

      final saved = await ref
          .read(noticeRepositoryProvider)
          .save(id: widget.noticeId, values: values);
      _saved = true;
      await ref.read(noticeRepositoryProvider).removeAttachmentFiles(removed);
      ref.invalidate(noticeDetailProvider(saved.id));
      if (!mounted) return;

      showAppSnack(context, switch (_mode) {
        _PublishMode.draft => 'Draft saved.',
        _PublishMode.schedule => 'Notice scheduled.',
        _PublishMode.now => _editing ? 'Notice updated.' : 'Notice published.',
      });
      context.go('/notices/${saved.id}');
    } catch (error) {
      if (!mounted) return;
      showAppSnack(context, friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_editing && !_populated) {
      final existing = ref.watch(noticeDetailProvider(widget.noticeId!));
      return existing.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorState(
          error: error,
          onRetry: () => ref.invalidate(noticeDetailProvider(widget.noticeId!)),
        ),
        data: (notice) {
          if (notice == null) {
            return EmptyState(
              icon: Icons.campaign_outlined,
              title: 'Notice not found',
              action: AppButton(
                label: 'Back to notices',
                variant: AppButtonVariant.secondary,
                onPressed: () => context.go('/notices'),
              ),
            );
          }
          _populate(notice);
          return _buildForm();
        },
      );
    }
    return _buildForm();
  }

  String get _submitLabel => switch (_mode) {
    _PublishMode.draft => 'Save draft',
    _PublishMode.schedule => 'Schedule notice',
    _PublishMode.now => _editing ? 'Save changes' : 'Publish notice',
  };

  Widget _buildForm() {
    final branches = ref.watch(branchesProvider).valueOrNull ?? const [];
    final departments = ref.watch(departmentsProvider).valueOrNull ?? const [];
    final fallback = _editing ? '/notices/${widget.noticeId}' : '/notices';
    final colors = context.colors;

    return Form(
      key: _formKey,
      child: PageScroll(
        maxWidth: 860,
        children: [
          PageHeader(
            title: _editing ? 'Edit notice' : 'New notice',
            subtitle: 'Write once and reach the right people instantly.',
            leading: PageBackButton(fallback: fallback),
          ),
          Reveal(
            child: AppCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppTextField(
                    controller: _title,
                    label: 'Title *',
                    maxLength: 140,
                    validator: Validators.requiredField('Title'),
                  ),
                  const SizedBox(height: 16),
                  AppSelectField<String>(
                    label: 'Category',
                    value: _category,
                    allowClear: false,
                    options: Options.select(Options.noticeCategories),
                    onChanged: (v) =>
                        setState(() => _category = v ?? _category),
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _body,
                    label: 'Message *',
                    minLines: 7,
                    maxLines: 16,
                    validator: Validators.requiredField('Message'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Reveal(
            index: 1,
            child: AppCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionTitle('Audience'),
                  AppSelectField<String>(
                    label: 'Who should see this',
                    value: _audience,
                    allowClear: false,
                    options: const [
                      SelectOption('all', 'Everyone'),
                      SelectOption('branch', 'One branch'),
                      SelectOption('department', 'One department'),
                    ],
                    onChanged: (v) => setState(() {
                      _audience = v ?? 'all';
                      _branchId = null;
                      _departmentId = null;
                    }),
                  ),
                  if (_audience == 'branch') ...[
                    const SizedBox(height: 16),
                    AppSelectField<String>(
                      label: 'Branch *',
                      value: _branchId,
                      allowClear: false,
                      options: [
                        for (final b in branches) SelectOption(b.id, b.name),
                      ],
                      onChanged: (v) => setState(() => _branchId = v),
                    ),
                  ],
                  if (_audience == 'department') ...[
                    const SizedBox(height: 16),
                    AppSelectField<String>(
                      label: 'Department *',
                      value: _departmentId,
                      allowClear: false,
                      options: [
                        for (final d in departments) SelectOption(d.id, d.name),
                      ],
                      onChanged: (v) => setState(() => _departmentId = v),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Reveal(
            index: 2,
            child: AppCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionTitle('Delivery'),
                  SegmentedButton<_PublishMode>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: _PublishMode.now,
                        label: Text('Publish now'),
                        icon: Icon(Icons.send_outlined, size: 18),
                      ),
                      ButtonSegment(
                        value: _PublishMode.schedule,
                        label: Text('Schedule'),
                        icon: Icon(Icons.schedule_outlined, size: 18),
                      ),
                      ButtonSegment(
                        value: _PublishMode.draft,
                        label: Text('Draft'),
                        icon: Icon(Icons.edit_note_outlined, size: 18),
                      ),
                    ],
                    selected: {_mode},
                    onSelectionChanged: (s) => setState(() => _mode = s.first),
                  ),
                  if (_mode == _PublishMode.schedule) ...[
                    const SizedBox(height: 16),
                    AppDateField(
                      label: 'Send at *',
                      value: _publishAt,
                      withTime: true,
                      allowClear: false,
                      firstDate: DateTime.now(),
                      onChanged: (v) => setState(() => _publishAt = v),
                      validator: (v) => v == null
                          ? 'Choose a date and time'
                          : (v.isBefore(DateTime.now())
                                ? 'Choose a time in the future'
                                : null),
                    ),
                  ],
                  if (_mode == _PublishMode.draft)
                    const Padding(
                      padding: EdgeInsets.only(top: 14),
                      child: InlineBanner(
                        message:
                            'Drafts are only visible to people who manage '
                            'notices. Nobody is notified.',
                      ),
                    ),
                  const SizedBox(height: 16),
                  AppDateField(
                    label: 'Expires on (optional)',
                    value: _expiresAt,
                    withTime: true,
                    firstDate: DateTime.now(),
                    onChanged: (v) => setState(() => _expiresAt = v),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _pinned,
                    onChanged: (v) => setState(() => _pinned = v),
                    title: const Text('Pin to the top'),
                    subtitle: const Text('Pinned notices stay above the rest.'),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _requiresAck,
                    onChanged: (v) => setState(() => _requiresAck = v),
                    title: const Text('Require acknowledgement'),
                    subtitle: const Text(
                      'People must confirm they have read it, and you can '
                      'see who did.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Reveal(
            index: 3,
            child: AppCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionTitle(
                    'Attachments',
                    trailing: AppButton(
                      label: 'Add file',
                      icon: Icons.attach_file,
                      compact: true,
                      variant: AppButtonVariant.secondary,
                      loading: _uploading,
                      onPressed: _addFile,
                    ),
                  ),
                  if (_attachments.isEmpty)
                    Text(
                      'No files attached. PDF, images and Office files up to '
                      '15 MB each.',
                      style: TextStyle(color: colors.mutedText),
                    )
                  else
                    for (final file in _attachments)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.insert_drive_file_outlined),
                        title: Text(
                          file.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          tooltip: 'Remove',
                          icon: const Icon(Icons.close),
                          onPressed: () => _removeFile(file),
                        ),
                      ),
                ],
              ),
            ),
          ),
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
                label: _submitLabel,
                icon: Icons.check,
                loading: _saving,
                onPressed: _uploading ? null : _save,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
