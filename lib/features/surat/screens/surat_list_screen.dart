import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/surat_service.dart';
import '../../../core/utils/error_classifier.dart';
import '../../../core/utils/formatters.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../providers/surat_providers.dart';
import '../../../shared/models/surat_model.dart';
import '../../../shared/widgets/app_surface.dart';
import '../../../shared/widgets/floating_action_pill.dart';

final suratListProvider = FutureProvider.autoDispose<SuratListData>((
  ref,
) async {
  final auth = ref.watch(authProvider);
  ref.watch(suratRefreshTickProvider);
  return ref.watch(suratServiceProvider).fetchList(auth);
});

class SuratListScreen extends ConsumerStatefulWidget {
  const SuratListScreen({super.key});

  @override
  ConsumerState<SuratListScreen> createState() => _SuratListScreenState();
}

class _SuratListScreenState extends ConsumerState<SuratListScreen> {
  static const String _statusAll = 'all';

  String _query = '';
  String _statusFilter = _statusAll;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final suratAsync = ref.watch(suratListProvider);
    final normalizedRole = AppConstants.normalizeRole(auth.role);

    return Scaffold(
      appBar: AppBar(title: const Text('Surat')),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: AppPageBackground(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: suratAsync.when(
          data: (data) {
            final filtered = _applyFilters(data.requests, data, normalizedRole);
            final canSubmit =
                normalizedRole != AppConstants.roleSysadmin &&
                (data.myWargaId ?? '').isNotEmpty;

            return Column(
              children: [
                _buildHero(auth, data),
                const SizedBox(height: 12),
                AppSearchBar(
                  hintText: 'Cari jenis surat, nama warga, atau keperluan',
                  value: _query,
                  onChanged: (value) => setState(() => _query = value),
                ),
                const SizedBox(height: 12),
                _buildStatusFilters(),
                const SizedBox(height: 14),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async => ref.invalidate(suratListProvider),
                    child: filtered.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              const SizedBox(height: 80),
                              AppEmptyState(
                                icon: Icons.description_outlined,
                                title: data.requests.isEmpty
                                    ? 'Belum ada pengajuan surat'
                                    : 'Tidak ada hasil yang cocok',
                                message: data.requests.isEmpty
                                    ? _emptyMessageForRole(normalizedRole)
                                    : 'Ubah pencarian atau filter status untuk melihat data lain.',
                              ),
                            ],
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final surat = filtered[index];
                              return _SuratListCard(
                                surat: surat,
                                wargaName:
                                    data
                                        .wargaById[surat.wargaId]
                                        ?.namaLengkap ??
                                    'Warga',
                                role: normalizedRole,
                                onTap: () => context.push('/surat/${surat.id}'),
                              );
                            },
                          ),
                  ),
                ),
                const SizedBox(height: 72),
                if (canSubmit) const SizedBox.shrink(),
              ],
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
                    onPressed: () => ref.invalidate(suratListProvider),
                    child: const Text('Coba Lagi'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: suratAsync.maybeWhen(
        data: (data) {
          final canSubmit =
              AppConstants.normalizeRole(auth.role) !=
                  AppConstants.roleSysadmin &&
              (data.myWargaId ?? '').isNotEmpty;
          if (!canSubmit) {
            return null;
          }
          return FloatingActionPill(
            onTap: () async {
              await context.push(Routes.suratForm);
              if (mounted) {
                ref.invalidate(suratListProvider);
              }
            },
            icon: Icons.add_rounded,
            label: 'Ajukan Surat',
            gradientColors: const [AppTheme.primaryDark, AppTheme.primaryColor],
          );
        },
        orElse: () => null,
      ),
    );
  }

  Widget _buildHero(AuthState auth, SuratListData data) {
    final normalizedRole = AppConstants.normalizeRole(auth.role);
    final actionable = data.requests
        .where((item) => _requiresActionForRole(item, normalizedRole))
        .length;
    final completed = data.requests.where((item) => item.isCompleted).length;

    final subtitle = normalizedRole == AppConstants.roleWarga
        ? 'Ajukan surat pengantar, pantau proses verifikasi, dan unduh hasil surat yang sudah selesai.'
        : 'Kelola pengajuan surat sesuai wilayah akses Anda, lalu lanjutkan proses review hingga finalisasi.';

    return AppHeroPanel(
      eyebrow: AppConstants.roleLabel(normalizedRole),
      icon: Icons.mail_outline_rounded,
      title: normalizedRole == AppConstants.roleWarga
          ? 'Layanan surat untuk kebutuhan warga'
          : 'Workflow surat warga dan pengurus',
      subtitle: subtitle,
      chips: [
        _heroChip(Icons.description_outlined, 'Total ${data.requests.length}'),
        _heroChip(Icons.bolt_rounded, 'Perlu aksi $actionable'),
        _heroChip(Icons.check_circle_outline_rounded, 'Selesai $completed'),
      ],
    );
  }

  Widget _buildStatusFilters() {
    const statuses = <String>[
      _statusAll,
      AppConstants.suratSubmitted,
      AppConstants.suratNeedRevision,
      AppConstants.suratApprovedRt,
      AppConstants.suratForwardedToRw,
      AppConstants.suratApprovedRw,
      AppConstants.suratCompleted,
      AppConstants.suratRejected,
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: statuses.map((status) {
          final selected = _statusFilter == status;
          final label = status == _statusAll
              ? 'Semua'
              : AppConstants.suratStatusLabel(status);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              selected: selected,
              label: Text(label),
              onSelected: (_) => setState(() => _statusFilter = status),
            ),
          );
        }).toList(),
      ),
    );
  }

  List<SuratModel> _applyFilters(
    List<SuratModel> requests,
    SuratListData data,
    String role,
  ) {
    final query = _query.trim().toLowerCase();

    return requests.where((surat) {
      if (_statusFilter != _statusAll && surat.status != _statusFilter) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      final wargaName =
          data.wargaById[surat.wargaId]?.namaLengkap.toLowerCase() ?? '';
      final haystacks = <String>[
        surat.title.toLowerCase(),
        surat.purpose.toLowerCase(),
        AppConstants.suratStatusLabel(surat.status).toLowerCase(),
        AppConstants.suratApprovalLabel(surat.approvalLevel).toLowerCase(),
        wargaName,
      ];

      for (final entry in surat.requestPayload.entries) {
        haystacks.add('${entry.key} ${entry.value}'.toLowerCase());
      }

      if (role == AppConstants.roleWarga) {
        return haystacks.any((value) => value.contains(query));
      }

      return haystacks.any((value) => value.contains(query));
    }).toList();
  }

  bool _requiresActionForRole(SuratModel surat, String role) {
    switch (role) {
      case AppConstants.roleWarga:
        return surat.isNeedRevision;
      case AppConstants.roleAdminRt:
        return surat.isSubmitted ||
            (!surat.requiresRwApproval && surat.isApprovedRt);
      case AppConstants.roleAdminRw:
      case AppConstants.roleAdminRwPro:
      case AppConstants.roleSysadmin:
        return surat.isForwardedToRw || surat.isApprovedRw;
      default:
        return false;
    }
  }

  String _emptyMessageForRole(String role) {
    switch (role) {
      case AppConstants.roleAdminRt:
        return 'Pengajuan surat warga di RT Anda akan muncul di sini.';
      case AppConstants.roleAdminRw:
      case AppConstants.roleAdminRwPro:
        return 'Surat eskalasi dari RT akan muncul di sini untuk review RW.';
      case AppConstants.roleSysadmin:
        return 'Belum ada pengajuan surat yang masuk ke sistem.';
      case AppConstants.roleWarga:
      default:
        return 'Mulai ajukan surat dari tombol di kanan bawah.';
    }
  }

  Widget _heroChip(IconData icon, String label) {
    return AppHeroBadge(
      label: label,
      icon: icon,
      foregroundColor: Colors.white,
      backgroundColor: Colors.white.withValues(alpha: 0.16),
    );
  }
}

class _SuratListCard extends StatelessWidget {
  const _SuratListCard({
    required this.surat,
    required this.wargaName,
    required this.role,
    required this.onTap,
  });

  final SuratModel surat;
  final String wargaName;
  final String role;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = AppTheme.statusColor(surat.status);
    final showApplicant = role != AppConstants.roleWarga;

    return AppSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.description_outlined,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        surat.title,
                        style: AppTheme.heading3.copyWith(fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        surat.purpose,
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  Formatters.tanggalRelatif(
                    surat.updated ?? surat.created ?? DateTime.now(),
                  ),
                  style: AppTheme.caption,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _metaChip(
                  AppConstants.suratStatusLabel(surat.status),
                  statusColor.withValues(alpha: 0.12),
                  statusColor,
                ),
                _metaChip(
                  AppConstants.suratApprovalLabel(surat.approvalLevel),
                  AppTheme.primaryColor.withValues(alpha: 0.10),
                  AppTheme.primaryColor,
                ),
                _metaChip(
                  AppConstants.suratCategoryLabel(surat.category),
                  const Color(0xFFF1F3F2),
                  AppTheme.textSecondary,
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (showApplicant) ...[
              Text(
                'Pemohon: $wargaName',
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
            ],
            Text(
              'Diajukan ${Formatters.tanggalWaktu(surat.created ?? DateTime.now())}',
              style: AppTheme.caption,
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaChip(String label, Color background, Color foreground) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTheme.caption.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
