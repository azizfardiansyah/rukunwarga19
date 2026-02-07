import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme.dart';
import '../../../core/services/pocketbase_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/error_classifier.dart';
import '../../../shared/models/chat_model.dart';
import '../../../features/auth/providers/auth_provider.dart';

final announcementListProvider =
    FutureProvider.autoDispose<List<AnnouncementModel>>((ref) async {
  final result = await pb.collection(AppConstants.colAnnouncements).getList(
    page: 1, perPage: 50, sort: '-created',
  );
  return result.items.map((r) => AnnouncementModel.fromRecord(r)).toList();
});

class AnnouncementScreen extends ConsumerWidget {
  const AnnouncementScreen({super.key});

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final judulCtrl = TextEditingController();
    final isiCtrl = TextEditingController();
    String target = 'all';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Buat Pengumuman'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: judulCtrl, decoration: const InputDecoration(labelText: 'Judul')),
              const SizedBox(height: 8),
              TextField(controller: isiCtrl, decoration: const InputDecoration(labelText: 'Isi'), maxLines: 3),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: target,
                decoration: const InputDecoration(labelText: 'Target'),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('Semua RW 19')),
                  DropdownMenuItem(value: '01', child: Text('RT 01')),
                  DropdownMenuItem(value: '02', child: Text('RT 02')),
                  DropdownMenuItem(value: '03', child: Text('RT 03')),
                ],
                onChanged: (v) => target = v ?? 'all',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              try {
                await pb.collection(AppConstants.colAnnouncements).create(body: {
                  'judul': judulCtrl.text.trim(),
                  'isi': isiCtrl.text.trim(),
                  'target': target,
                  'author': pb.authStore.record?.id ?? '',
                });
                if (ctx.mounted) Navigator.pop(ctx);
                ref.invalidate(announcementListProvider);
              } catch (e) {
                if (ctx.mounted) ErrorClassifier.showErrorSnackBar(ctx, e);
              }
            },
            child: const Text('Kirim'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final announcementAsync = ref.watch(announcementListProvider);
    final isAdmin = ref.watch(isAdminProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pengumuman')),
      body: announcementAsync.when(
        data: (list) {
          if (list.isEmpty) return const Center(child: Text('Belum ada pengumuman'));
          return ListView.builder(
            padding: const EdgeInsets.all(AppTheme.paddingMedium),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final ann = list[index];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.paddingMedium),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.campaign, color: AppTheme.accentColor),
                          const SizedBox(width: 8),
                          Expanded(child: Text(ann.judul, style: AppTheme.heading3)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryLight.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(ann.target == 'all' ? 'Semua' : 'RT ${ann.target}',
                                style: AppTheme.caption),
                          ),
                        ],
                      ),
                      const Divider(),
                      Text(ann.isi, style: AppTheme.bodyMedium),
                      const SizedBox(height: 8),
                      Text(
                        ann.created != null ? Formatters.tanggalRelatif(ann.created!) : '',
                        style: AppTheme.caption,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: () => _showCreateDialog(context, ref),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
