import 'json_utils.dart';

class NoticeAttachment {
  const NoticeAttachment({required this.path, required this.name, this.size});

  factory NoticeAttachment.fromJson(Json json) => NoticeAttachment(
    path: strOr(json['path']),
    name: strOr(json['name'], 'Attachment'),
    size: json['size'] == null ? null : intOr(json['size']),
  );

  final String path;
  final String name;
  final int? size;

  Json toJson() => {'path': path, 'name': name, 'size': size};
}

class Notice {
  const Notice({
    required this.id,
    required this.title,
    required this.body,
    this.category = 'general',
    this.isPinned = false,
    this.audience = 'all',
    this.branchId,
    this.departmentId,
    this.status = 'published',
    this.publishAt,
    this.expiresAt,
    this.requiresAck = false,
    this.attachments = const [],
    this.createdByName,
    this.createdAt,
    this.readAt,
    this.acknowledgedAt,
  });

  /// The repository merges the caller's receipt into [json] as `read_at`
  /// and `acknowledged_at` before parsing.
  factory Notice.fromJson(Json json) {
    return Notice(
      id: strOr(json['id']),
      title: strOr(json['title']),
      body: strOr(json['body']),
      category: strOr(json['category'], 'general'),
      isPinned: boolOr(json['is_pinned']),
      audience: strOr(json['audience'], 'all'),
      branchId: str(json['branch_id']),
      departmentId: str(json['department_id']),
      status: strOr(json['status'], 'published'),
      publishAt: timestamp(json['publish_at']),
      expiresAt: timestamp(json['expires_at']),
      requiresAck: boolOr(json['requires_ack']),
      attachments: jsonList(json['attachments'])
          .map(NoticeAttachment.fromJson)
          .toList(),
      createdByName: str(json['created_by_name']),
      createdAt: timestamp(json['created_at']),
      readAt: timestamp(json['read_at']),
      acknowledgedAt: timestamp(json['acknowledged_at']),
    );
  }

  final String id;
  final String title;
  final String body;
  final String category;
  final bool isPinned;
  final String audience;
  final String? branchId;
  final String? departmentId;
  final String status;
  final DateTime? publishAt;
  final DateTime? expiresAt;
  final bool requiresAck;
  final List<NoticeAttachment> attachments;
  final String? createdByName;
  final DateTime? createdAt;
  final DateTime? readAt;
  final DateTime? acknowledgedAt;

  bool get isRead => readAt != null;
  bool get isAcknowledged => acknowledgedAt != null;
  bool get isScheduled =>
      status == 'published' &&
      publishAt != null &&
      publishAt!.isAfter(DateTime.now());
  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.category,
    required this.title,
    this.body,
    this.route,
    this.readAt,
    this.createdAt,
  });

  factory AppNotification.fromJson(Json json) => AppNotification(
    id: strOr(json['id']),
    category: strOr(json['category'], 'system'),
    title: strOr(json['title']),
    body: str(json['body']),
    route: str(json['route']),
    readAt: timestamp(json['read_at']),
    createdAt: timestamp(json['created_at']),
  );

  final String id;
  final String category;
  final String title;
  final String? body;
  final String? route;
  final DateTime? readAt;
  final DateTime? createdAt;

  bool get isRead => readAt != null;
}

class NotificationPreference {
  const NotificationPreference({
    required this.category,
    this.inApp = true,
    this.push = true,
  });

  final String category;
  final bool inApp;
  final bool push;
}

class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.action,
    required this.entityType,
    this.summary,
    this.actorName,
    this.changes,
    this.createdAt,
  });

  factory AuditEntry.fromJson(Json json) => AuditEntry(
    id: intOr(json['id']),
    action: strOr(json['action']),
    entityType: strOr(json['entity_type']),
    summary: str(json['summary']),
    actorName: str(json['actor_name']),
    changes: json['changes'],
    createdAt: timestamp(json['created_at']),
  );

  final int id;
  final String action;
  final String entityType;
  final String? summary;
  final String? actorName;
  final dynamic changes;
  final DateTime? createdAt;
}
