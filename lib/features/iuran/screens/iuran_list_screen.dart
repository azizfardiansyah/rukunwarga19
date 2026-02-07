import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/services/pocketbase_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/iuran_model.dart';
import '../../../features/auth/providers/auth_provider.dart';

final iuranListProvider = FutureProvider.autoDispose<List<IuranModel>>((ref) async {
  final result = await pb.collection(AppConstants.colIuran).getList(
    page: 1, perPage: 100, sort: '-created',
  );
  return result.items.map((r) => IuranModel.fromRecord(r)).toList();
});

class IuranListScreen extends ConsumerWidget {
  const IuranListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final iuranAsync = ref.watch(iuranListProvider);
    final isAdmin = ref.watch(isAdminProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Iuran Warga')),
      body: iuranAsync.when(
        data: (list) {
          if (list.isEmpty) return const Center(child: Text('Belum ada data iuran'));
          return ListView.builder(
            padding: const EdgeInsets.all(AppTheme.paddingMedium),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final iuran = list[index];
              return Card(
                child: ListTile(
                  leading: Icon(
                    iuran.isLunas ? Icons.check_circle : Icons.warning,
                    color: AppTheme.statusColor(iuran.status),
                  ),
                  title: Text(Formatters.rupiah(iuran.jumlah)),
                  subtitle: Text(
                    '${iuran.bulan ?? "-"}\nStatus: ${iuran.status}',
                  ),
                  isThreeLine: true,
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
              onPressed: () => context.push(Routes.iuranForm),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
