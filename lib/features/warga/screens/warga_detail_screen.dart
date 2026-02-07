import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../app/router.dart';
import '../../../core/services/pocketbase_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/error_classifier.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/warga_model.dart';
import '../../../features/auth/providers/auth_provider.dart';

class WargaDetailScreen extends ConsumerWidget {
  final String wargaId;
  const WargaDetailScreen({super.key, required this.wargaId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Warga'),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => context.push('${Routes.wargaForm}?id=$wargaId'),
            ),
        ],
      ),
      body: FutureBuilder(
        future: pb.collection(AppConstants.colWarga).getOne(wargaId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(ErrorClassifier.classify(snapshot.error).message),
            );
          }

          final warga = WargaModel.fromRecord(snapshot.data!);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.paddingMedium),
            child: Column(
              children: [
                // Header
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.paddingMedium),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: AppTheme.primaryColor,
                          child: Text(
                            Formatters.inisial(warga.namaLengkap),
                            style: const TextStyle(
                              color: Colors.white, fontSize: 28),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(warga.namaLengkap, style: AppTheme.heading2),
                        Text('NIK: ${Formatters.formatNik(warga.nik)}',
                            style: AppTheme.bodySmall),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Data pribadi
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.paddingMedium),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Data Pribadi', style: AppTheme.heading3),
                        const Divider(),
                        _InfoRow('Tempat/Tgl Lahir',
                            '${warga.tempatLahir}, ${warga.tanggalLahir != null ? Formatters.tanggalLengkap(warga.tanggalLahir!) : "-"}'),
                        _InfoRow('Jenis Kelamin', warga.jenisKelamin),
                        _InfoRow('Agama', warga.agama),
                        _InfoRow('Status', warga.statusPernikahan),
                        _InfoRow('Pekerjaan', warga.pekerjaan),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Alamat & Kontak
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.paddingMedium),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Alamat & Kontak', style: AppTheme.heading3),
                        const Divider(),
                        _InfoRow('Alamat', warga.alamat),
                        _InfoRow('RT/RW', 'RT ${warga.rt}/RW ${warga.rw}'),
                        _InfoRow('No. HP', Formatters.formatNoHp(warga.noHp)),
                        _InfoRow('Email', warga.email ?? '-'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: AppTheme.bodySmall),
          ),
          Expanded(child: Text(value, style: AppTheme.bodyMedium)),
        ],
      ),
    );
  }
}
