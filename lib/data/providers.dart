import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/utils/formatters.dart';
import 'models/access_models.dart';
import 'models/app_context.dart';
import 'models/communication_models.dart';
import 'models/employee_models.dart';
import 'models/org_models.dart';
import 'repositories/access_repository.dart';
import 'repositories/auth_repository.dart';
import 'repositories/dashboard_repository.dart';
import 'repositories/employee_repository.dart';
import 'repositories/notice_repository.dart';
import 'repositories/notification_repository.dart';
import 'repositories/organization_repository.dart';
import 'repositories/storage_helper.dart';

// ---------------------------------------------------------------- clients
final supabaseProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

final storageHelperProvider = Provider<StorageHelper>(
  (ref) => StorageHelper(ref.watch(supabaseProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseProvider)),
);

final organizationRepositoryProvider = Provider<OrganizationRepository>(
  (ref) => OrganizationRepository(
    ref.watch(supabaseProvider),
    ref.watch(storageHelperProvider),
  ),
);

final accessRepositoryProvider = Provider<AccessRepository>(
  (ref) => AccessRepository(ref.watch(supabaseProvider)),
);

final employeeRepositoryProvider = Provider<EmployeeRepository>(
  (ref) => EmployeeRepository(
    ref.watch(supabaseProvider),
    ref.watch(storageHelperProvider),
  ),
);

final noticeRepositoryProvider = Provider<NoticeRepository>(
  (ref) => NoticeRepository(
    ref.watch(supabaseProvider),
    ref.watch(storageHelperProvider),
  ),
);

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(ref.watch(supabaseProvider)),
);

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => DashboardRepository(ref.watch(supabaseProvider)),
);

final auditRepositoryProvider = Provider<AuditRepository>(
  (ref) => AuditRepository(ref.watch(supabaseProvider)),
);

// ------------------------------------------------------------------- auth
class AuthSnapshot {
  const AuthSnapshot({this.session, this.recovering = false});

  final Session? session;

  /// True while the user arrived from a password reset e-mail and must
  /// choose a new password.
  final bool recovering;

  bool get isSignedIn => session != null;
}

class AuthController extends Notifier<AuthSnapshot> {
  @override
  AuthSnapshot build() {
    final repository = ref.read(authRepositoryProvider);
    final subscription = repository.authChanges.listen((change) {
      var recovering = state.recovering;
      if (change.event == AuthChangeEvent.passwordRecovery) recovering = true;
      if (change.event == AuthChangeEvent.signedOut) recovering = false;
      state = AuthSnapshot(session: change.session, recovering: recovering);
    });
    ref.onDispose(subscription.cancel);
    return AuthSnapshot(session: repository.currentSession);
  }

  void finishRecovery() {
    state = AuthSnapshot(session: state.session);
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthSnapshot>(
  AuthController.new,
);

// ---------------------------------------------------------------- context
class AppContextNotifier extends AsyncNotifier<AppContext?> {
  @override
  Future<AppContext?> build() async {
    final userId = ref.watch(
      authControllerProvider.select((s) => s.session?.user.id),
    );
    if (userId == null) return null;

    final repository = ref.read(authRepositoryProvider);
    var json = await repository.loadContext();

    if (json == null) {
      // Sign-up with an invitation code may finish before the first login.
      final code = repository.pendingInviteCode;
      if (code != null) {
        try {
          await repository.claimInvite(code);
          json = await repository.loadContext();
        } catch (_) {
          json = null;
        }
      }
    }
    if (json == null) return null;

    final context = AppContext.fromJson(json);
    Fmt.configure(
      datePattern: context.organization.dateFormat,
      timeFormat: context.organization.timeFormat,
    );
    return context;
  }

  Future<void> reload() async {
    ref.invalidateSelf();
    await future;
  }
}

final appContextProvider =
    AsyncNotifierProvider<AppContextNotifier, AppContext?>(
      AppContextNotifier.new,
    );

/// Current context or null. Convenience for widgets that are only built
/// after the context has loaded.
final currentContextProvider = Provider<AppContext?>(
  (ref) => ref.watch(appContextProvider).valueOrNull,
);

// ---------------------------------------------------------------- lookups
String? _orgKey(Ref ref) =>
    ref.watch(appContextProvider.select((c) => c.valueOrNull?.organization.id));

final organizationProvider = FutureProvider<Organization?>((ref) async {
  if (_orgKey(ref) == null) return null;
  return ref.watch(organizationRepositoryProvider).getOrganization();
});

final branchesProvider = FutureProvider<List<Branch>>((ref) async {
  if (_orgKey(ref) == null) return const [];
  return ref.watch(organizationRepositoryProvider).branches();
});

final departmentsProvider = FutureProvider<List<Department>>((ref) async {
  if (_orgKey(ref) == null) return const [];
  return ref.watch(organizationRepositoryProvider).departments();
});

final designationsProvider = FutureProvider<List<Designation>>((ref) async {
  if (_orgKey(ref) == null) return const [];
  return ref.watch(organizationRepositoryProvider).designations();
});

final rolesProvider = FutureProvider<List<Role>>((ref) async {
  if (_orgKey(ref) == null) return const [];
  return ref.watch(accessRepositoryProvider).roles();
});

final permissionCatalogProvider = FutureProvider<List<PermissionDef>>((
  ref,
) async {
  if (_orgKey(ref) == null) return const [];
  return ref.watch(accessRepositoryProvider).permissionCatalog();
});

/// People that can be chosen as reporting manager or department head.
final employeePickerProvider = FutureProvider<List<DirectoryEntry>>((
  ref,
) async {
  if (_orgKey(ref) == null) return const [];
  return ref.watch(employeeRepositoryProvider).pickerList();
});

// ---------------------------------------------------------- notifications
class NotificationsNotifier extends AsyncNotifier<List<AppNotification>> {
  RealtimeChannel? _channel;

  @override
  Future<List<AppNotification>> build() async {
    final context = ref.watch(currentContextProvider);
    if (context == null) return const [];

    final repository = ref.read(notificationRepositoryProvider);

    // Notices that were scheduled for a later time become notifications now.
    try {
      await repository.dispatchDueNotices();
    } catch (_) {
      // Not critical for listing existing notifications.
    }

    _channel = repository.subscribe(context.employee.id, _refreshQuietly);
    ref.onDispose(() {
      final channel = _channel;
      if (channel != null) {
        repository.unsubscribe(channel);
      }
    });

    return repository.list();
  }

  Future<void> _refreshQuietly() async {
    final repository = ref.read(notificationRepositoryProvider);
    try {
      state = AsyncData(await repository.list());
    } catch (_) {
      // Keep the previous list when a background refresh fails.
    }
  }

  Future<void> refresh() => _refreshQuietly();

  Future<void> markRead(String id) async {
    await ref.read(notificationRepositoryProvider).markRead(id);
    await _refreshQuietly();
  }

  Future<void> markAllRead() async {
    await ref.read(notificationRepositoryProvider).markAllRead();
    await _refreshQuietly();
  }

  Future<void> remove(String id) async {
    await ref.read(notificationRepositoryProvider).delete(id);
    await _refreshQuietly();
  }
}

final notificationsProvider =
    AsyncNotifierProvider<NotificationsNotifier, List<AppNotification>>(
      NotificationsNotifier.new,
    );

final unreadNotificationsProvider = Provider<int>((ref) {
  final list = ref.watch(notificationsProvider).valueOrNull ?? const [];
  return list.where((n) => !n.isRead).length;
});
