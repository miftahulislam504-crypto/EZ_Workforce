import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/errors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/back_button.dart';
import '../../core/widgets/display.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/states.dart';
import '../../data/models/access_models.dart';
import '../../data/models/employee_models.dart';
import '../../data/models/options.dart';
import '../../data/models/permissions.dart';
import '../../data/providers.dart';
import 'employee_profile_tabs.dart';
import 'employee_providers.dart';
import 'employee_widgets.dart';

/// The signed-in person's own profile.
class MyProfileScreen extends ConsumerWidget {
  const MyProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appContext = ref.watch(currentContextProvider);
    if (appContext == null) return const LoadingView();
    return EmployeeProfileScreen(
      employeeId: appContext.employee.id,
      ownProfileRoute: true,
    );
  }
}

class EmployeeProfileScreen extends ConsumerStatefulWidget {
  const EmployeeProfileScreen({
    super.key,
    required this.employeeId,
    this.ownProfileRoute = false,
  });

  final String employeeId;

  /// True for the "My profile" page, which has no back button.
  final bool ownProfileRoute;

  @override
  ConsumerState<EmployeeProfileScreen> createState() =>
      _EmployeeProfileScreenState();
}

enum _Tab { overview, employment, documents, onboarding, sensitive }

class _EmployeeProfileScreenState extends ConsumerState<EmployeeProfileScreen> {
  _Tab _tab = _Tab.overview;
  bool _uploadingPhoto = false;

  String get _id => widget.employeeId;

  void _refreshAll() {
    ref.invalidate(employeeDetailProvider(_id));
    ref.invalidate(directoryEntryProvider(_id));
  }

  Future<void> _changePhoto({required bool isSelf}) async {
    final appContext = ref.read(currentContextProvider);
    if (appContext == null) return;
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 900,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    if (bytes.length > 5 * 1024 * 1024) {
      showAppSnack(context, 'Choose a photo smaller than 5 MB.', error: true);
      return;
    }

    setState(() => _uploadingPhoto = true);
    try {
      await ref
          .read(employeeRepositoryProvider)
          .uploadPhoto(
            organizationId: appContext.organization.id,
            employeeId: _id,
            isSelf: isSelf,
            bytes: bytes,
            fileName: file.name,
          );
      _refreshAll();
      ref.invalidate(employeePickerProvider);
      if (isSelf) await ref.read(appContextProvider.notifier).reload();
      if (mounted) showAppSnack(context, 'Photo updated.');
    } catch (error) {
      if (mounted) showAppSnack(context, friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _newInvite(Employee employee) async {
    try {
      final code = await ref
          .read(employeeRepositoryProvider)
          .regenerateInvite(employee.id);
      ref.invalidate(employeeDetailProvider(_id));
      if (!mounted) return;
      await showInviteCodeDialog(
        context,
        employeeName: employee.fullName,
        code: code,
      );
    } catch (error) {
      if (mounted) showAppSnack(context, friendlyError(error), error: true);
    }
  }

  Future<void> _toggleArchive(Employee employee) async {
    final archiving = !employee.isArchived;
    final confirmed = await confirmAction(
      context,
      title: archiving ? 'Archive employee' : 'Restore employee',
      message: archiving
          ? '${employee.fullName} will lose access and disappear from the '
                'directory. Their records are kept and you can restore them '
                'later.'
          : '${employee.fullName} will get their access back.',
      confirmLabel: archiving ? 'Archive' : 'Restore',
      destructive: archiving,
    );
    if (!confirmed) return;
    try {
      await ref
          .read(employeeRepositoryProvider)
          .archive(employee.id, archive: archiving);
      _refreshAll();
      ref.invalidate(employeePickerProvider);
      if (mounted) {
        showAppSnack(
          context,
          archiving ? 'Employee archived.' : 'Employee restored.',
        );
      }
    } catch (error) {
      if (mounted) showAppSnack(context, friendlyError(error), error: true);
    }
  }

  Future<void> _launch(Uri uri) async {
    final ok = await launchUrl(uri);
    if (!ok && mounted) {
      showAppSnack(context, 'Could not open this link.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appContext = ref.watch(currentContextProvider);
    if (appContext == null) return const LoadingView();

    final entryAsync = ref.watch(directoryEntryProvider(_id));
    final fullAsync = ref.watch(employeeDetailProvider(_id));

    if (entryAsync.isLoading && !entryAsync.hasValue ||
        fullAsync.isLoading && !fullAsync.hasValue) {
      return const LoadingView();
    }
    if (entryAsync.hasError && !entryAsync.hasValue) {
      return ErrorState(error: entryAsync.error!, onRetry: _refreshAll);
    }

    final entry = entryAsync.valueOrNull;
    final full = fullAsync.valueOrNull;
    if (entry == null && full == null) {
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

    final isSelf = _id == appContext.employee.id;
    final canEdit = appContext.can(Perm.employeesEdit) && full != null;
    final canArchive =
        appContext.can(Perm.employeesArchive) && full != null && !isSelf;
    final canManageDocs =
        appContext.can(Perm.employeesDocuments) && full != null;
    final canManageOnboarding =
        appContext.can(Perm.onboardingManage) && full != null;
    final canEditPrivate =
        appContext.can(Perm.employeesEditPrivate) && full != null;
    final canPhoto = full != null && (isSelf || canEdit);

    final view = _ProfileView(
      id: _id,
      fullName: entry?.fullName ?? full!.fullName,
      photoPath: entry?.photoPath ?? full?.photoPath,
      designation: entry?.designationTitle,
      department: entry?.departmentName,
      branch: entry?.branchName,
      status: entry?.status ?? full!.status,
      type: entry?.employeeType ?? full!.employeeType,
      code: entry?.employeeCode ?? full!.employeeCode,
      workEmail: entry?.workEmail ?? full?.workEmail,
      workPhone: entry?.workPhone ?? full?.workPhone,
      managerName: entry?.managerName,
      joiningDate: entry?.joiningDate ?? full?.joiningDate,
    );

    final tabs = <_Tab>[
      _Tab.overview,
      _Tab.employment,
      if (full != null && (isSelf || appContext.can(Perm.employeesDocuments)))
        _Tab.documents,
      if (full != null &&
          (isSelf ||
              appContext.can(Perm.onboardingManage) ||
              appContext.can(Perm.employeesView)))
        _Tab.onboarding,
      if (full != null && (isSelf || appContext.can(Perm.employeesViewPrivate)))
        _Tab.sensitive,
    ];
    final tab = tabs.contains(_tab) ? _tab : _Tab.overview;

    return PageScroll(
      onRefresh: () async => _refreshAll(),
      children: [
        PageHeader(
          title: widget.ownProfileRoute ? 'My profile' : 'Employee profile',
          leading: widget.ownProfileRoute
              ? null
              : const PageBackButton(fallback: '/employees'),
          actions: [
            if (isSelf && !widget.ownProfileRoute)
              AppButton(
                label: 'Open my profile',
                variant: AppButtonVariant.secondary,
                onPressed: () => context.go('/profile'),
              ),
            if (canEdit)
              AppButton(
                label: 'Edit',
                icon: Icons.edit_outlined,
                onPressed: () => context.push('/employees/$_id/edit'),
              ),
            if (full != null &&
                (canArchive || (canEdit && !full.hasLogin && !full.isArchived)))
              PopupMenuButton<String>(
                tooltip: 'More actions',
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                onSelected: (value) {
                  if (value == 'invite') _newInvite(full);
                  if (value == 'archive') _toggleArchive(full);
                },
                itemBuilder: (context) => [
                  if (canEdit && !full.hasLogin && !full.isArchived)
                    const PopupMenuItem(
                      value: 'invite',
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.vpn_key_outlined),
                        title: Text('New invitation code'),
                      ),
                    ),
                  if (canArchive)
                    PopupMenuItem(
                      value: 'archive',
                      child: ListTile(
                        dense: true,
                        leading: Icon(
                          full.isArchived
                              ? Icons.unarchive_outlined
                              : Icons.archive_outlined,
                        ),
                        title: Text(
                          full.isArchived
                              ? 'Restore employee'
                              : 'Archive employee',
                        ),
                      ),
                    ),
                ],
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    border: Border.all(color: context.colors.border),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Icon(Icons.more_horiz),
                ),
              ),
          ],
        ),
        Reveal(
          child: _HeaderCard(
            view: view,
            full: full,
            canPhoto: canPhoto,
            uploading: _uploadingPhoto,
            onPhoto: () => _changePhoto(isSelf: isSelf),
            onEmail: view.workEmail == null
                ? null
                : () => _launch(Uri(scheme: 'mailto', path: view.workEmail)),
            onCall: view.workPhone == null
                ? null
                : () => _launch(Uri(scheme: 'tel', path: view.workPhone)),
          ),
        ),
        const SizedBox(height: 20),
        if (tabs.length > 1) ...[
          _TabStrip(
            tabs: tabs,
            selected: tab,
            onChanged: (value) => setState(() => _tab = value),
          ),
          const SizedBox(height: 20),
        ],
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          child: KeyedSubtree(
            key: ValueKey<_Tab>(tab),
            child: switch (tab) {
              _Tab.overview => _OverviewTab(view: view, full: full),
              _Tab.employment => _EmploymentTab(
                view: view,
                full: full,
                canSeeInvite: canEdit,
                onNewInvite: full == null ? null : () => _newInvite(full),
              ),
              _Tab.documents => DocumentsTab(
                employeeId: _id,
                canManage: canManageDocs,
              ),
              _Tab.onboarding => OnboardingTab(
                employeeId: _id,
                canManage: canManageOnboarding,
                isSelf: isSelf,
              ),
              _Tab.sensitive => SensitiveTab(
                employeeId: _id,
                canEdit: canEditPrivate,
              ),
            },
          ),
        ),
      ],
    );
  }
}

/// Values shown in the header and tabs, merged from the directory entry
/// (always visible) and the full record (only when permitted).
class _ProfileView {
  const _ProfileView({
    required this.id,
    required this.fullName,
    required this.status,
    required this.type,
    required this.code,
    this.photoPath,
    this.designation,
    this.department,
    this.branch,
    this.workEmail,
    this.workPhone,
    this.managerName,
    this.joiningDate,
  });

  final String id;
  final String fullName;
  final String? photoPath;
  final String? designation;
  final String? department;
  final String? branch;
  final String status;
  final String type;
  final String code;
  final String? workEmail;
  final String? workPhone;
  final String? managerName;
  final DateTime? joiningDate;
}

// ------------------------------------------------------------------- header
class _HeaderCard extends ConsumerWidget {
  const _HeaderCard({
    required this.view,
    required this.full,
    required this.canPhoto,
    required this.uploading,
    required this.onPhoto,
    required this.onEmail,
    required this.onCall,
  });

  final _ProfileView view;
  final Employee? full;
  final bool canPhoto;
  final bool uploading;
  final VoidCallback onPhoto;
  final VoidCallback? onEmail;
  final VoidCallback? onCall;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final photoUrl = ref
        .read(employeeRepositoryProvider)
        .photoUrl(view.photoPath);

    final avatar = Stack(
      children: [
        UserAvatar(name: view.fullName, imageUrl: photoUrl, size: 104),
        if (uploading)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.4),
              ),
              child: const Center(
                child: SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        if (canPhoto && !uploading)
          Positioned(
            right: 0,
            bottom: 0,
            child: Material(
              color: context.scheme.primary,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onPhoto,
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(
                    Icons.photo_camera_outlined,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          view.fullName,
          style: context.text.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          [view.designation, view.department].whereType<String>().join('  |  '),
          style: TextStyle(color: colors.mutedText, fontSize: 15),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatusChip.employeeStatus(view.status),
            StatusChip(label: Options.label(view.type)),
            StatusChip(label: view.code, icon: Icons.badge_outlined),
            if (full != null) onboardingChip(full!.onboardingStatus),
            if (full?.isArchived ?? false)
              const StatusChip(
                label: 'Archived',
                tone: StatusTone.danger,
                icon: Icons.archive_outlined,
              ),
          ],
        ),
        if (onEmail != null || onCall != null) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (onEmail != null)
                AppButton(
                  label: view.workEmail!,
                  icon: Icons.mail_outline,
                  variant: AppButtonVariant.secondary,
                  compact: true,
                  onPressed: onEmail,
                ),
              if (onCall != null)
                AppButton(
                  label: view.workPhone!,
                  icon: Icons.call_outlined,
                  variant: AppButtonVariant.secondary,
                  compact: true,
                  onPressed: onCall,
                ),
            ],
          ),
        ],
      ],
    );

    return AppCard(
      padding: EdgeInsets.all(context.isMobile ? 20 : 28),
      child: context.isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [avatar, const SizedBox(height: 18), details],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                avatar,
                const SizedBox(width: 26),
                Expanded(child: details),
              ],
            ),
    );
  }
}

// --------------------------------------------------------------------- tabs
class _TabStrip extends StatelessWidget {
  const _TabStrip({
    required this.tabs,
    required this.selected,
    required this.onChanged,
  });

  final List<_Tab> tabs;
  final _Tab selected;
  final ValueChanged<_Tab> onChanged;

  static String _label(_Tab tab) => switch (tab) {
    _Tab.overview => 'Overview',
    _Tab.employment => 'Employment',
    _Tab.documents => 'Documents',
    _Tab.onboarding => 'Onboarding',
    _Tab.sensitive => 'Sensitive',
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final tab in tabs)
              InkWell(
                onTap: () => onChanged(tab),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        width: 3,
                        color: tab == selected
                            ? context.scheme.primary
                            : Colors.transparent,
                      ),
                    ),
                  ),
                  child: Text(
                    _label(tab),
                    style: TextStyle(
                      fontWeight: tab == selected
                          ? FontWeight.w800
                          : FontWeight.w600,
                      color: tab == selected
                          ? context.scheme.primary
                          : colors.mutedText,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.view, required this.full});

  final _ProfileView view;
  final Employee? full;

  @override
  Widget build(BuildContext context) {
    final e = full;
    if (e == null) {
      return AppCard(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle('Work information'),
            DetailGrid(
              items: [
                DetailItem('Employee ID', view.code),
                DetailItem('Designation', view.designation),
                DetailItem('Department', view.department),
                DetailItem('Branch', view.branch),
                DetailItem('Reports to', view.managerName),
                DetailItem('Work email', view.workEmail),
                DetailItem('Work phone', view.workPhone),
                DetailItem('Joined', Fmt.date(view.joiningDate)),
              ],
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('Personal information'),
              DetailGrid(
                items: [
                  DetailItem('Full name', e.fullName),
                  DetailItem(
                    'Date of birth',
                    e.dateOfBirth == null ? null : Fmt.date(e.dateOfBirth),
                  ),
                  DetailItem(
                    'Gender',
                    e.gender == null ? null : Options.label(e.gender!),
                  ),
                  DetailItem('Blood group', e.bloodGroup),
                  DetailItem(
                    'Marital status',
                    e.maritalStatus == null
                        ? null
                        : Options.label(e.maritalStatus!),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        AppCard(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('Contact'),
              DetailGrid(
                items: [
                  DetailItem('Work email', e.workEmail),
                  DetailItem('Work phone', e.workPhone),
                  DetailItem('Personal phone', e.personalPhone),
                  DetailItem('Personal email', e.personalEmail),
                  DetailItem('Present address', e.presentAddress),
                  DetailItem('Permanent address', e.permanentAddress),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        AppCard(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('Emergency contact'),
              DetailGrid(
                items: [
                  DetailItem('Name', e.emergencyContactName),
                  DetailItem('Relationship', e.emergencyContactRelation),
                  DetailItem('Phone', e.emergencyContactPhone),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmploymentTab extends ConsumerWidget {
  const _EmploymentTab({
    required this.view,
    required this.full,
    required this.canSeeInvite,
    required this.onNewInvite,
  });

  final _ProfileView view;
  final Employee? full;
  final bool canSeeInvite;
  final VoidCallback? onNewInvite;

  String _tenure(DateTime from) {
    final now = DateTime.now();
    var months = (now.year - from.year) * 12 + now.month - from.month;
    if (now.day < from.day) months -= 1;
    if (months < 0) return 'Not started yet';
    final years = months ~/ 12;
    final rest = months % 12;
    final parts = [
      if (years > 0) Fmt.plural(years, 'year'),
      if (rest > 0) Fmt.plural(rest, 'month'),
    ];
    return parts.isEmpty ? 'Less than a month' : parts.join(' ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = full;
    final colors = context.colors;
    final roles = ref.watch(rolesProvider).valueOrNull ?? const <Role>[];
    String? roleName;
    if (e != null) {
      for (final role in roles) {
        if (role.id == e.roleId) roleName = role.name;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('Job details'),
              DetailGrid(
                items: [
                  DetailItem('Employee ID', view.code),
                  DetailItem('Employment type', Options.label(view.type)),
                  DetailItem(
                    'Status',
                    null,
                    widget: Align(
                      alignment: Alignment.centerLeft,
                      child: StatusChip.employeeStatus(view.status),
                    ),
                  ),
                  DetailItem('Joining date', Fmt.date(view.joiningDate)),
                  DetailItem(
                    'Time with company',
                    view.joiningDate == null
                        ? null
                        : _tenure(view.joiningDate!),
                  ),
                  DetailItem('Branch', view.branch),
                  DetailItem('Department', view.department),
                  DetailItem('Designation', view.designation),
                  DetailItem('Reports to', view.managerName),
                  DetailItem('Work location', e?.workLocation),
                  if (roleName != null) DetailItem('Access role', roleName),
                ],
              ),
            ],
          ),
        ),
        if (e != null) ...[
          const SizedBox(height: 20),
          AppCard(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('Probation and contract'),
                DetailGrid(
                  items: [
                    DetailItem(
                      'Probation ends',
                      e.probationEndDate == null
                          ? null
                          : Fmt.date(e.probationEndDate),
                    ),
                    DetailItem(
                      'Confirmation date',
                      e.confirmationDate == null
                          ? null
                          : Fmt.date(e.confirmationDate),
                    ),
                    DetailItem(
                      'Contract starts',
                      e.contractStartDate == null
                          ? null
                          : Fmt.date(e.contractStartDate),
                    ),
                    DetailItem(
                      'Contract ends',
                      e.contractEndDate == null
                          ? null
                          : Fmt.date(e.contractEndDate),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          AppCard(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('App access'),
                if (e.hasLogin)
                  Row(
                    children: [
                      Icon(Icons.check_circle_outline, color: colors.success),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          e.activatedAt == null
                              ? 'This person can sign in.'
                              : 'Signed up on ${Fmt.date(e.activatedAt)}.',
                        ),
                      ),
                    ],
                  )
                else ...[
                  Row(
                    children: [
                      Icon(Icons.hourglass_empty, color: colors.warning),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text('Waiting for this person to join the app.'),
                      ),
                    ],
                  ),
                  if (canSeeInvite && e.inviteCode != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: colors.brandSoft,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: SelectableText(
                              e.inviteCode!.toUpperCase(),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 3,
                                color: context.scheme.primary,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Copy code',
                            icon: const Icon(Icons.copy_outlined),
                            onPressed: () async {
                              await Clipboard.setData(
                                ClipboardData(
                                  text: e.inviteCode!.toUpperCase(),
                                ),
                              );
                              if (context.mounted) {
                                showAppSnack(
                                  context,
                                  'Invitation code copied.',
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    if (onNewInvite != null && !e.isArchived)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: AppButton(
                          label: 'Generate new code',
                          icon: Icons.refresh,
                          variant: AppButtonVariant.secondary,
                          compact: true,
                          onPressed: onNewInvite,
                        ),
                      ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
