import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/audit_text.dart';
import '../../core/utils/errors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/display.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/states.dart';
import '../../data/models/communication_models.dart';
import '../../data/providers.dart';

class AuditScreen extends ConsumerStatefulWidget {
  const AuditScreen({super.key});

  @override
  ConsumerState<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends ConsumerState<AuditScreen> {
  static const int _pageSize = 40;

  String? _entityType;
  List<AuditEntry> _items = const [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  Object? _error;
  int _requestId = 0;
  final Set<int> _expanded = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
      _expanded.clear();
    });
    try {
      final rows = await ref
          .read(auditRepositoryProvider)
          .list(entityType: _entityType, limit: _pageSize);
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
    if (_loadingMore) return;
    final id = _requestId;
    setState(() => _loadingMore = true);
    try {
      final rows = await ref
          .read(auditRepositoryProvider)
          .list(
            entityType: _entityType,
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

  @override
  Widget build(BuildContext context) {
    return PageScroll(
      maxWidth: 960,
      onRefresh: _load,
      children: [
        const PageHeader(
          title: 'Audit trail',
          subtitle: 'A record of who changed what, and when.',
        ),
        SizedBox(
          width: 320,
          child: AppSelectField<String>(
            label: 'Show',
            value: _entityType,
            hint: 'Everything',
            options: [
              for (final type in AuditText.entityTypes)
                SelectOption(
                  type,
                  AuditText.entityLabel(type).replaceFirstMapped(
                    RegExp(r'^.'),
                    (m) => m.group(0)!.toUpperCase(),
                  ),
                ),
            ],
            onChanged: (value) {
              _entityType = value;
              _load();
            },
          ),
        ),
        const SizedBox(height: 20),
        _buildBody(),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading && _items.isEmpty) {
      return const SkeletonList(count: 6, itemHeight: 64);
    }
    if (_error != null && _items.isEmpty) {
      return ErrorState(error: _error!, onRetry: _load);
    }
    if (_items.isEmpty) {
      return const EmptyState(
        icon: Icons.history,
        title: 'No activity recorded',
        message: 'Changes made by your team will be listed here.',
      );
    }

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: _loading ? 0.5 : 1,
      child: Column(
        children: [
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < _items.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: context.colors.border),
                  _AuditRow(
                    entry: _items[i],
                    expanded: _expanded.contains(_items[i].id),
                    onToggle: () => setState(() {
                      if (!_expanded.add(_items[i].id)) {
                        _expanded.remove(_items[i].id);
                      }
                    }),
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

class _AuditRow extends StatelessWidget {
  const _AuditRow({
    required this.entry,
    required this.expanded,
    required this.onToggle,
  });

  final AuditEntry entry;
  final bool expanded;
  final VoidCallback onToggle;

  StatusTone get _tone => switch (entry.action) {
    'create' || 'insert' => StatusTone.success,
    'delete' => StatusTone.danger,
    _ => StatusTone.info,
  };

  IconData get _icon => switch (entry.action) {
    'create' || 'insert' => Icons.add_circle_outline,
    'delete' => Icons.remove_circle_outline,
    _ => Icons.edit_outlined,
  };

  /// Field-level changes for updates, as "field: old to new".
  List<_Change> get _changes {
    final raw = entry.changes;
    if (raw is! Map) return const [];
    final result = <_Change>[];
    raw.forEach((key, value) {
      if (value is Map && value.containsKey('new')) {
        result.add(_Change(key.toString(), value['old'], value['new']));
      } else {
        result.add(_Change(key.toString(), null, value));
      }
    });
    return result;
  }

  static String _show(dynamic value) {
    if (value == null) return 'empty';
    final text = value.toString();
    return text.length > 90 ? '${text.substring(0, 90)}...' : text;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final palette = toneColors(context, _tone);
    final changes = _changes;

    return InkWell(
      onTap: changes.isEmpty ? null : onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: palette.background,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(_icon, size: 20, color: palette.foreground),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AuditText.describe(
                          action: entry.action,
                          entityType: entry.entityType,
                          summary: entry.summary,
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          entry.actorName ?? 'System',
                          Fmt.dateTime(entry.createdAt),
                        ].join('  |  '),
                        style: TextStyle(
                          color: colors.mutedText,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (changes.isNotEmpty)
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: colors.mutedText,
                  ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: expanded
                  ? Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 12, left: 52),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colors.surfaceAlt,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final change in changes.take(24))
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: SelectableText.rich(
                                TextSpan(
                                  style: const TextStyle(
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: '${Fmt.humanize(change.field)}: ',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (entry.action == 'update') ...[
                                      TextSpan(
                                        text: _show(change.oldValue),
                                        style: TextStyle(
                                          color: colors.mutedText,
                                        ),
                                      ),
                                      const TextSpan(text: '  to  '),
                                      TextSpan(text: _show(change.newValue)),
                                    ] else
                                      TextSpan(text: _show(change.newValue)),
                                  ],
                                ),
                              ),
                            ),
                          if (changes.length > 24)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                '${changes.length - 24} more fields not shown',
                                style: TextStyle(
                                  color: colors.mutedText,
                                  fontSize: 12.5,
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
      ),
    );
  }
}

class _Change {
  const _Change(this.field, this.oldValue, this.newValue);

  final String field;
  final dynamic oldValue;
  final dynamic newValue;
}
