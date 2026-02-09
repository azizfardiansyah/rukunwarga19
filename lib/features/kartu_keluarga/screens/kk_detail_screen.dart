// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketbase/src/dtos/record_model.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/pocketbase_service.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/kartu_keluarga_model.dart';

class KkDetailScreen extends StatelessWidget {
  final String kkId;
  const KkDetailScreen({super.key, required this.kkId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Kartu Keluarga')),
      body: FutureBuilder(
        future: pb.collection(AppConstants.colKartuKeluarga).getOne(kkId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));

          final kk = KartuKeluargaModel.fromRecord(snapshot.data!);
          final kepalaKeluargaId = snapshot.data!.getStringValue('user_id');
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
                const SizedBox(height: 16),
                // Cek jika user adalah kepala keluarga
                if (kepalaKeluargaId.toString() == pb.authStore.model.id.toString()) ...[
                  ElevatedButton(
                    onPressed: () {
                      // Navigasi ke form tambah anggota (warga) dengan GoRouter
                      context.go(Routes.wargaForm);
                    },
                    child: const Text('Tambah Anggota KK'),
                  ),
                  const SizedBox(height: 8),
                ],
                Text('Anggota Keluarga', style: AppTheme.heading3),
                FutureBuilder(
                  future: pb.collection(AppConstants.colAnggotaKk).getList(
                    page: 1,
                    perPage: 20,
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
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: anggotaList.length,
                      separatorBuilder: (_, _) => Divider(),
                      itemBuilder: (context, idx) {
                        final anggota = anggotaList[idx];
                        final hubungan = anggota.getStringValue('hubungan_');
                        final status = anggota.getStringValue('status');
                        final warga = anggota.expand['warga'];
                        String namaWarga;
                        if (warga != null && warga.isNotEmpty) {
                          namaWarga = warga[0].getStringValue('nama');
                        } else {
                          namaWarga = anggota.getStringValue('warga');
                        }
                        return ListTile(
                          title: Text(hubungan),
                          subtitle: Text(namaWarga),
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

extension on List<RecordModel> {
}
