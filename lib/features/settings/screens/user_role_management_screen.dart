import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../app/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/role_management_service.dart';
import '../../../core/utils/error_classifier.dart';
import '../../../core/utils/formatters.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/models/role_request_model.dart';

final managedUsersProvider = FutureProvider.autoDispose<List<RecordModel>>((
  ref,
) async {
  try {
    return await ref.watch(roleManagementServiceProvider).getAllUsers();
  } catch (error) {
    if (ErrorClassifier.isAuthError(error)) {
      ref.read(authProvider.notifier).logout();
    }
    rethrow;
  }
});

final allRoleRequestsProvider =
    FutureProvider.autoDispose<List<RoleRequestModel>>((ref) async {
      try {
        return await ref.watch(roleManagementServiceProvider).getRoleRequests();
      } catch (error) {
        if (ErrorClassifier.isAuthError(error)) {
          ref.read(authProvider.notifier).logout();
        }
        rethrow;
      }
    });

class UserRoleManagementScreen extends ConsumerStatefulWidget {
  const UserRoleManagementScreen({super.key});

  @override
  ConsumerState<UserRoleManagementScreen> createState() =>
      _UserRoleManagementScreenState();
}

class _UserRoleManagementScreenState
    extends ConsumerState<UserRoleManagementScreen> {
  String _searchQuery = '';

  Future<void> _showRoleDialog(RecordModel user) async {
    String selectedRole = AppConstants.normalizeRole(
      user.getStringValue('role'),
    );

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Ubah Role User'),
            content: DropdownButtonFormField<String>(
              initialValue: selectedRole,
              decoration: const InputDecoration(labelText: 'Role'),
              items: AppConstants.assignableRoles
                  .map(
                    (role) => DropdownMenuItem(
                      value: role,
                      child: Text(AppConstants.roleLabel(role)),
                    ),
                  )
                  .toList(),
              onChanged: (value) => selectedRole = value ?? selectedRole,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Simpan'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    try {
      await ref
          .read(roleManagementServiceProvider)
          .updateUserRole(user: user, newRole: selectedRole);
      if (!mounted) return;
      ErrorClassifier.showSuccessSnackBar(context, 'Role user diperbarui.');
      ref.invalidate(managedUsersProvider);
      ref.invalidate(allRoleRequestsProvider);
    } catch (e) {
      if (!mounted) return;
      ErrorClassifier.showErrorSnackBar(context, e);
    }
  }

  Future<void> _toggleSubscription(RecordModel user, bool activate) async {
    try {
      final service = ref.read(roleManagementServiceProvider);
      if (activate) {
        await service.activateSubscription(user: user);
      } else {
        await service.deactivateSubscription(user: user);
      }
      if (!mounted) return;
      ErrorClassifier.showSuccessSnackBar(
        context,
        activate ? 'Subscription diaktifkan.' : 'Subscription dinonaktifkan.',
      );
      ref.invalidate(managedUsersProvider);
    } catch (e) {
      if (!mounted) return;
      ErrorClassifier.showErrorSnackBar(context, e);
    }
  }

  Future<void> _handleRequestAction(
    RoleRequestModel request, {
    required bool approve,
  }) async {
    final isUnsubscribeRequest =
        AppConstants.normalizeRole(request.requestedRole) ==
        AppConstants.roleWarga;
    final dialogTitle = approve
        ? (isUnsubscribeRequest ? 'Setujui Unsubscribe' : 'Setujui Pengajuan')
        : (isUnsubscribeRequest ? 'Tolak Unsubscribe' : 'Tolak Pengajuan');
    final actionLabel = approve
        ? (isUnsubscribeRequest ? 'Setujui Unsubscribe' : 'Setujui')
        : (isUnsubscribeRequest ? 'Tolak Unsubscribe' : 'Tolak');
    final successMessage = approve
        ? (isUnsubscribeRequest
              ? 'Pengajuan unsubscribe disetujui.'
              : 'Pengajuan disetujui.')
        : (isUnsubscribeRequest
              ? 'Pengajuan unsubscribe ditolak.'
              : 'Pengajuan ditolak.');
    final noteController = TextEditingController();
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(dialogTitle),
            content: TextField(
              controller: noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Catatan sysadmin',
                alignLabelWithHint: true,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(actionLabel),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    try {
      final service = ref.read(roleManagementServiceProvider);
      if (approve) {
        await service.approveRoleRequest(
          request: request,
          reviewNote: noteController.text.trim(),
        );
      } else {
        await service.rejectRoleRequest(
          request: request,
          reviewNote: noteController.text.trim(),
        );
      }
      if (!mounted) return;
      ErrorClassifier.showSuccessSnackBar(context, successMessage);
      ref.invalidate(allRoleRequestsProvider);
      ref.invalidate(managedUsersProvider);
    } catch (e) {
      if (!mounted) return;
      ErrorClassifier.showErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    if (!auth.isSysadmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Manajemen User & Role')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(AppTheme.paddingLarge),
            child: Text(
              'Halaman ini hanya bisa diakses oleh sysadmin.',
              style: AppTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final usersAsync = ref.watch(managedUsersProvider);
    final requestsAsync = ref.watch(allRoleRequestsProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Manajemen User & Role'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Users'),
              Tab(text: 'Request Akses'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            usersAsync.when(
              data: _buildUsersTab,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text(ErrorClassifier.classify(error).message)),
            ),
            requestsAsync.when(
              data: _buildRequestsTab,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text(ErrorClassifier.classify(error).message)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersTab(List<RecordModel> users) {
    final filteredUsers = users.where((user) {
      final query = _searchQuery.trim().toLowerCase();
      if (query.isEmpty) return true;

      final name = _displayName(user).toLowerCase();
      final email = user.getStringValue('email').toLowerCase();
      final role = AppConstants.roleLabel(
        user.getStringValue('role'),
      ).toLowerCase();

      return name.contains(query) ||
          email.contains(query) ||
          role.contains(query);
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(AppTheme.paddingMedium),
      children: [
        AppTheme.glassContainer(
          opacity: 0.76,
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Cari nama, email, atau role',
              prefixIcon: Icon(Icons.search_rounded),
              border: InputBorder.none,
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),
        const SizedBox(height: 12),
        ...filteredUsers.map((user) {
          final role = AppConstants.normalizeRole(user.getStringValue('role'));
          final subscriptionStatus = user.getStringValue('subscription_status');
          final subscriptionExpiry = Formatters.parseTanggal(
            user.getStringValue('subscription_expired'),
          );

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppTheme.glassContainer(
              opacity: 0.74,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        backgroundColor: AppTheme.roleColor(role),
                        child: Text(
                          Formatters.inisial(_displayName(user)),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _displayName(user),
                              style: AppTheme.bodyLarge.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(user.getStringValue('email')),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _pill(
                                  label: AppConstants.roleLabel(role),
                                  color: AppTheme.roleColor(role),
                                ),
                                if (AppConstants.requiresSubscription(role))
                                  _pill(
                                    label: subscriptionStatus.isEmpty
                                        ? 'subscription belum diatur'
                                        : 'subscription $subscriptionStatus',
                                    color:
                                        subscriptionStatus ==
                                            AppConstants
                                                .subscriptionStatusActive
                                        ? AppTheme.successColor
                                        : AppTheme.warningColor,
                                  ),
                              ],
                            ),
                            if (subscriptionExpiry != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Expired: ${Formatters.tanggalWaktu(subscriptionExpiry)}',
                                style: AppTheme.caption,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _showRoleDialog(user),
                        icon: const Icon(Icons.manage_accounts_rounded),
                        label: const Text('Ubah Role'),
                      ),
                      if (AppConstants.requiresSubscription(role))
                        ElevatedButton.icon(
                          onPressed: () => _toggleSubscription(user, true),
                          icon: const Icon(Icons.check_circle_outline_rounded),
                          label: const Text('Aktifkan 30 Hari'),
                        ),
                      if (AppConstants.requiresSubscription(role))
                        TextButton.icon(
                          onPressed: () => _toggleSubscription(user, false),
                          icon: const Icon(Icons.block_rounded),
                          label: const Text('Nonaktifkan'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildRequestsTab(List<RoleRequestModel> requests) {
    if (requests.isEmpty) {
      return const Center(child: Text('Belum ada pengajuan unsubscribe.'));
    }

    return ListView(
      padding: const EdgeInsets.all(AppTheme.paddingMedium),
      children: requests.map((request) {
        final statusColor = switch (request.status) {
          AppConstants.roleRequestApproved => AppTheme.successColor,
          AppConstants.roleRequestRejected => AppTheme.errorColor,
          _ => AppTheme.warningColor,
        };

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppTheme.glassContainer(
            opacity: 0.74,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            request.requesterName ?? 'User',
                            style: AppTheme.bodyLarge.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            request.requesterEmail ?? '-',
                            style: AppTheme.caption,
                          ),
                        ],
                      ),
                    ),
                    _pill(
                      label: request.status.toUpperCase(),
                      color: statusColor,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '${AppConstants.roleLabel(request.currentRole)} -> ${AppConstants.roleLabel(request.requestedRole)}',
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(request.reason, style: AppTheme.bodySmall),
                const SizedBox(height: 10),
                Text(
                  request.created != null
                      ? 'Diajukan ${Formatters.tanggalWaktu(request.created!)}'
                      : 'Waktu pengajuan tidak tersedia',
                  style: AppTheme.caption,
                ),
                if ((request.reviewNote ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Catatan: ${request.reviewNote}',
                    style: AppTheme.caption.copyWith(
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
                if (request.isPending) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () =>
                            _handleRequestAction(request, approve: true),
                        icon: const Icon(Icons.check_rounded),
                        label: Text(
                          AppConstants.normalizeRole(request.requestedRole) ==
                                  AppConstants.roleWarga
                              ? 'Setujui Unsubscribe'
                              : 'Setujui',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () =>
                            _handleRequestAction(request, approve: false),
                        icon: const Icon(Icons.close_rounded),
                        label: Text(
                          AppConstants.normalizeRole(request.requestedRole) ==
                                  AppConstants.roleWarga
                              ? 'Tolak Unsubscribe'
                              : 'Tolak',
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  String _displayName(RecordModel user) {
    final name = user.getStringValue('name');
    if (name.isNotEmpty) return name;

    final nama = user.getStringValue('nama');
    if (nama.isNotEmpty) return nama;

    final email = user.getStringValue('email');
    if (email.isNotEmpty) return email;

    return user.id;
  }

  Widget _pill({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTheme.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
