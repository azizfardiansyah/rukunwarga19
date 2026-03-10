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
import '../../../shared/models/warga_model.dart';
import '../../../shared/widgets/app_surface.dart';
import '../../../shared/widgets/floating_action_pill.dart';

class WargaListData {
  const WargaListData({required this.wargaList, required this.kkById});

  final List<WargaModel> wargaList;
  final Map<String, KartuKeluargaModel> kkById;
}

class _WargaGroup {
  const _WargaGroup({
    required this.groupKey,
    required this.kk,
    required this.members,
  });

  final String groupKey;
  final KartuKeluargaModel? kk;
  final List<WargaModel> members;
}

final wargaListProvider = FutureProvider.autoDispose<WargaListData>((
  ref,
) async {
  final auth = ref.watch(authProvider);
  if (auth.user == null) {
    return const WargaListData(wargaList: [], kkById: {});
  }

  final access = await resolveAreaAccessContext(auth);
  final wargaRecords = await pb
      .collection(AppConstants.colWarga)
      .getFullList(
        sort: 'nama_lengkap',
        filter: buildWargaScopeFilter(auth, context: access),
      );
  final kkRecords = await pb
      .collection(AppConstants.colKartuKeluarga)
      .getFullList(
        sort: '-created',
        filter: buildKkScopeFilter(auth, context: access),
      );

  return WargaListData(
    wargaList: wargaRecords.map(WargaModel.fromRecord).toList(),
    kkById: {
      for (final record in kkRecords)
        record.id: KartuKeluargaModel.fromRecord(record),
    },
  );
});

class WargaListScreen extends ConsumerStatefulWidget {
  const WargaListScreen({super.key});

  @override
  ConsumerState<WargaListScreen> createState() => _WargaListScreenState();
}

class _WargaListScreenState extends ConsumerState<WargaListScreen> {
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
    final wargaAsync = ref.watch(wargaListProvider);
    final auth = ref.watch(authProvider);
    final isAdmin = auth.isAdmin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Warga'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: isAdmin
          ? FloatingActionPill(
              onTap: () async {
                await context.push(Routes.wargaForm);
                if (mounted) {
                  ref.invalidate(wargaListProvider);
                }
              },
              icon: Icons.person_add_alt_1_rounded,
              label: 'Tambah Warga',
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
              child: wargaAsync.when(
                data: (data) {
                  final groups = _buildGroups(data);

                  if (groups.isEmpty) {
                    return RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 80),
                          AppEmptyState(
                            icon: Icons.person_search_rounded,
                            title: _searchQuery.trim().isEmpty
                                ? 'Belum ada data warga'
                                : 'Data warga tidak ditemukan',
                            message: _searchQuery.trim().isEmpty
                                ? 'Data akan muncul sesuai wilayah akses Anda.'
                                : 'Coba nama, NIK, atau nomor KK lain.',
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: groups.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final group = groups[index];
                        return _WargaGroupCard(
                          group: group,
                          onOpenKk: group.kk == null
                              ? null
                              : () => context.push(
                                  '${Routes.kartuKeluarga}/${group.kk!.id}',
                                ),
                          onOpenWarga: (warga) async {
                            await context.push('${Routes.warga}/${warga.id}');
                            if (mounted) {
                              ref.invalidate(wargaListProvider);
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
                          onPressed: () => ref.invalidate(wargaListProvider),
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

  List<_WargaGroup> _buildGroups(WargaListData data) {
    final query = _searchQuery.trim().toLowerCase();
    final filtered = data.wargaList.where((warga) {
      final kk = data.kkById[warga.noKkId];
      if (query.isEmpty) {
        return true;
      }

      return warga.namaLengkap.toLowerCase().contains(query) ||
          warga.nik.contains(query) ||
          warga.rt.contains(query) ||
          warga.rw.contains(query) ||
          (kk?.noKk.toLowerCase().contains(query) ?? false) ||
          (kk?.alamat.toLowerCase().contains(query) ?? false);
    }).toList();

    final grouped = <String, List<WargaModel>>{};
    for (final warga in filtered) {
      final key = warga.noKkId.isEmpty ? 'no-kk-${warga.id}' : warga.noKkId;
      grouped.putIfAbsent(key, () => []).add(warga);
    }

    final groups = grouped.entries.map((entry) {
      final members = [...entry.value]
        ..sort((left, right) => left.namaLengkap.compareTo(right.namaLengkap));
      return _WargaGroup(
        groupKey: entry.key,
        kk: data.kkById[entry.key],
        members: members,
      );
    }).toList();

    groups.sort((left, right) {
      final leftKey = left.kk?.noKk ?? left.members.first.namaLengkap;
      final rightKey = right.kk?.noKk ?? right.members.first.namaLengkap;
      return leftKey.compareTo(rightKey);
    });

    return groups;
  }

  Widget _buildTopPanel({required bool isAdmin}) {
    return Column(
      children: [
        AppHeroPanel(
          eyebrow: isAdmin ? 'Panel Operasional' : 'Akses Warga',
          icon: Icons.groups_2_rounded,
          title: 'Data warga per keluarga',
          subtitle: isAdmin
              ? 'Data warga ditampilkan sesuai wilayah akses dan dikelompokkan per nomor KK.'
              : 'Data warga Anda ditampilkan bersama grup keluarga yang terkait.',
          chips: [
            AppHeroBadge(
              label: 'Grouped by KK',
              foregroundColor: Colors.white,
              backgroundColor: Colors.white.withValues(alpha: 0.16),
              icon: Icons.family_restroom_rounded,
            ),
            AppHeroBadge(
              label: isAdmin ? 'Scope wilayah aktif' : 'Akun pribadi',
              foregroundColor: Colors.white,
              backgroundColor: Colors.white.withValues(alpha: 0.16),
              icon: Icons.visibility_outlined,
            ),
          ],
        ),
        const SizedBox(height: 12),
        AppSearchBar(
          controller: _searchController,
          value: _searchQuery,
          hintText: 'Cari nama, NIK, atau nomor KK',
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
    ref.invalidate(wargaListProvider);
    await ref.read(wargaListProvider.future);
  }
}

class _WargaGroupCard extends StatelessWidget {
  const _WargaGroupCard({
    required this.group,
    required this.onOpenWarga,
    this.onOpenKk,
  });

  final _WargaGroup group;
  final VoidCallback? onOpenKk;
  final ValueChanged<WargaModel> onOpenWarga;

  @override
  Widget build(BuildContext context) {
    final kk = group.kk;
    final kkLabel = kk == null
        ? 'KK belum terhubung'
        : 'No. KK ${Formatters.formatNoKk(kk.noKk)}';

    return AppSurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.family_restroom_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kkLabel,
                      style: AppTheme.bodyLarge.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      kk?.alamat ?? 'Belum ada alamat KK yang terhubung.',
                      style: AppTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _pill(
                          Icons.people_alt_rounded,
                          '${group.members.length} warga',
                        ),
                        if (kk != null)
                          _pill(
                            Icons.home_work_rounded,
                            'RT ${kk.rt}/RW ${kk.rw}',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (onOpenKk != null)
                TextButton.icon(
                  onPressed: onOpenKk,
                  icon: const Icon(Icons.visibility_rounded),
                  label: const Text('Lihat KK'),
                ),
            ],
          ),
          const SizedBox(height: 14),
          ...group.members.map(
            (warga) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _WargaListCard(
                warga: warga,
                onTap: () => onOpenWarga(warga),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(IconData icon, String label) {
    return AppHeroBadge(
      label: label,
      foregroundColor: AppTheme.textPrimary,
      backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.08),
      icon: icon,
    );
  }
}

class _WargaListCard extends StatelessWidget {
  const _WargaListCard({required this.warga, required this.onTap});

  final WargaModel warga;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
          color: const Color(0xFFFBFCFC),
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          border: Border.all(color: AppTheme.dividerColor),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
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
    return AppHeroBadge(
      label: text,
      foregroundColor: AppTheme.textPrimary,
      backgroundColor: AppTheme.backgroundColor,
      icon: icon,
    );
  }
}
