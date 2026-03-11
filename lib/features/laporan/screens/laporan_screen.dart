import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/iuran_pdf_service.dart';
import '../../../core/services/laporan_service.dart';
import '../../../core/services/pocketbase_service.dart';
import '../../../core/utils/error_classifier.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_surface.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/laporan_providers.dart';

class LaporanScreen extends ConsumerStatefulWidget {
  const LaporanScreen({super.key, this.initialFocus});

  final String? initialFocus;

  @override
  ConsumerState<LaporanScreen> createState() => _LaporanScreenState();
}

class _LaporanScreenState extends ConsumerState<LaporanScreen> {
  LaporanRangePreset _preset = LaporanRangePreset.month;
  String _selectedFocus = 'surat_total';
  Timer? _refreshDebounce;
  final List<Future<void> Function()> _unsubscribers = [];

  @override
  void initState() {
    super.initState();
    _selectedFocus = widget.initialFocus ?? _selectedFocus;
    _bindRealtime();
  }

  Future<void> _bindRealtime() async {
    for (final collection in [
      AppConstants.colSurat,
      AppConstants.colIuranBills,
      AppConstants.colIuranPayments,
      AppConstants.colDokumen,
      AppConstants.colWarga,
      AppConstants.colKartuKeluarga,
    ]) {
      final unsubscribe = await pb
          .collection(collection)
          .subscribe('*', (_) => _scheduleRefresh());
      _unsubscribers.add(unsubscribe);
    }
  }

  void _scheduleRefresh() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 180), () {
      if (mounted) {
        ref.read(laporanRefreshTickProvider.notifier).bump();
      }
    });
  }

  @override
  void dispose() {
    _refreshDebounce?.cancel();
    for (final unsubscribe in _unsubscribers) {
      unsubscribe();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final normalizedRole = AppConstants.normalizeRole(auth.role);
    if (!AppConstants.isAdminRole(normalizedRole)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Laporan')),
        body: const AppPageBackground(
          child: AppEmptyState(
            icon: Icons.lock_outline_rounded,
            title: 'Akses laporan dibatasi',
            message: 'Laporan operasional hanya tersedia untuk admin wilayah.',
          ),
        ),
      );
    }

    final reportAsync = ref.watch(laporanOperationalProvider(_preset));
    final userName = auth.user?.getStringValue('name').trim().isNotEmpty == true
        ? auth.user!.getStringValue('name').trim()
        : 'Admin';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Operasional'),
        actions: [
          IconButton(
            tooltip: 'Refresh laporan',
            onPressed: () => ref.read(laporanRefreshTickProvider.notifier).bump(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: AppPageBackground(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: reportAsync.when(
          data: (report) => RefreshIndicator(
            onRefresh: () async =>
                ref.read(laporanRefreshTickProvider.notifier).bump(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                AppHeroPanel(
                  eyebrow: AppConstants.roleLabel(normalizedRole),
                  icon: Icons.insights_rounded,
                  title: 'Pantau layanan RT/RW secara real-time',
                  subtitle:
                      'Gunakan KPI interaktif untuk menelusuri Surat Pengantar, iuran, dokumen, mutasi, serta data warga dan KK dalam satu dashboard operasional.',
                  chips: [
                    _heroChip(Icons.date_range_rounded, report.preset.label),
                    _heroChip(
                      Icons.people_outline_rounded,
                      '${report.wargaRecords.length} warga',
                    ),
                    _heroChip(
                      Icons.account_balance_wallet_outlined,
                      Formatters.rupiah(report.iuranSummary.totalTunggakan),
                    ),
                  ],
                  trailing: FilledButton.tonalIcon(
                    onPressed: report.unpaidBills.isEmpty
                        ? null
                        : () => _shareOutstandingPdf(report, userName),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('PDF Iuran'),
                  ),
                ),
                const SizedBox(height: 8),
                AppSurfaceCard(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: LaporanRangePreset.values
                        .map(
                          (preset) => ChoiceChip(
                            label: Text(preset.label),
                            selected: _preset == preset,
                            onSelected: (_) => setState(() => _preset = preset),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 10),
                _buildOverviewCard(report),
                const SizedBox(height: 10),
                _buildSuratCard(report),
                const SizedBox(height: 10),
                _buildIuranCard(report),
                const SizedBox(height: 10),
                _buildDokumenCard(report),
                const SizedBox(height: 10),
                _buildMutasiCard(report),
                const SizedBox(height: 10),
                _buildDetailPanel(report),
              ],
            ),
          ),
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
                    onPressed: () =>
                        ref.read(laporanRefreshTickProvider.notifier).bump(),
                    child: const Text('Coba Lagi'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewCard(LaporanOperationalData report) {
    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionHeader(
            title: 'Ringkasan Inti',
            subtitle: 'Snapshot operasional saat ini di wilayah akses admin.',
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _metricCard(
                keyId: 'warga_total',
                label: 'Total Warga',
                value: '${report.wargaRecords.length}',
                tone: AppTheme.primaryColor,
                icon: Icons.people_alt_outlined,
              ),
              _metricCard(
                keyId: 'kk_total',
                label: 'Total KK',
                value: '${report.kkRecords.length}',
                tone: AppTheme.secondaryColor,
                icon: Icons.family_restroom_outlined,
              ),
              _metricCard(
                keyId: 'surat_total',
                label: 'Surat Pengantar',
                value: '${report.suratSummary.total}',
                tone: const Color(0xFF64748B),
                icon: Icons.description_outlined,
              ),
              _metricCard(
                keyId: 'iuran_outstanding',
                label: 'Iuran Belum Lunas',
                value: '${report.iuranSummary.outstandingBills}',
                tone: AppTheme.primaryDark,
                icon: Icons.payments_outlined,
              ),
              _metricCard(
                keyId: 'dokumen_pending',
                label: 'Dokumen Pending',
                value: '${report.dokumenSummary.pending}',
                tone: AppTheme.warningColor,
                icon: Icons.folder_outlined,
              ),
              _metricCard(
                keyId: 'mutasi_total',
                label: 'Mutasi Warga',
                value: '${report.mutasiSummary.total}',
                tone: AppTheme.accentColor,
                icon: Icons.swap_horiz_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuratCard(LaporanOperationalData report) {
    final summary = report.suratSummary;
    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(
            title: 'Surat Pengantar',
            subtitle: 'Aktivitas pengajuan dan tindakan admin yang perlu diproses.',
            action: TextButton(
              onPressed: () => context.push(Routes.surat),
              child: const Text('Buka Modul'),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _metricCard(
                keyId: 'surat_submitted',
                label: 'Masuk',
                value: '${summary.submitted}',
                tone: AppTheme.primaryColor,
                icon: Icons.mark_email_unread_outlined,
              ),
              _metricCard(
                keyId: 'surat_action',
                label: 'Perlu Aksi',
                value: '${summary.actionRequired}',
                tone: AppTheme.accentColor,
                icon: Icons.pending_actions_outlined,
              ),
              _metricCard(
                keyId: 'surat_revision',
                label: 'Perlu Revisi',
                value: '${summary.needRevision}',
                tone: AppTheme.warningColor,
                icon: Icons.edit_note_rounded,
              ),
              _metricCard(
                keyId: 'surat_completed',
                label: 'Selesai',
                value: '${summary.completed}',
                tone: AppTheme.successColor,
                icon: Icons.task_alt_rounded,
              ),
              _metricCard(
                keyId: 'surat_rejected',
                label: 'Ditolak',
                value: '${summary.rejected}',
                tone: AppTheme.errorColor,
                icon: Icons.cancel_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIuranCard(LaporanOperationalData report) {
    final summary = report.iuranSummary;
    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(
            title: 'Iuran',
            subtitle:
                'Rekap tagihan per KK, pembayaran lunas, dan bukti transfer yang belum tervalidasi.',
            action: TextButton.icon(
              onPressed: report.unpaidBills.isEmpty
                  ? null
                  : () => _shareOutstandingPdf(
                        report,
                        ref.read(authProvider).user?.getStringValue('name') ??
                            'Admin',
                      ),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('PDF Belum Masuk'),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _metricCard(
                keyId: 'iuran_total',
                label: 'Total Tagihan',
                value: Formatters.rupiah(summary.totalTagihan),
                tone: AppTheme.primaryDark,
                icon: Icons.summarize_outlined,
              ),
              _metricCard(
                keyId: 'iuran_paid',
                label: 'Total Lunas',
                value: Formatters.rupiah(summary.totalLunas),
                tone: AppTheme.successColor,
                icon: Icons.paid_outlined,
              ),
              _metricCard(
                keyId: 'iuran_outstanding',
                label: 'Total Tunggakan',
                value: Formatters.rupiah(summary.totalTunggakan),
                tone: AppTheme.errorColor,
                icon: Icons.warning_amber_rounded,
              ),
              _metricCard(
                keyId: 'iuran_pending',
                label: 'Menunggu Verifikasi',
                value: '${summary.pendingVerificationBills}',
                tone: AppTheme.accentColor,
                icon: Icons.fact_check_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDokumenCard(LaporanOperationalData report) {
    final summary = report.dokumenSummary;
    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(
            title: 'Dokumen',
            subtitle:
                'Lihat antrean verifikasi dan tindak lanjut dokumen warga dalam scope saat ini.',
            action: TextButton(
              onPressed: () => context.push(Routes.dokumen),
              child: const Text('Buka Modul'),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _metricCard(
                keyId: 'dokumen_pending',
                label: 'Pending',
                value: '${summary.pending}',
                tone: AppTheme.warningColor,
                icon: Icons.schedule_outlined,
              ),
              _metricCard(
                keyId: 'dokumen_revision',
                label: 'Perlu Revisi',
                value: '${summary.needRevision}',
                tone: AppTheme.accentColor,
                icon: Icons.rule_folder_outlined,
              ),
              _metricCard(
                keyId: 'dokumen_verified',
                label: 'Terverifikasi',
                value: '${summary.verified}',
                tone: AppTheme.successColor,
                icon: Icons.verified_outlined,
              ),
              _metricCard(
                keyId: 'dokumen_rejected',
                label: 'Ditolak',
                value: '${summary.rejected}',
                tone: AppTheme.errorColor,
                icon: Icons.block_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMutasiCard(LaporanOperationalData report) {
    final summary = report.mutasiSummary;
    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionHeader(
            title: 'Mutasi Warga',
            subtitle:
                'Mutasi dihitung dari Surat Pengantar yang berkaitan dengan pindah, kematian, dan perubahan KK.',
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _metricCard(
                keyId: 'mutasi_total',
                label: 'Total Mutasi',
                value: '${summary.total}',
                tone: AppTheme.accentColor,
                icon: Icons.swap_horiz_rounded,
              ),
              _metricCard(
                keyId: 'mutasi_masuk',
                label: 'Pindah Datang',
                value: '${summary.masuk}',
                tone: AppTheme.primaryColor,
                icon: Icons.south_west_rounded,
              ),
              _metricCard(
                keyId: 'mutasi_keluar',
                label: 'Pindah Keluar',
                value: '${summary.keluar}',
                tone: AppTheme.warningColor,
                icon: Icons.north_east_rounded,
              ),
              _metricCard(
                keyId: 'mutasi_kematian',
                label: 'Kematian',
                value: '${summary.kematian}',
                tone: AppTheme.errorColor,
                icon: Icons.health_and_safety_outlined,
              ),
              _metricCard(
                keyId: 'mutasi_perubahan_kk',
                label: 'Perubahan KK',
                value: '${summary.perubahanKk}',
                tone: AppTheme.secondaryColor,
                icon: Icons.groups_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailPanel(LaporanOperationalData report) {
    final detail = _buildDetailForFocus(report, _selectedFocus);
    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(
            title: detail.title,
            subtitle: detail.subtitle,
          ),
          const SizedBox(height: 14),
          if (detail.items.isEmpty)
            const AppEmptyState(
              icon: Icons.inbox_outlined,
              title: 'Belum ada data',
              message:
                  'Tidak ada item yang cocok untuk KPI ini pada rentang laporan yang dipilih.',
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: detail.items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = detail.items[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: item.onTap,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: item.tone.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(item.icon, color: item.tone, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.title, style: AppTheme.heading3),
                              const SizedBox(height: 4),
                              Text(
                                item.subtitle,
                                style: AppTheme.bodySmall.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              if ((item.meta ?? '').isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  item.meta!,
                                  style: AppTheme.caption.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: item.tone.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                item.statusLabel,
                                style: AppTheme.caption.copyWith(
                                  color: item.tone,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              Formatters.tanggalRelatif(item.timestamp),
                              style: AppTheme.caption,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _metricCard({
    required String keyId,
    required String label,
    required String value,
    required Color tone,
    required IconData icon,
  }) {
    final isActive = _selectedFocus == keyId;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() => _selectedFocus = keyId),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 150,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isActive ? tone.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive
                ? tone.withValues(alpha: 0.35)
                : const Color(0xFFE5E7EB),
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: tone.withValues(alpha: 0.12),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: tone, size: 20),
            const SizedBox(height: 14),
            Text(value, style: AppTheme.heading2.copyWith(color: tone)),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  AppHeroBadge _heroChip(IconData icon, String label) {
    return AppHeroBadge(
      label: label,
      icon: icon,
      foregroundColor: Colors.white,
      backgroundColor: Colors.white.withValues(alpha: 0.16),
    );
  }

  Future<void> _shareOutstandingPdf(
    LaporanOperationalData report,
    String generatedBy,
  ) async {
    try {
      await ref
          .read(iuranPdfServiceProvider)
          .shareOutstandingBillsPdf(report, generatedBy: generatedBy);
    } catch (error) {
      if (mounted) {
        ErrorClassifier.showErrorSnackBar(context, error);
      }
    }
  }

  _DetailBlock _buildDetailForFocus(
    LaporanOperationalData report,
    String focus,
  ) {
    switch (focus) {
      case 'warga_total':
        final items = [...report.wargaRecords]
          ..sort((a, b) => a.namaLengkap.compareTo(b.namaLengkap));
        return _DetailBlock(
          title: 'Daftar Warga',
          subtitle: 'Klik item untuk membuka detail data warga.',
          items: items
              .map(
                (warga) => _ReportDetailItem(
                  title: warga.namaLengkap,
                  subtitle: 'NIK ${warga.nik} • RT ${warga.rt} / RW ${warga.rw}',
                  meta: warga.alamat,
                  statusLabel: 'Warga',
                  timestamp: warga.updated ?? warga.created ?? DateTime.now(),
                  icon: Icons.person_outline_rounded,
                  tone: AppTheme.primaryColor,
                  onTap: () => context.push('/warga/${warga.id}'),
                ),
              )
              .toList(),
        );
      case 'kk_total':
        final items = [...report.kkRecords]
          ..sort((a, b) => a.noKk.compareTo(b.noKk));
        return _DetailBlock(
          title: 'Daftar Kartu Keluarga',
          subtitle: 'Klik item untuk membuka detail KK.',
          items: items
              .map(
                (kk) => _ReportDetailItem(
                  title: kk.noKk,
                  subtitle: 'RT ${kk.rt} / RW ${kk.rw}',
                  meta:
                      '${kk.desaKelurahan ?? '-'}, ${kk.kecamatan ?? '-'}, ${kk.kabupatenKota ?? '-'}',
                  statusLabel: 'KK',
                  timestamp: kk.updated ?? kk.created ?? DateTime.now(),
                  icon: Icons.family_restroom_outlined,
                  tone: AppTheme.secondaryColor,
                  onTap: () => context.push('/kartu-keluarga/${kk.id}'),
                ),
              )
              .toList(),
        );
      case 'surat_total':
      case 'surat_submitted':
      case 'surat_action':
      case 'surat_revision':
      case 'surat_completed':
      case 'surat_rejected':
        return _buildSuratDetails(report, focus);
      case 'iuran_total':
      case 'iuran_paid':
      case 'iuran_outstanding':
      case 'iuran_pending':
        return _buildIuranDetails(report, focus);
      case 'dokumen_pending':
      case 'dokumen_revision':
      case 'dokumen_verified':
      case 'dokumen_rejected':
        return _buildDokumenDetails(report, focus);
      case 'mutasi_total':
      case 'mutasi_masuk':
      case 'mutasi_keluar':
      case 'mutasi_kematian':
      case 'mutasi_perubahan_kk':
        return _buildMutasiDetails(report, focus);
      default:
        return _buildSuratDetails(report, 'surat_total');
    }
  }

  _DetailBlock _buildSuratDetails(LaporanOperationalData report, String focus) {
    final items = switch (focus) {
      'surat_submitted' => report.filteredSurat
          .where((item) => item.isSubmitted)
          .toList(),
      'surat_action' => report.filteredSurat
          .where(
            (item) => item.isSubmitted ||
                (!item.requiresRwApproval && item.isApprovedRt),
          )
          .toList(),
      'surat_revision' => report.filteredSurat
          .where((item) => item.isNeedRevision)
          .toList(),
      'surat_completed' => report.filteredSurat
          .where((item) => item.isCompleted)
          .toList(),
      'surat_rejected' => report.filteredSurat
          .where((item) => item.isRejected)
          .toList(),
      _ => report.filteredSurat,
    }..sort(
        (a, b) =>
            (b.submittedAt ?? b.updated ?? b.created ?? DateTime.now())
                .compareTo(
                  a.submittedAt ?? a.updated ?? a.created ?? DateTime.now(),
                ),
      );

    return _DetailBlock(
      title: 'Detail Surat Pengantar',
      subtitle: 'Klik item untuk membuka halaman detail surat.',
      items: items
          .map(
            (surat) => _ReportDetailItem(
              title: surat.title,
              subtitle:
                  '${report.suratData.wargaById[surat.wargaId]?.namaLengkap ?? 'Warga'} • ${surat.purpose}',
              meta: AppConstants.suratApprovalLabel(surat.approvalLevel),
              statusLabel: AppConstants.suratStatusLabel(surat.status),
              timestamp:
                  surat.submittedAt ?? surat.updated ?? surat.created ?? DateTime.now(),
              icon: Icons.description_outlined,
              tone: AppTheme.statusColor(surat.status),
              onTap: () => context.push('/surat/${surat.id}'),
            ),
          )
          .toList(),
    );
  }

  _DetailBlock _buildIuranDetails(LaporanOperationalData report, String focus) {
    final items = switch (focus) {
      'iuran_paid' => report.paidBills,
      'iuran_pending' => report.pendingVerificationBills,
      'iuran_outstanding' => report.unpaidBills,
      _ => report.filteredBills,
    };

    return _DetailBlock(
      title: 'Detail Iuran per KK',
      subtitle:
          'Klik item untuk membuka modul Iuran dan tindak lanjuti pembayaran.',
      items: items
          .map(
            (bill) => _ReportDetailItem(
              title: bill.title,
              subtitle:
                  '${(bill.kkHolderName ?? '').trim().isEmpty ? bill.kkNumber : bill.kkHolderName} • ${bill.kkNumber}',
              meta:
                  '${Formatters.rupiah(bill.amount)} • ${bill.dueDate == null ? '-' : Formatters.tanggalPendek(bill.dueDate!)}',
              statusLabel: AppConstants.iuranBillStatusLabel(bill.status),
              timestamp:
                  bill.dueDate ?? bill.updated ?? bill.created ?? DateTime.now(),
              icon: Icons.payments_outlined,
              tone: AppTheme.statusColor(bill.status),
              onTap: () => context.push(Routes.iuran),
            ),
          )
          .toList(),
    );
  }

  _DetailBlock _buildDokumenDetails(
    LaporanOperationalData report,
    String focus,
  ) {
    final items = switch (focus) {
      'dokumen_pending' => report.filteredDokumen
          .where((item) => item.isPending)
          .toList(),
      'dokumen_revision' => report.filteredDokumen
          .where((item) => item.isNeedRevision)
          .toList(),
      'dokumen_verified' => report.filteredDokumen
          .where((item) => item.isVerified)
          .toList(),
      'dokumen_rejected' => report.filteredDokumen
          .where((item) => item.isRejected)
          .toList(),
      _ => report.filteredDokumen,
    };

    return _DetailBlock(
      title: 'Detail Dokumen',
      subtitle: 'Klik item untuk membuka modul Dokumen.',
      items: items
          .map(
            (document) => _ReportDetailItem(
              title: document.jenis,
              subtitle:
                  report.dokumenWargaById[document.warga]?.namaLengkap ?? 'Warga',
              meta: document.catatan,
              statusLabel: _dokumenStatusLabel(document.statusVerifikasi),
              timestamp: document.updated ?? document.created ?? DateTime.now(),
              icon: Icons.folder_open_outlined,
              tone: AppTheme.statusColor(document.statusVerifikasi),
              onTap: () => context.push(Routes.dokumen),
            ),
          )
          .toList(),
    );
  }

  _DetailBlock _buildMutasiDetails(
    LaporanOperationalData report,
    String focus,
  ) {
    final items = switch (focus) {
      'mutasi_masuk' => report.mutasiMasuk,
      'mutasi_keluar' => report.mutasiKeluar,
      'mutasi_kematian' => report.mutasiKematian,
      'mutasi_perubahan_kk' => report.mutasiPerubahanKk,
      _ => report.mutasiRequests,
    };

    return _DetailBlock(
      title: 'Detail Mutasi Warga',
      subtitle:
          'Mutasi disusun dari jenis Surat Pengantar yang berkaitan dengan perpindahan, kematian, dan perubahan KK.',
      items: items
          .map(
            (surat) => _ReportDetailItem(
              title: surat.title,
              subtitle:
                  report.suratData.wargaById[surat.wargaId]?.namaLengkap ?? 'Warga',
              meta: surat.purpose,
              statusLabel: AppConstants.suratStatusLabel(surat.status),
              timestamp:
                  surat.submittedAt ?? surat.updated ?? surat.created ?? DateTime.now(),
              icon: Icons.swap_horiz_rounded,
              tone: AppTheme.accentColor,
              onTap: () => context.push('/surat/${surat.id}'),
            ),
          )
          .toList(),
    );
  }

  String _dokumenStatusLabel(String value) {
    switch (value) {
      case AppConstants.statusPending:
        return 'Pending';
      case AppConstants.statusNeedRevision:
        return 'Perlu Revisi';
      case AppConstants.statusVerified:
        return 'Terverifikasi';
      case AppConstants.statusRejected:
        return 'Ditolak';
      default:
        return value;
    }
  }
}

class _DetailBlock {
  const _DetailBlock({
    required this.title,
    required this.subtitle,
    required this.items,
  });

  final String title;
  final String subtitle;
  final List<_ReportDetailItem> items;
}

class _ReportDetailItem {
  const _ReportDetailItem({
    required this.title,
    required this.subtitle,
    required this.statusLabel,
    required this.timestamp,
    required this.icon,
    required this.tone,
    this.meta,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final String statusLabel;
  final DateTime timestamp;
  final IconData icon;
  final Color tone;
  final String? meta;
  final VoidCallback? onTap;
}
