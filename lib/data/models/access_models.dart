import 'json_utils.dart';

class PermissionDef {
  const PermissionDef({
    required this.code,
    required this.module,
    required this.label,
    this.description,
    this.sortOrder = 0,
  });

  factory PermissionDef.fromJson(Json json) => PermissionDef(
    code: strOr(json['code']),
    module: strOr(json['module']),
    label: strOr(json['label']),
    description: str(json['description']),
    sortOrder: intOr(json['sort_order']),
  );

  final String code;
  final String module;
  final String label;
  final String? description;
  final int sortOrder;
}

class Role {
  const Role({
    required this.id,
    required this.name,
    this.description,
    this.dataScope = 'self',
    this.isOwner = false,
    this.isSystem = false,
    this.isDefault = false,
    this.permissionCodes = const {},
    this.employeeCount = 0,
  });

  factory Role.fromJson(Json json) => Role(
    id: strOr(json['id']),
    name: strOr(json['name']),
    description: str(json['description']),
    dataScope: strOr(json['data_scope'], 'self'),
    isOwner: boolOr(json['is_owner']),
    isSystem: boolOr(json['is_system']),
    isDefault: boolOr(json['is_default']),
  );

  final String id;
  final String name;
  final String? description;
  final String dataScope;
  final bool isOwner;
  final bool isSystem;
  final bool isDefault;
  final Set<String> permissionCodes;
  final int employeeCount;

  Role copyWith({Set<String>? permissionCodes, int? employeeCount}) => Role(
    id: id,
    name: name,
    description: description,
    dataScope: dataScope,
    isOwner: isOwner,
    isSystem: isSystem,
    isDefault: isDefault,
    permissionCodes: permissionCodes ?? this.permissionCodes,
    employeeCount: employeeCount ?? this.employeeCount,
  );

  static String scopeLabel(String scope) => switch (scope) {
    'organization' => 'Whole organization',
    'branch' => 'Own branch',
    'department' => 'Own department',
    _ => 'Own records only',
  };
}
