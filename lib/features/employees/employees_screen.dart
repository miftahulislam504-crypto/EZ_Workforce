import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/errors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/display.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/states.dart';
import '../../data/models/employee_models.dart';
import '../../data/models/options.dart';
import '../../data/models/permissions.dart';
import '../../data/providers.dart';
import '../../data/repositories/employee_repository.dart';

class EmployeesScreen extends ConsumerStatefulWidget {
  const EmployeesScreen({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  ConsumerState<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends ConsumerState<EmployeesScreen> {
  static const int _pageSize = 24;

  final TextEditingController _search = TextEditingController();
  Timer? _debounce;
  DirectoryFilter _filter = const DirectoryFilter();
  List<DirectoryEntry> _items = const [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  bool _showFilters = false;
  bool _exporting = false;
  bool? _grid;
  Object? _error;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _search.text = widget.initialQuery;
    _filter = DirectoryFilter(query: widget.initialQuery);
    _load();
  }

  @override
  void didUpdateWidget(covariant EmployeesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The top bar search can open this page again with a new query.
    if (oldWidget.initialQuery != widget.initialQuery) {
      _search.text = widget.initialQuery;
      _apply(_filter.copyWith(query: widget.initialQuery));
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _apply(DirectoryFilter next) {
    _filter = next;
    _load();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _apply(_filter.copyWith(query: value.trim()));
    });
  }

  Future<void> _load() async {
    final id = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await ref
          .read(employeeRepositoryProvider)
          .searchDirectory(_filter, limit: _pageSize);
      if (!mounted || id != _requestId) return;
      setState(() {
        _items = rows;
        _hasMore = rows.length == _pageSize;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    final id = _requestId;
    setState(() => _loadingMore = true);
    try {
      final rows = await ref
          .read(employeeRepositoryProvider)
          .searchDirectory(_filter, offset: _items.length, limit: _pageSize);
      if (!mounted || id != _requestId) return;
      setState(() {
        _items = [..._items, ...rows];
        _hasMore = rows.length == _pageSize;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      showAppSnack(context, friendlyError(error), error: true);
    }
  }

  void _clearFilters() {
    _search.clear();
    _apply(const DirectoryFilter());
  }

  // ----------------------------------------------------------- CSV export
  static String _cell(String? value) {
    var text = value ?? '';
    final risky =
        text.isNotEmpty &&
        (text.startsWith('=') ||
            text.startsWith('@') ||
            ((text.startsWith('+') || text.startsWith('-')) &&
                !RegExp(r'^[+-][0-9 ()\-]+$').hasMatch(text)));
    if (risky) text = "'$text";
    if (text.contains(RegExp(r'[",\n\r]'))) {
      text = '"${text.replaceAll('"', '""')}"';
    }
    return text;
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final rows = await ref
          .read(employeeRepositoryProvider)
          .exportRows(_filter);
      final branches = {
        for (final b in await ref.read(branchesProvider.future)) b.id: b.name,
      };
      final departments = {
        for (final d in await ref.read(departmentsProvider.future))
          d.id: d.name,
      };
      final designations = {
        for (final d in await ref.read(designationsProvider.future))
          d.id: d.title,
      };

      const header = [
        'Employee ID',
        'First name',
        'Last name',
        'Status',
        'Employment type',
        'Joining date',
        'Branch',
        'Department',
        'Designation',
        'Work email',
        'Work phone',
        'Personal phone',
        'Gender',
        'Date of birth',
      ];
      final buffer = StringBuffer('\uFEFF')..writeln(header.map(_cell).join(','));
      for (final e in rows) {
        buffer.writeln(
          [
            e.employeeCode,
            e.firstName,
            e.lastName,
            Fmt.humanize(e.status),
            Fmt.humanize(e.employeeType),
            e.joiningDate == null ? '' : Fmt.isoDate(e.joiningDate!),
            branches[e.branchId],
            departments[e.departmentId],
            designations[e.designationId],
            e.workEmail,
            e.workPhone,
            e.personalPhone,
            e.gender == null ? '' : Options.label(e.gender!),
            e.dateOfBirth == null ? '' : Fmt.isoDate(e.dateOfBirth!),
          ].map(_cell).join(','),
        );
      }

      final bytes = Uint8List.fromList(utf8.encode(buffer.toString()));
      await FilePicker.platform.saveFile(
        dialogTitle: 'Save employee list',
        fileName: 'employees_${Fmt.isoDate(DateTime.now())}.csv',
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: const ['csv'],
      );
      if (!mounted) return;
      showAppSnack(
        context,
        'Exported ${Fmt.plural(rows.length, 'employee')} to CSV.',
      );
    } catch (error) {
      if (!mounted) return;
      showAppSnack(context, friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  // ---------------------------------------------------------------- build
  int get _activeFilterCount => [
    _filter.status,
    _filter.branchId,
    _filter.departmentId,
    _filter.employeeType,
  ].where((v) => v != null).length;

  @override
  Widget build(BuildContext context) {
    final appContext = ref.watch(currentContextProvider);
    final canCreate = appContext?.can(Perm.employeesCreate) ?? false;
    final canExport = appContext?.can(Perm.employeesExport) ?? false;
    final grid = _grid ?? !context.isMobile;

    return PageScroll(
      onRefresh: _load,
      children: [
        PageHeader(
          title: 'Employees',
          subtitle: 'Find and manage everyone in your organization',
          actions: [
            if (canExport)
              AppButton(
                label: 'Export CSV',
                icon: Icons.download_outlined,
                variant: AppButtonVariant.secondary,
                loading: _exporting,
                onPressed: _export,
              ),
            if (canCreate)
              AppButton(
                label: 'Add employee',
                icon: Icons.person_add_alt_1_outlined,
                onPressed: () => context.push('/employees/new'),
              ),
          ],
        ),
        _Toolbar(
          controller: _search,
          onSearchChanged: _onSearchChanged,
          filter: _filter,
          showFilters: _showFilters,
          activeFilters: _activeFilterCount,
          grid: grid,
          onToggleFilters: () => setState(() => _showFilters = !_showFilters),
          onGridChanged: (value) => setState(() => _grid = value),
          onFilterChanged: _apply,
        ),
        const SizedBox(height: 20),
        _buildResults(grid),
      ],
    );
  }

  Widget _buildResults(bool grid) {
    if (_loading && _items.isEmpty) {
      return grid
          ? ResponsiveGrid(
              minTileWidth: 300,
              children: List.generate(
                6,
                (_) => const SkeletonBox(height: 150, radius: 20),
              ),
            )
          : const SkeletonList(count: 6);
    }
    if (_error != null && _items.isEmpty) {
      return ErrorState(error: _error!, onRetry: _load);
    }
    if (_items.isEmpty) {
      final filtered = _filter.query.isNotEmpty || _filter.hasFilters;
      return EmptyState(
        icon: Icons.groups_outlined,
        title: filtered ? 'No employees match your search' : 'No employees yet',
        message: filtered
            ? 'Try a different name or clear the filters.'
            : 'People you add will appear here.',
        action: filtered
            ? AppButton(
                label: 'Clear search and filters',
                variant: AppButtonVariant.secondary,
                onPressed: _clearFilters,
              )
            : null,
      );
    }

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: _loading ? 0.5 : 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12, left: 4),
            child: Text(
              _hasMore
                  ? 'Showing ${_items.length} people'
                  : Fmt.plural(_items.length, 'person', 'people'),
              style: TextStyle(color: context.colors.mutedText),
            ),
          ),
          if (grid)
            ResponsiveGrid(
              minTileWidth: 300,
              children: [for (final e in _items) _EmployeeCard(entry: e)],
            )
          else
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  if (context.isDesktop) const _ListHeader(),
                  for (var i = 0; i < _items.length; i++) ...[
                    if (i > 0 || context.isDesktop)
                      Divider(height: 1, color: context.colors.border),
                    _EmployeeRow(entry: _items[i]),
                  ],
                ],
              ),
            ),
          if (_hasMore)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Center(
                child: AppButton(
                  label: 'Load more',
                  icon: Icons.expand_more,
                  variant: AppButtonVariant.secondary,
                  loading: _loadingMore,
                  onPressed: _loadMore,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ toolbar
class _Toolbar extends ConsumerWidget {
  const _Toolbar({
    required this.controller,
    required this.onSearchChanged,
    required this.filter,
    required this.showFilters,
    required this.activeFilters,
    required this.grid,
    required this.onToggleFilters,
    required this.onGridChanged,
    required this.onFilterChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSearchChanged;
  final DirectoryFilter filter;
  final bool showFilters;
  final int activeFilters;
  final bool grid;
  final VoidCallback onToggleFilters;
  final ValueChanged<bool> onGridChanged;
  final ValueChanged<DirectoryFilter> onFilterChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branches = ref.watch(branchesProvider).valueOrNull ?? const [];
    final departments = ref.watch(departmentsProvider).valueOrNull ?? const [];

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: AppSearchField(
                  controller: controller,
                  hint: 'Search by name, ID, email or phone',
                  onChanged: onSearchChanged,
                ),
              ),
              const SizedBox(width: 12),
              Badge(
                isLabelVisible: activeFilters > 0,
                label: Text('$activeFilters'),
                child: AppButton(
                  label: 'Filters',
                  icon: Icons.tune,
                  variant: AppButtonVariant.secondary,
                  onPressed: onToggleFilters,
                ),
              ),
              const SizedBox(width: 12),
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.grid_view_rounded, size: 18),
                    tooltip: 'Card view',
                  ),
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.view_list_rounded, size: 18),
                    tooltip: 'List view',
                  ),
                ],
                selected: {grid},
                onSelectionChanged: (selection) =>
                    onGridChanged(selection.first),
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: showFilters
                ? Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ResponsiveGrid(
                          minTileWidth: 200,
                          maxColumns: 4,
                          children: [
                            AppSelectField<String>(
                              label: 'Status',
                              value: filter.status,
                              options: Options.select(Options.employeeStatuses),
                              onChanged: (v) =>
                                  onFilterChanged(filter.copyWith(status: v)),
                            ),
                            AppSelectField<String>(
                              label: 'Employment type',
                              value: filter.employeeType,
                              options: Options.select(Options.employeeTypes),
                              onChanged: (v) => onFilterChanged(
                                filter.copyWith(employeeType: v),
                              ),
                            ),
                            AppSelectField<String>(
                              label: 'Branch',
                              value: filter.branchId,
                              options: [
                                for (final b in branches)
                                  SelectOption(b.id, b.name),
                              ],
                              onChanged: (v) =>
                                  onFilterChanged(filter.copyWith(branchId: v)),
                            ),
                            AppSelectField<String>(
                              label: 'Department',
                              value: filter.departmentId,
                              options: [
                                for (final d in departments)
                                  SelectOption(d.id, d.name),
                              ],
                              onChanged: (v) => onFilterChanged(
                                filter.copyWith(departmentId: v),
                              ),
                            ),
                          ],
                        ),
                        if (activeFilters > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: AppButton(
                              label: 'Reset filters',
                              icon: Icons.restart_alt,
                              variant: AppButtonVariant.ghost,
                              compact: true,
                              onPressed: () => onFilterChanged(
                                DirectoryFilter(query: filter.query),
                              ),
                            ),
                          ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------- cards
class _EmployeeCard extends ConsumerWidget {
  const _EmployeeCard({required this.entry});

  final DirectoryEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return AppCard(
      onTap: () => context.push('/employees/${entry.id}'),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(
                name: entry.fullName,
                imageUrl: ref
                    .read(employeeRepositoryProvider)
                    .photoUrl(entry.photoPath),
                size: 54,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.designationTitle ?? 'No designation',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.mutedText),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _InfoLine(
            icon: Icons.account_tree_outlined,
            text: entry.departmentName ?? 'No department',
          ),
          const SizedBox(height: 6),
          _InfoLine(
            icon: Icons.location_on_outlined,
            text: entry.branchName ?? 'No branch',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              StatusChip.employeeStatus(entry.status),
              const Spacer(),
              Text(
                entry.employeeCode,
                style: TextStyle(
                  color: colors.mutedText,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: context.colors.mutedText),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13.5),
          ),
        ),
      ],
    );
  }
}

// --------------------------------------------------------------------- list
class _ListHeader extends StatelessWidget {
  const _ListHeader();

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: context.colors.mutedText,
      fontWeight: FontWeight.w700,
      fontSize: 12,
      letterSpacing: 0.6,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text('EMPLOYEE', style: style)),
          Expanded(flex: 2, child: Text('ID', style: style)),
          Expanded(flex: 3, child: Text('DEPARTMENT', style: style)),
          Expanded(flex: 3, child: Text('BRANCH', style: style)),
          Expanded(flex: 2, child: Text('STATUS', style: style)),
        ],
      ),
    );
  }
}

class _EmployeeRow extends ConsumerWidget {
  const _EmployeeRow({required this.entry});

  final DirectoryEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final avatar = UserAvatar(
      name: entry.fullName,
      imageUrl: ref.read(employeeRepositoryProvider).photoUrl(entry.photoPath),
      size: 42,
    );
    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          entry.fullName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        Text(
          entry.designationTitle ?? entry.workEmail ?? 'No designation',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: colors.mutedText, fontSize: 13),
        ),
      ],
    );

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: () => context.push('/employees/${entry.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: context.isDesktop
            ? Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Row(
                      children: [
                        avatar,
                        const SizedBox(width: 12),
                        Expanded(child: identity),
                      ],
                    ),
                  ),
                  Expanded(flex: 2, child: Text(entry.employeeCode)),
                  Expanded(
                    flex: 3,
                    child: Text(
                      entry.departmentName ?? '-',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      entry.branchName ?? '-',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: StatusChip.employeeStatus(entry.status),
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  avatar,
                  const SizedBox(width: 12),
                  Expanded(child: identity),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      StatusChip.employeeStatus(entry.status),
                      const SizedBox(height: 4),
                      Text(
                        entry.employeeCode,
                        style: TextStyle(color: colors.mutedText, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
