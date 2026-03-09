import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/pocketbase_service.dart';
import '../../../core/utils/area_access.dart';
import '../../../core/utils/error_classifier.dart';
import '../../../core/utils/formatters.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/models/kartu_keluarga_model.dart';
import '../../../shared/widgets/floating_action_pill.dart';

final kkListProvider = FutureProvider.autoDispose<List<KartuKeluargaModel>>((
  ref,
) async {
  final auth = ref.watch(authProvider);
  if (auth.user == null) {
    return [];
  }

  final access = await resolveAreaAccessContext(auth);
  final records = await pb
      .collection(AppConstants.colKartuKeluarga)
      .getFullList(
        sort: '-created',
        filter: buildKkScopeFilter(auth, context: access),
      );

  return records.map(KartuKeluargaModel.fromRecord).toList();
});

class KkListScreen extends ConsumerStatefulWidget {
  const KkListScreen({super.key});

  @override
  ConsumerState<KkListScreen> createState() => _KkListScreenState();
}

class _KkListScreenState extends ConsumerState<KkListScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final kkAsync = ref.watch(kkListProvider);
    final auth = ref.watch(authProvider);
    final isAdmin = auth.isAdmin;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Kartu Keluarga'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: isAdmin
          ? FloatingActionPill(
              onTap: () async {
                await context.push(Routes.kkForm);
                if (mounted) {
                  ref.invalidate(kkListProvider);
                }
              },
              icon: Icons.add_home_work_rounded,
              label: 'Tambah KK',
              gradientColors: const [Color(0xFF00897B), Color(0xFF26A69A)],
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
              right: -36,
              child: _blob(const Color(0x331565C0), 190),
            ),
            Positioned(
              top: 140,
              left: -52,
              child: _blob(const Color(0x3326A69A), 150),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  children: [
                    _buildTopPanel(isAdmin: isAdmin),
                    const SizedBox(height: 14),
                    Expanded(
                      child: kkAsync.when(
                        data: (records) {
                          final filtered = _filterRecords(records);
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
                                          Icons.family_restroom_rounded,
                                          size: 54,
                                          color: AppTheme.textSecondary
                                              .withValues(alpha: 0.45),
                                        ),
                                        const SizedBox(height: 14),
                                        Text(
                                          _searchQuery.trim().isEmpty
                                              ? 'Belum ada data KK'
                                              : 'Data KK tidak ditemukan',
                                          style: AppTheme.heading3,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          _searchQuery.trim().isEmpty
                                              ? 'Data KK akan tampil sesuai wilayah akses Anda.'
                                              : 'Coba nomor KK, alamat, desa, kecamatan, atau kabupaten/kota lain.',
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
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final kk = filtered[index];
                                return _KkListCard(
                                  kk: kk,
                                  onTap: () async {
                                    await context.push(
                                      '/kartu-keluarga/${kk.id}',
                                    );
                                    if (mounted) {
                                      ref.invalidate(kkListProvider);
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
                                      ref.invalidate(kkListProvider),
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

  List<KartuKeluargaModel> _filterRecords(List<KartuKeluargaModel> input) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return input;
    }

    return input.where((kk) {
      return kk.noKk.toLowerCase().contains(query) ||
          kk.alamat.toLowerCase().contains(query) ||
          kk.rt.contains(query) ||
          kk.rw.contains(query) ||
          (kk.desaKelurahan ?? '').toLowerCase().contains(query) ||
          (kk.kecamatan ?? '').toLowerCase().contains(query) ||
          (kk.kabupatenKota ?? '').toLowerCase().contains(query) ||
          (kk.provinsi ?? '').toLowerCase().contains(query);
    }).toList();
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
                  Icons.family_restroom_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Data KK', style: AppTheme.heading2),
                    const SizedBox(height: 4),
                    Text(
                      isAdmin
                          ? 'Data KK dan detail anggotanya dibatasi sesuai wilayah akses Anda.'
                          : 'Anda hanya melihat KK yang terhubung dengan akun Anda.',
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
              hintText: 'Cari nomor KK, alamat, desa, atau kecamatan',
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
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),
      ],
    );
  }

  Future<void> _refresh() async {
    ref.invalidate(kkListProvider);
    await ref.read(kkListProvider.future);
  }

  Widget _blob(Color color, double size) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}

class _KkListCard extends StatelessWidget {
  const _KkListCard({required this.kk, required this.onTap});

  final KartuKeluargaModel kk;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasScan = (kk.scanKk ?? '').isNotEmpty;

    return AppTheme.glassContainer(
      opacity: 0.74,
      padding: const EdgeInsets.all(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.credit_card_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No. KK ${Formatters.formatNoKk(kk.noKk)}',
                    style: AppTheme.bodyLarge.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    kk.alamat,
                    style: AppTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _chip(Icons.home_work_rounded, 'RT ${kk.rt}/RW ${kk.rw}'),
                      if ((kk.kecamatan ?? '').isNotEmpty)
                        _chip(Icons.location_city_rounded, kk.kecamatan!),
                      _chip(
                        hasScan
                            ? Icons.image_outlined
                            : Icons.file_present_outlined,
                        hasScan ? 'File KK tersedia' : 'Belum ada file KK',
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

  Widget _chip(IconData icon, String text) {
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
