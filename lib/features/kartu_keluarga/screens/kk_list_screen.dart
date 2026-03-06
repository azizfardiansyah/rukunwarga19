import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/services/pocketbase_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/kartu_keluarga_model.dart';
import '../../../features/auth/providers/auth_provider.dart';

final kkListProvider =
    FutureProvider.autoDispose<List<KartuKeluargaModel>>((ref) async {
  final auth = ref.watch(authProvider);
  final userId = auth.user?.id;
  if (userId == null) return [];
  final isAdmin = auth.role == AppConstants.roleAdmin || auth.role == AppConstants.roleSuperuser;

  final result = await pb.collection(AppConstants.colKartuKeluarga).getList(
    page: 1,
    perPage: 100,
    sort: '-created',
    filter: isAdmin ? '' : 'user_id = "$userId"',
  );
  return result.items.map((r) => KartuKeluargaModel.fromRecord(r)).toList();
});

class KkListScreen extends ConsumerWidget {
  const KkListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kkAsync = ref.watch(kkListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Kartu Keluarga')),
      body: kkAsync.when(
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('Belum ada data Kartu Keluarga'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(AppTheme.paddingMedium),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final kk = list[index];
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.family_restroom)),
                  title: Text('No. KK: ${Formatters.formatNoKk(kk.noKk)}'),
                  subtitle: Text('RT ${kk.rt}/RW ${kk.rw}\n${kk.alamat}'),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/kartu-keluarga/${kk.id}'),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(Routes.kkForm),
        child: const Icon(Icons.add),
      ),
    );
  }
}
