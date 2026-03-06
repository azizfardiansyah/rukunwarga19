// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/pocketbase_service.dart';
import '../../../core/utils/error_classifier.dart';
import '../../../core/utils/formatters.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/models/kartu_keluarga_model.dart';

class KkDetailScreen extends ConsumerWidget {
  final String kkId;
  const KkDetailScreen({super.key, required this.kkId});

  Future<void> _deleteKk(BuildContext context) async {
    final shouldDelete =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Hapus Kartu Keluarga'),
              content: const Text(
                'Data KK dan relasi anggota akan dihapus. Lanjutkan?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Hapus'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldDelete) return;

    try {
      await pb.collection(AppConstants.colKartuKeluarga).delete(kkId);
      if (!context.mounted) return;
      ErrorClassifier.showSuccessSnackBar(context, 'Data KK berhasil dihapus');
      context.go(Routes.kartuKeluarga);
    } catch (e) {
      if (!context.mounted) return;
      ErrorClassifier.showErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final userId = authState.user?.id;
    final isAdmin =
        authState.role == AppConstants.roleAdmin ||
        authState.role == AppConstants.roleSuperuser;

    return Scaffold(
      appBar: AppBar(title: const Text('Detail Kartu Keluarga'), elevation: 0),
      body: FutureBuilder(
        future: pb.collection(AppConstants.colKartuKeluarga).getOne(kkId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 48,
                    color: AppTheme.errorColor,
                  ),
                  const SizedBox(height: 12),
                  Text('Error: ${snapshot.error}', style: AppTheme.bodySmall),
                ],
              ),
            );
          }

          final record = snapshot.data!;
          final kk = KartuKeluargaModel.fromRecord(record);
          final kkOwnerId = record.getStringValue('user_id');
          final canManage = isAdmin || (userId != null && kkOwnerId == userId);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.paddingMedium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // KK Info Card with gradient header
                Container(
                  decoration: AppTheme.cardDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppTheme.paddingMedium),
                        decoration: const BoxDecoration(
                          gradient: AppTheme.headerGradient,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(AppTheme.radiusLarge),
                            topRight: Radius.circular(AppTheme.radiusLarge),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusMedium,
                                ),
                              ),
                              child: const Icon(
                                Icons.credit_card_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Kartu Keluarga',
                                    style: AppTheme.caption.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.8,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    Formatters.formatNoKk(kk.noKk),
                                    style: AppTheme.heading3.copyWith(
                                      color: Colors.white,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(AppTheme.paddingMedium),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInfoRow(
                              Icons.location_on_rounded,
                              'Alamat',
                              kk.alamat,
                            ),
                            _buildInfoRow(
                              Icons.grid_view_rounded,
                              'RT/RW',
                              'RT ${kk.rt} / RW ${kk.rw}',
                            ),
                            if ((kk.desaKelurahan ?? '').isNotEmpty)
                              _buildInfoRow(
                                Icons.holiday_village_rounded,
                                'Desa/Kelurahan',
                                kk.desaKelurahan!,
                              ),
                            if ((kk.kecamatan ?? '').isNotEmpty)
                              _buildInfoRow(
                                Icons.location_city_rounded,
                                'Kecamatan',
                                kk.kecamatan!,
                              ),
                            if ((kk.kabupatenKota ?? '').isNotEmpty)
                              _buildInfoRow(
                                Icons.apartment_rounded,
                                'Kabupaten/Kota',
                                kk.kabupatenKota!,
                              ),
                            if ((kk.provinsi ?? '').isNotEmpty)
                              _buildInfoRow(
                                Icons.map_rounded,
                                'Provinsi',
                                kk.provinsi!,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (canManage) ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              context.push('${Routes.kkForm}?id=${kk.id}'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusMedium,
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.edit_rounded, size: 18),
                          label: const Text('Edit KK'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              context.push('${Routes.wargaForm}?noKk=${kk.id}'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.secondaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusMedium,
                              ),
                            ),
                          ),
                          icon: const Icon(
                            Icons.person_add_alt_1_rounded,
                            size: 18,
                          ),
                          label: const Text('Tambah Anggota'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _deleteKk(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.errorColor,
                        side: const BorderSide(color: AppTheme.errorColor),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusMedium,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('Hapus KK'),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                // Anggota section header
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.people_rounded,
                        size: 22,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Text('Anggota Keluarga', style: AppTheme.heading3),
                    ],
                  ),
                ),
                FutureBuilder(
                  future: pb
                      .collection(AppConstants.colAnggotaKk)
                      .getList(
                        page: 1,
                        perPage: 100,
                        filter: 'no_kk = "${kk.id}"',
                        expand: 'warga',
                      ),
                  builder: (context, anggotaSnapshot) {
                    if (anggotaSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (anggotaSnapshot.hasError) {
                      return Text('Error: ${anggotaSnapshot.error}');
                    }
                    final anggotaList = anggotaSnapshot.data?.items ?? [];
                    if (anggotaList.isEmpty) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: AppTheme.cardDecoration(
                          color: AppTheme.backgroundColor,
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.person_search_rounded,
                              size: 40,
                              color: AppTheme.textSecondary.withValues(
                                alpha: 0.4,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Belum ada anggota keluarga',
                              style: AppTheme.bodySmall,
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: anggotaList.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, idx) {
                        final anggota = anggotaList[idx];
                        final hubungan = anggota.getStringValue('hubungan');
                        final status = anggota.getStringValue('status');
                        final wargaExpand = anggota.expand['warga'];
                        final namaWarga =
                            (wargaExpand != null && wargaExpand.isNotEmpty)
                            ? wargaExpand[0].getStringValue('nama_lengkap')
                            : '-';
                        final isActive = status.toLowerCase() == 'aktif';
                        return Container(
                          decoration: AppTheme.cardDecoration(),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            leading: CircleAvatar(
                              radius: 20,
                              backgroundColor: AppTheme.primaryColor.withValues(
                                alpha: 0.1,
                              ),
                              child: Text(
                                '${idx + 1}',
                                style: AppTheme.bodyMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                            title: Text(
                              namaWarga,
                              style: AppTheme.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              hubungan,
                              style: AppTheme.caption.copyWith(
                                color: AppTheme.secondaryColor,
                              ),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? AppTheme.successColor.withValues(
                                        alpha: 0.1,
                                      )
                                    : AppTheme.textSecondary.withValues(
                                        alpha: 0.1,
                                      ),
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusXLarge,
                                ),
                              ),
                              child: Text(
                                status,
                                style: AppTheme.caption.copyWith(
                                  color: isActive
                                      ? AppTheme.successColor
                                      : AppTheme.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: AppTheme.primaryColor.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTheme.caption.copyWith(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(value, style: AppTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
