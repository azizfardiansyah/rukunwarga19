import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme.dart';
import '../../../core/services/pocketbase_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/error_classifier.dart';
import '../../../shared/models/surat_model.dart';
import '../../../features/auth/providers/auth_provider.dart';

class SuratDetailScreen extends ConsumerWidget {
  final String suratId;
  const SuratDetailScreen({super.key, required this.suratId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Detail Surat')),
      body: FutureBuilder(
        future: pb.collection(AppConstants.colSurat).getOne(suratId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));

          final surat = SuratModel.fromRecord(snapshot.data!);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.paddingMedium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.paddingMedium),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(surat.jenis, style: AppTheme.heading3)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.statusColor(surat.status),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                surat.status.toUpperCase(),
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const Divider(),
                        Text('Keperluan', style: AppTheme.bodySmall),
                        const SizedBox(height: 4),
                        Text(surat.keperluan, style: AppTheme.bodyMedium),
                        if (surat.catatan != null && surat.catatan!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text('Catatan', style: AppTheme.bodySmall),
                          const SizedBox(height: 4),
                          Text(surat.catatan!, style: AppTheme.bodyMedium),
                        ],
                        const SizedBox(height: 12),
                        Text('Diajukan: ${surat.created != null ? Formatters.tanggalWaktu(surat.created!) : "-"}',
                            style: AppTheme.caption),
                      ],
                    ),
                  ),
                ),
                if (isAdmin && surat.isPending) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            try {
                              await pb.collection(AppConstants.colSurat).update(suratId, body: {'status': 'rejected'});
                              if (context.mounted) ErrorClassifier.showSuccessSnackBar(context, 'Surat ditolak');
                            } catch (e) {
                              if (context.mounted) ErrorClassifier.showErrorSnackBar(context, e);
                            }
                          },
                          style: OutlinedButton.styleFrom(foregroundColor: AppTheme.errorColor),
                          child: const Text('Tolak'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            try {
                              await pb.collection(AppConstants.colSurat).update(suratId, body: {'status': 'approved'});
                              if (context.mounted) ErrorClassifier.showSuccessSnackBar(context, 'Surat disetujui');
                            } catch (e) {
                              if (context.mounted) ErrorClassifier.showErrorSnackBar(context, e);
                            }
                          },
                          child: const Text('Setujui'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
