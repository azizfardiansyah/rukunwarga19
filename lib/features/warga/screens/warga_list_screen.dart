import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/pocketbase_service.dart';
import '../../../core/utils/error_classifier.dart';
import '../../../core/utils/formatters.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/models/warga_model.dart';

final wargaListProvider = FutureProvider.autoDispose<List<WargaModel>>((
  ref,
) async {
  final auth = ref.watch(authProvider);
  final userId = auth.user?.id;
  if (userId == null) return [];

  final isAdmin =
      auth.role == AppConstants.roleAdmin ||
      auth.role == AppConstants.roleSuperuser;

  final result = await pb
      .collection(AppConstants.colWarga)
      .getList(
        page: 1,
        perPage: 100,
        sort: 'nama_lengkap',
        filter: isAdmin ? '' : 'user_id = "$userId"',
      );

  return result.items.map((record) => WargaModel.fromRecord(record)).toList();
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
    final auth = ref.watch(authProvider);
    final isAdmin = auth.isAdmin;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Data Warga'),
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () async {
                await context.push(Routes.wargaForm);
                if (mounted) {
                  ref.invalidate(wargaListProvider);
                }
              },
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Tambah Warga'),
            )
          : null,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFEAF3FF), Color(0xFFF7FBFF), Color(0xFFF5FFFC)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -80,
              right: -32,
              child: _blob(const Color(0x331565C0), 190),
            ),
            Positioned(
              top: 150,
              left: -50,
              child: _blob(const Color(0x3326A69A), 140),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  children: [
                    _buildTopPanel(isAdmin: isAdmin),
                    const SizedBox(height: 14),
                    Expanded(
                      child: wargaAsync.when(
                        data: (wargaList) {
                          final query = _searchQuery.trim().toLowerCase();
                          final filtered = wargaList.where((warga) {
                            if (query.isEmpty) return true;
                            return warga.namaLengkap.toLowerCase().contains(
                                  query,
                                ) ||
                                warga.nik.contains(query);
                          }).toList();

                          if (filtered.isEmpty) {
                            return RefreshIndicator(
                              onRefresh: _refresh,
                              child: ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  const SizedBox(height: 80),
                                  AppTheme.glassContainer(
                                    opacity: 0.74,
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.person_search_rounded,
                                          size: 54,
                                          color: AppTheme.textSecondary
                                              .withValues(alpha: 0.45),
                                        ),
                                        const SizedBox(height: 14),
                                        Text(
                                          query.isEmpty
                                              ? 'Belum ada data warga'
                                              : 'Data warga tidak ditemukan',
                                          style: AppTheme.heading3,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          query.isEmpty
                                              ? 'Data akan muncul setelah warga ditambahkan.'
                                              : 'Coba kata kunci lain untuk mencari warga.',
                                          style: AppTheme.bodySmall,
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return RefreshIndicator(
                            onRefresh: _refresh,
                            child: ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final warga = filtered[index];
                                return _WargaListCard(
                                  warga: warga,
                                  onTap: () async {
                                    await context.push(
                                      '${Routes.warga}/${warga.id}',
                                    );
                                    if (mounted) {
                                      ref.invalidate(wargaListProvider);
                                    }
                                  },
                                );
                              },
                            ),
                          );
                        },
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (error, _) => Center(
                          child: AppTheme.glassContainer(
                            opacity: 0.74,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  ErrorClassifier.classify(error).message,
                                  style: AppTheme.bodyMedium,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 10),
                                ElevatedButton(
                                  onPressed: () =>
                                      ref.invalidate(wargaListProvider),
                                  child: const Text('Coba Lagi'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopPanel({required bool isAdmin}) {
    return Column(
      children: [
        AppTheme.glassContainer(
          opacity: 0.78,
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.groups_2_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Data Warga', style: AppTheme.heading2),
                    const SizedBox(height: 4),
                    Text(
                      isAdmin
                          ? 'Kelola seluruh data warga dengan tampilan yang lebih ringkas.'
                          : 'Daftar ini hanya menampilkan data warga milik akun Anda.',
                      style: AppTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppTheme.glassContainer(
          opacity: 0.76,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Cari nama atau NIK warga',
              prefixIcon: const Icon(Icons.search_rounded),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              fillColor: Colors.transparent,
              filled: true,
              suffixIcon: _searchQuery.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () => setState(() => _searchQuery = ''),
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
            onChanged: (value) {
              setState(() => _searchQuery = value);
            },
          ),
        ),
      ],
    );
  }

  Future<void> _refresh() async {
    ref.invalidate(wargaListProvider);
    await ref.read(wargaListProvider.future);
  }

  Widget _blob(Color color, double size) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class _WargaListCard extends StatelessWidget {
  final WargaModel warga;
  final VoidCallback onTap;

  const _WargaListCard({required this.warga, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      child: AppTheme.glassContainer(
        opacity: 0.74,
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor.withValues(alpha: 0.9),
                    AppTheme.secondaryColor.withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  Formatters.inisial(warga.namaLengkap),
                  style: AppTheme.bodyMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    warga.namaLengkap,
                    style: AppTheme.bodyLarge.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    Formatters.formatNik(warga.nik),
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _miniChip(
                        Icons.home_work_rounded,
                        'RT ${warga.rt}/RW ${warga.rw}',
                      ),
                      if (warga.jenisKelamin.isNotEmpty)
                        _miniChip(Icons.wc_rounded, warga.jenisKelamin),
                      if (warga.golonganDarah.isNotEmpty)
                        _miniChip(
                          Icons.water_drop_rounded,
                          warga.golonganDarah,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: AppTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppTheme.textSecondary),
          const SizedBox(width: 5),
          Text(
            text,
            style: AppTheme.caption.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
