import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../core/services/pocketbase_service.dart';
import '../../../core/constants/app_constants.dart';
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
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.paddingMedium),
            child: Card(
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
          );
        },
      ),
    );
  }
}
