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
    final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Hapus Kartu Keluarga'),
              content: const Text('Data KK dan relasi anggota akan dihapus. Lanjutkan?'),
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
    final isAdmin = authState.role == AppConstants.roleAdmin || authState.role == AppConstants.roleSuperuser;

    return Scaffold(
      appBar: AppBar(title: const Text('Detail Kartu Keluarga')),
      body: FutureBuilder(
        future: pb.collection(AppConstants.colKartuKeluarga).getOne(kkId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
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
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.paddingMedium),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('No. KK', style: AppTheme.bodySmall),
                        Text(Formatters.formatNoKk(kk.noKk), style: AppTheme.heading3),
                        const Divider(),
                        Text('Alamat', style: AppTheme.bodySmall),
                        Text(kk.alamat, style: AppTheme.bodyMedium),
                        const SizedBox(height: 8),
                        Text('RT ${kk.rt} / RW ${kk.rw}', style: AppTheme.bodyMedium),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (canManage) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => context.push('${Routes.kkForm}?id=${kk.id}'),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit KK'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => context.push('${Routes.wargaForm}?noKk=${kk.noKk}'),
                        icon: const Icon(Icons.person_add_alt_1),
                        label: const Text('Tambah Anggota'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _deleteKk(context),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Hapus KK'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                Text('Anggota Keluarga', style: AppTheme.heading3),
                FutureBuilder(
                  future: pb.collection(AppConstants.colAnggotaKk).getList(
                    page: 1,
                    perPage: 100,
                    filter: 'no_kk = "${kk.id}"',
                    expand: 'warga',
                  ),
                  builder: (context, anggotaSnapshot) {
                    if (anggotaSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (anggotaSnapshot.hasError) {
                      return Text('Error: ${anggotaSnapshot.error}');
                    }
                    final anggotaList = anggotaSnapshot.data?.items ?? [];
                    if (anggotaList.isEmpty) {
                      return Text('Belum ada anggota keluarga', style: AppTheme.bodySmall);
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: anggotaList.length,
                      separatorBuilder: (_, _) => const Divider(),
                      itemBuilder: (context, idx) {
                        final anggota = anggotaList[idx];
                        final hubungan = anggota.getStringValue('hubungan_');
                        final status = anggota.getStringValue('status');
                        final wargaExpand = anggota.expand['warga'];
                        final namaWarga = (wargaExpand != null && wargaExpand.isNotEmpty)
                            ? wargaExpand[0].getStringValue('nama_lengkap')
                            : '-';
                        return ListTile(
                          title: Text(namaWarga),
                          subtitle: Text(hubungan),
                          trailing: Text(status),
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
}
