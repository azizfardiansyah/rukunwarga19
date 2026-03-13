import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketbase/pocketbase.dart';

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

class _KkListEntry {
  const _KkListEntry({required this.kk, this.kepalaName, required this.record});
  final KartuKeluargaModel kk;
  final String? kepalaName;
  final RecordModel record;
}

final kkListProvider = FutureProvider.autoDispose<List<_KkListEntry>>((
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
        expand: 'kepala_keluarga',
      );

  return records.map((record) {
    final kk = KartuKeluargaModel.fromRecord(record);
    String? kepalaName;
    try {
      final kepalaRecord = record.get<RecordModel>('expand.kepala_keluarga');
      kepalaName = kepalaRecord.getStringValue('nama_lengkap');
    } catch (_) {
      kepalaName = null;
    }
    return _KkListEntry(kk: kk, kepalaName: kepalaName, record: record);
  }).toList();
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
      appBar: AppBar(title: const Text('Kartu Keluarga')),
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
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
        child: Column(
          children: [
            _buildCompactHeader(isAdmin: isAdmin),
            const SizedBox(height: 10),
            Expanded(
              child: kkAsync.when(
                data: (entries) {
                  final filtered = _filterEntries(entries);
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
                                : 'Coba nomor KK, nama kepala keluarga, atau alamat.',
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
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final entry = filtered[index];
                        return _KkCompactTile(
                          entry: entry,
                          onTap: () async {
                            await context.push(
                              '/kartu-keluarga/${entry.kk.id}',
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

  List<_KkListEntry> _filterEntries(List<_KkListEntry> input) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return input;
    }

    return input.where((entry) {
      final kk = entry.kk;
      return kk.noKk.toLowerCase().contains(query) ||
          kk.alamat.toLowerCase().contains(query) ||
          kk.rt.contains(query) ||
          kk.rw.contains(query) ||
          (kk.desaKelurahan ?? '').toLowerCase().contains(query) ||
          (kk.kecamatan ?? '').toLowerCase().contains(query) ||
          (kk.kabupatenKota ?? '').toLowerCase().contains(query) ||
          (kk.provinsi ?? '').toLowerCase().contains(query) ||
          (entry.kepalaName ?? '').toLowerCase().contains(query);
    }).toList();
  }

  Widget _buildCompactHeader({required bool isAdmin}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.credit_card_rounded,
                size: 18,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Kartu keluarga & wilayah',
                style: AppTheme.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
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
                isAdmin ? 'Master KK' : 'Akun terhubung',
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
          hintText: 'Cari nomor KK, kepala keluarga, alamat',
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

// ─── Compact KK tile ─────────────────────────────────────────────────
class _KkCompactTile extends StatefulWidget {
  const _KkCompactTile({required this.entry, required this.onTap});

  final _KkListEntry entry;
  final VoidCallback onTap;

  @override
  State<_KkCompactTile> createState() => _KkCompactTileState();
}

class _KkCompactTileState extends State<_KkCompactTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final kk = widget.entry.kk;
    final kepalaName = widget.entry.kepalaName;

    return Container(
      decoration: AppTheme.cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // ── Main row: No KK + kepala keluarga ──
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.credit_card_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          Formatters.formatNoKk(kk.noKk),
                          style: AppTheme.bodyMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                        if (kepalaName != null && kepalaName.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            kepalaName,
                            style: AppTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  // RT/RW badge
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
                      'RT ${kk.rt}/${kk.rw}',
                      style: AppTheme.caption.copyWith(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
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

          // ── Expanded detail ──
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildDetail(kk),
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

  Widget _buildDetail(KartuKeluargaModel kk) {
    final hasScan = (kk.scanKk ?? '').isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.extraLightGray,
        border: Border(
          top: BorderSide(color: AppTheme.dividerColor.withValues(alpha: 0.5)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Address
          if (kk.alamat.isNotEmpty)
            _infoLine(Icons.location_on_outlined, kk.alamat),
          if ((kk.kecamatan ?? '').isNotEmpty)
            _infoLine(Icons.location_city_rounded, kk.kecamatan!),
          if ((kk.kabupatenKota ?? '').isNotEmpty)
            _infoLine(Icons.map_outlined, kk.kabupatenKota!),
          _infoLine(
            hasScan ? Icons.image_outlined : Icons.file_present_outlined,
            hasScan ? 'File KK tersedia' : 'Belum ada file KK',
          ),
          const SizedBox(height: 8),
          // Open detail button
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: widget.onTap,
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('Lihat Detail KK'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: AppTheme.primaryColor.withValues(alpha: 0.15),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoLine(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppTheme.textTertiary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

