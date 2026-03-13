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
import '../../../shared/models/iuran_model.dart';
import '../../../shared/models/surat_model.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../../../shared/widgets/app_surface.dart';
import '../../../shared/widgets/laporan/alert_card.dart';
import '../../../shared/widgets/laporan/metric_card.dart';
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
  String _selectedFocus = '';
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

  Future<void> _refreshReport() async {
    ref.read(laporanRefreshTickProvider.notifier).bump();
    await ref.read(laporanOperationalProvider(_preset).future);
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
    final readyReport = reportAsync.asData?.value;
    final userName = auth.user?.getStringValue('name').trim().isNotEmpty == true
        ? auth.user!.getStringValue('name').trim()
        : 'Admin';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Operasional'),
        actions: [
          if (readyReport != null && readyReport.unpaidBills.isNotEmpty)
            IconButton(
              tooltip: 'PDF iuran belum lunas',
              onPressed: () => _shareOutstandingPdf(readyReport, userName),
              icon: const Icon(Icons.picture_as_pdf_outlined),
            ),
          IconButton(
            tooltip: 'Refresh laporan',
            onPressed: () =>
                ref.read(laporanRefreshTickProvider.notifier).bump(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: AppPageBackground(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: reportAsync.when(
          data: (report) => RefreshIndicator(
            onRefresh: _refreshReport,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                _buildContextCard(normalizedRole, report),
                const SizedBox(height: 12),
                _buildPresetSelector(),
                const SizedBox(height: 18),
                _buildAlertsSection(report),
                const SizedBox(height: 18),
                _buildSnapshotSection(report),
                const SizedBox(height: 18),
                _buildDetailPanel(report),
              ],
            ),
          ),
          loading: () => const _LaporanSkeleton(),
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

  Widget _buildContextCard(
    String normalizedRole,
    LaporanOperationalData report,
  ) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.statusInfo.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.track_changes_rounded,
                  color: AppTheme.statusInfo,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppConstants.roleLabel(normalizedRole),
                      style: AppTheme.labelMedium.copyWith(
                        color: AppTheme.statusInfo,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Real-time view untuk tindakan operasional harian',
                      style: AppTheme.heading3.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Scan antrian penting dulu, lalu buka detail hanya saat dibutuhkan.',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _summaryChip(Icons.date_range_rounded, report.preset.label),
              _summaryChip(
                Icons.people_alt_outlined,
                '${report.wargaRecords.length} warga',
              ),
              _summaryChip(
                Icons.pending_actions_outlined,
                '${report.suratSummary.actionRequired} surat perlu aksi',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPresetSelector() {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(10),
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
            .toList(growable: false),
      ),
    );
  }

  Widget _buildAlertsSection(LaporanOperationalData report) {
    final alerts = _collectAlerts(report);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          icon: Icons.priority_high_rounded,
          title: 'Tindakan Urgent',
          subtitle: 'Fokuskan 2-3 item yang paling perlu aksi terlebih dahulu.',
          tone: AppTheme.statusError,
        ),
        const SizedBox(height: 12),
        if (alerts.isEmpty)
          AppSurfaceCard(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppTheme.statusSuccess.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: AppTheme.statusSuccess,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Semua berjalan baik',
                  style: AppTheme.heading3.copyWith(fontSize: 18),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tidak ada tindakan yang perlu ditangani pada rentang laporan ini.',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = constraints.maxWidth;
              final columns = maxWidth >= 1080
                  ? 3
                  : maxWidth >= 720
                  ? 2
                  : 1;
              final itemWidth = columns == 1
                  ? maxWidth
                  : (maxWidth - ((columns - 1) * 12)) / columns;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: alerts
                    .map(
                      (alert) => SizedBox(
                        width: itemWidth,
                        child: AlertCard(
                          title: alert.title,
                          value: alert.value,
                          subtitle: alert.subtitle,
                          meta: alert.meta,
                          ctaLabel: alert.ctaLabel,
                          onTap: alert.onTap,
                          status: alert.status,
                          icon: alert.icon,
                        ),
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
      ],
    );
  }

  Widget _buildSnapshotSection(LaporanOperationalData report) {
    final metrics = <_SnapshotMetric>[
      _SnapshotMetric(
        focus: 'warga_total',
        label: 'WARGA',
        value: '${report.wargaRecords.length}',
        icon: Icons.people_alt_outlined,
        color: AppTheme.statusInfo,
      ),
      _SnapshotMetric(
        focus: 'kk_total',
        label: 'KK',
        value: '${report.kkRecords.length}',
        icon: Icons.family_restroom_outlined,
        color: AppTheme.statusInfo,
      ),
      _SnapshotMetric(
        focus: 'surat_completed',
        label: 'SURAT SELESAI',
        value: '${report.suratSummary.completed}',
        icon: Icons.description_outlined,
        color: AppTheme.statusSuccess,
      ),
      _SnapshotMetric(
        focus: 'iuran_paid',
        label: 'IURAN LUNAS',
        value: Formatters.rupiahPendek(report.iuranSummary.totalLunas),
        icon: Icons.paid_outlined,
        color: AppTheme.statusSuccess,
      ),
      _SnapshotMetric(
        focus: 'dokumen_pending',
        label: 'DOKUMEN PENDING',
        value: '${report.dokumenSummary.pending}',
        icon: Icons.schedule_outlined,
        color: AppTheme.statusWarning,
      ),
      _SnapshotMetric(
        focus: 'mutasi_total',
        label: 'MUTASI',
        value: '${report.mutasiSummary.total}',
        icon: Icons.swap_horiz_rounded,
        color: AppTheme.statusInfo,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          icon: Icons.dashboard_outlined,
          title: 'Snapshot Operasional',
          subtitle: 'Tap kartu untuk membuka detail di layer berikutnya.',
          tone: AppTheme.darkGray,
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth;
            final crossAxisCount = maxWidth >= 1080
                ? 4
                : maxWidth >= 720
                ? 3
                : 2;

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: maxWidth >= 720 ? 1.15 : 1.08,
              ),
              itemCount: metrics.length,
              itemBuilder: (context, index) {
                final metric = metrics[index];
                return MetricCard(
                  label: metric.label,
                  value: metric.value,
                  icon: metric.icon,
                  isActive: _selectedFocus == metric.focus,
                  activeColor: metric.color,
                  onTap: () => setState(() => _selectedFocus = metric.focus),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _summaryChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.extraLightGray,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.lightGray),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.statusInfo),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTheme.caption.copyWith(
              fontSize: 12,
              color: AppTheme.darkGray,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailPanel(LaporanOperationalData report) {
    if (_selectedFocus.isEmpty) {
      return AppSurfaceCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle(
              icon: Icons.insights_outlined,
              title: 'Detail Dashboard',
              subtitle: 'Pilih salah satu snapshot untuk membuka detail.',
              tone: AppTheme.darkGray,
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.extraLightGray,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.lightGray),
              ),
              child: Text(
                'Konten detail disembunyikan dulu agar layar tetap ringan. Tap snapshot di atas saat Anda ingin drill-down.',
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final detail = _buildDetailForFocus(report, _selectedFocus);
    final visibleItems = detail.items.take(5).toList(growable: false);

    return AppSurfaceCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _SectionTitle(
                  icon: Icons.insights_outlined,
                  title: detail.title,
                  subtitle: detail.subtitle,
                  tone: AppTheme.darkGray,
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.tonalIcon(
                onPressed: detail.onOpenModule,
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: Text(detail.ctaLabel),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  foregroundColor: AppTheme.darkGray,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (detail.items.isEmpty)
            const AppEmptyState(
              icon: Icons.inbox_outlined,
              title: 'Belum ada data',
              message:
                  'Tidak ada item yang cocok untuk snapshot ini pada rentang laporan yang dipilih.',
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: visibleItems.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = visibleItems[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: item.onTap,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.lightGray),
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
                                    fontSize: 12,
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
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              Formatters.tanggalRelatif(item.timestamp),
                              style: AppTheme.caption.copyWith(fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          if (detail.items.length > visibleItems.length) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: detail.onOpenModule,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: Text(
                'Lihat ${detail.items.length - visibleItems.length} item lainnya',
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<_DashboardAlert> _collectAlerts(LaporanOperationalData report) {
    final alerts = <_DashboardAlert>[];
    final unpaidBills = report.unpaidBills;
    final pendingVerificationBills = report.pendingVerificationBills;
    final pendingDocuments = report.filteredDokumen
        .where((item) => item.isPending)
        .toList(growable: false);
    final actionRequiredSurat = _actionRequiredSurat(report);

    if (unpaidBills.isNotEmpty) {
      alerts.add(
        _DashboardAlert(
          title: '${report.iuranSummary.outstandingBills} IURAN BELUM LUNAS',
          value: Formatters.rupiah(report.iuranSummary.totalTunggakan),
          subtitle:
              '${_countDistinctKk(unpaidBills)} KK masih memiliki tagihan aktif.',
          meta: _timestampMeta(
            unpaidBills
                .map((bill) => bill.dueDate ?? bill.updated ?? bill.created)
                .whereType<DateTime>()
                .toList(growable: false),
          ),
          ctaLabel: 'Proses Iuran',
          status: AlertStatus.error,
          icon: Icons.warning_amber_rounded,
          onTap: () => context.push(
            _routeWithQuery(Routes.iuran, {
              'status': AppConstants.iuranBillUnpaid,
            }),
          ),
        ),
      );
    }

    if (pendingDocuments.isNotEmpty) {
      alerts.add(
        _DashboardAlert(
          title: '${pendingDocuments.length} DOKUMEN PERLU REVIEW',
          subtitle: _topBreakdown(
            pendingDocuments,
            labelOf: (document) => document.jenis,
          ),
          meta: _timestampMeta(
            pendingDocuments
                .map((document) => document.created ?? document.updated)
                .whereType<DateTime>()
                .toList(growable: false),
          ),
          ctaLabel: 'Review Dokumen',
          status: AlertStatus.warning,
          icon: Icons.description_outlined,
          onTap: () => context.push(
            _routeWithQuery(Routes.dokumen, {
              'section': 'verification',
              'status': AppConstants.statusPending,
            }),
          ),
        ),
      );
    }

    if (actionRequiredSurat.isNotEmpty) {
      alerts.add(
        _DashboardAlert(
          title: '${report.suratSummary.actionRequired} SURAT PERLU APPROVAL',
          subtitle: _topBreakdown(
            actionRequiredSurat,
            labelOf: (surat) => AppConstants.suratTypeLabel(surat.jenisSurat),
          ),
          meta: _timestampMeta(
            actionRequiredSurat
                .map(
                  (surat) =>
                      surat.submittedAt ?? surat.updated ?? surat.created,
                )
                .whereType<DateTime>()
                .toList(growable: false),
          ),
          ctaLabel: 'Proses Surat',
          status: AlertStatus.warning,
          icon: Icons.pending_actions_outlined,
          onTap: () => context.push(
            _routeWithQuery(Routes.surat, {
              'status': _SuratActionFilter.actionRequired,
            }),
          ),
        ),
      );
    }

    if (pendingVerificationBills.isNotEmpty) {
      alerts.add(
        _DashboardAlert(
          title: '${pendingVerificationBills.length} BUKTI TRANSFER MENUNGGU',
          subtitle: 'Bukti transfer warga belum divalidasi admin.',
          meta: _timestampMeta(
            report.filteredPendingPayments
                .map((payment) => payment.submittedAt ?? payment.created)
                .whereType<DateTime>()
                .toList(growable: false),
          ),
          ctaLabel: 'Validasi Bukti',
          status: AlertStatus.info,
          icon: Icons.fact_check_outlined,
          onTap: () => context.push(
            _routeWithQuery(Routes.iuran, {
              'status': AppConstants.iuranBillSubmittedVerification,
            }),
          ),
        ),
      );
    }

    return alerts;
  }

  String _routeWithQuery(String path, Map<String, String?> query) {
    final filtered = <String, String>{};
    query.forEach((key, value) {
      if ((value ?? '').trim().isNotEmpty) {
        filtered[key] = value!;
      }
    });
    return Uri(path: path, queryParameters: filtered).toString();
  }

  List<SuratModel> _actionRequiredSurat(LaporanOperationalData report) {
    final normalizedRole = AppConstants.normalizeRole(report.role);
    return report.filteredSurat
        .where((surat) {
          switch (normalizedRole) {
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
        })
        .toList(growable: false);
  }

  int _countDistinctKk(List<IuranBillModel> bills) {
    return bills.map((bill) => bill.kkId).toSet().length;
  }

  String _topBreakdown<T>(
    List<T> items, {
    required String Function(T item) labelOf,
    int take = 2,
  }) {
    if (items.isEmpty) {
      return 'Belum ada item pada kategori ini.';
    }

    final counts = <String, int>{};
    for (final item in items) {
      final label = labelOf(item).trim();
      if (label.isEmpty) {
        continue;
      }
      counts[label] = (counts[label] ?? 0) + 1;
    }

    final sorted = counts.entries.toList(growable: false)
      ..sort((a, b) {
        final countCompare = b.value.compareTo(a.value);
        if (countCompare != 0) {
          return countCompare;
        }
        return a.key.compareTo(b.key);
      });

    return sorted
        .take(take)
        .map((entry) => '${entry.key} (${entry.value})')
        .join(' | ');
  }

  String? _timestampMeta(List<DateTime> timestamps) {
    if (timestamps.isEmpty) {
      return null;
    }
    final sorted = [...timestamps]..sort();
    return 'Tertua ${Formatters.tanggalRelatif(sorted.first)}';
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
          title: 'Detail Warga',
          subtitle: 'Daftar warga dalam scope akses Anda.',
          ctaLabel: 'Buka Modul Warga',
          onOpenModule: () => context.push(Routes.warga),
          items: items
              .map(
                (warga) => _ReportDetailItem(
                  title: warga.namaLengkap,
                  subtitle:
                      'NIK ${warga.nik} • RT ${warga.rt} / RW ${warga.rw}',
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
          title: 'Detail Kartu Keluarga',
          subtitle: 'Daftar KK aktif pada wilayah laporan saat ini.',
          ctaLabel: 'Buka Modul KK',
          onOpenModule: () => context.push(Routes.kartuKeluarga),
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
        return _DetailBlock(
          title: 'Detail Dashboard',
          subtitle: 'Pilih snapshot lain untuk melihat rincian item.',
          ctaLabel: 'Buka Laporan',
          onOpenModule: () => context.push(Routes.laporan),
          items: const [],
        );
    }
  }

  _DetailBlock _buildSuratDetails(LaporanOperationalData report, String focus) {
    final items =
        switch (focus) {
          'surat_submitted' =>
            report.filteredSurat.where((item) => item.isSubmitted).toList(),
          'surat_action' => _actionRequiredSurat(report),
          'surat_revision' =>
            report.filteredSurat.where((item) => item.isNeedRevision).toList(),
          'surat_completed' =>
            report.filteredSurat.where((item) => item.isCompleted).toList(),
          'surat_rejected' =>
            report.filteredSurat.where((item) => item.isRejected).toList(),
          _ => report.filteredSurat,
        }..sort(
          (a, b) => (b.submittedAt ?? b.updated ?? b.created ?? DateTime.now())
              .compareTo(
                a.submittedAt ?? a.updated ?? a.created ?? DateTime.now(),
              ),
        );

    final routeStatus = switch (focus) {
      'surat_submitted' => AppConstants.suratSubmitted,
      'surat_action' => _SuratActionFilter.actionRequired,
      'surat_revision' => AppConstants.suratNeedRevision,
      'surat_completed' => AppConstants.suratCompleted,
      'surat_rejected' => AppConstants.suratRejected,
      _ => null,
    };

    return _DetailBlock(
      title: 'Detail Surat',
      subtitle: 'Item terbaru yang terkait dengan workflow surat pengantar.',
      ctaLabel: 'Buka Modul Surat',
      onOpenModule: () =>
          context.push(_routeWithQuery(Routes.surat, {'status': routeStatus})),
      items: items
          .map(
            (surat) => _ReportDetailItem(
              title: surat.title,
              subtitle:
                  '${report.suratData.wargaById[surat.wargaId]?.namaLengkap ?? 'Warga'} • ${surat.purpose}',
              meta: AppConstants.suratApprovalLabel(surat.approvalLevel),
              statusLabel: AppConstants.suratStatusLabel(surat.status),
              timestamp:
                  surat.submittedAt ??
                  surat.updated ??
                  surat.created ??
                  DateTime.now(),
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

    final routeStatus = switch (focus) {
      'iuran_paid' => 'paid',
      'iuran_pending' => AppConstants.iuranBillSubmittedVerification,
      'iuran_outstanding' => AppConstants.iuranBillUnpaid,
      _ => null,
    };

    return _DetailBlock(
      title: 'Detail Iuran',
      subtitle: 'Tagihan terbaru per KK untuk tindak lanjut pembayaran.',
      ctaLabel: 'Buka Modul Iuran',
      onOpenModule: () =>
          context.push(_routeWithQuery(Routes.iuran, {'status': routeStatus})),
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
                  bill.dueDate ??
                  bill.updated ??
                  bill.created ??
                  DateTime.now(),
              icon: Icons.payments_outlined,
              tone: AppTheme.statusColor(bill.status),
              onTap: () => context.push(
                _routeWithQuery(Routes.iuran, {'status': routeStatus}),
              ),
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
      'dokumen_pending' =>
        report.filteredDokumen.where((item) => item.isPending).toList(),
      'dokumen_revision' =>
        report.filteredDokumen.where((item) => item.isNeedRevision).toList(),
      'dokumen_verified' =>
        report.filteredDokumen.where((item) => item.isVerified).toList(),
      'dokumen_rejected' =>
        report.filteredDokumen.where((item) => item.isRejected).toList(),
      _ => report.filteredDokumen,
    };

    final routeStatus = switch (focus) {
      'dokumen_pending' => AppConstants.statusPending,
      'dokumen_revision' => AppConstants.statusNeedRevision,
      'dokumen_verified' => AppConstants.statusVerified,
      'dokumen_rejected' => AppConstants.statusRejected,
      _ => 'all',
    };

    return _DetailBlock(
      title: 'Detail Dokumen',
      subtitle: 'Antrean dokumen warga sesuai filter yang dipilih.',
      ctaLabel: 'Buka Modul Dokumen',
      onOpenModule: () => context.push(
        _routeWithQuery(Routes.dokumen, {
          'section': 'verification',
          'status': routeStatus,
        }),
      ),
      items: items
          .map(
            (document) => _ReportDetailItem(
              title: document.jenis,
              subtitle:
                  report.dokumenWargaById[document.warga]?.namaLengkap ??
                  'Warga',
              meta: document.catatan,
              statusLabel: _dokumenStatusLabel(document.statusVerifikasi),
              timestamp: document.updated ?? document.created ?? DateTime.now(),
              icon: Icons.folder_open_outlined,
              tone: AppTheme.statusColor(document.statusVerifikasi),
              onTap: () => context.push(
                _routeWithQuery(Routes.dokumen, {
                  'section': 'verification',
                  'status': routeStatus,
                }),
              ),
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
          'Mutasi dirangkum dari surat pindah, kematian, dan perubahan KK.',
      ctaLabel: 'Buka Modul Surat',
      onOpenModule: () => context.push(Routes.surat),
      items: items
          .map(
            (surat) => _ReportDetailItem(
              title: surat.title,
              subtitle:
                  report.suratData.wargaById[surat.wargaId]?.namaLengkap ??
                  'Warga',
              meta: surat.purpose,
              statusLabel: AppConstants.suratStatusLabel(surat.status),
              timestamp:
                  surat.submittedAt ??
                  surat.updated ??
                  surat.created ??
                  DateTime.now(),
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tone,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: tone, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: AppTheme.heading3.copyWith(fontSize: 16, color: tone),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: AppTheme.bodySmall.copyWith(
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _DashboardAlert {
  const _DashboardAlert({
    required this.title,
    required this.subtitle,
    required this.ctaLabel,
    required this.onTap,
    required this.status,
    required this.icon,
    this.value,
    this.meta,
  });

  final String title;
  final String subtitle;
  final String ctaLabel;
  final VoidCallback onTap;
  final AlertStatus status;
  final IconData icon;
  final String? value;
  final String? meta;
}

class _SnapshotMetric {
  const _SnapshotMetric({
    required this.focus,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String focus;
  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class _DetailBlock {
  const _DetailBlock({
    required this.title,
    required this.subtitle,
    required this.ctaLabel,
    required this.onOpenModule,
    required this.items,
  });

  final String title;
  final String subtitle;
  final String ctaLabel;
  final VoidCallback onOpenModule;
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

class _SuratActionFilter {
  static const String actionRequired = 'action_required';
}

// ═══════════════════════════════════════════════════════════════════
// SKELETON LOADER
// ═══════════════════════════════════════════════════════════════════

class _LaporanSkeleton extends StatelessWidget {
  const _LaporanSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        // Context card skeleton
        Container(
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.cardDecorationFor(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const AppSkeleton(width: 42, height: 42, borderRadius: 12),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AppSkeleton(width: 80, height: 12),
                        const SizedBox(height: 6),
                        AppSkeleton(width: MediaQuery.of(context).size.width * 0.6, height: 16),
                        const SizedBox(height: 6),
                        const AppSkeleton(height: 12),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Row(
                children: [
                  AppSkeleton(width: 90, height: 24, borderRadius: 12),
                  SizedBox(width: 8),
                  AppSkeleton(width: 80, height: 24, borderRadius: 12),
                  SizedBox(width: 8),
                  AppSkeleton(width: 120, height: 24, borderRadius: 12),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Preset selector skeleton
        Container(
          padding: const EdgeInsets.all(10),
          decoration: AppTheme.cardDecorationFor(context),
          child: const Row(
            children: [
              AppSkeleton(width: 70, height: 32, borderRadius: 16),
              SizedBox(width: 8),
              AppSkeleton(width: 70, height: 32, borderRadius: 16),
              SizedBox(width: 8),
              AppSkeleton(width: 70, height: 32, borderRadius: 16),
              SizedBox(width: 8),
              AppSkeleton(width: 70, height: 32, borderRadius: 16),
            ],
          ),
        ),
        const SizedBox(height: 18),
        // Alerts section skeleton
        const Row(
          children: [
            AppSkeleton(width: 24, height: 24, borderRadius: 8),
            SizedBox(width: 8),
            AppSkeleton(width: 140, height: 16),
          ],
        ),
        const SizedBox(height: 6),
        const AppSkeleton(width: 280, height: 12),
        const SizedBox(height: 12),
        const SkeletonCard(height: 100),
        const SizedBox(height: 18),
        // Snapshot section skeleton
        const Row(
          children: [
            AppSkeleton(width: 24, height: 24, borderRadius: 8),
            SizedBox(width: 8),
            AppSkeleton(width: 160, height: 16),
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: Row(
            children: List.generate(4, (index) => const Padding(
              padding: EdgeInsets.only(right: 12),
              child: SkeletonMetricCard(),
            )),
          ),
        ),
      ],
    );
  }
}
