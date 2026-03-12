import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../shared/models/workspace_access_model.dart';
import '../constants/app_constants.dart';
import 'pocketbase_service.dart';
import '../utils/area_access.dart';
import 'workspace_access_service.dart';

final organizationServiceProvider = Provider<OrganizationService>((ref) {
  return OrganizationService(ref);
});

class OrganizationWorkspaceActor {
  const OrganizationWorkspaceActor({
    required this.member,
    required this.displayName,
    required this.email,
    this.avatarUrl,
  });

  final WorkspaceMemberModel member;
  final String displayName;
  final String email;
  final String? avatarUrl;

  String get shortScope {
    final scopeType = (member.scopeType ?? '').trim();
    if (scopeType == AppConstants.unitTypeRt && (member.scopeRt ?? 0) > 0) {
      return 'RT ${member.scopeRt}';
    }
    if (scopeType == AppConstants.unitTypeRw && (member.scopeRw ?? 0) > 0) {
      return 'RW ${member.scopeRw}';
    }
    if ((member.scopeRw ?? 0) > 0) {
      return 'RW ${member.scopeRw}';
    }
    return 'Workspace';
  }
}

class OrganizationMembershipCandidate {
  const OrganizationMembershipCandidate({
    required this.userId,
    required this.displayName,
    required this.email,
    this.workspaceMemberId,
    this.scopeRt,
    this.scopeRw,
  });

  final String userId;
  final String displayName;
  final String email;
  final String? workspaceMemberId;
  final int? scopeRt;
  final int? scopeRw;

  String get key {
    final memberId = (workspaceMemberId ?? '').trim();
    if (memberId.isNotEmpty) {
      return 'member:$memberId';
    }
    return 'user:$userId';
  }
}

class OrganizationOverviewData {
  const OrganizationOverviewData({
    required this.profile,
    required this.workspaceActors,
    required this.orgUnits,
    required this.jabatanMaster,
    required this.orgMemberships,
  });

  final WorkspaceAccessProfile profile;
  final List<OrganizationWorkspaceActor> workspaceActors;
  final List<OrgUnitModel> orgUnits;
  final List<JabatanMasterModel> jabatanMaster;
  final List<OrgMembershipModel> orgMemberships;

  List<OrgUnitModel> unitsByType(String type) {
    final normalizedType = type.trim().toLowerCase();
    return orgUnits
        .where((unit) => unit.type.trim().toLowerCase() == normalizedType)
        .toList(growable: false);
  }

  OrganizationWorkspaceActor? actorByMemberId(String memberId) {
    for (final actor in workspaceActors) {
      if (actor.member.id == memberId) {
        return actor;
      }
    }
    return null;
  }

  OrganizationWorkspaceActor? get ownerActor {
    for (final actor in workspaceActors) {
      if (actor.member.isOwner) {
        return actor;
      }
    }
    return null;
  }
}

class OrganizationBootstrapResult {
  const OrganizationBootstrapResult({
    required this.created,
    required this.repairedExisting,
    required this.workspaceId,
    required this.workspaceName,
    required this.rw,
    required this.workspaceMemberId,
    this.rwUnitId,
    this.orgMembershipId,
  });

  final bool created;
  final bool repairedExisting;
  final String workspaceId;
  final String workspaceName;
  final int rw;
  final String workspaceMemberId;
  final String? rwUnitId;
  final String? orgMembershipId;

  factory OrganizationBootstrapResult.fromJson(Map<String, dynamic> json) {
    final workspaceJson = Map<String, dynamic>.from(
      json['workspace'] as Map? ?? const {},
    );

    return OrganizationBootstrapResult(
      created: json['created'] == true,
      repairedExisting: json['repairedExisting'] == true,
      workspaceId: workspaceJson['id'] as String? ?? '',
      workspaceName: workspaceJson['name'] as String? ?? '',
      rw: (workspaceJson['rw'] as num?)?.toInt() ?? 0,
      workspaceMemberId: json['workspaceMemberId'] as String? ?? '',
      rwUnitId: json['rwUnitId'] as String?,
      orgMembershipId: json['orgMembershipId'] as String?,
    );
  }
}

class OrganizationService {
  OrganizationService(this._ref);

  final Ref _ref;

  Future<OrganizationOverviewData> fetchOverview() async {
    final profile = await _requireAccessProfile();
    return _loadOverview(profile);
  }

  Future<OrganizationOverviewData?> fetchReadableOverview() async {
    final auth = _ref.read(authProvider);
    final authUser = auth.user;
    if (authUser == null) {
      throw ClientException(
        statusCode: 401,
        response: const {'message': 'Autentikasi dibutuhkan.'},
      );
    }

    final boundProfile = await _ref
        .read(workspaceAccessServiceProvider)
        .getCurrentAccessProfile();
    if (boundProfile != null) {
      return _loadOverview(boundProfile);
    }

    final workspace = await _resolveReadableWorkspace(auth);
    if (workspace == null) {
      return null;
    }

    await _saveReadableWorkspaceBinding(workspaceId: workspace.id);

    return _loadOverview(
      _buildPublicReadProfile(authUser: authUser, workspace: workspace),
    );
  }

  Future<OrganizationOverviewData> _loadOverview(
    WorkspaceAccessProfile profile,
  ) async {
    final workspaceId = profile.workspace.id;

    final members = await _loadWorkspaceMembers(workspaceId);
    final workspaceActors = await _buildWorkspaceActors(members);

    final unitRecords = await pb
        .collection(AppConstants.colOrgUnits)
        .getFullList(
          filter: 'workspace = "${_escapeFilterValue(workspaceId)}"',
          sort: 'type,name,created',
        );
    final orgUnits = unitRecords
        .map(OrgUnitModel.fromRecord)
        .toList(growable: false);
    final unitMap = {for (final unit in orgUnits) unit.id: unit};

    final jabatanRecords = await pb
        .collection(AppConstants.colJabatanMaster)
        .getFullList(filter: 'is_active = true', sort: 'sort_order,created');
    final jabatanMaster = jabatanRecords
        .map(JabatanMasterModel.fromRecord)
        .toList(growable: false);
    final jabatanMap = {
      for (final jabatan in jabatanMaster) jabatan.id: jabatan,
    };

    final membershipRecords = await pb
        .collection(AppConstants.colOrgMemberships)
        .getFullList(
          filter: 'workspace = "${_escapeFilterValue(workspaceId)}"',
          sort: '-is_primary,created',
        );
    final orgMemberships = membershipRecords
        .map(
          (record) => OrgMembershipModel.fromRecord(
            record,
            jabatan: jabatanMap[record.getStringValue('jabatan')],
            orgUnit: unitMap[record.getStringValue('org_unit')],
          ),
        )
        .toList(growable: false);

    return OrganizationOverviewData(
      profile: profile,
      workspaceActors: workspaceActors,
      orgUnits: orgUnits,
      jabatanMaster: jabatanMaster,
      orgMemberships: orgMemberships,
    );
  }

  Future<List<OrganizationMembershipCandidate>>
  fetchMembershipCandidates() async {
    final profile = await _requireAccessProfile();
    final members = await _loadWorkspaceMembers(profile.workspace.id);
    final workspaceActors = await _buildWorkspaceActors(members);
    return _buildMembershipCandidates(
      profile: profile,
      workspaceActors: workspaceActors,
    );
  }

  Future<OrganizationBootstrapResult> bootstrapOrganization({
    required String workspaceName,
    required int rw,
    String desaKelurahan = '',
    String kecamatan = '',
    String kabupatenKota = '',
    String provinsi = '',
  }) async {
    final authUser = pb.authStore.record;
    if (authUser == null) {
      throw ClientException(
        statusCode: 401,
        response: const {'message': 'Autentikasi dibutuhkan.'},
      );
    }

    final normalizedRole = AppConstants.effectiveLegacyRole(
      role: authUser.getStringValue('role'),
      systemRole: authUser.getStringValue('system_role'),
      planCode: authUser.getStringValue('plan_code'),
      subscriptionPlan: authUser.getStringValue('subscription_plan'),
    );
    final planCode = AppConstants.effectivePlanCode(
      role: authUser.getStringValue('role'),
      planCode: authUser.getStringValue('plan_code'),
      subscriptionPlan: authUser.getStringValue('subscription_plan'),
    );
    if (!AppConstants.isSysadminRole(normalizedRole) &&
        !AppConstants.hasRwWidePlanAccess(planCode)) {
      throw ClientException(
        statusCode: 403,
        response: const {
          'message':
              'Hanya operator RW atau sysadmin yang dapat membuat organisasi.',
        },
      );
    }

    final memberList = await pb
        .collection(AppConstants.colWorkspaceMembers)
        .getList(
          page: 1,
          perPage: 1,
          filter:
              'user = "${_escapeFilterValue(authUser.id)}" && is_active = true',
          sort: '-is_owner,-owner_rank,created',
        );
    if (memberList.items.isNotEmpty) {
      final member = WorkspaceMemberModel.fromRecord(memberList.items.first);
      final workspaceRecord = await pb
          .collection(AppConstants.colWorkspaces)
          .getOne(member.workspaceId);
      await _saveLocalOrganizationBinding(
        workspaceId: member.workspaceId,
        workspaceMemberId: member.id,
      );
      return OrganizationBootstrapResult(
        created: false,
        repairedExisting: true,
        workspaceId: workspaceRecord.id,
        workspaceName: workspaceRecord.getStringValue('name'),
        rw: workspaceRecord.getIntValue('rw'),
        workspaceMemberId: member.id,
      );
    }

    final workspaceRecord = await pb
        .collection(AppConstants.colWorkspaces)
        .create(
          body: {
            'code': _bootstrapWorkspaceCode(workspaceName, rw),
            'name': workspaceName.trim(),
            'rw': rw,
            'status': 'active',
            'desa_kelurahan': desaKelurahan.trim(),
            'kecamatan': kecamatan.trim(),
            'kabupaten_kota': kabupatenKota.trim(),
            'provinsi': provinsi.trim(),
          },
        );

    final workspaceMemberRecord = await pb
        .collection(AppConstants.colWorkspaceMembers)
        .create(
          body: {
            'workspace': workspaceRecord.id,
            'user': authUser.id,
            'display_name': _bootstrapUserDisplayName(authUser),
            'system_role': AppConstants.effectiveSystemRole(
              role: authUser.getStringValue('role'),
              systemRole: authUser.getStringValue('system_role'),
            ),
            'plan_code': planCode,
            'subscription_status': AppConstants.normalizeSubscriptionStatus(
              authUser.getStringValue('subscription_status'),
            ),
            if (authUser
                .getStringValue('subscription_started')
                .trim()
                .isNotEmpty)
              'subscription_started': authUser.getStringValue(
                'subscription_started',
              ),
            if (authUser
                .getStringValue('subscription_expired')
                .trim()
                .isNotEmpty)
              'subscription_expired': authUser.getStringValue(
                'subscription_expired',
              ),
            'is_owner': true,
            'owner_rank': _bootstrapOwnerRank(planCode),
            'scope_type': AppConstants.unitTypeRw,
            'scope_rt': 0,
            'scope_rw': rw,
            'is_active': true,
          },
        );

    await pb
        .collection(AppConstants.colWorkspaces)
        .update(
          workspaceRecord.id,
          body: {'owner_member': workspaceMemberRecord.id},
        );

    final rwUnitRecord = await pb
        .collection(AppConstants.colOrgUnits)
        .create(
          body: {
            'workspace': workspaceRecord.id,
            'type': AppConstants.unitTypeRw,
            'name': _bootstrapRwUnitName(workspaceName, rw),
            'code': 'rw-$rw',
            'is_official': true,
            'scope_rt': 0,
            'scope_rw': rw,
            'status': 'active',
          },
        );

    String? orgMembershipId;
    final jabatanList = await pb
        .collection(AppConstants.colJabatanMaster)
        .getList(
          page: 1,
          perPage: 1,
          filter: 'code = "ketua_rw" && is_active = true',
          sort: 'sort_order,created',
        );
    if (jabatanList.items.isNotEmpty) {
      final membershipRecord = await pb
          .collection(AppConstants.colOrgMemberships)
          .create(
            body: {
              'workspace': workspaceRecord.id,
              'user': authUser.id,
              'workspace_member': workspaceMemberRecord.id,
              'org_unit': rwUnitRecord.id,
              'jabatan': jabatanList.items.first.id,
              'is_primary': true,
              'started_at': DateTime.now().toIso8601String(),
              'status': 'active',
              'period_label': '',
            },
          );
      orgMembershipId = membershipRecord.id;
    }

    await _saveLocalOrganizationBinding(
      workspaceId: workspaceRecord.id,
      workspaceMemberId: workspaceMemberRecord.id,
    );

    return OrganizationBootstrapResult(
      created: true,
      repairedExisting: false,
      workspaceId: workspaceRecord.id,
      workspaceName: workspaceName.trim(),
      rw: rw,
      workspaceMemberId: workspaceMemberRecord.id,
      rwUnitId: rwUnitRecord.id,
      orgMembershipId: orgMembershipId,
    );
  }

  Future<WorkspaceModel> updateWorkspace({
    required String name,
    String? status,
  }) async {
    final profile = await _requireAccessProfile();
    if (!profile.canManageWorkspace) {
      throw ClientException(
        statusCode: 403,
        response: const {
          'message': 'Anda tidak memiliki hak kelola workspace.',
        },
      );
    }
    if (name.trim().isEmpty) {
      throw ClientException(
        statusCode: 400,
        response: const {'message': 'Nama workspace wajib diisi.'},
      );
    }

    final body = <String, dynamic>{'name': name.trim()};
    if ((status ?? '').trim().isNotEmpty) {
      body['status'] = status!.trim().toLowerCase();
    }

    final record = await pb
        .collection(AppConstants.colWorkspaces)
        .update(profile.workspace.id, body: body);
    return WorkspaceModel.fromRecord(record);
  }

  Future<OrgUnitModel> saveOrgUnit({
    String? unitId,
    required String type,
    required String name,
    String code = '',
    String? parentUnitId,
    int? scopeRt,
    int? scopeRw,
    bool isOfficial = true,
    String status = 'active',
  }) async {
    final profile = await _requireAccessProfile();
    if (!profile.canManageUnit) {
      throw ClientException(
        statusCode: 403,
        response: const {'message': 'Anda tidak memiliki hak kelola unit.'},
      );
    }
    if (name.trim().isEmpty) {
      throw ClientException(
        statusCode: 400,
        response: const {'message': 'Nama unit wajib diisi.'},
      );
    }

    final normalizedType = type.trim().toLowerCase();
    final normalizedCode = _resolveOrgUnitCode(
      rawCode: code,
      name: name,
      type: normalizedType,
    );
    final body = <String, dynamic>{
      'workspace': profile.workspace.id,
      'type': normalizedType,
      'name': name.trim(),
      'code': normalizedCode,
      'parent_unit': (parentUnitId ?? '').trim(),
      'scope_rt': scopeRt,
      'scope_rw': scopeRw,
      'is_official': isOfficial,
      'status': status.trim().toLowerCase(),
    };

    final collection = pb.collection(AppConstants.colOrgUnits);
    final record = (unitId ?? '').trim().isEmpty
        ? await collection.create(body: body)
        : await collection.update(unitId!, body: body);
    return OrgUnitModel.fromRecord(record);
  }

  Future<OrgUnitModel> archiveOrgUnit(String unitId) async {
    final profile = await _requireAccessProfile();
    if (!profile.canManageUnit) {
      throw ClientException(
        statusCode: 403,
        response: const {'message': 'Anda tidak memiliki hak arsip unit.'},
      );
    }

    final record = await pb
        .collection(AppConstants.colOrgUnits)
        .update(unitId, body: {'status': 'inactive'});
    return OrgUnitModel.fromRecord(record);
  }

  Future<OrgMembershipModel> saveOrgMembership({
    String? membershipId,
    String? workspaceMemberId,
    String? userId,
    String displayName = '',
    String email = '',
    int? scopeRt,
    int? scopeRw,
    required String orgUnitId,
    required String jabatanId,
    bool isPrimary = false,
    String status = 'active',
    String periodLabel = '',
    DateTime? startedAt,
    DateTime? endedAt,
  }) async {
    final profile = await _requireAccessProfile();
    if (!profile.canManageMembership) {
      throw ClientException(
        statusCode: 403,
        response: const {'message': 'Anda tidak memiliki hak kelola pengurus.'},
      );
    }
    if (orgUnitId.trim().isEmpty || jabatanId.trim().isEmpty) {
      throw ClientException(
        statusCode: 400,
        response: const {'message': 'Unit dan jabatan wajib dipilih.'},
      );
    }

    final workspaceMember = await _resolveWorkspaceMemberForMembership(
      profile: profile,
      workspaceMemberId: workspaceMemberId,
      userId: userId,
      displayName: displayName,
      email: email,
      scopeRt: scopeRt,
      scopeRw: scopeRw,
    );
    if (workspaceMember.workspaceId != profile.workspace.id) {
      throw ClientException(
        statusCode: 400,
        response: const {'message': 'Member workspace tidak sesuai.'},
      );
    }

    if (isPrimary) {
      final currentPrimaries = await pb
          .collection(AppConstants.colOrgMemberships)
          .getFullList(
            filter:
                'workspace = "${_escapeFilterValue(profile.workspace.id)}" && org_unit = "${_escapeFilterValue(orgUnitId)}" && is_primary = true',
          );
      for (final primary in currentPrimaries) {
        if (primary.id == membershipId) {
          continue;
        }
        await pb
            .collection(AppConstants.colOrgMemberships)
            .update(primary.id, body: {'is_primary': false});
      }
    }

    final body = <String, dynamic>{
      'workspace': profile.workspace.id,
      'user': workspaceMember.userId,
      'workspace_member': workspaceMember.id,
      'org_unit': orgUnitId,
      'jabatan': jabatanId,
      'is_primary': isPrimary,
      'status': status.trim().toLowerCase(),
      'period_label': periodLabel.trim(),
      'started_at': startedAt?.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
    };

    final collection = pb.collection(AppConstants.colOrgMemberships);
    final record = (membershipId ?? '').trim().isEmpty
        ? await collection.create(body: body)
        : await collection.update(membershipId!, body: body);
    return OrgMembershipModel.fromRecord(record);
  }

  Future<OrgMembershipModel> setOrgMembershipStatus({
    required String membershipId,
    required String status,
    DateTime? endedAt,
  }) async {
    final profile = await _requireAccessProfile();
    if (!profile.canManageMembership) {
      throw ClientException(
        statusCode: 403,
        response: const {'message': 'Anda tidak memiliki hak kelola pengurus.'},
      );
    }

    final record = await pb
        .collection(AppConstants.colOrgMemberships)
        .update(
          membershipId,
          body: {
            'status': status.trim().toLowerCase(),
            if (endedAt != null) 'ended_at': endedAt.toIso8601String(),
          },
        );
    return OrgMembershipModel.fromRecord(record);
  }

  Future<WorkspaceAccessProfile> _requireAccessProfile() async {
    final accessService = _ref.read(workspaceAccessServiceProvider);
    final profile = await accessService.getCurrentAccessProfile();
    if (profile == null) {
      final auth = _ref.read(authProvider);
      final authUser = auth.user;
      if (authUser != null && (auth.isSysadmin || auth.hasRwWideAccess)) {
        final resolved = await _resolveManageAccessProfile(
          auth: auth,
          authUser: authUser,
        );
        if (resolved != null) {
          return resolved;
        }
      }
      throw ClientException(
        statusCode: 403,
        response: const {'message': 'Workspace aktif belum tersedia.'},
      );
    }
    return profile;
  }

  Future<WorkspaceAccessProfile?> _resolveManageAccessProfile({
    required AuthState auth,
    required RecordModel authUser,
  }) async {
    final workspace = await _resolveReadableWorkspace(auth);
    if (workspace == null) {
      return null;
    }

    final member = await _ensureCurrentOperatorWorkspaceMember(
      workspace: workspace,
      authUser: authUser,
    );
    final orgMemberships = await _ref
        .read(workspaceAccessServiceProvider)
        .getOrgMemberships(
          workspaceId: workspace.id,
          userId: authUser.id,
          workspaceMemberId: member.id,
          activeOnly: true,
        );
    return WorkspaceAccessProfile(
      workspace: workspace,
      member: member,
      orgMemberships: orgMemberships,
    );
  }

  Future<List<WorkspaceMemberModel>> _loadWorkspaceMembers(
    String workspaceId,
  ) async {
    final memberRecords = await pb
        .collection(AppConstants.colWorkspaceMembers)
        .getFullList(
          filter:
              'workspace = "${_escapeFilterValue(workspaceId)}" && is_active = true',
          sort: '-is_owner,-owner_rank,created',
        );
    return memberRecords
        .map(WorkspaceMemberModel.fromRecord)
        .toList(growable: false);
  }

  Future<WorkspaceModel?> _resolveReadableWorkspace(AuthState auth) async {
    final area = await resolveAreaAccessContext(auth);
    final rw = area.rw;
    final regionFilters = <String>[];
    if (area.hasRegionalCodes) {
      regionFilters.addAll([
        'desa_code = "${_escapeFilterValue(area.desaCode!)}"',
        'kecamatan_code = "${_escapeFilterValue(area.kecamatanCode!)}"',
        'kabupaten_code = "${_escapeFilterValue(area.kabupatenCode!)}"',
        'provinsi_code = "${_escapeFilterValue(area.provinsiCode!)}"',
      ]);
    } else if (area.hasRegionalNames) {
      regionFilters.addAll([
        'desa_kelurahan ~ "${_escapeFilterValue(area.desaKelurahan!)}"',
        'kecamatan ~ "${_escapeFilterValue(area.kecamatan!)}"',
        'kabupaten_kota ~ "${_escapeFilterValue(area.kabupatenKota!)}"',
        'provinsi ~ "${_escapeFilterValue(area.provinsi!)}"',
      ]);
    }

    final candidateFilters = <String>[
      if (rw != null && rw > 0 && regionFilters.isNotEmpty)
        'status = "active" && rw = $rw && ${regionFilters.join(' && ')}',
      if (rw != null && rw > 0) 'status = "active" && rw = $rw',
      if (regionFilters.isNotEmpty)
        'status = "active" && ${regionFilters.join(' && ')}',
      'status = "active"',
    ];

    for (var i = 0; i < candidateFilters.length; i++) {
      final filter = candidateFilters[i];
      try {
        final result = await pb
            .collection(AppConstants.colWorkspaces)
            .getList(
              page: 1,
              perPage: i == candidateFilters.length - 1 ? 2 : 1,
              filter: filter,
              sort: '-updated,-created',
            );
        if (result.items.isEmpty) {
          continue;
        }
        if (i == candidateFilters.length - 1 && result.items.length != 1) {
          continue;
        }
        return WorkspaceModel.fromRecord(result.items.first);
      } catch (_) {
        continue;
      }
    }

    return null;
  }

  Future<WorkspaceMemberModel> _ensureCurrentOperatorWorkspaceMember({
    required WorkspaceModel workspace,
    required RecordModel authUser,
  }) async {
    final displayName = _bootstrapUserDisplayName(authUser);
    final systemRole = AppConstants.effectiveSystemRole(
      role: authUser.getStringValue('role'),
      systemRole: authUser.getStringValue('system_role'),
    );
    final planCode = AppConstants.effectivePlanCode(
      role: authUser.getStringValue('role'),
      planCode: authUser.getStringValue('plan_code'),
      subscriptionPlan: authUser.getStringValue('subscription_plan'),
    );
    final subscriptionStatus = AppConstants.normalizeSubscriptionStatus(
      authUser.getStringValue('subscription_status'),
    );
    final subscriptionStarted = authUser
        .getStringValue('subscription_started')
        .trim();
    final subscriptionExpired = authUser
        .getStringValue('subscription_expired')
        .trim();

    final existingResult = await pb
        .collection(AppConstants.colWorkspaceMembers)
        .getList(
          page: 1,
          perPage: 1,
          filter:
              'workspace = "${_escapeFilterValue(workspace.id)}" && user = "${_escapeFilterValue(authUser.id)}"',
          sort: '-is_owner,-owner_rank,created',
        );

    if (existingResult.items.isNotEmpty) {
      final existingRecord = existingResult.items.first;
      final existingMember = WorkspaceMemberModel.fromRecord(existingRecord);
      RecordModel resolvedRecord = existingRecord;
      if (_workspaceMemberNeedsSync(
        member: existingMember,
        displayName: displayName,
        systemRole: systemRole,
        planCode: planCode,
        subscriptionStatus: subscriptionStatus,
        scopeRw: workspace.rw,
      )) {
        resolvedRecord = await pb
            .collection(AppConstants.colWorkspaceMembers)
            .update(
              existingRecord.id,
              body: {
                'display_name': displayName,
                'system_role': systemRole,
                'plan_code': planCode,
                'subscription_status': subscriptionStatus,
                if (subscriptionStarted.isNotEmpty)
                  'subscription_started': subscriptionStarted,
                if (subscriptionExpired.isNotEmpty)
                  'subscription_expired': subscriptionExpired,
                'scope_type': AppConstants.unitTypeRw,
                'scope_rt': 0,
                'scope_rw': workspace.rw,
                'is_active': true,
              },
            );
      }

      final member = WorkspaceMemberModel.fromRecord(resolvedRecord);
      await _saveLocalOrganizationBinding(
        workspaceId: workspace.id,
        workspaceMemberId: member.id,
      );
      await _syncWorkspaceOwnerMember(workspace: workspace, member: member);
      return member;
    }

    final existingWorkspaceMembers = await pb
        .collection(AppConstants.colWorkspaceMembers)
        .getList(
          page: 1,
          perPage: 1,
          filter: 'workspace = "${_escapeFilterValue(workspace.id)}"',
          sort: '-is_owner,-owner_rank,created',
        );
    final shouldBeOwner = existingWorkspaceMembers.items.isEmpty;

    final createdRecord = await pb
        .collection(AppConstants.colWorkspaceMembers)
        .create(
          body: {
            'workspace': workspace.id,
            'user': authUser.id,
            'display_name': displayName,
            'system_role': systemRole,
            'plan_code': planCode,
            'subscription_status': subscriptionStatus,
            if (subscriptionStarted.isNotEmpty)
              'subscription_started': subscriptionStarted,
            if (subscriptionExpired.isNotEmpty)
              'subscription_expired': subscriptionExpired,
            'is_owner': shouldBeOwner,
            'owner_rank': shouldBeOwner ? _bootstrapOwnerRank(planCode) : 0,
            'scope_type': AppConstants.unitTypeRw,
            'scope_rt': 0,
            'scope_rw': workspace.rw,
            'is_active': true,
          },
        );
    final createdMember = WorkspaceMemberModel.fromRecord(createdRecord);
    await _saveLocalOrganizationBinding(
      workspaceId: workspace.id,
      workspaceMemberId: createdMember.id,
    );
    await _syncWorkspaceOwnerMember(
      workspace: workspace,
      member: createdMember,
    );
    return createdMember;
  }

  Future<void> _syncWorkspaceOwnerMember({
    required WorkspaceModel workspace,
    required WorkspaceMemberModel member,
  }) async {
    final currentOwnerMemberId = (workspace.ownerMemberId ?? '').trim();
    if (!member.isOwner && currentOwnerMemberId.isNotEmpty) {
      return;
    }
    if (currentOwnerMemberId == member.id) {
      return;
    }
    try {
      await pb
          .collection(AppConstants.colWorkspaces)
          .update(workspace.id, body: {'owner_member': member.id});
    } catch (_) {}
  }

  WorkspaceAccessProfile _buildPublicReadProfile({
    required RecordModel authUser,
    required WorkspaceModel workspace,
  }) {
    final record = RecordModel.fromJson({
      'id': 'public-${workspace.id}-${authUser.id}',
      'workspace': workspace.id,
      'user': authUser.id,
      'display_name': _bootstrapUserDisplayName(authUser),
      'system_role': AppConstants.systemRoleWarga,
      'plan_code': AppConstants.planFree,
      'subscription_status': 'inactive',
      'is_owner': false,
      'owner_rank': 0,
      'scope_type': AppConstants.unitTypeRw,
      'scope_rt': 0,
      'scope_rw': workspace.rw,
      'is_active': true,
    });

    return WorkspaceAccessProfile(
      workspace: workspace,
      member: WorkspaceMemberModel.fromRecord(record),
      orgMemberships: const [],
    );
  }

  Future<List<OrganizationMembershipCandidate>> _buildMembershipCandidates({
    required WorkspaceAccessProfile profile,
    required List<OrganizationWorkspaceActor> workspaceActors,
  }) async {
    final candidateByUserId = <String, OrganizationMembershipCandidate>{};
    for (final actor in workspaceActors) {
      candidateByUserId[actor.member.userId] = OrganizationMembershipCandidate(
        userId: actor.member.userId,
        displayName: actor.displayName,
        email: actor.email,
        workspaceMemberId: actor.member.id,
        scopeRt: actor.member.scopeRt,
        scopeRw: actor.member.scopeRw,
      );
    }

    final wargaFilter = _buildWorkspaceWargaFilter(profile.workspace);
    if (wargaFilter.isNotEmpty) {
      try {
        final wargaRecords = await pb
            .collection(AppConstants.colWarga)
            .getFullList(filter: wargaFilter, sort: 'nama_lengkap,created');
        for (final warga in wargaRecords) {
          final userId = warga.getStringValue('user_id').trim();
          if (userId.isEmpty) {
            continue;
          }
          final existing = candidateByUserId[userId];
          final namaLengkap = warga.getStringValue('nama_lengkap').trim();
          final email = warga.getStringValue('email').trim();
          candidateByUserId[userId] = OrganizationMembershipCandidate(
            userId: userId,
            displayName: _firstNonEmptyString([
              existing?.displayName,
              namaLengkap,
              _emailLocalPart(email),
              userId,
            ]),
            email: _firstNonEmptyString([existing?.email, email]),
            workspaceMemberId: existing?.workspaceMemberId,
            scopeRt: existing?.scopeRt ?? _recordIntOrNull(warga, 'rt'),
            scopeRw: existing?.scopeRw ?? _recordIntOrNull(warga, 'rw'),
          );
        }
      } catch (_) {}
    }

    final candidates = candidateByUserId.values.toList(growable: false);
    candidates.sort((a, b) {
      final nameCompare = a.displayName.toLowerCase().compareTo(
        b.displayName.toLowerCase(),
      );
      if (nameCompare != 0) {
        return nameCompare;
      }
      return a.userId.compareTo(b.userId);
    });
    return candidates;
  }

  Future<List<OrganizationWorkspaceActor>> _buildWorkspaceActors(
    List<WorkspaceMemberModel> members,
  ) async {
    if (members.isEmpty) {
      return const [];
    }
    final userById = <String, RecordModel>{};
    final wargaByUserId = <String, RecordModel>{};
    final userIds = members.map((member) => member.userId).toSet().toList();
    try {
      final userRecords = await pb
          .collection(AppConstants.colUsers)
          .getFullList(filter: _orFilter('id', userIds));
      userById.addEntries(userRecords.map((user) => MapEntry(user.id, user)));
    } catch (_) {}
    try {
      final wargaRecords = await pb
          .collection(AppConstants.colWarga)
          .getFullList(filter: _orFilter('user_id', userIds));
      wargaByUserId.addEntries(
        wargaRecords.map(
          (warga) => MapEntry(warga.getStringValue('user_id'), warga),
        ),
      );
    } catch (_) {}

    String? resolveAvatarUrl(RecordModel? user, RecordModel? warga) {
      final avatarFile = user?.getStringValue('avatar').trim() ?? '';
      if (user != null && avatarFile.isNotEmpty) {
        return getFileUrl(user, avatarFile);
      }
      final fotoWarga = warga?.getStringValue('foto_warga').trim() ?? '';
      if (warga != null && fotoWarga.isNotEmpty) {
        return getFileUrl(warga, fotoWarga);
      }
      return null;
    }

    return members
        .map((member) {
          final user = userById[member.userId];
          final warga = wargaByUserId[member.userId];
          final displayName = _organizationActorDisplayName(
            member: member,
            user: user,
            warga: warga,
          );
          return OrganizationWorkspaceActor(
            member: member,
            displayName: displayName,
            email: user?.getStringValue('email') ?? '',
            avatarUrl: resolveAvatarUrl(user, warga),
          );
        })
        .toList(growable: false);
  }

  Future<WorkspaceMemberModel> _resolveWorkspaceMemberForMembership({
    required WorkspaceAccessProfile profile,
    String? workspaceMemberId,
    String? userId,
    String displayName = '',
    String email = '',
    int? scopeRt,
    int? scopeRw,
  }) async {
    final normalizedMemberId = (workspaceMemberId ?? '').trim();
    if (normalizedMemberId.isNotEmpty) {
      final workspaceMemberRecord = await pb
          .collection(AppConstants.colWorkspaceMembers)
          .getOne(normalizedMemberId);
      return WorkspaceMemberModel.fromRecord(workspaceMemberRecord);
    }

    final normalizedUserId = (userId ?? '').trim();
    if (normalizedUserId.isEmpty) {
      throw ClientException(
        statusCode: 400,
        response: const {'message': 'Akun pengurus wajib dipilih.'},
      );
    }

    final existingMembers = await pb
        .collection(AppConstants.colWorkspaceMembers)
        .getList(
          page: 1,
          perPage: 1,
          filter:
              'workspace = "${_escapeFilterValue(profile.workspace.id)}" && user = "${_escapeFilterValue(normalizedUserId)}" && is_active = true',
          sort: '-is_owner,-owner_rank,created',
        );
    if (existingMembers.items.isNotEmpty) {
      return WorkspaceMemberModel.fromRecord(existingMembers.items.first);
    }

    RecordModel? userRecord;
    try {
      userRecord = await pb
          .collection(AppConstants.colUsers)
          .getOne(normalizedUserId);
    } catch (_) {}

    final resolvedDisplayName = _firstNonEmptyString([
      displayName,
      userRecord?.getStringValue('name'),
      userRecord?.getStringValue('nama'),
      userRecord?.getStringValue('username'),
      _emailLocalPart(email),
      _emailLocalPart(userRecord?.getStringValue('email') ?? ''),
      normalizedUserId,
    ]);
    final normalizedScopeRw = scopeRw != null && scopeRw > 0
        ? scopeRw
        : profile.workspace.rw;
    final normalizedScopeRt = scopeRt != null && scopeRt > 0 ? scopeRt : null;
    final systemRole = userRecord == null
        ? AppConstants.systemRoleWarga
        : AppConstants.effectiveSystemRole(
            role: userRecord.getStringValue('role'),
            systemRole: userRecord.getStringValue('system_role'),
          );
    final planCode = userRecord == null
        ? AppConstants.planFree
        : AppConstants.effectivePlanCode(
            role: userRecord.getStringValue('role'),
            planCode: userRecord.getStringValue('plan_code'),
            subscriptionPlan: userRecord.getStringValue('subscription_plan'),
          );
    final subscriptionStatus = userRecord == null
        ? 'inactive'
        : AppConstants.normalizeSubscriptionStatus(
            userRecord.getStringValue('subscription_status'),
          );

    final created = await pb
        .collection(AppConstants.colWorkspaceMembers)
        .create(
          body: {
            'workspace': profile.workspace.id,
            'user': normalizedUserId,
            'display_name': resolvedDisplayName,
            'system_role': systemRole,
            'plan_code': planCode,
            'subscription_status': subscriptionStatus,
            if ((userRecord?.getStringValue('subscription_started') ?? '')
                .trim()
                .isNotEmpty)
              'subscription_started': userRecord!.getStringValue(
                'subscription_started',
              ),
            if ((userRecord?.getStringValue('subscription_expired') ?? '')
                .trim()
                .isNotEmpty)
              'subscription_expired': userRecord!.getStringValue(
                'subscription_expired',
              ),
            'is_owner': false,
            'owner_rank': 0,
            'scope_type': normalizedScopeRt != null
                ? AppConstants.unitTypeRt
                : AppConstants.unitTypeRw,
            'scope_rt': normalizedScopeRt ?? 0,
            'scope_rw': normalizedScopeRw,
            'is_active': true,
          },
        );
    return WorkspaceMemberModel.fromRecord(created);
  }
}

bool _workspaceMemberNeedsSync({
  required WorkspaceMemberModel member,
  required String displayName,
  required String systemRole,
  required String planCode,
  required String subscriptionStatus,
  required int scopeRw,
}) {
  return member.displayName.trim() != displayName.trim() ||
      member.systemRole.trim() != systemRole.trim() ||
      member.planCode.trim() != planCode.trim() ||
      member.subscriptionStatus.trim() != subscriptionStatus.trim() ||
      (member.scopeType ?? '').trim() != AppConstants.unitTypeRw ||
      (member.scopeRt ?? 0) != 0 ||
      (member.scopeRw ?? 0) != scopeRw ||
      !member.isActive;
}

String _organizationActorDisplayName({
  required WorkspaceMemberModel member,
  RecordModel? user,
  RecordModel? warga,
}) {
  final displayName = member.displayName.trim();
  if (displayName.isNotEmpty) {
    return displayName;
  }

  final wargaName = warga?.getStringValue('nama_lengkap').trim() ?? '';
  if (wargaName.isNotEmpty) {
    return wargaName;
  }

  return _organizationUserDisplayName(user, member.userId);
}

String _resolveOrgUnitCode({
  required String rawCode,
  required String name,
  required String type,
}) {
  final normalizedCode = rawCode.trim().toLowerCase();
  if (normalizedCode.isNotEmpty) {
    return normalizedCode;
  }
  final normalizedName = name.trim();
  if (normalizedName.isEmpty) {
    return '';
  }

  final slug = normalizedName
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  if (slug.isEmpty) {
    return type.trim().toLowerCase();
  }
  return '$type-$slug';
}

String _bootstrapWorkspaceCode(String workspaceName, int rw) {
  final slug = workspaceName
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  final suffix = DateTime.now().millisecondsSinceEpoch;
  final base = slug.isEmpty ? 'rw' : slug;
  return 'rw-$rw-$base-$suffix';
}

String _bootstrapRwUnitName(String workspaceName, int rw) {
  final trimmed = workspaceName.trim();
  if (trimmed.toLowerCase().contains('rw $rw')) {
    return trimmed;
  }
  return 'RW $rw';
}

int _bootstrapOwnerRank(String planCode) {
  switch (planCode) {
    case AppConstants.planRwPro:
      return 3;
    case AppConstants.planRw:
      return 2;
    case AppConstants.planRt:
      return 1;
    default:
      return 0;
  }
}

String _bootstrapUserDisplayName(RecordModel authUser) {
  final candidates = [
    authUser.getStringValue('name'),
    authUser.getStringValue('nama'),
    authUser.getStringValue('username'),
  ];
  for (final candidate in candidates) {
    final normalized = candidate.trim();
    if (normalized.isNotEmpty) {
      return normalized;
    }
  }
  final email = authUser.getStringValue('email').trim();
  if (email.isNotEmpty) {
    return email.split('@').first;
  }
  return authUser.id;
}

Future<void> _saveLocalOrganizationBinding({
  required String workspaceId,
  required String workspaceMemberId,
}) async {
  final currentRecord = pb.authStore.record;
  final currentToken = pb.authStore.token;
  if (currentRecord == null || currentToken.isEmpty) {
    return;
  }
  final currentWorkspace = currentRecord
      .getStringValue('active_workspace')
      .trim();
  final currentMember = currentRecord
      .getStringValue('active_workspace_member')
      .trim();
  if (currentWorkspace == workspaceId && currentMember == workspaceMemberId) {
    return;
  }
  final data = Map<String, dynamic>.from(currentRecord.toJson())
    ..['active_workspace'] = workspaceId
    ..['active_workspace_member'] = workspaceMemberId;
  pb.authStore.save(currentToken, RecordModel.fromJson(data));
  try {
    final updated = await pb
        .collection(AppConstants.colUsers)
        .update(
          currentRecord.id,
          body: {
            'active_workspace': workspaceId,
            'active_workspace_member': workspaceMemberId,
          },
        );
    pb.authStore.save(currentToken, updated);
  } catch (_) {}
}

Future<void> _saveReadableWorkspaceBinding({
  required String workspaceId,
}) async {
  final currentRecord = pb.authStore.record;
  final currentToken = pb.authStore.token;
  if (currentRecord == null || currentToken.isEmpty) {
    return;
  }
  final currentWorkspace = currentRecord
      .getStringValue('active_workspace')
      .trim();
  if (currentWorkspace == workspaceId) {
    return;
  }
  final currentMember = currentRecord
      .getStringValue('active_workspace_member')
      .trim();
  final data = Map<String, dynamic>.from(currentRecord.toJson())
    ..['active_workspace'] = workspaceId
    ..['active_workspace_member'] = currentMember;
  pb.authStore.save(currentToken, RecordModel.fromJson(data));
  try {
    final updated = await pb
        .collection(AppConstants.colUsers)
        .update(
          currentRecord.id,
          body: {
            'active_workspace': workspaceId,
            'active_workspace_member': currentMember,
          },
        );
    pb.authStore.save(currentToken, updated);
  } catch (_) {}
}

String _orFilter(String field, List<String> ids) {
  return ids
      .where((id) => id.trim().isNotEmpty)
      .map((id) => '$field = "${_escapeFilterValue(id)}"')
      .join(' || ');
}

String _escapeFilterValue(String value) {
  return value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
}

String _organizationUserDisplayName(RecordModel? user, String fallbackId) {
  final nameCandidates = [
    user?.getStringValue('name'),
    user?.getStringValue('nama'),
    user?.getStringValue('username'),
  ];

  for (final candidate in nameCandidates) {
    final normalized = (candidate ?? '').trim();
    if (normalized.isNotEmpty) {
      return normalized;
    }
  }

  final email = user?.getStringValue('email').trim() ?? '';
  if (email.isNotEmpty) {
    return email.split('@').first;
  }

  return fallbackId;
}

String _buildWorkspaceWargaFilter(WorkspaceModel workspace) {
  final filters = <String>[];
  if (workspace.rw > 0) {
    filters.add('rw = ${workspace.rw}');
  }

  final desaCode = (workspace.desaCode ?? '').trim();
  final kecamatanCode = (workspace.kecamatanCode ?? '').trim();
  final kabupatenCode = (workspace.kabupatenCode ?? '').trim();
  final provinsiCode = (workspace.provinsiCode ?? '').trim();
  final desaKelurahan = (workspace.desaKelurahan ?? '').trim();
  final kecamatan = (workspace.kecamatan ?? '').trim();
  final kabupatenKota = (workspace.kabupatenKota ?? '').trim();
  final provinsi = (workspace.provinsi ?? '').trim();

  if (desaCode.isNotEmpty &&
      kecamatanCode.isNotEmpty &&
      kabupatenCode.isNotEmpty &&
      provinsiCode.isNotEmpty) {
    filters.add(
      [
        'no_kk.desa_code = "${_escapeFilterValue(desaCode)}"',
        'no_kk.kecamatan_code = "${_escapeFilterValue(kecamatanCode)}"',
        'no_kk.kabupaten_code = "${_escapeFilterValue(kabupatenCode)}"',
        'no_kk.provinsi_code = "${_escapeFilterValue(provinsiCode)}"',
      ].join(' && '),
    );
  } else if (desaKelurahan.isNotEmpty &&
      kecamatan.isNotEmpty &&
      kabupatenKota.isNotEmpty &&
      provinsi.isNotEmpty) {
    filters.add(
      [
        'no_kk.desa_kelurahan ~ "${_escapeFilterValue(desaKelurahan)}"',
        'no_kk.kecamatan ~ "${_escapeFilterValue(kecamatan)}"',
        'no_kk.kabupaten_kota ~ "${_escapeFilterValue(kabupatenKota)}"',
        'no_kk.provinsi ~ "${_escapeFilterValue(provinsi)}"',
      ].join(' && '),
    );
  }

  if (filters.isEmpty) {
    return '';
  }
  return filters.join(' && ');
}

String _firstNonEmptyString(List<String?> values) {
  for (final value in values) {
    final normalized = (value ?? '').trim();
    if (normalized.isNotEmpty) {
      return normalized;
    }
  }
  return '';
}

String _emailLocalPart(String email) {
  final normalized = email.trim();
  if (normalized.isEmpty) {
    return '';
  }
  return normalized.split('@').first.trim();
}

int? _recordIntOrNull(RecordModel record, String field) {
  final raw = record.data[field];
  if (raw is int) {
    return raw;
  }
  return int.tryParse(record.getStringValue(field).trim());
}
