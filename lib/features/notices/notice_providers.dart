import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/communication_models.dart';
import '../../data/providers.dart';
import '../../data/repositories/notice_repository.dart';

/// A single notice with the caller's read and acknowledgement state.
/// Null when the notice does not exist or is not visible to the caller.
final noticeDetailProvider = FutureProvider.autoDispose.family<Notice?, String>(
  (ref, id) async {
    final context = ref.watch(currentContextProvider);
    if (context == null) return null;
    return ref
        .watch(noticeRepositoryProvider)
        .get(id, employeeId: context.employee.id);
  },
);

/// Read and acknowledgement counts, for people who manage notices.
final noticeStatsProvider = FutureProvider.autoDispose
    .family<NoticeStats, String>(
      (ref, id) => ref.watch(noticeRepositoryProvider).stats(id),
    );
