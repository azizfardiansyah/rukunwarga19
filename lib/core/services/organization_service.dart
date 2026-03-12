import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../shared/models/workspace_access_model.dart';
import '../constants/app_constants.dart';
import 'pocketbase_service.dart';
import 'workspace_access_service.dart';

final organizationServiceProvider = Provider<OrganizationService>((ref) {
  return OrganizationService(ref);
});

class OrganizationWorkspaceActor {
  const OrganizationWorkspaceActor({
    required this.member,
    required this.displayName,
    required this.email,
  });

  final WorkspaceMemberModel member;
  final String displayName;
  final String email;

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

class OrganizationService {
  OrganizationService(this._ref);

  final Ref _ref;

  Future<OrganizationOverviewData> fetchOverview() async {
    final profile = await _requireAccessProfile();
    final workspaceId = profile.workspace.id;

    final memberRecords = await pb
        .collection(AppConstants.colWorkspaceMembers)
        .getFullList(
          filter:
              'workspace = "${_escapeFilterValue(workspaceId)}" && is_active = true',
          sort: '-is_owner,-owner_rank,created',
        );
    final members = memberRecords
        .map(WorkspaceMemberModel.fromRecord)
        .toList(growable: false);
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
    required String code,
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
    if (name.trim().isEmpty || code.trim().isEmpty) {
      throw ClientException(
        statusCode: 400,
        response: const {'message': 'Nama dan kode unit wajib diisi.'},
      );
    }

    final normalizedType = type.trim().toLowerCase();
    final body = <String, dynamic>{
      'workspace': profile.workspace.id,
      'type': normalizedType,
      'name': name.trim(),
      'code': code.trim().toLowerCase(),
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
    required String workspaceMemberId,
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

    final workspaceMemberRecord = await pb
        .collection(AppConstants.colWorkspaceMembers)
        .getOne(workspaceMemberId);
    final workspaceMember = WorkspaceMemberModel.fromRecord(
      workspaceMemberRecord,
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
                'workspace_member = "${_escapeFilterValue(workspaceMemberId)}" && org_unit = "${_escapeFilterValue(orgUnitId)}" && is_primary = true',
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
      'workspace_member': workspaceMemberId,
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
    final profile = await _ref
        .read(workspaceAccessServiceProvider)
        .getCurrentAccessProfile();
    if (profile == null) {
      throw ClientException(
        statusCode: 403,
        response: const {'message': 'Workspace aktif belum tersedia.'},
      );
    }
    return profile;
  }

  Future<List<OrganizationWorkspaceActor>> _buildWorkspaceActors(
    List<WorkspaceMemberModel> members,
  ) async {
    if (members.isEmpty) {
      return const [];
    }
    final userIds = members.map((member) => member.userId).toSet().toList();
    final userRecords = await pb
        .collection(AppConstants.colUsers)
        .getFullList(filter: _orFilter('id', userIds));
    final userById = {for (final user in userRecords) user.id: user};

    return members
        .map((member) {
          final user = userById[member.userId];
          final displayName = _organizationUserDisplayName(user, member.userId);
          return OrganizationWorkspaceActor(
            member: member,
            displayName: displayName,
            email: user?.getStringValue('email') ?? '',
          );
        })
        .toList(growable: false);
  }
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
