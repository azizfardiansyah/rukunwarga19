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
import '../../../shared/widgets/app_surface.dart';
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
  late final TextEditingController _searchController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kkAsync = ref.watch(kkListProvider);
    final auth = ref.watch(authProvider);
    final isAdmin = auth.isAdmin;

    return Scaffold(
      appBar: AppBar(
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
              gradientColors: const [
                AppTheme.primaryDark,
                AppTheme.primaryColor,
              ],
            )
          : null,
      body: AppPageBackground(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
                          AppEmptyState(
                            icon: Icons.family_restroom_rounded,
                            title: _searchQuery.trim().isEmpty
                                ? 'Belum ada data KK'
                                : 'Data KK tidak ditemukan',
                            message: _searchQuery.trim().isEmpty
                                ? 'Data KK akan tampil sesuai wilayah akses Anda.'
                                : 'Coba nomor KK, alamat, desa, kecamatan, atau kabupaten/kota lain.',
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
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final kk = filtered[index];
                        return _KkListCard(
                          kk: kk,
                          onTap: () async {
                            await context.push('/kartu-keluarga/${kk.id}');
                            if (mounted) {
                              ref.invalidate(kkListProvider);
                            }
                          },
                        );
                      },
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: AppSurfaceCard(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          ErrorClassifier.classify(error).message,
                          style: AppTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        FilledButton(
                          onPressed: () => ref.invalidate(kkListProvider),
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
        AppHeroPanel(
          eyebrow: isAdmin ? 'Master Keluarga' : 'Akun Terhubung',
          icon: Icons.family_restroom_rounded,
          title: 'Kartu keluarga dan wilayah',
          subtitle: isAdmin
              ? 'Setiap kartu keluarga tampil sesuai scope wilayah dan menyimpan kode wilayah resmi.'
              : 'Anda hanya melihat KK yang terhubung dengan akun Anda.',
          chips: [
            AppHeroBadge(
              label: 'Nomor KK',
              foregroundColor: Colors.white,
              backgroundColor: Colors.white.withValues(alpha: 0.16),
              icon: Icons.badge_outlined,
            ),
            AppHeroBadge(
              label: 'Area lengkap',
              foregroundColor: Colors.white,
              backgroundColor: Colors.white.withValues(alpha: 0.16),
              icon: Icons.map_outlined,
            ),
          ],
        ),
        const SizedBox(height: 12),
        AppSearchBar(
          controller: _searchController,
          value: _searchQuery,
          hintText: 'Cari nomor KK, alamat, desa, atau kecamatan',
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
              if (value.isEmpty && _searchController.text.isNotEmpty) {
                _searchController.clear();
              }
            });
          },
        ),
      ],
    );
  }

  Future<void> _refresh() async {
    ref.invalidate(kkListProvider);
    await ref.read(kkListProvider.future);
  }
}

class _KkListCard extends StatelessWidget {
  const _KkListCard({required this.kk, required this.onTap});

  final KartuKeluargaModel kk;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasScan = (kk.scanKk ?? '').isNotEmpty;

    return AppSurfaceCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
      ),
    );
  }

  Widget _chip(IconData icon, String text) {
    return AppHeroBadge(
      label: text,
      foregroundColor: AppTheme.textPrimary,
      backgroundColor: AppTheme.backgroundColor,
      icon: icon,
    );
  }
}
