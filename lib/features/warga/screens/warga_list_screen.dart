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
      appBar: AppBar(title: const Text('Data Warga')),
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
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
        child: Column(
          children: [
            _buildCompactHeader(context, isAdmin: isAdmin),
            const SizedBox(height: 10),
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
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final group = groups[index];
                        return _WargaGroupTile(
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

  Widget _buildCompactHeader(BuildContext context, {required bool isAdmin}) {
    final subtitleColor = AppTheme.secondaryTextFor(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Slim info row
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.groups_2_rounded,
                size: 18,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Dikelompokkan per KK',
                style: AppTheme.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: subtitleColor,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isAdmin ? 'Scope wilayah' : 'Akun pribadi',
                style: AppTheme.caption.copyWith(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
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

// ─── Compact expandable group tile ───────────────────────────────────
class _WargaGroupTile extends StatefulWidget {
  const _WargaGroupTile({
    required this.group,
    required this.onOpenWarga,
    this.onOpenKk,
  });

  final _WargaGroup group;
  final VoidCallback? onOpenKk;
  final ValueChanged<WargaModel> onOpenWarga;

  @override
  State<_WargaGroupTile> createState() => _WargaGroupTileState();
}

class _WargaGroupTileState extends State<_WargaGroupTile>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final kk = widget.group.kk;
    final kkLabel = kk == null
        ? 'KK belum terhubung'
        : Formatters.formatNoKk(kk.noKk);
    // Find kepala keluarga name from members
    final kepalaName = _findKepalaName();

    return Container(
      decoration: AppTheme.cardDecorationFor(context),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // ── Collapsed header row ──
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  // Gradient icon pill
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.family_restroom_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // KK number + kepala keluarga
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          kkLabel,
                          style: AppTheme.bodyMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          kepalaName,
                          style: AppTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Member count badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${widget.group.members.length}',
                      style: AppTheme.caption.copyWith(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded member list ──
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildExpandedContent(),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }

  String _findKepalaName() {
    final kk = widget.group.kk;
    if (kk == null) {
      return widget.group.members.isNotEmpty
          ? widget.group.members.first.namaLengkap
          : 'Tidak diketahui';
    }
    // kepalaKeluarga is a warga id
    for (final member in widget.group.members) {
      if (member.id == kk.kepalaKeluarga) {
        return member.namaLengkap;
      }
    }
    // Fallback: first member
    return widget.group.members.isNotEmpty
        ? widget.group.members.first.namaLengkap
        : '-';
  }

  Widget _buildExpandedContent() {
    final kk = widget.group.kk;
    final borderColor = AppTheme.cardBorderColorFor(context);
    final backgroundColor = AppTheme.isDark(context)
        ? AppTheme.darkSurfaceRaised
        : const Color(0xFFF8FAFB);
    final subtitleColor = AppTheme.secondaryTextFor(context);
    final tertiaryColor = AppTheme.tertiaryTextFor(context);
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Compact info row
          if (kk != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 13,
                    color: tertiaryColor,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      kk.alamat.isNotEmpty ? kk.alamat : 'Alamat belum diisi',
                      style: AppTheme.caption.copyWith(color: subtitleColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'RT ${kk.rt}/RW ${kk.rw}',
                    style: AppTheme.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: subtitleColor,
                    ),
                  ),
                  if (widget.onOpenKk != null) ...[
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: widget.onOpenKk,
                      child: Text(
                        'Lihat KK',
                        style: AppTheme.caption.copyWith(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 4),
          // Member list — compact
          ...widget.group.members.map(
            (warga) => _CompactWargaRow(
              warga: warga,
              isKepala: kk != null && warga.id == kk.kepalaKeluarga,
              onTap: () => widget.onOpenWarga(warga),
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

// ─── Compact warga row inside group ──────────────────────────────────
class _CompactWargaRow extends StatelessWidget {
  const _CompactWargaRow({
    required this.warga,
    required this.onTap,
    this.isKepala = false,
  });

  final WargaModel warga;
  final VoidCallback onTap;
  final bool isKepala;

  @override
  Widget build(BuildContext context) {
    final tertiaryColor = AppTheme.tertiaryTextFor(context);
    final primaryText = AppTheme.primaryTextFor(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            // Avatar circle
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: isKepala
                    ? AppTheme.primaryGradient
                    : const LinearGradient(
                        colors: [Color(0xFFE5E0DA), Color(0xFFD4CDC5)],
                      ),
                borderRadius: BorderRadius.circular(11),
              ),
              alignment: Alignment.center,
              child: Text(
                Formatters.inisial(warga.namaLengkap),
                style: AppTheme.caption.copyWith(
                  color: isKepala ? Colors.white : primaryText,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Name + info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          warga.namaLengkap,
                          style: AppTheme.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isKepala) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Kepala',
                            style: AppTheme.caption.copyWith(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '${Formatters.formatNik(warga.nik)}  ·  ${warga.jenisKelamin}',
                    style: AppTheme.caption.copyWith(color: tertiaryColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: tertiaryColor),
          ],
        ),
      ),
    );
  }
}
