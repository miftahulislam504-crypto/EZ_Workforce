import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/employee_models.dart';
import '../../data/providers.dart';

/// Full employee row. Null when the caller is not allowed to see it.
final employeeDetailProvider = FutureProvider.autoDispose
    .family<Employee?, String>(
      (ref, id) => ref.watch(employeeRepositoryProvider).employee(id),
    );

/// Limited colleague view, always readable inside the organization.
final directoryEntryProvider = FutureProvider.autoDispose
    .family<DirectoryEntry?, String>(
      (ref, id) => ref.watch(employeeRepositoryProvider).directoryEntry(id),
    );

final employeeOnboardingProvider = FutureProvider.autoDispose
    .family<List<OnboardingItem>, String>(
      (ref, id) => ref.watch(employeeRepositoryProvider).onboardingItems(id),
    );

final employeeDocumentsProvider = FutureProvider.autoDispose
    .family<List<EmployeeDocument>, String>(
      (ref, id) => ref.watch(employeeRepositoryProvider).documents(id),
    );

final employeePrivateProvider = FutureProvider.autoDispose
    .family<EmployeePrivate?, String>(
      (ref, id) => ref.watch(employeeRepositoryProvider).privateData(id),
    );
