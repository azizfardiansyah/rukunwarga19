import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../shared/models/workspace_access_model.dart';
import '../constants/app_constants.dart';
import 'pocketbase_service.dart';

final workspaceAccessServiceProvider = Provider<WorkspaceAccessService>((ref) {
  return WorkspaceAccessService(ref);
});

class WorkspaceAccessService {
  WorkspaceAccessService(this._ref);

  final Ref _ref;

  AuthState get _auth => _ref.read(authProvider);

  Future<WorkspaceAccessProfile?> getCurrentAccessProfile() async {
    final authUser = _auth.user;
    if (authUser == null) {
      return null;
    }

    final member = await _resolveActiveWorkspaceMember(authUser);
    if (member == null) {
      return null;
    }
    if (member.workspaceId.isEmpty) {
      return null;
    }

    final workspaceRecord = await pb
        .collection(AppConstants.colWorkspaces)
        .getOne(member.workspaceId);
    final workspace = WorkspaceModel.fromRecord(workspaceRecord);
    final orgMemberships = await getOrgMemberships(
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

  Future<List<WorkspaceMemberModel>> getWorkspaceMembers(
    String workspaceId,
  ) async {
    final records = await pb
        .collection(AppConstants.colWorkspaceMembers)
        .getFullList(
          filter:
              'workspace = "${_escapeFilterValue(workspaceId)}" && is_active = true',
          sort: '-is_owner,-owner_rank,created',
        );
    return records.map(WorkspaceMemberModel.fromRecord).toList(growable: false);
  }

  Future<List<OrgUnitModel>> getOrgUnits(
    String workspaceId, {
    String? type,
    bool officialOnly = false,
  }) async {
    final filters = <String>[
      'workspace = "${_escapeFilterValue(workspaceId)}"',
      'status = "active"',
    ];
    final normalizedType = (type ?? '').trim().toLowerCase();
    if (normalizedType.isNotEmpty) {
      filters.add('type = "${_escapeFilterValue(normalizedType)}"');
    }
    if (officialOnly) {
      filters.add('is_official = true');
    }

    final records = await pb
        .collection(AppConstants.colOrgUnits)
        .getFullList(filter: filters.join(' && '), sort: 'type,name,created');
    return records.map(OrgUnitModel.fromRecord).toList(growable: false);
  }

  Future<List<JabatanMasterModel>> getJabatanMaster({String? unitType}) async {
    final filters = <String>['is_active = true'];
    final normalizedType = (unitType ?? '').trim().toLowerCase();
    if (normalizedType.isNotEmpty) {
      filters.add('unit_type = "${_escapeFilterValue(normalizedType)}"');
    }

    final records = await pb
        .collection(AppConstants.colJabatanMaster)
        .getFullList(filter: filters.join(' && '), sort: 'sort_order,created');
    return records.map(JabatanMasterModel.fromRecord).toList(growable: false);
  }

  Future<List<OrgMembershipModel>> getOrgMemberships({
    required String workspaceId,
    String? userId,
    String? workspaceMemberId,
    String? orgUnitId,
    bool activeOnly = false,
  }) async {
    final filters = <String>[
      'workspace = "${_escapeFilterValue(workspaceId)}"',
    ];
    if ((userId ?? '').isNotEmpty) {
      filters.add('user = "${_escapeFilterValue(userId!)}"');
    }
    if ((workspaceMemberId ?? '').isNotEmpty) {
      filters.add(
        'workspace_member = "${_escapeFilterValue(workspaceMemberId!)}"',
      );
    }
    if ((orgUnitId ?? '').isNotEmpty) {
      filters.add('org_unit = "${_escapeFilterValue(orgUnitId!)}"');
    }
    if (activeOnly) {
      filters.add('status = "active"');
    }

    final unitRecords = await getOrgUnits(workspaceId);
    final unitMap = {for (final unit in unitRecords) unit.id: unit};
    final jabatanRecords = await getJabatanMaster();
    final jabatanMap = {
      for (final jabatan in jabatanRecords) jabatan.id: jabatan,
    };

    final records = await pb
        .collection(AppConstants.colOrgMemberships)
        .getFullList(filter: filters.join(' && '), sort: '-is_primary,created');
    return records
        .map(
          (record) => OrgMembershipModel.fromRecord(
            record,
            jabatan: jabatanMap[record.getStringValue('jabatan')],
            orgUnit: unitMap[record.getStringValue('org_unit')],
          ),
        )
        .toList(growable: false);
  }

  Future<bool> canAccessOrgUnit(String orgUnitId) async {
    final profile = await getCurrentAccessProfile();
    if (profile == null) {
      return false;
    }
    if (profile.member.isSysadmin) {
      return true;
    }
    return profile.hasUnitMembership(orgUnitId);
  }

  Future<WorkspaceMemberModel?> _resolveActiveWorkspaceMember(
    RecordModel authUser,
  ) async {
    final activeMemberId = authUser.getStringValue('active_workspace_member');
    if (activeMemberId.isNotEmpty) {
      try {
        final record = await pb
            .collection(AppConstants.colWorkspaceMembers)
            .getOne(activeMemberId);
        return WorkspaceMemberModel.fromRecord(record);
      } catch (_) {}
    }

    try {
      final result = await pb
          .collection(AppConstants.colWorkspaceMembers)
          .getList(
            page: 1,
            perPage: 1,
            filter:
                'user = "${_escapeFilterValue(authUser.id)}" && is_active = true',
            sort: '-is_owner,-owner_rank,created',
          );
      if (result.items.isEmpty) {
        return null;
      }
      return WorkspaceMemberModel.fromRecord(result.items.first);
    } catch (_) {
      return null;
    }
  }
}

String _escapeFilterValue(String value) {
  return value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
}
