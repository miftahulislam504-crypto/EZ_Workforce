import 'json_utils.dart';

class CountItem {
  const CountItem({required this.name, required this.count, this.id});

  factory CountItem.fromJson(Json json) => CountItem(
    id: str(json['id']),
    name: strOr(json['name']),
    count: intOr(json['count']),
  );

  final String? id;
  final String name;
  final int count;
}

class TrendPoint {
  const TrendPoint({required this.label, required this.joined});

  factory TrendPoint.fromJson(Json json) =>
      TrendPoint(label: strOr(json['label']), joined: intOr(json['joined']));

  final String label;
  final int joined;
}

class ActivityItem {
  const ActivityItem({
    required this.action,
    required this.entityType,
    this.summary,
    this.actorName,
    this.createdAt,
  });

  factory ActivityItem.fromJson(Json json) => ActivityItem(
    action: strOr(json['action']),
    entityType: strOr(json['entity_type']),
    summary: str(json['summary']),
    actorName: str(json['actor_name']),
    createdAt: timestamp(json['created_at']),
  );

  final String action;
  final String entityType;
  final String? summary;
  final String? actorName;
  final DateTime? createdAt;
}

class AdminStats {
  const AdminStats({
    required this.total,
    required this.active,
    required this.probation,
    required this.onLeave,
    required this.suspended,
    required this.inactive,
    required this.joinedThisMonth,
    required this.onboardingPending,
    required this.invitesPending,
    required this.probationEndingSoon,
    required this.contractsExpiringSoon,
    required this.byBranch,
    required this.byDepartment,
    required this.byDesignation,
    required this.byType,
    required this.byGender,
    required this.joiningTrend,
    required this.recentActivity,
  });

  factory AdminStats.fromJson(Json json) {
    final s = jsonMap(json['summary']);
    return AdminStats(
      total: intOr(s['total']),
      active: intOr(s['active']),
      probation: intOr(s['probation']),
      onLeave: intOr(s['on_leave']),
      suspended: intOr(s['suspended']),
      inactive: intOr(s['inactive']),
      joinedThisMonth: intOr(s['joined_this_month']),
      onboardingPending: intOr(s['onboarding_pending']),
      invitesPending: intOr(s['invites_pending']),
      probationEndingSoon: intOr(s['probation_ending_soon']),
      contractsExpiringSoon: intOr(s['contracts_expiring_soon']),
      byBranch: jsonList(json['by_branch']).map(CountItem.fromJson).toList(),
      byDepartment: jsonList(json['by_department'])
          .map(CountItem.fromJson)
          .toList(),
      byDesignation: jsonList(json['by_designation'])
          .map(CountItem.fromJson)
          .toList(),
      byType: jsonList(json['by_type']).map(CountItem.fromJson).toList(),
      byGender: jsonList(json['by_gender']).map(CountItem.fromJson).toList(),
      joiningTrend: jsonList(json['joining_trend'])
          .map(TrendPoint.fromJson)
          .toList(),
      recentActivity: jsonList(json['recent_activity'])
          .map(ActivityItem.fromJson)
          .toList(),
    );
  }

  final int total;
  final int active;
  final int probation;
  final int onLeave;
  final int suspended;
  final int inactive;
  final int joinedThisMonth;
  final int onboardingPending;
  final int invitesPending;
  final int probationEndingSoon;
  final int contractsExpiringSoon;
  final List<CountItem> byBranch;
  final List<CountItem> byDepartment;
  final List<CountItem> byDesignation;
  final List<CountItem> byType;
  final List<CountItem> byGender;
  final List<TrendPoint> joiningTrend;
  final List<ActivityItem> recentActivity;
}

class TeamMember {
  const TeamMember({
    required this.id,
    required this.fullName,
    required this.status,
    this.photoPath,
    this.designationTitle,
  });

  factory TeamMember.fromJson(Json json) => TeamMember(
    id: strOr(json['id']),
    fullName: strOr(json['full_name']),
    status: strOr(json['status'], 'active'),
    photoPath: str(json['photo_path']),
    designationTitle: str(json['designation_title']),
  );

  final String id;
  final String fullName;
  final String status;
  final String? photoPath;
  final String? designationTitle;
}

class TeamStats {
  const TeamStats({
    required this.total,
    required this.active,
    required this.probation,
    required this.onLeave,
    required this.joinedThisMonth,
    required this.onboardingPending,
    required this.members,
  });

  factory TeamStats.fromJson(Json json) {
    final s = jsonMap(json['summary']);
    return TeamStats(
      total: intOr(s['total']),
      active: intOr(s['active']),
      probation: intOr(s['probation']),
      onLeave: intOr(s['on_leave']),
      joinedThisMonth: intOr(s['joined_this_month']),
      onboardingPending: intOr(s['onboarding_pending']),
      members: jsonList(json['members']).map(TeamMember.fromJson).toList(),
    );
  }

  final int total;
  final int active;
  final int probation;
  final int onLeave;
  final int joinedThisMonth;
  final int onboardingPending;
  final List<TeamMember> members;
}

class Celebration {
  const Celebration({
    required this.employeeId,
    required this.fullName,
    required this.kind,
    required this.eventDate,
    required this.years,
    this.photoPath,
  });

  factory Celebration.fromJson(Json json) => Celebration(
    employeeId: strOr(json['employee_id']),
    fullName: strOr(json['full_name']),
    kind: strOr(json['kind']),
    eventDate: dateOnly(json['event_date']) ?? DateTime.now(),
    years: intOr(json['years']),
    photoPath: str(json['photo_path']),
  );

  final String employeeId;
  final String fullName;
  final String kind;
  final DateTime eventDate;
  final int years;
  final String? photoPath;

  bool get isBirthday => kind == 'birthday';
}
