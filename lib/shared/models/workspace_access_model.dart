import 'package:pocketbase/pocketbase.dart';

import '../../core/constants/app_constants.dart';

class WorkspaceModel {
  const WorkspaceModel({
    required this.id,
    required this.record,
    required this.code,
    required this.name,
    required this.rw,
    required this.status,
    this.ownerMemberId,
    this.desaCode,
    this.kecamatanCode,
    this.kabupatenCode,
    this.provinsiCode,
    this.desaKelurahan,
    this.kecamatan,
    this.kabupatenKota,
    this.provinsi,
  });

  final String id;
  final RecordModel record;
  final String code;
  final String name;
  final int rw;
  final String status;
  final String? ownerMemberId;
  final String? desaCode;
  final String? kecamatanCode;
  final String? kabupatenCode;
  final String? provinsiCode;
  final String? desaKelurahan;
  final String? kecamatan;
  final String? kabupatenKota;
  final String? provinsi;

  factory WorkspaceModel.fromRecord(RecordModel record) {
    return WorkspaceModel(
      id: record.id,
      record: record,
      code: record.getStringValue('code'),
      name: record.getStringValue('name'),
      rw: _recordInt(record, 'rw'),
      status: record.getStringValue('status'),
      ownerMemberId: _textOrNull(record, 'owner_member'),
      desaCode: _textOrNull(record, 'desa_code'),
      kecamatanCode: _textOrNull(record, 'kecamatan_code'),
      kabupatenCode: _textOrNull(record, 'kabupaten_code'),
      provinsiCode: _textOrNull(record, 'provinsi_code'),
      desaKelurahan: _textOrNull(record, 'desa_kelurahan'),
      kecamatan: _textOrNull(record, 'kecamatan'),
      kabupatenKota: _textOrNull(record, 'kabupaten_kota'),
      provinsi: _textOrNull(record, 'provinsi'),
    );
  }
}

class WorkspaceMemberModel {
  const WorkspaceMemberModel({
    required this.id,
    required this.record,
    required this.workspaceId,
    required this.userId,
    required this.systemRole,
    required this.planCode,
    required this.subscriptionStatus,
    required this.isOwner,
    required this.ownerRank,
    required this.isActive,
    this.scopeType,
    this.scopeRt,
    this.scopeRw,
    this.subscriptionStarted,
    this.subscriptionExpired,
  });

  final String id;
  final RecordModel record;
  final String workspaceId;
  final String userId;
  final String systemRole;
  final String planCode;
  final String subscriptionStatus;
  final bool isOwner;
  final int ownerRank;
  final bool isActive;
  final String? scopeType;
  final int? scopeRt;
  final int? scopeRw;
  final DateTime? subscriptionStarted;
  final DateTime? subscriptionExpired;

  factory WorkspaceMemberModel.fromRecord(RecordModel record) {
    final legacyRole = record.getStringValue('role');
    final subscriptionPlan = record.getStringValue('subscription_plan');
    return WorkspaceMemberModel(
      id: record.id,
      record: record,
      workspaceId: record.getStringValue('workspace'),
      userId: record.getStringValue('user'),
      systemRole: AppConstants.effectiveSystemRole(
        role: legacyRole,
        systemRole: record.getStringValue('system_role'),
      ),
      planCode: AppConstants.effectivePlanCode(
        role: legacyRole,
        planCode: record.getStringValue('plan_code'),
        subscriptionPlan: subscriptionPlan,
      ),
      subscriptionStatus: AppConstants.normalizeSubscriptionStatus(
        record.getStringValue('subscription_status'),
      ),
      isOwner: record.data['is_owner'] == true,
      ownerRank: _recordInt(record, 'owner_rank'),
      isActive: record.data['is_active'] == true,
      scopeType: _textOrNull(record, 'scope_type'),
      scopeRt: _nullableInt(record.data['scope_rt']),
      scopeRw: _nullableInt(record.data['scope_rw']),
      subscriptionStarted: _dateOrNull(record, 'subscription_started'),
      subscriptionExpired: _dateOrNull(record, 'subscription_expired'),
    );
  }

  bool get requiresSubscription =>
      AppConstants.planCodeRequiresSubscription(planCode);

  bool get hasActiveSubscription => AppConstants.hasActiveSubscription(
    role: effectiveRole,
    subscriptionStatus: subscriptionStatus,
    subscriptionExpired: subscriptionExpired?.toIso8601String(),
  );

  bool get isOperator => AppConstants.isOperatorSystemRole(systemRole);

  bool get isSysadmin => AppConstants.isSysadminSystemRole(systemRole);

  String get effectiveRole => AppConstants.roleFromSystemRolePlan(
    systemRole: systemRole,
    planCode: planCode,
  );
}

class OrgUnitModel {
  const OrgUnitModel({
    required this.id,
    required this.record,
    required this.workspaceId,
    required this.type,
    required this.name,
    required this.code,
    required this.isOfficial,
    required this.status,
    this.parentUnitId,
    this.scopeRt,
    this.scopeRw,
  });

  final String id;
  final RecordModel record;
  final String workspaceId;
  final String type;
  final String name;
  final String code;
  final bool isOfficial;
  final String status;
  final String? parentUnitId;
  final int? scopeRt;
  final int? scopeRw;

  factory OrgUnitModel.fromRecord(RecordModel record) {
    return OrgUnitModel(
      id: record.id,
      record: record,
      workspaceId: record.getStringValue('workspace'),
      type: record.getStringValue('type'),
      name: record.getStringValue('name'),
      code: record.getStringValue('code'),
      isOfficial: record.data['is_official'] == true,
      status: record.getStringValue('status'),
      parentUnitId: _textOrNull(record, 'parent_unit'),
      scopeRt: _nullableInt(record.data['scope_rt']),
      scopeRw: _nullableInt(record.data['scope_rw']),
    );
  }
}

class JabatanMasterModel {
  const JabatanMasterModel({
    required this.id,
    required this.record,
    required this.code,
    required this.label,
    required this.unitType,
    required this.sortOrder,
    required this.canManageWorkspace,
    required this.canManageUnit,
    required this.canManageMembership,
    required this.canSubmitFinance,
    required this.canApproveFinance,
    required this.canPublishFinance,
    required this.canManageSchedule,
    required this.canBroadcastUnit,
    required this.canManageIuran,
    required this.canVerifyIuranPayment,
    required this.isActive,
  });

  final String id;
  final RecordModel record;
  final String code;
  final String label;
  final String unitType;
  final int sortOrder;
  final bool canManageWorkspace;
  final bool canManageUnit;
  final bool canManageMembership;
  final bool canSubmitFinance;
  final bool canApproveFinance;
  final bool canPublishFinance;
  final bool canManageSchedule;
  final bool canBroadcastUnit;
  final bool canManageIuran;
  final bool canVerifyIuranPayment;
  final bool isActive;

  factory JabatanMasterModel.fromRecord(RecordModel record) {
    return JabatanMasterModel(
      id: record.id,
      record: record,
      code: record.getStringValue('code'),
      label: record.getStringValue('label'),
      unitType: record.getStringValue('unit_type'),
      sortOrder: _recordInt(record, 'sort_order'),
      canManageWorkspace: record.data['can_manage_workspace'] == true,
      canManageUnit: record.data['can_manage_unit'] == true,
      canManageMembership: record.data['can_manage_membership'] == true,
      canSubmitFinance: record.data['can_submit_finance'] == true,
      canApproveFinance: record.data['can_approve_finance'] == true,
      canPublishFinance: record.data['can_publish_finance'] == true,
      canManageSchedule: record.data['can_manage_schedule'] == true,
      canBroadcastUnit: record.data['can_broadcast_unit'] == true,
      canManageIuran: record.data['can_manage_iuran'] == true,
      canVerifyIuranPayment: record.data['can_verify_iuran_payment'] == true,
      isActive: record.data['is_active'] == true,
    );
  }
}

class OrgMembershipModel {
  const OrgMembershipModel({
    required this.id,
    required this.record,
    required this.workspaceId,
    required this.userId,
    required this.workspaceMemberId,
    required this.orgUnitId,
    required this.jabatanId,
    required this.isPrimary,
    required this.status,
    this.periodLabel,
    this.startedAt,
    this.endedAt,
    this.jabatan,
    this.orgUnit,
  });

  final String id;
  final RecordModel record;
  final String workspaceId;
  final String userId;
  final String workspaceMemberId;
  final String orgUnitId;
  final String jabatanId;
  final bool isPrimary;
  final String status;
  final String? periodLabel;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final JabatanMasterModel? jabatan;
  final OrgUnitModel? orgUnit;

  factory OrgMembershipModel.fromRecord(
    RecordModel record, {
    JabatanMasterModel? jabatan,
    OrgUnitModel? orgUnit,
  }) {
    return OrgMembershipModel(
      id: record.id,
      record: record,
      workspaceId: record.getStringValue('workspace'),
      userId: record.getStringValue('user'),
      workspaceMemberId: record.getStringValue('workspace_member'),
      orgUnitId: record.getStringValue('org_unit'),
      jabatanId: record.getStringValue('jabatan'),
      isPrimary: record.data['is_primary'] == true,
      status: record.getStringValue('status'),
      periodLabel: _textOrNull(record, 'period_label'),
      startedAt: _dateOrNull(record, 'started_at'),
      endedAt: _dateOrNull(record, 'ended_at'),
      jabatan: jabatan,
      orgUnit: orgUnit,
    );
  }

  bool get isActive => status == 'active';

  bool get canManageWorkspace => jabatan?.canManageWorkspace == true;

  bool get canManageUnit => jabatan?.canManageUnit == true;

  bool get canManageMembership => jabatan?.canManageMembership == true;

  bool get canSubmitFinance => jabatan?.canSubmitFinance == true;

  bool get canApproveFinance => jabatan?.canApproveFinance == true;

  bool get canPublishFinance => jabatan?.canPublishFinance == true;

  bool get canManageSchedule => jabatan?.canManageSchedule == true;

  bool get canBroadcastUnit => jabatan?.canBroadcastUnit == true;

  bool get canManageIuran => jabatan?.canManageIuran == true;

  bool get canVerifyIuranPayment => jabatan?.canVerifyIuranPayment == true;
}

class WorkspaceAccessProfile {
  const WorkspaceAccessProfile({
    required this.workspace,
    required this.member,
    required this.orgMemberships,
  });

  final WorkspaceModel workspace;
  final WorkspaceMemberModel member;
  final List<OrgMembershipModel> orgMemberships;

  bool get isOperator => member.isOperator;

  bool get canBroadcastByPlan =>
      member.isSysadmin ||
      (member.hasActiveSubscription &&
          (member.planCode == AppConstants.planRt ||
              member.planCode == AppConstants.planRw ||
              member.planCode == AppConstants.planRwPro));

  bool get canCreateCustomGroup =>
      member.hasActiveSubscription &&
      (member.planCode == AppConstants.planRw ||
          member.planCode == AppConstants.planRwPro);

  bool get canUsePolling => AppConstants.planIncludesFeature(
    planCode: member.planCode,
    featureFlag: AppConstants.featurePolling,
  );

  bool get canUseVoiceNote => AppConstants.planIncludesFeature(
    planCode: member.planCode,
    featureFlag: AppConstants.featureVoiceNote,
  );

  bool get canPublishFinanceByPlan =>
      member.isSysadmin ||
      AppConstants.planIncludesFeature(
        planCode: member.planCode,
        featureFlag: AppConstants.featureFinancePublish,
      );

  bool get _hasRwWideOrganizationAdminAccess =>
      member.isOperator && AppConstants.hasRwWidePlanAccess(member.planCode);

  bool get canManageWorkspace =>
      member.isSysadmin ||
      _hasRwWideOrganizationAdminAccess ||
      orgMemberships.any(
        (membership) => membership.isActive && membership.canManageWorkspace,
      );

  bool get canManageUnit =>
      member.isSysadmin ||
      _hasRwWideOrganizationAdminAccess ||
      orgMemberships.any(
        (membership) => membership.isActive && membership.canManageUnit,
      );

  bool get canManageMembership =>
      member.isSysadmin ||
      _hasRwWideOrganizationAdminAccess ||
      orgMemberships.any(
        (membership) => membership.isActive && membership.canManageMembership,
      );

  bool hasUnitMembership(String orgUnitId) {
    return orgMemberships.any(
      (membership) => membership.orgUnitId == orgUnitId && membership.isActive,
    );
  }

  OrgMembershipModel? primaryMembershipForUnit(String orgUnitId) {
    for (final membership in orgMemberships) {
      if (membership.orgUnitId == orgUnitId &&
          membership.isActive &&
          membership.isPrimary) {
        return membership;
      }
    }
    for (final membership in orgMemberships) {
      if (membership.orgUnitId == orgUnitId && membership.isActive) {
        return membership;
      }
    }
    return null;
  }

  bool canSubmitFinanceForUnit(String orgUnitId) {
    if (member.isSysadmin) {
      return true;
    }
    return orgMemberships.any(
      (membership) =>
          membership.orgUnitId == orgUnitId &&
          membership.isActive &&
          membership.canSubmitFinance,
    );
  }

  bool canApproveFinanceForUnit(String orgUnitId) {
    if (member.isSysadmin) {
      return true;
    }
    return orgMemberships.any(
      (membership) =>
          membership.orgUnitId == orgUnitId &&
          membership.isActive &&
          membership.canApproveFinance,
    );
  }

  bool canPublishFinanceForUnit(String orgUnitId) {
    if (member.isSysadmin) {
      return true;
    }
    return orgMemberships.any(
      (membership) =>
          membership.orgUnitId == orgUnitId &&
          membership.isActive &&
          membership.canPublishFinance,
    );
  }

  bool canManageScheduleForUnit(String orgUnitId) {
    if (member.isSysadmin) {
      return true;
    }
    return orgMemberships.any(
      (membership) =>
          membership.orgUnitId == orgUnitId &&
          membership.isActive &&
          membership.canManageSchedule,
    );
  }

  bool canBroadcastUnit(String orgUnitId) {
    if (member.isSysadmin) {
      return true;
    }
    return orgMemberships.any(
      (membership) =>
          membership.orgUnitId == orgUnitId &&
          membership.isActive &&
          membership.canBroadcastUnit,
    );
  }

  bool canManageIuranForUnit(String orgUnitId) {
    if (member.isSysadmin) {
      return true;
    }
    return orgMemberships.any(
      (membership) =>
          membership.orgUnitId == orgUnitId &&
          membership.isActive &&
          membership.canManageIuran,
    );
  }

  bool canVerifyIuranForUnit(String orgUnitId) {
    if (member.isSysadmin) {
      return true;
    }
    return orgMemberships.any(
      (membership) =>
          membership.orgUnitId == orgUnitId &&
          membership.isActive &&
          membership.canVerifyIuranPayment,
    );
  }
}

int _recordInt(RecordModel record, String field) {
  final raw = record.data[field];
  if (raw is int) {
    return raw;
  }
  return int.tryParse(record.getStringValue(field)) ?? 0;
}

int? _nullableInt(Object? raw) {
  if (raw is int) {
    return raw;
  }
  return int.tryParse(raw?.toString() ?? '');
}

String? _textOrNull(RecordModel record, String field) {
  final value = record.getStringValue(field).trim();
  if (value.isNotEmpty) {
    return value;
  }
  final raw = record.data[field]?.toString().trim() ?? '';
  return raw.isEmpty ? null : raw;
}

DateTime? _dateOrNull(RecordModel record, String field) {
  return DateTime.tryParse(record.getStringValue(field));
}
