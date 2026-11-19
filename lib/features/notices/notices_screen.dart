import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/errors.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/display.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/states.dart';
import '../../data/models/communication_models.dart';
import '../../data/models/options.dart';
import '../../data/models/permissions.dart';
import '../../data/providers.dart';
import 'notice_widgets.dart';

class NoticesScreen extends ConsumerStatefulWidget {
  const NoticesScreen({super.key});

  @override
  ConsumerState<NoticesScreen> createState() => _NoticesScreenState();
}

class _NoticesScreenState extends ConsumerState<NoticesScreen> {
  static const int _pageSize = 20;

  String? _category;
  String? _status;
  List<Notice> _items = const [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  Object? _error;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final appContext = ref.read(currentContextProvider);
    if (appContext == null) return;
    final id = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await ref
          .read(noticeRepositoryProvider)
          .list(
            employeeId: appContext.employee.id,
            category: _category,
            status: _status,
            limit: _pageSize,
          );
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
    final appContext = ref.read(currentContextProvider);
    if (appContext == null || _loadingMore) return;
    final id = _requestId;
    setState(() => _loadingMore = true);
    try {
      final rows = await ref
          .read(noticeRepositoryProvider)
          .list(
            employeeId: appContext.employee.id,
            category: _category,
            status: _status,
            offset: _items.length,
            limit: _pageSize,
          );
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

  Future<void> _open(Notice notice) async {
    await context.push('/notices/${notice.id}');
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final appContext = ref.watch(currentContextProvider);
    final canManage = appContext?.can(Perm.noticesManage) ?? false;

    return PageScroll(
      maxWidth: 960,
      onRefresh: _load,
      children: [
        PageHeader(
          title: 'Notice Board',
          subtitle: canManage
              ? 'Publish announcements and see who has read them.'
              : 'Announcements from your company.',
          actions: [
            if (canManage)
              AppButton(
                label: 'New notice',
                icon: Icons.add,
                onPressed: () => context.push('/notices/new'),
              ),
          ],
        ),
        _Filters(
          category: _category,
          status: _status,
          canManage: canManage,
          onCategory: (value) {
            _category = value;
            _load();
          },
          onStatus: (value) {
            _status = value;
            _load();
          },
        ),
        const SizedBox(height: 20),
        _buildBody(canManage),
      ],
    );
  }

  Widget _buildBody(bool canManage) {
    if (_loading && _items.isEmpty) {
      return const SkeletonList(count: 5, itemHeight: 96);
    }
    if (_error != null && _items.isEmpty) {
      return ErrorState(error: _error!, onRetry: _load);
    }
    if (_items.isEmpty) {
      final filtered = _category != null || _status != null;
      return EmptyState(
        icon: Icons.campaign_outlined,
        title: filtered ? 'No notices match this filter' : 'No notices yet',
        message: filtered
            ? 'Try another category.'
            : canManage
            ? 'Post your first announcement to reach everyone at once.'
            : 'Company announcements will appear here.',
        action: !filtered && canManage
            ? AppButton(
                label: 'Post a notice',
                icon: Icons.add,
                onPressed: () => context.push('/notices/new'),
              )
            : null,
      );
    }

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: _loading ? 0.5 : 1,
      child: Column(
        children: [
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: Column(
              children: [
                for (var i = 0; i < _items.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: context.colors.border),
                  NoticeTile(
                    notice: _items[i],
                    showStatus: canManage,
                    onTap: () => _open(_items[i]),
                  ),
                ],
              ],
            ),
          ),
          if (_hasMore)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: AppButton(
                label: 'Load more',
                icon: Icons.expand_more,
                variant: AppButtonVariant.secondary,
                loading: _loadingMore,
                onPressed: _loadMore,
              ),
            ),
        ],
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.category,
    required this.status,
    required this.canManage,
    required this.onCategory,
    required this.onStatus,
  });

  final String? category;
  final String? status;
  final bool canManage;
  final ValueChanged<String?> onCategory;
  final ValueChanged<String?> onStatus;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Widget chip(String label, bool selected, VoidCallback onTap) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: InkWell(
          borderRadius: BorderRadius.circular(99),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: selected ? context.scheme.primary : colors.surfaceAlt,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
                color: selected ? context.scheme.onPrimary : colors.mutedText,
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              chip('All', category == null, () => onCategory(null)),
              for (final c in Options.noticeCategories)
                chip(Options.label(c), category == c, () => onCategory(c)),
            ],
          ),
        ),
        if (canManage) ...[
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                chip('Any status', status == null, () => onStatus(null)),
                chip(
                  'Published',
                  status == 'published',
                  () => onStatus('published'),
                ),
                chip('Drafts', status == 'draft', () => onStatus('draft')),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
