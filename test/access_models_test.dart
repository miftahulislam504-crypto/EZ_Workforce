import 'package:ez_workforce/data/models/access_models.dart';
import 'package:ez_workforce/data/models/app_context.dart';
import 'package:ez_workforce/data/models/permissions.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _contextJson({
  required bool isOwner,
  List<String> permissions = const [],
}) => {
  'employee': {
    'id': 'e1',
    'employee_code': 'EMP-0001',
    'first_name': 'Rahim',
    'full_name': 'Rahim Uddin',
  },
  'role': {
    'id': 'r1',
    'name': isOwner ? 'Owner' : 'Employee',
    'is_owner': isOwner,
    'data_scope': isOwner ? 'organization' : 'self',
  },
  'organization': {'id': 'o1', 'name': 'Acme Ltd'},
  'permissions': permissions,
  'unread_notifications': 3,
};

void main() {
  group('Role', () {
    test('parses flags and defaults', () {
      final role = Role.fromJson({
        'id': 'r1',
        'name': 'HR Admin',
        'is_system': true,
        'data_scope': 'organization',
      });
      expect(role.name, 'HR Admin');
      expect(role.isSystem, isTrue);
      expect(role.isOwner, isFalse);
      expect(role.isDefault, isFalse);
      expect(role.description, isNull);
      expect(role.permissionCodes, isEmpty);
    });

    test('copyWith keeps identity and replaces counts', () {
      final role = Role.fromJson({'id': 'r1', 'name': 'Custom'});
      final updated = role.copyWith(
        permissionCodes: {'employees.view'},
        employeeCount: 4,
      );
      expect(updated.id, 'r1');
      expect(updated.name, 'Custom');
      expect(updated.permissionCodes, {'employees.view'});
      expect(updated.employeeCount, 4);
    });

    test('scope labels are readable', () {
      expect(Role.scopeLabel('organization'), 'Whole organization');
      expect(Role.scopeLabel('branch'), 'Own branch');
      expect(Role.scopeLabel('department'), 'Own department');
      expect(Role.scopeLabel('self'), 'Own records only');
      expect(Role.scopeLabel('unknown'), 'Own records only');
    });
  });

  group('PermissionDef', () {
    test('parses the catalog row', () {
      final def = PermissionDef.fromJson({
        'code': 'employees.view',
        'module': 'employees',
        'label': 'View employees',
        'sort_order': 20,
      });
      expect(def.code, 'employees.view');
      expect(def.module, 'employees');
      expect(def.description, isNull);
      expect(def.sortOrder, 20);
    });
  });

  group('AppContext', () {
    test('an owner can do everything', () {
      final context = AppContext.fromJson(_contextJson(isOwner: true));
      expect(context.can(Perm.rolesManage), isTrue);
      expect(context.can('anything.at_all'), isTrue);
      expect(context.organization.name, 'Acme Ltd');
      expect(context.unreadNotifications, 3);
    });

    test('other roles are limited to granted permissions', () {
      final context = AppContext.fromJson(
        _contextJson(isOwner: false, permissions: [Perm.employeesView]),
      );
      expect(context.can(Perm.employeesView), isTrue);
      expect(context.can(Perm.rolesManage), isFalse);
      expect(context.canAny([Perm.rolesManage, Perm.employeesView]), isTrue);
      expect(context.canAny([Perm.rolesManage, Perm.auditView]), isFalse);
    });

    test('organization defaults match the database defaults', () {
      final context = AppContext.fromJson(_contextJson(isOwner: false));
      expect(context.organization.timezone, 'Asia/Dhaka');
      expect(context.organization.currency, 'BDT');
      expect(context.organization.plan, 'trial');
    });
  });
}
