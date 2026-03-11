import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/iuran_service.dart';
import '../../../core/services/pocketbase_service.dart';
import '../../../core/utils/error_classifier.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/finance_model.dart';
import '../../../shared/models/iuran_model.dart';
import '../../../shared/widgets/app_surface.dart';
import '../../../shared/widgets/floating_action_pill.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/iuran_providers.dart';

enum _AdminIuranTab { tagihan, verifikasi, periode, jenis }

enum _WargaIuranTab { aktif, riwayat }

class IuranListScreen extends ConsumerStatefulWidget {
  const IuranListScreen({super.key});

  @override
  ConsumerState<IuranListScreen> createState() => _IuranListScreenState();
}

class _IuranListScreenState extends ConsumerState<IuranListScreen> {
  String _query = '';
  _AdminIuranTab _adminTab = _AdminIuranTab.tagihan;
  _WargaIuranTab _wargaTab = _WargaIuranTab.aktif;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final isAdminView = auth.isOperator || auth.isSysadmin;
    final listAsync = ref.watch(iuranListDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Iuran'),
        actions: [
          if (isAdminView)
            IconButton(
              onPressed: () => context.push(Routes.iuranForm),
              icon: const Icon(Icons.tune_rounded),
              tooltip: 'Kelola iuran',
            ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: isAdminView
          ? FloatingActionPill(
              onTap: () async {
                await context.push(Routes.iuranForm);
                if (mounted) {
                  ref.read(iuranRefreshTickProvider.notifier).bump();
                }
              },
              icon: Icons.add_card_rounded,
              label: 'Buat Periode Iuran',
              gradientColors: const [
                AppTheme.primaryDark,
                AppTheme.primaryColor,
              ],
            )
          : null,
      body: AppPageBackground(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: listAsync.when(
          data: (data) => Column(
            children: [
              _buildHero(auth, data),
              const SizedBox(height: 12),
              AppSearchBar(
                hintText: 'Cari tagihan, jenis iuran, KK, atau catatan',
                value: _query,
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 12),
              _buildTabs(isAdminView),
              const SizedBox(height: 14),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async =>
                      ref.read(iuranRefreshTickProvider.notifier).bump(),
                  child: _buildContent(context, auth, data, isAdminView),
                ),
              ),
              if (isAdminView) const SizedBox(height: 72),
            ],
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
                        ref.read(iuranRefreshTickProvider.notifier).bump(),
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

  Widget _buildHero(AuthState auth, IuranListData data) {
    final isWargaView = !auth.isOperator && !auth.isSysadmin;
    final subtitle = isWargaView
        ? 'Pantau tagihan per KK, unggah bukti transfer, dan lihat status verifikasi pembayaran.'
        : 'Kelola jenis iuran, periode, tagihan per KK, dan verifikasi pembayaran sesuai wilayah akses Anda.';

    return AppHeroPanel(
      eyebrow: AppConstants.roleLabel(auth.role),
      icon: Icons.payments_outlined,
      title: isWargaView
          ? 'Tagihan iuran keluarga Anda'
          : 'Operasional iuran warga per KK',
      subtitle: subtitle,
      chips: [
        _heroChip(
          Icons.receipt_long_rounded,
          'Tagihan ${data.summary.totalBills}',
        ),
        _heroChip(
          Icons.check_circle_outline_rounded,
          'Lunas ${data.summary.paidBills}',
        ),
        _heroChip(
          Icons.warning_amber_rounded,
          'Tunggakan ${Formatters.rupiah(data.summary.totalTunggakan)}',
        ),
      ],
    );
  }

  Widget _buildTabs(bool isAdminView) {
    if (isAdminView) {
      return SegmentedButton<_AdminIuranTab>(
        segments: const [
          ButtonSegment(
            value: _AdminIuranTab.tagihan,
            label: Text('Tagihan'),
            icon: Icon(Icons.receipt_long_rounded),
          ),
          ButtonSegment(
            value: _AdminIuranTab.verifikasi,
            label: Text('Verifikasi'),
            icon: Icon(Icons.verified_outlined),
          ),
          ButtonSegment(
            value: _AdminIuranTab.periode,
            label: Text('Periode'),
            icon: Icon(Icons.calendar_month_rounded),
          ),
          ButtonSegment(
            value: _AdminIuranTab.jenis,
            label: Text('Jenis'),
            icon: Icon(Icons.category_outlined),
          ),
        ],
        selected: {_adminTab},
        onSelectionChanged: (selection) =>
            setState(() => _adminTab = selection.first),
      );
    }

    return SegmentedButton<_WargaIuranTab>(
      segments: const [
        ButtonSegment(
          value: _WargaIuranTab.aktif,
          label: Text('Aktif'),
          icon: Icon(Icons.pending_actions_rounded),
        ),
        ButtonSegment(
          value: _WargaIuranTab.riwayat,
          label: Text('Riwayat'),
          icon: Icon(Icons.history_rounded),
        ),
      ],
      selected: {_wargaTab},
      onSelectionChanged: (selection) =>
          setState(() => _wargaTab = selection.first),
    );
  }

  Widget _buildContent(
    BuildContext context,
    AuthState auth,
    IuranListData data,
    bool isAdminView,
  ) {
    if (isAdminView) {
      switch (_adminTab) {
        case _AdminIuranTab.tagihan:
          return _buildAdminBills(data);
        case _AdminIuranTab.verifikasi:
          return _buildAdminVerification(data);
        case _AdminIuranTab.periode:
          return _buildPeriods(data);
        case _AdminIuranTab.jenis:
          return _buildTypes(data);
      }
    }

    return _buildWargaBills(auth, data);
  }

  Widget _buildAdminBills(IuranListData data) {
    final bills = _filterBills(
      data.bills,
      includePaidOnly: false,
      excludePaidOnly: false,
    );
    if (bills.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 80),
          AppEmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'Belum ada tagihan iuran',
            message:
                'Buat periode iuran terlebih dahulu untuk menghasilkan tagihan per KK.',
          ),
        ],
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: bills.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final bill = bills[index];
        final latestPayment = data.paymentsByBill[bill.id]?.isNotEmpty == true
            ? data.paymentsByBill[bill.id]!.first
            : null;
        final financeTransaction = data.financeTransactionForBill(bill.id);
        return _buildBillCard(
          bill,
          data.periodsById[bill.periodId],
          latestPayment,
          financeTransaction: financeTransaction,
          isAdmin: true,
          onPrimaryAction: bill.isSubmittedVerification
              ? () => setState(() => _adminTab = _AdminIuranTab.verifikasi)
              : () => _recordCash(bill),
          onFinanceAction:
              financeTransaction != null &&
                  bill.isPaid &&
                  !financeTransaction.isPublished
              ? () => _publishFinance(bill)
              : null,
          primaryActionLabel: bill.isSubmittedVerification
              ? 'Lihat Verifikasi'
              : 'Catat Cash',
          financeActionLabel: financeTransaction?.isPublished == true
              ? 'Sudah Dipublish'
              : 'Publish Kas',
        );
      },
    );
  }

  Widget _buildAdminVerification(IuranListData data) {
    final payments = _filterPendingPayments(data.pendingPayments, data);
    if (payments.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 80),
          AppEmptyState(
            icon: Icons.verified_user_outlined,
            title: 'Tidak ada pembayaran menunggu verifikasi',
            message:
                'Bukti transfer baru akan muncul di sini saat warga mengunggah pembayaran.',
          ),
        ],
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: payments.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final payment = payments[index];
        final bill = data.bills.firstWhere((item) => item.id == payment.billId);
        return _buildPendingPaymentCard(bill, payment);
      },
    );
  }

  Widget _buildPeriods(IuranListData data) {
    final periods = _filterPeriods(data.periods);
    if (periods.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 80),
          AppEmptyState(
            icon: Icons.calendar_month_outlined,
            title: 'Belum ada periode iuran',
            message:
                'Gunakan tombol kanan bawah untuk membuat periode dan generate tagihan.',
          ),
        ],
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: periods.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final period = periods[index];
        final bills = data.bills
            .where((item) => item.periodId == period.id)
            .toList();
        return _buildPeriodCard(period, bills);
      },
    );
  }

  Widget _buildTypes(IuranListData data) {
    final types = _filterTypes(data.types);
    if (types.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 80),
          AppEmptyState(
            icon: Icons.category_outlined,
            title: 'Belum ada jenis iuran',
            message:
                'Tambahkan jenis iuran seperti kebersihan, keamanan, atau kas sosial.',
          ),
        ],
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: types.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _buildTypeCard(types[index]),
    );
  }

  Widget _buildWargaBills(AuthState auth, IuranListData data) {
    final bills = _filterBills(
      data.bills,
      includePaidOnly: _wargaTab == _WargaIuranTab.riwayat,
      excludePaidOnly: _wargaTab == _WargaIuranTab.aktif,
    );
    if (bills.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          AppEmptyState(
            icon: Icons.payments_outlined,
            title: _wargaTab == _WargaIuranTab.aktif
                ? 'Tidak ada tagihan aktif'
                : 'Belum ada riwayat pembayaran',
            message: _wargaTab == _WargaIuranTab.aktif
                ? 'Tagihan iuran per KK akan muncul di sini setelah admin menerbitkan periode baru.'
                : 'Riwayat pembayaran yang sudah lunas akan tampil di sini.',
          ),
        ],
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: bills.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final bill = bills[index];
        final latestPayment = data.paymentsByBill[bill.id]?.isNotEmpty == true
            ? data.paymentsByBill[bill.id]!.first
            : null;
        final hasPendingTransfer = latestPayment?.isSubmitted == true;
        final hasRejectedPayment = latestPayment?.isRejected == true;
        final isPaid = latestPayment?.isVerified == true || bill.isPaid;
        return _buildBillCard(
          bill,
          data.periodsById[bill.periodId],
          latestPayment,
          financeTransaction: data.financeTransactionForBill(bill.id),
          isAdmin: false,
          onPrimaryAction: isPaid || hasPendingTransfer
              ? null
              : () => _uploadTransfer(auth, bill),
          onFinanceAction: null,
          primaryActionLabel: isPaid
              ? 'Lunas'
              : hasPendingTransfer || bill.isSubmittedVerification
              ? 'Menunggu Verifikasi'
              : hasRejectedPayment || bill.isRejectedPayment
              ? 'Upload Ulang Bukti Transfer'
              : 'Upload Bukti Transfer',
          financeActionLabel: '',
        );
      },
    );
  }

  List<IuranBillModel> _filterBills(
    List<IuranBillModel> bills, {
    required bool includePaidOnly,
    required bool excludePaidOnly,
  }) {
    final query = _query.trim().toLowerCase();
    return bills.where((bill) {
      if (includePaidOnly && !bill.isPaid) {
        return false;
      }
      if (excludePaidOnly && bill.isPaid) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      final haystack = [
        bill.title,
        bill.typeLabel,
        bill.kkNumber,
        bill.kkHolderName ?? '',
        bill.billNumber,
        AppConstants.iuranBillStatusLabel(bill.status),
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  List<IuranPaymentModel> _filterPendingPayments(
    List<IuranPaymentModel> payments,
    IuranListData data,
  ) {
    final query = _query.trim().toLowerCase();
    return payments.where((payment) {
      if (query.isEmpty) {
        return true;
      }
      final bill = data.bills.firstWhere((item) => item.id == payment.billId);
      final haystack = [
        bill.title,
        bill.kkNumber,
        bill.kkHolderName ?? '',
        payment.note ?? '',
        AppConstants.iuranMethodLabel(payment.method),
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  List<IuranPeriodModel> _filterPeriods(List<IuranPeriodModel> periods) {
    final query = _query.trim().toLowerCase();
    return periods.where((period) {
      if (query.isEmpty) {
        return true;
      }
      final haystack = [
        period.title,
        period.typeLabel,
        AppConstants.iuranFrequencyLabel(period.frequency),
        AppConstants.iuranPeriodStatusLabel(period.status),
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  List<IuranTypeModel> _filterTypes(List<IuranTypeModel> types) {
    final query = _query.trim().toLowerCase();
    return types.where((type) {
      if (query.isEmpty) {
        return true;
      }
      final haystack = [
        type.label,
        type.code,
        type.description ?? '',
        AppConstants.iuranFrequencyLabel(type.defaultFrequency),
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  Widget _buildBillCard(
    IuranBillModel bill,
    IuranPeriodModel? period,
    IuranPaymentModel? latestPayment, {
    FinanceTransactionModel? financeTransaction,
    required bool isAdmin,
    required VoidCallback? onPrimaryAction,
    required VoidCallback? onFinanceAction,
    required String primaryActionLabel,
    required String financeActionLabel,
  }) {
    final statusColor = AppTheme.statusColor(bill.status);
    final financePublishLabel = financeTransaction == null
        ? null
        : financeTransaction.isPublished
        ? 'Ledger dipublish'
        : 'Ledger pending publish';
    final paymentInfo = latestPayment == null
        ? null
        : '${AppConstants.iuranMethodLabel(latestPayment.method)} • ${AppConstants.iuranPaymentStatusLabel(latestPayment.status)}';

    return AppSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bill.title,
                      style: AppTheme.heading3.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${bill.typeLabel} • ${bill.kkHolderName?.trim().isNotEmpty == true ? bill.kkHolderName : bill.kkNumber}',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                Formatters.tanggalRelatif(
                  bill.updated ?? bill.created ?? DateTime.now(),
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
                AppConstants.iuranBillStatusLabel(bill.status),
                statusColor.withValues(alpha: 0.12),
                statusColor,
              ),
              if ((period?.frequency ?? bill.frequency ?? '').isNotEmpty)
                _metaChip(
                  AppConstants.iuranFrequencyLabel(
                    period?.frequency ?? bill.frequency ?? '',
                  ),
                  AppTheme.primaryColor.withValues(alpha: 0.10),
                  AppTheme.primaryColor,
                ),
              if ((paymentInfo ?? '').isNotEmpty)
                _metaChip(
                  paymentInfo!,
                  const Color(0xFFF1F3F2),
                  AppTheme.textSecondary,
                ),
              if ((financePublishLabel ?? '').isNotEmpty)
                _metaChip(
                  financePublishLabel!,
                  financeTransaction?.isPublished == true
                      ? AppTheme.successColor.withValues(alpha: 0.12)
                      : AppTheme.accentColor.withValues(alpha: 0.12),
                  financeTransaction?.isPublished == true
                      ? AppTheme.successColor
                      : AppTheme.accentColor,
                ),
            ],
          ),
          const SizedBox(height: 12),
          _infoRow('Tagihan', Formatters.rupiah(bill.amount)),
          _infoRow(
            'Jatuh tempo',
            bill.dueDate == null
                ? '-'
                : Formatters.tanggalPendek(bill.dueDate!),
          ),
          _infoRow('No. KK', bill.kkNumber),
          _infoRow(
            'Kepala KK',
            bill.kkHolderName?.trim().isNotEmpty == true
                ? bill.kkHolderName!
                : '-',
          ),
          if ((period?.title ?? '').isNotEmpty)
            _infoRow('Periode', period!.title),
          if ((bill.rejectionNote ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.errorColor.withValues(alpha: 0.16),
                  ),
                ),
                child: Text(
                  bill.rejectionNote!,
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.errorColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          if (latestPayment != null &&
              !latestPayment.isRejected &&
              !bill.isPaid) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.16),
                ),
              ),
              child: Text(
                latestPayment.isSubmitted
                    ? 'Bukti transfer sudah dikirim dan sedang menunggu verifikasi admin.'
                    : 'Pembayaran tercatat dan riwayat transfer terbaru sudah tersimpan.',
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.primaryDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: onPrimaryAction,
                  child: Text(primaryActionLabel),
                ),
              ),
              if (isAdmin && financeTransaction != null) ...[
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: financeTransaction.isPublished
                      ? null
                      : onFinanceAction,
                  child: Text(financeActionLabel),
                ),
              ],
              if (isAdmin && latestPayment != null) ...[
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: () => _openProof(latestPayment),
                  child: const Text('Bukti'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPendingPaymentCard(
    IuranBillModel bill,
    IuranPaymentModel payment,
  ) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.verified_outlined,
                  color: AppTheme.accentColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bill.title,
                      style: AppTheme.heading3.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${bill.kkHolderName?.trim().isNotEmpty == true ? bill.kkHolderName : bill.kkNumber} • ${AppConstants.iuranMethodLabel(payment.method)}',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                Formatters.tanggalRelatif(
                  payment.submittedAt ?? payment.created ?? DateTime.now(),
                ),
                style: AppTheme.caption,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _infoRow('Tagihan', Formatters.rupiah(payment.amount)),
          _infoRow('No. KK', bill.kkNumber),
          if ((payment.note ?? '').isNotEmpty)
            _infoRow('Catatan warga', payment.note!),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: payment.proofFile == null
                      ? null
                      : () => _openProof(payment),
                  icon: const Icon(Icons.attach_file_rounded),
                  label: const Text('Buka Bukti'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () => _reviewPayment(payment, approve: true),
                  child: const Text('Verifikasi'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _reviewPayment(payment, approve: false),
              child: const Text('Tolak Pembayaran'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodCard(IuranPeriodModel period, List<IuranBillModel> bills) {
    final total = bills.fold<int>(0, (sum, item) => sum + item.amount);
    final paid = bills
        .where((item) => item.isPaid)
        .fold<int>(0, (sum, item) => sum + item.amount);
    return AppSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      period.title,
                      style: AppTheme.heading3.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${period.typeLabel} • ${AppConstants.iuranFrequencyLabel(period.frequency)}',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _metaChip(
                AppConstants.iuranPeriodStatusLabel(period.status),
                AppTheme.statusColor(period.status).withValues(alpha: 0.12),
                AppTheme.statusColor(period.status),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _infoRow('Target KK', '${bills.length} KK'),
          _infoRow('Nominal default', Formatters.rupiah(period.defaultAmount)),
          _infoRow(
            'Jatuh tempo',
            period.dueDate == null
                ? '-'
                : Formatters.tanggalPendek(period.dueDate!),
          ),
          _infoRow('Total tagihan', Formatters.rupiah(total)),
          _infoRow('Sudah lunas', Formatters.rupiah(paid)),
        ],
      ),
    );
  }

  Widget _buildTypeCard(IuranTypeModel type) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type.label,
                      style: AppTheme.heading3.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      type.description?.trim().isNotEmpty == true
                          ? type.description!
                          : 'Jenis iuran siap dipakai untuk generate tagihan.',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _metaChip(
                type.isActive ? 'Aktif' : 'Nonaktif',
                (type.isActive ? AppTheme.successColor : AppTheme.textSecondary)
                    .withValues(alpha: 0.12),
                type.isActive ? AppTheme.successColor : AppTheme.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _infoRow('Kode', type.code),
          _infoRow(
            'Frekuensi default',
            AppConstants.iuranFrequencyLabel(type.defaultFrequency),
          ),
          _infoRow('Nominal default', Formatters.rupiah(type.defaultAmount)),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
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

  Widget _heroChip(IconData icon, String label) {
    return AppHeroBadge(
      label: label,
      icon: icon,
      foregroundColor: Colors.white,
      backgroundColor: Colors.white.withValues(alpha: 0.16),
    );
  }

  Future<void> _uploadTransfer(AuthState auth, IuranBillModel bill) async {
    final noteController = TextEditingController();
    PlatformFile? pickedFile;
    var isSubmitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (modalContext) => StatefulBuilder(
        builder: (modalContext, setModalState) {
          Future<void> pickFile() async {
            final result = await FilePicker.platform.pickFiles(
              withData: true,
              type: FileType.custom,
              allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
            );
            if (result == null || result.files.isEmpty) {
              return;
            }
            setModalState(() => pickedFile = result.files.single);
          }

          Future<void> submit() async {
            if (pickedFile == null) {
              ErrorClassifier.showErrorSnackBar(
                context,
                Exception('Pilih file bukti transfer terlebih dahulu.'),
              );
              return;
            }
            setModalState(() => isSubmitting = true);
            try {
              await ref
                  .read(iuranServiceProvider)
                  .submitTransfer(
                    auth,
                    IuranTransferSubmitPayload(
                      billId: bill.id,
                      proofFile: pickedFile!,
                      note: noteController.text.trim(),
                    ),
                  );
              if (!mounted || !modalContext.mounted) return;
              ref.read(iuranRefreshTickProvider.notifier).bump();
              ref.invalidate(iuranListDataProvider);
              Navigator.of(modalContext).pop();
              ErrorClassifier.showSuccessSnackBar(
                context,
                'Bukti transfer berhasil dikirim dan sedang menunggu verifikasi admin.',
              );
            } catch (error) {
              if (mounted) {
                ErrorClassifier.showErrorSnackBar(context, error);
              }
            } finally {
              if (mounted) {
                setModalState(() => isSubmitting = false);
              }
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: MediaQuery.of(modalContext).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Upload Bukti Transfer', style: AppTheme.heading3),
                const SizedBox(height: 6),
                Text(
                  'Tagihan ${Formatters.rupiah(bill.amount)} untuk ${bill.title}.',
                  style: AppTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: isSubmitting ? null : pickFile,
                  icon: const Icon(Icons.attach_file_rounded),
                  label: Text(
                    pickedFile == null ? 'Pilih File Bukti' : pickedFile!.name,
                  ),
                ),
                if (pickedFile != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    Formatters.fileSize(pickedFile!.size),
                    style: AppTheme.caption,
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  enabled: !isSubmitting,
                  decoration: const InputDecoration(
                    labelText: 'Catatan Pembayaran',
                    hintText: 'Opsional, misalnya nama rekening pengirim',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: isSubmitting ? null : submit,
                    child: isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Kirim Bukti Transfer'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _recordCash(IuranBillModel bill) async {
    final noteController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Catat Pembayaran Cash'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Tandai tagihan ${Formatters.rupiah(bill.amount)} sebagai pembayaran cash?',
              style: AppTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: 'Catatan admin',
                hintText: 'Opsional, misalnya dibayar langsung ke pengurus',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Catat Cash'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref
          .read(iuranServiceProvider)
          .recordCashPayment(
            ref.read(authProvider),
            bill.id,
            note: noteController.text.trim(),
          );
      ref.read(iuranRefreshTickProvider.notifier).bump();
      if (mounted) {
        ErrorClassifier.showSuccessSnackBar(
          context,
          'Pembayaran cash berhasil dicatat.',
        );
      }
    } catch (error) {
      if (mounted) {
        ErrorClassifier.showErrorSnackBar(context, error);
      }
    }
  }

  Future<void> _reviewPayment(
    IuranPaymentModel payment, {
    required bool approve,
  }) async {
    final noteController = TextEditingController();
    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(approve ? 'Verifikasi Pembayaran' : 'Tolak Pembayaran'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              approve
                  ? 'Tambahkan catatan verifikasi jika diperlukan.'
                  : 'Jelaskan alasan penolakan agar warga bisa unggah ulang bukti yang benar.',
              style: AppTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: InputDecoration(
                labelText: approve ? 'Catatan verifikasi' : 'Alasan penolakan',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(approve ? 'Verifikasi' : 'Tolak'),
          ),
        ],
      ),
    );

    if (proceed != true) return;

    try {
      final auth = ref.read(authProvider);
      if (approve) {
        await ref
            .read(iuranServiceProvider)
            .verifyPayment(
              auth,
              IuranPaymentReviewPayload(
                paymentId: payment.id,
                note: noteController.text.trim(),
              ),
            );
      } else {
        await ref
            .read(iuranServiceProvider)
            .rejectPayment(
              auth,
              IuranPaymentReviewPayload(
                paymentId: payment.id,
                note: noteController.text.trim(),
              ),
            );
      }
      ref.read(iuranRefreshTickProvider.notifier).bump();
      if (mounted) {
        ErrorClassifier.showSuccessSnackBar(
          context,
          approve
              ? 'Pembayaran berhasil diverifikasi.'
              : 'Pembayaran berhasil ditolak.',
        );
      }
    } catch (error) {
      if (mounted) {
        ErrorClassifier.showErrorSnackBar(context, error);
      }
    }
  }

  Future<void> _publishFinance(IuranBillModel bill) async {
    final titleController = TextEditingController(
      text: 'Transparansi kas ${bill.typeLabel}',
    );
    final contentController = TextEditingController(
      text:
          'Pembayaran iuran ${bill.title} dari ${bill.kkHolderName?.trim().isNotEmpty == true ? bill.kkHolderName : bill.kkNumber} sudah diverifikasi dan masuk ke kas sesuai yuridiksi.',
    );

    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Publish Pengumuman Kas'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Judul Pengumuman'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: contentController,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Isi Pengumuman'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Publish'),
          ),
        ],
      ),
    );

    if (proceed != true) {
      return;
    }

    try {
      await ref
          .read(iuranServiceProvider)
          .publishFinanceForBill(
            ref.read(authProvider),
            bill.id,
            announcementTitle: titleController.text.trim(),
            announcementContent: contentController.text.trim(),
          );
      ref.read(iuranRefreshTickProvider.notifier).bump();
      if (mounted) {
        ErrorClassifier.showSuccessSnackBar(
          context,
          'Pengumuman kas dari iuran berhasil dipublish.',
        );
      }
    } catch (error) {
      if (mounted) {
        ErrorClassifier.showErrorSnackBar(context, error);
      }
    }
  }

  Future<void> _openProof(IuranPaymentModel payment) async {
    final fileName = payment.proofFile;
    if (fileName == null || fileName.isEmpty) return;
    final uri = Uri.parse(pb.files.getUrl(payment.record, fileName).toString());
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ErrorClassifier.showErrorSnackBar(
        context,
        Exception('File bukti tidak dapat dibuka.'),
      );
    }
  }
}
