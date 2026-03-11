import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

import '../constants/app_constants.dart';
import 'pocketbase_service.dart';
import '../../shared/models/role_request_model.dart';

final roleManagementServiceProvider = Provider<RoleManagementService>((ref) {
  return RoleManagementService(pb);
});

class RoleManagementService {
  RoleManagementService(this._pb);

  final PocketBase _pb;

  Future<List<RecordModel>> getAllUsers() async {
    final result = await _pb
        .collection(AppConstants.colUsers)
        .getList(page: 1, perPage: 200, sort: '-created');

    return result.items;
  }

  Future<List<RoleRequestModel>> getRoleRequests({String? requesterId}) async {
    final filter = requesterId == null || requesterId.isEmpty
        ? ''
        : 'requester = "$requesterId"';

    final result = await _pb
        .collection(AppConstants.colRoleRequests)
        .getList(
          page: 1,
          perPage: 200,
          sort: '-created',
          filter: filter,
          expand: 'requester,reviewer',
        );

    return result.items.map(RoleRequestModel.fromRecord).toList();
  }

  Future<void> submitRoleRequest({
    required String requestedRole,
    required String reason,
  }) async {
    final authUser = _pb.authStore.record;

    if (authUser == null) {
      throw StateError('User belum login.');
    }

    final normalizedRole = AppConstants.normalizeRole(requestedRole);

    if (!AppConstants.requestableRoles.contains(normalizedRole)) {
      throw ArgumentError('Role tujuan tidak valid.');
    }

    final currentRole = AppConstants.normalizeRole(
      authUser.getStringValue('role'),
    );

    if (currentRole == normalizedRole) {
      throw ArgumentError('Role yang diminta sama dengan role saat ini.');
    }

    final pending = await _findPendingRequest(authUser.id);
    if (pending != null) {
      throw StateError('Masih ada pengajuan role yang belum diproses.');
    }

    await _pb
        .collection(AppConstants.colRoleRequests)
        .create(
          body: {
            'requester': authUser.id,
            'requested_role': normalizedRole,
            'current_role': currentRole,
            'reason': reason.trim(),
            'status': AppConstants.roleRequestPending,
          },
        );
  }

  Future<void> unsubscribeCurrentUser() async {
    final authUser = _pb.authStore.record;

    if (authUser == null) {
      throw StateError('User belum login.');
    }

    final currentRole = AppConstants.normalizeRole(
      authUser.getStringValue('role'),
    );

    if (!AppConstants.canRequestUnsubscribe(currentRole)) {
      throw ArgumentError('Role saat ini tidak memerlukan proses unsubscribe.');
    }

    await _pb.send<Map<String, dynamic>>(
      '/api/rukunwarga/account/unsubscribe',
      method: 'POST',
    );
  }

  Future<void> approveRoleRequest({
    required RoleRequestModel request,
    required String reviewNote,
  }) async {
    final reviewer = _pb.authStore.record;

    if (reviewer == null) {
      throw StateError('Sysadmin belum login.');
    }

    final user = await _pb
        .collection(AppConstants.colUsers)
        .getOne(request.requester);
    final requestedRole = AppConstants.normalizeRole(request.requestedRole);
    final userBody = _buildAccessBodyForRole(requestedRole);

    await _pb.collection(AppConstants.colUsers).update(user.id, body: userBody);
    await _pb
        .collection(AppConstants.colRoleRequests)
        .update(
          request.id,
          body: {
            'status': AppConstants.roleRequestApproved,
            'reviewer': reviewer.id,
            'review_note': reviewNote.trim(),
          },
        );
  }

  Future<void> rejectRoleRequest({
    required RoleRequestModel request,
    required String reviewNote,
  }) async {
    final reviewer = _pb.authStore.record;

    if (reviewer == null) {
      throw StateError('Sysadmin belum login.');
    }

    await _pb
        .collection(AppConstants.colRoleRequests)
        .update(
          request.id,
          body: {
            'status': AppConstants.roleRequestRejected,
            'reviewer': reviewer.id,
            'review_note': reviewNote.trim(),
          },
        );
  }

  Future<void> updateUserRole({
    required RecordModel user,
    required String newRole,
  }) async {
    final normalizedRole = AppConstants.normalizeRole(newRole);
    final body = _buildAccessBodyForRole(
      normalizedRole,
      existingSubscriptionPlan: user.getStringValue('subscription_plan'),
      existingSubscriptionStatus: user.getStringValue('subscription_status'),
    );

    await _pb.collection(AppConstants.colUsers).update(user.id, body: body);
  }

  Future<void> activateSubscription({
    required RecordModel user,
    int durationDays = 30,
  }) async {
    final normalizedRole = AppConstants.normalizeRole(
      user.getStringValue('role'),
    );
    final plan = AppConstants.subscriptionPlanForRole(normalizedRole);

    if (plan == null) {
      throw ArgumentError('Role user ini tidak memakai subscription.');
    }

    final now = DateTime.now();
    final nextExpiry = now.add(Duration(days: durationDays));

    await _pb
        .collection(AppConstants.colUsers)
        .update(
          user.id,
          body: {
            'role': normalizedRole,
            'system_role': AppConstants.systemRoleFromRole(normalizedRole),
            'plan_code': AppConstants.planCodeFromRole(normalizedRole),
            'subscription_plan': plan,
            'subscription_status': AppConstants.subscriptionStatusActive,
            'subscription_started': now.toIso8601String(),
            'subscription_expired': nextExpiry.toIso8601String(),
          },
        );
  }

  Future<void> deactivateSubscription({required RecordModel user}) async {
    await _pb
        .collection(AppConstants.colUsers)
        .update(
          user.id,
          body: {
            'plan_code': AppConstants.planCodeFromRole(
              user.getStringValue('role'),
            ),
            'subscription_status': AppConstants.subscriptionStatusInactive,
            'subscription_started': null,
            'subscription_expired': null,
          },
        );
  }

  Future<RoleRequestModel?> _findPendingRequest(String requesterId) async {
    try {
      final record = await _pb
          .collection(AppConstants.colRoleRequests)
          .getFirstListItem(
            'requester = "$requesterId" && status = "${AppConstants.roleRequestPending}"',
            expand: 'requester,reviewer',
          );
      return RoleRequestModel.fromRecord(record);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _buildAccessBodyForRole(
    String role, {
    String? existingSubscriptionPlan,
    String? existingSubscriptionStatus,
  }) {
    final normalizedRole = AppConstants.normalizeRole(role);
    final body = <String, dynamic>{
      'role': normalizedRole,
      'system_role': AppConstants.systemRoleFromRole(normalizedRole),
      'plan_code': AppConstants.planCodeFromRole(normalizedRole),
    };

    if (AppConstants.requiresSubscription(normalizedRole)) {
      body['subscription_plan'] = (existingSubscriptionPlan ?? '').isNotEmpty
          ? existingSubscriptionPlan
          : (AppConstants.subscriptionPlanForRole(normalizedRole) ?? '');
      body['subscription_status'] =
          (existingSubscriptionStatus ?? '').isNotEmpty
          ? AppConstants.normalizeSubscriptionStatus(
              existingSubscriptionStatus!,
            )
          : AppConstants.subscriptionStatusInactive;
      body['subscription_started'] = null;
      body['subscription_expired'] = null;
    } else {
      body['subscription_plan'] = '';
      body['subscription_status'] = AppConstants.subscriptionStatusInactive;
      body['subscription_started'] = null;
      body['subscription_expired'] = null;
    }

    return body;
  }
}
