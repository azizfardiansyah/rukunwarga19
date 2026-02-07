import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/services/pocketbase_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/models/dokumen_model.dart';

final dokumenListProvider =
    FutureProvider.autoDispose<List<DokumenModel>>((ref) async {
  final result = await pb.collection(AppConstants.colDokumen).getList(
    page: 1, perPage: 100, sort: '-created',
  );
  return result.items.map((r) => DokumenModel.fromRecord(r)).toList();
});

class DokumenListScreen extends ConsumerWidget {
  const DokumenListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dokumenAsync = ref.watch(dokumenListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Dokumen')),
      body: dokumenAsync.when(
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('Belum ada dokumen'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(AppTheme.paddingMedium),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final doc = list[index];
              return Card(
                child: ListTile(
                  leading: Icon(
                    Icons.description,
                    color: AppTheme.statusColor(doc.statusVerifikasi),
                  ),
                  title: Text(doc.jenis),
                  subtitle: Text('Status: ${doc.statusVerifikasi}'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.statusColor(doc.statusVerifikasi).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      doc.statusVerifikasi.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.statusColor(doc.statusVerifikasi),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(Routes.dokumenUpload),
        child: const Icon(Icons.upload_file),
      ),
    );
  }
}
