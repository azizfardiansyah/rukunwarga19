import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/services/pocketbase_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/surat_model.dart';

final suratListProvider = FutureProvider.autoDispose<List<SuratModel>>((ref) async {
  final result = await pb.collection(AppConstants.colSurat).getList(
    page: 1, perPage: 100, sort: '-created',
  );
  return result.items.map((r) => SuratModel.fromRecord(r)).toList();
});

class SuratListScreen extends ConsumerWidget {
  const SuratListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suratAsync = ref.watch(suratListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Surat Pengantar')),
      body: suratAsync.when(
        data: (list) {
          if (list.isEmpty) return const Center(child: Text('Belum ada surat'));
          return ListView.builder(
            padding: const EdgeInsets.all(AppTheme.paddingMedium),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final surat = list[index];
              return Card(
                child: ListTile(
                  leading: Icon(Icons.description,
                      color: AppTheme.statusColor(surat.status)),
                  title: Text(surat.jenis),
                  subtitle: Text(
                    '${surat.keperluan}\n${surat.created != null ? Formatters.tanggalRelatif(surat.created!) : ""}',
                  ),
                  isThreeLine: true,
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.statusColor(surat.status).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      surat.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.bold,
                        color: AppTheme.statusColor(surat.status),
                      ),
                    ),
                  ),
                  onTap: () => context.push('/surat/${surat.id}'),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(Routes.suratForm),
        child: const Icon(Icons.add),
      ),
    );
  }
}
