import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/role_management_service.dart';
import '../../../core/utils/error_classifier.dart';
import '../../../core/utils/formatters.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/models/role_request_model.dart';

final myRoleRequestsProvider =
    FutureProvider.autoDispose<List<RoleRequestModel>>((ref) async {
      final userId = ref.watch(authProvider).user?.id;
      if (userId == null) return [];

      return ref
          .watch(roleManagementServiceProvider)
          .getRoleRequests(requesterId: userId);
    });

class RoleRequestScreen extends ConsumerStatefulWidget {
  const RoleRequestScreen({super.key});

  @override
  ConsumerState<RoleRequestScreen> createState() => _RoleRequestScreenState();
}

class _RoleRequestScreenState extends ConsumerState<RoleRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  String _selectedRole = AppConstants.roleAdminRt;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit(List<RoleRequestModel> existingRequests) async {
    if (!_formKey.currentState!.validate()) return;

    final hasPending = existingRequests.any((request) => request.isPending);
    if (hasPending) {
      ErrorClassifier.showErrorSnackBar(
        context,
        StateError('Masih ada pengajuan role yang belum diproses.'),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref.read(roleManagementServiceProvider).submitRoleRequest(
            requestedRole: _selectedRole,
            reason: _reasonController.text.trim(),
          );
      _reasonController.clear();
      if (!mounted) return;
      ErrorClassifier.showSuccessSnackBar(
        context,
        'Pengajuan role berhasil dikirim.',
      );
      ref.invalidate(myRoleRequestsProvider);
    } catch (e) {
      if (!mounted) return;
      ErrorClassifier.showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final requestsAsync = ref.watch(myRoleRequestsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pengajuan Role')),
      body: requestsAsync.when(
        data: (requests) {
          final hasPending = requests.any((request) => request.isPending);
          return ListView(
            padding: const EdgeInsets.all(AppTheme.paddingMedium),
            children: [
              AppTheme.glassContainer(
                opacity: 0.78,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Role Saat Ini', style: AppTheme.heading3),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        AppConstants.roleLabel(auth.role),
                        style: AppTheme.bodyMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Alur yang disarankan: user ajukan perubahan role dengan alasan yang jelas, lalu sysadmin review. Jika disetujui, role berubah dan subscription admin diaktifkan terpisah.',
                      style: AppTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppTheme.glassContainer(
                opacity: 0.76,
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ajukan Role Baru', style: AppTheme.heading3),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedRole,
                        decoration: const InputDecoration(
                          labelText: 'Role yang diajukan',
                        ),
                        items: AppConstants.requestableRoles
                            .map(
                              (role) => DropdownMenuItem(
                                value: role,
                                child: Text(AppConstants.roleLabel(role)),
                              ),
                            )
                            .toList(),
                        onChanged: hasPending
                            ? null
                            : (value) {
                                if (value == null) return;
                                setState(() => _selectedRole = value);
                              },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _reasonController,
                        enabled: !hasPending,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Alasan pengajuan',
                          alignLabelWithHint: true,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Alasan wajib diisi';
                          }
                          if (value.trim().length < 12) {
                            return 'Alasan terlalu singkat';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isSubmitting || hasPending
                              ? null
                              : () => _submit(requests),
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.outbox_rounded),
                          label: Text(
                            hasPending
                                ? 'Menunggu Review Sysadmin'
                                : 'Kirim Pengajuan',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Riwayat Pengajuan', style: AppTheme.heading3),
              const SizedBox(height: 12),
              if (requests.isEmpty)
                AppTheme.glassContainer(
                  opacity: 0.72,
                  child: const Text('Belum ada pengajuan role.'),
                )
              else
                ...requests.map(_RoleRequestHistoryCard.new),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.paddingLarge),
            child: Text(
              ErrorClassifier.classify(error).message,
              style: AppTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleRequestHistoryCard extends StatelessWidget {
  const _RoleRequestHistoryCard(this.request);

  final RoleRequestModel request;

  @override
  Widget build(BuildContext context) {
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
              children: [
                Expanded(
                  child: Text(
                    '${AppConstants.roleLabel(request.currentRole)} -> ${AppConstants.roleLabel(request.requestedRole)}',
                    style: AppTheme.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    request.status.toUpperCase(),
                    style: AppTheme.caption.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
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
                'Catatan sysadmin: ${request.reviewNote}',
                style: AppTheme.caption.copyWith(
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
