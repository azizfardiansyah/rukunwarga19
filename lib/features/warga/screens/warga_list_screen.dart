import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/services/pocketbase_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/error_classifier.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/warga_model.dart';
import '../../../features/auth/providers/auth_provider.dart';

final wargaListProvider = FutureProvider.autoDispose<List<WargaModel>>((ref) async {
  final auth = ref.watch(authProvider);
  final userId = auth.user?.id;
  if (userId == null) return [];
  final isAdmin = auth.role == AppConstants.roleAdmin || auth.role == AppConstants.roleSuperuser;

  final result = await pb.collection(AppConstants.colWarga).getList(
    page: 1,
    perPage: 100,
    sort: 'nama_lengkap',
    filter: isAdmin ? '' : 'user_id = "$userId"',
  );
  return result.items.map((r) => WargaModel.fromRecord(r)).toList();
});

class WargaListScreen extends ConsumerStatefulWidget {
  const WargaListScreen({super.key});

  @override
  ConsumerState<WargaListScreen> createState() => _WargaListScreenState();
}

class _WargaListScreenState extends ConsumerState<WargaListScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final wargaAsync = ref.watch(wargaListProvider);
    final isAdmin = ref.watch(isAdminProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Warga'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              // TODO: Filter dialog
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(AppTheme.paddingMedium),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Cari warga...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
            ),
          ),
          // List
          Expanded(
            child: wargaAsync.when(
              data: (wargaList) {
                final filtered = wargaList.where((w) =>
                    w.namaLengkap.toLowerCase().contains(_searchQuery) ||
                    w.nik.contains(_searchQuery)).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text('Belum ada data warga'),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(wargaListProvider);
                  },
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final warga = filtered[index];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.primaryColor,
                            child: Text(
                              Formatters.inisial(warga.namaLengkap),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(warga.namaLengkap),
                          subtitle: Text(
                            'NIK: ${Formatters.formatNik(warga.nik)}\n'
                            'RT ${warga.rt}/RW ${warga.rw}',
                          ),
                          isThreeLine: true,
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push('/warga/${warga.id}'),
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(ErrorClassifier.classify(error).message),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(wargaListProvider),
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: () => context.push(Routes.wargaForm),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
