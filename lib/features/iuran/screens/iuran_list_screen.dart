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
import '../../../shared/widgets/app_skeleton.dart';
import '../../../shared/widgets/app_surface.dart';
import '../../../shared/widgets/current_user_avatar.dart';
import '../../../shared/widgets/floating_action_pill.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/iuran_providers.dart';

enum _AdminIuranSection { operasional, master, publikasi }

enum _AdminOperasionalTab { tagihan, verifikasi, lunas }

enum _AdminMasterTab { periode, jenis }

enum _AdminPublikasiTab { publishDataIuran, kasPendingPublish }

enum _WargaIuranTab { aktif, riwayat }

class _IuranPeriodPublicationStats {
  const _IuranPeriodPublicationStats({
    required this.totalTarget,
    required this.paidCount,
    required this.unpaidCount,
    required this.totalCollected,
    required this.completionPercent,
  });

  final int totalTarget;
  final int paidCount;
  final int unpaidCount;
  final int totalCollected;
  final int completionPercent;
}

class IuranListScreen extends ConsumerStatefulWidget {
  const IuranListScreen({super.key, this.initialStatus});

  final String? initialStatus;

  @override
  ConsumerState<IuranListScreen> createState() => _IuranListScreenState();
}

class _IuranListScreenState extends ConsumerState<IuranListScreen> {
  static const String _billStatusAll = 'all';
  static const String _billStatusPaid = 'paid';

  String _query = '';
  _AdminIuranSection _adminSection = _AdminIuranSection.operasional;
  _AdminOperasionalTab _operasionalTab = _AdminOperasionalTab.tagihan;
  _AdminMasterTab _masterTab = _AdminMasterTab.periode;
  _AdminPublikasiTab _publikasiTab = _AdminPublikasiTab.publishDataIuran;
  _WargaIuranTab _wargaTab = _WargaIuranTab.aktif;
  String _adminBillStatusFilter = _billStatusAll;
  bool _isPublishingSummaryBatch = false;
  bool _isPublishingFinanceBatch = false;
  final Set<String> _publishedSummaryPeriodIds = <String>{};

  @override
  void initState() {
    super.initState();
    final requestedStatus = (widget.initialStatus ?? '').trim();
    switch (requestedStatus) {
      case AppConstants.iuranBillSubmittedVerification:
        _adminSection = _AdminIuranSection.operasional;
        _operasionalTab = _AdminOperasionalTab.verifikasi;
        _adminBillStatusFilter = _billStatusAll;
        break;
      case AppConstants.iuranBillUnpaid:
        _adminSection = _AdminIuranSection.operasional;
        _operasionalTab = _AdminOperasionalTab.tagihan;
        _adminBillStatusFilter = AppConstants.iuranBillUnpaid;
        break;
      case _billStatusPaid:
        _adminSection = _AdminIuranSection.operasional;
        _operasionalTab = _AdminOperasionalTab.lunas;
        _adminBillStatusFilter = _billStatusPaid;
        _wargaTab = _WargaIuranTab.riwayat;
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final accessAsync = ref.watch(iuranAccessProvider);
    final listAsync = ref.watch(iuranListDataProvider);

    return accessAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Iuran')),
        body: AppPageBackground(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: const _IuranListSkeleton(),
        ),
      ),
      error: (error, stackTrace) => _buildScaffold(
        auth: auth,
        canManageSetup: false,
        isAdminView: false,
        body: listAsync.when(
          data: (data) => _buildBody(
            auth: auth,
            data: data,
            isAdminView: false,
            canReviewPayments: false,
            canPublishIuranData: false,
            canPublishFinance: false,
            showOperatorFallbackNotice: auth.isOperator,
          ),
          loading: () => const _IuranListSkeleton(),
          error: (error, _) => _buildErrorState(error),
        ),
      ),
      data: (access) => _buildScaffold(
        auth: auth,
        canManageSetup: access.canManageSetup,
        isAdminView: access.canOpenAdminView,
        body: listAsync.when(
          data: (data) => _buildBody(
            auth: auth,
            data: data,
            isAdminView: access.canOpenAdminView,
            canReviewPayments: access.canReviewPayments,
            canPublishIuranData: access.canPublishIuranData,
            canPublishFinance: access.canPublishFinance,
            showOperatorFallbackNotice: access.showOperatorFallbackNotice,
          ),
          loading: () => const _IuranListSkeleton(),
          error: (error, _) => _buildErrorState(error),
        ),
      ),
    );
  }

  Widget _buildScaffold({
    required AuthState auth,
    required bool canManageSetup,
    required bool isAdminView,
    required Widget body,
  }) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Iuran'),
        actions: [
          if (canManageSetup)
            IconButton(
              onPressed: () => context.push(Routes.iuranForm),
              icon: const Icon(Icons.tune_rounded),
              tooltip: 'Kelola iuran',
            ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton:
          canManageSetup &&
              isAdminView &&
              _adminSection == _AdminIuranSection.master
          ? FloatingActionPill(
              onTap: () async {
                await context.push(Routes.iuranForm);
                if (mounted) {
                  ref.read(iuranRefreshTickProvider.notifier).bump();
                }
              },
              icon: Icons.add_card_rounded,
              label: _masterTab == _AdminMasterTab.periode
                  ? 'Buat Periode Iuran'
                  : 'Kelola Master Iuran',
              gradientColors: const [
                AppTheme.primaryDark,
                AppTheme.primaryColor,
              ],
            )
          : null,
      body: AppPageBackground(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: body,
      ),
    );
  }

  Widget _buildBody({
    required AuthState auth,
    required IuranListData data,
    required bool isAdminView,
    required bool canReviewPayments,
    required bool canPublishIuranData,
    required bool canPublishFinance,
    required bool showOperatorFallbackNotice,
  }) {
    return Column(
      children: [
        _buildHero(auth, data, isAdminView: isAdminView),
        if (showOperatorFallbackNotice) ...[
          const SizedBox(height: 6),
          _buildOperatorFallbackNotice(),
        ],
        const SizedBox(height: 6),
        AppSearchBar(
          hintText: 'Cari tagihan, jenis iuran, KK, atau catatan',
          value: _query,
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: 6),
        _buildTabs(
          isAdminView,
          canPublishIuranData: canPublishIuranData,
          canPublishFinance: canPublishFinance,
        ),
        if (isAdminView) ...[
          const SizedBox(height: 6),
          _buildAdminContextNote(),
        ],
        const SizedBox(height: 8),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async =>
                ref.read(iuranRefreshTickProvider.notifier).bump(),
            child: _buildContent(
              context,
              auth,
              data,
              isAdminView,
              canReviewPayments: canReviewPayments,
              canPublishIuranData: canPublishIuranData,
              canPublishFinance: canPublishFinance,
            ),
          ),
        ),
        if (isAdminView) const SizedBox(height: 72),
      ],
    );
  }

  Widget _buildErrorState(Object error) {
    return Center(
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
    );
  }

  Widget _buildHero(
    AuthState auth,
    IuranListData data, {
    required bool isAdminView,
  }) {
    final isWargaView = !auth.isOperator && !auth.isSysadmin;
    final effectiveWargaView = isWargaView || !isAdminView;
    final subtitle = effectiveWargaView
        ? 'Pantau tagihan, unggah bukti transfer, dan cek status verifikasi pembayaran keluarga Anda.'
        : 'Kelola tagihan, review verifikasi, dan publish rekap iuran sesuai wilayah akses Anda.';
    final title = effectiveWargaView
        ? 'Tagihan iuran keluarga Anda'
        : 'Operasional iuran warga per KK';

    return AppSurfaceCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeroIdentity(AppConstants.roleLabel(auth.role)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.primaryColor.withValues(alpha: 0.12),
                                AppTheme.accentColor.withValues(alpha: 0.06),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.payments_outlined,
                            color: AppTheme.primaryColor,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            title,
                            style: AppTheme.bodyMedium.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primaryTextFor(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: AppTheme.caption.copyWith(
                        color: AppTheme.tertiaryTextFor(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _heroChip(
                Icons.receipt_long_rounded,
                'Tagihan ${data.summary.outstandingBills}',
              ),
              _heroChip(
                Icons.verified_outlined,
                'Verifikasi ${data.summary.pendingVerificationBills}',
              ),
              _heroChip(
                Icons.check_circle_outline_rounded,
                'Lunas ${data.summary.paidBills}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroIdentity(String roleLabel) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CurrentUserAvatar(size: 38, showRing: true, ringWidth: 1.5),
        const SizedBox(height: 6),
        Container(
          constraints: const BoxConstraints(maxWidth: 88),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            roleLabel,
            style: AppTheme.caption.copyWith(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildOperatorFallbackNotice() {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.warningColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.lock_clock_rounded,
              color: AppTheme.warningColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mode warga aktif',
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Subscription atau hak operasional iuran belum aktif. Anda tetap bisa membayar iuran sendiri, tetapi verifikasi harus dilakukan pengurus lain atau RW.',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs(
    bool isAdminView, {
    required bool canPublishIuranData,
    required bool canPublishFinance,
  }) {
    if (isAdminView) {
      return Column(
        children: [
          SegmentedButton<_AdminIuranSection>(
            segments: const [
              ButtonSegment(
                value: _AdminIuranSection.operasional,
                label: Text('Operasional'),
                icon: Icon(Icons.dashboard_customize_outlined),
              ),
              ButtonSegment(
                value: _AdminIuranSection.master,
                label: Text('Master'),
                icon: Icon(Icons.inventory_2_outlined),
              ),
              ButtonSegment(
                value: _AdminIuranSection.publikasi,
                label: Text('Publikasi'),
                icon: Icon(Icons.campaign_outlined),
              ),
            ],
            selected: {_adminSection},
            onSelectionChanged: (selection) {
              setState(() => _adminSection = selection.first);
            },
          ),
          const SizedBox(height: 8),
          _buildAdminSubTabs(
            canPublishIuranData: canPublishIuranData,
            canPublishFinance: canPublishFinance,
          ),
        ],
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

  Widget _buildAdminSubTabs({
    required bool canPublishIuranData,
    required bool canPublishFinance,
  }) {
    switch (_adminSection) {
      case _AdminIuranSection.operasional:
        return SegmentedButton<_AdminOperasionalTab>(
          segments: const [
            ButtonSegment(
              value: _AdminOperasionalTab.tagihan,
              label: Text('Tagihan'),
              icon: Icon(Icons.receipt_long_rounded),
            ),
            ButtonSegment(
              value: _AdminOperasionalTab.verifikasi,
              label: Text('Verifikasi'),
              icon: Icon(Icons.verified_outlined),
            ),
            ButtonSegment(
              value: _AdminOperasionalTab.lunas,
              label: Text('Lunas'),
              icon: Icon(Icons.paid_outlined),
            ),
          ],
          selected: {_operasionalTab},
          onSelectionChanged: (selection) {
            setState(() => _operasionalTab = selection.first);
          },
        );
      case _AdminIuranSection.master:
        return SegmentedButton<_AdminMasterTab>(
          segments: const [
            ButtonSegment(
              value: _AdminMasterTab.periode,
              label: Text('Periode'),
              icon: Icon(Icons.calendar_month_rounded),
            ),
            ButtonSegment(
              value: _AdminMasterTab.jenis,
              label: Text('Jenis'),
              icon: Icon(Icons.category_outlined),
            ),
          ],
          selected: {_masterTab},
          onSelectionChanged: (selection) {
            setState(() => _masterTab = selection.first);
          },
        );
      case _AdminIuranSection.publikasi:
        return SegmentedButton<_AdminPublikasiTab>(
          segments: [
            ButtonSegment(
              value: _AdminPublikasiTab.publishDataIuran,
              label: Text(
                canPublishIuranData ? 'Publish Data Iuran' : 'Rekap Iuran',
              ),
              icon: const Icon(Icons.summarize_outlined),
            ),
            ButtonSegment(
              value: _AdminPublikasiTab.kasPendingPublish,
              label: Text(
                canPublishFinance ? 'Kas Pending Publish' : 'Kas Iuran',
              ),
              icon: const Icon(Icons.account_balance_wallet_outlined),
            ),
          ],
          selected: {_publikasiTab},
          onSelectionChanged: (selection) {
            setState(() => _publikasiTab = selection.first);
          },
        );
    }
  }

  Widget _buildContent(
    BuildContext context,
    AuthState auth,
    IuranListData data,
    bool isAdminView, {
    required bool canReviewPayments,
    required bool canPublishIuranData,
    required bool canPublishFinance,
  }) {
    if (isAdminView) {
      switch (_adminSection) {
        case _AdminIuranSection.operasional:
          switch (_operasionalTab) {
            case _AdminOperasionalTab.tagihan:
              return _buildAdminBills(
                data,
                canPublishFinance: canPublishFinance,
                excludePaidOnly: true,
                emptyTitle: 'Belum ada tagihan aktif',
                emptyMessage:
                    'Tagihan yang belum lunas atau masih menunggu tindak lanjut akan tampil di sini.',
              );
            case _AdminOperasionalTab.lunas:
              return _buildAdminBills(
                data,
                canPublishFinance: canPublishFinance,
                includePaidOnly: true,
                emptyTitle: 'Belum ada tagihan lunas',
                emptyMessage:
                    'Tagihan yang sudah lunas dan siap ditelusuri ke ledger kas akan tampil di sini.',
              );
            case _AdminOperasionalTab.verifikasi:
              return _buildAdminVerification(data, auth, canReviewPayments);
          }
        case _AdminIuranSection.master:
          switch (_masterTab) {
            case _AdminMasterTab.periode:
              return _buildPeriods(data);
            case _AdminMasterTab.jenis:
              return _buildTypes(data);
          }
        case _AdminIuranSection.publikasi:
          switch (_publikasiTab) {
            case _AdminPublikasiTab.publishDataIuran:
              return _buildPublishIuranData(
                data,
                canPublishIuranData: canPublishIuranData,
              );
            case _AdminPublikasiTab.kasPendingPublish:
              return _buildKasPendingPublish(
                data,
                canPublishFinance: canPublishFinance,
              );
          }
      }
    }

    return _buildWargaBills(auth, data);
  }

  Widget _buildAdminBills(
    IuranListData data, {
    required bool canPublishFinance,
    bool includePaidOnly = false,
    bool excludePaidOnly = false,
    String emptyTitle = 'Belum ada tagihan iuran',
    String emptyMessage =
        'Buat periode iuran terlebih dahulu untuk menghasilkan tagihan per KK.',
  }) {
    final bills = _filterBills(
      data.bills,
      includePaidOnly: includePaidOnly,
      excludePaidOnly: excludePaidOnly,
    );
    if (bills.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          AppEmptyState(
            icon: Icons.receipt_long_outlined,
            title: emptyTitle,
            message: emptyMessage,
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
          showPrimaryAction: !bill.isPaid,
          showFinanceAction:
              canPublishFinance && financeTransaction != null && bill.isPaid,
          onPrimaryAction: bill.isSubmittedVerification
              ? () => setState(() {
                  _adminSection = _AdminIuranSection.operasional;
                  _operasionalTab = _AdminOperasionalTab.verifikasi;
                })
              : () => _recordCash(bill),
          onFinanceAction:
              canPublishFinance &&
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

  Widget _buildAdminVerification(
    IuranListData data,
    AuthState auth,
    bool canReviewPayments,
  ) {
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
        final isSelfPayment =
            (data.myKkId ?? '').isNotEmpty && data.myKkId == bill.kkId ||
            payment.submittedBy == auth.user?.id;
        return _buildPendingPaymentCard(
          bill,
          payment,
          canReview: canReviewPayments && !isSelfPayment,
          isSelfPayment: isSelfPayment,
        );
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

  Widget _buildPublishIuranData(
    IuranListData data, {
    required bool canPublishIuranData,
  }) {
    final periods = _filterPeriods(data.periods);
    final unpublishedPeriods = periods
        .where((period) => !_publishedSummaryPeriodIds.contains(period.id))
        .toList(growable: false);
    var totalTarget = 0;
    var totalPaid = 0;
    for (final period in unpublishedPeriods) {
      final bills = data.bills
          .where((item) => item.periodId == period.id)
          .toList(growable: false);
      final stats = _periodPublicationStats(bills);
      totalTarget += stats.totalTarget;
      totalPaid += stats.paidCount;
    }
    if (periods.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 80),
          AppEmptyState(
            icon: Icons.campaign_outlined,
            title: 'Belum ada periode untuk dipublish',
            message:
                'Rekap iuran akan muncul setelah Anda memiliki periode dan tagihan yang aktif.',
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        if (unpublishedPeriods.isNotEmpty) ...[
          _buildBatchPublishCard(
            icon: Icons.campaign_outlined,
            tone: AppTheme.primaryDark,
            title: 'Batch publish rekap iuran',
            description:
                'Publish semua periode yang sedang tampil tanpa proses satu per satu.',
            summary:
                '${unpublishedPeriods.length} periode | $totalTarget KK target | $totalPaid lunas',
            buttonLabel: _isPublishingSummaryBatch
                ? 'Memproses batch...'
                : canPublishIuranData
                ? 'Batch Publish Rekap'
                : 'Butuh hak kelola iuran',
            onPressed: canPublishIuranData && !_isPublishingSummaryBatch
                ? () => _publishAllIuranSummaries(unpublishedPeriods)
                : null,
          ),
          const SizedBox(height: 12),
        ],
        for (var index = 0; index < periods.length; index++) ...[
          Builder(
            builder: (context) {
              final period = periods[index];
              final isSummaryPublished = _publishedSummaryPeriodIds.contains(
                period.id,
              );
              final bills = data.bills
                  .where((item) => item.periodId == period.id)
                  .toList(growable: false);
              final stats = _periodPublicationStats(bills);
              return AppSurfaceCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppTheme.accentColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.summarize_outlined,
                            color: AppTheme.accentColor,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                period.title,
                                style: AppTheme.heading3.copyWith(fontSize: 15),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${period.typeLabel} - ${AppConstants.iuranFrequencyLabel(period.frequency)}',
                                style: AppTheme.bodySmall.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _metaChip(
                          '${stats.completionPercent}% selesai',
                          AppTheme.primaryColor.withValues(alpha: 0.12),
                          AppTheme.primaryColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _metaChip(
                          'Target ${stats.totalTarget} KK',
                          AppTheme.primaryColor.withValues(alpha: 0.10),
                          AppTheme.primaryColor,
                        ),
                        _metaChip(
                          'Lunas ${stats.paidCount}',
                          AppTheme.successColor.withValues(alpha: 0.12),
                          AppTheme.successColor,
                        ),
                        _metaChip(
                          'Belum lunas ${stats.unpaidCount}',
                          AppTheme.warningColor.withValues(alpha: 0.12),
                          AppTheme.warningColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _infoRow('Masuk', Formatters.rupiah(stats.totalCollected)),
                    _infoRow(
                      'Deadline',
                      period.dueDate == null
                          ? '-'
                          : Formatters.tanggalPendek(period.dueDate!),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            'Rekap yang dipublish hanya memuat target, progres lunas, dan total pemasukan tanpa identitas KK.',
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                        if (isSummaryPublished) ...[
                          const SizedBox(width: 8),
                          _metaChip(
                            'Sudah dipublish',
                            AppTheme.successColor.withValues(alpha: 0.12),
                            AppTheme.successColor,
                          ),
                        ],
                      ],
                    ),
                    if (!isSummaryPublished) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: canPublishIuranData
                              ? () => _publishIuranSummary(period, stats)
                              : null,
                          icon: const Icon(Icons.campaign_outlined),
                          label: Text(
                            canPublishIuranData
                                ? 'Publish Rekap Periode'
                                : 'Butuh hak kelola iuran',
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: canPublishIuranData
                            ? () => _publishIuranSummary(period, stats)
                            : null,
                        icon: const Icon(Icons.campaign_outlined),
                        label: Text(
                          canPublishIuranData
                              ? 'Publish Rekap Periode'
                              : 'Butuh hak kelola iuran',
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          if (index != periods.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildKasPendingPublish(
    IuranListData data, {
    required bool canPublishFinance,
  }) {
    final bills = _filterBills(
      data.bills
          .where((item) {
            final finance = data.financeTransactionForBill(item.id);
            return item.isPaid && finance != null && !finance.isPublished;
          })
          .toList(growable: false),
      includePaidOnly: false,
      excludePaidOnly: false,
    );

    if (bills.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 80),
          AppEmptyState(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Tidak ada kas pending publish',
            message:
                'Semua transaksi iuran yang sudah masuk ledger sudah dipublish atau belum ada yang siap dipublikasikan.',
          ),
        ],
      );
    }

    final totalPendingAmount = bills.fold<int>(
      0,
      (sum, item) => sum + item.amount,
    );

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _buildBatchPublishCard(
          icon: Icons.account_balance_wallet_outlined,
          tone: AppTheme.accentColor,
          title: 'Batch publish kas pending',
          description:
              'Dorong semua transaksi kas yang siap publish agar operasional tidak terhambat.',
          summary:
              '${bills.length} transaksi • ${Formatters.rupiah(totalPendingAmount)}',
          buttonLabel: _isPublishingFinanceBatch
              ? 'Memproses batch...'
              : canPublishFinance
              ? 'Batch Publish Kas'
              : 'Butuh hak publish kas',
          onPressed: canPublishFinance && !_isPublishingFinanceBatch
              ? () => _publishAllFinanceBills(bills)
              : null,
        ),
        const SizedBox(height: 12),
        for (var index = 0; index < bills.length; index++) ...[
          Builder(
            builder: (context) {
              final bill = bills[index];
              final latestPayment =
                  data.paymentsByBill[bill.id]?.isNotEmpty == true
                  ? data.paymentsByBill[bill.id]!.first
                  : null;
              final financeTransaction = data.financeTransactionForBill(
                bill.id,
              );
              return _buildBillCard(
                bill,
                data.periodsById[bill.periodId],
                latestPayment,
                financeTransaction: financeTransaction,
                isAdmin: true,
                showPrimaryAction: false,
                showFinanceAction:
                    canPublishFinance && financeTransaction != null,
                onPrimaryAction: null,
                onFinanceAction: canPublishFinance && financeTransaction != null
                    ? () => _publishFinance(bill)
                    : null,
                primaryActionLabel: '',
                financeActionLabel: financeTransaction?.isPublished == true
                    ? 'Sudah Dipublish'
                    : 'Publish Kas',
              );
            },
          ),
          if (index != bills.length - 1) const SizedBox(height: 12),
        ],
      ],
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
      if (_adminBillStatusFilter == AppConstants.iuranBillUnpaid &&
          bill.isPaid) {
        return false;
      }
      if (_adminBillStatusFilter ==
              AppConstants.iuranBillSubmittedVerification &&
          !bill.isSubmittedVerification) {
        return false;
      }
      if (_adminBillStatusFilter == _billStatusPaid && !bill.isPaid) {
        return false;
      }
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
    bool showPrimaryAction = true,
    bool showFinanceAction = true,
    required VoidCallback? onPrimaryAction,
    required VoidCallback? onFinanceAction,
    required String primaryActionLabel,
    required String financeActionLabel,
  }) {
    final statusColor = AppTheme.statusColor(bill.status);
    final isEffectivelyPaid =
        bill.isPaid ||
        latestPayment?.isVerified == true ||
        financeTransaction != null;
    final shouldShowPrimaryAction = showPrimaryAction && !isEffectivelyPaid;
    final shouldShowFinanceAction =
        showFinanceAction && financeTransaction != null;
    final financePublishLabel = financeTransaction == null
        ? null
        : financeTransaction.isPublished
        ? 'Ledger dipublish'
        : 'Ledger pending publish';
    final paymentInfo = latestPayment == null
        ? null
        : '${AppConstants.iuranMethodLabel(latestPayment.method)} - ${AppConstants.iuranPaymentStatusLabel(latestPayment.status)}';

    return AppSurfaceCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: AppTheme.primaryColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bill.title,
                      style: AppTheme.heading3.copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${bill.typeLabel} - ${bill.kkHolderName?.trim().isNotEmpty == true ? bill.kkHolderName : bill.kkNumber}',
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
          const SizedBox(height: 10),
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
                  AppTheme.extraLightGray,
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
          const SizedBox(height: 10),
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
            const SizedBox(height: 8),
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
          const SizedBox(height: 12),
          if (shouldShowPrimaryAction)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onPrimaryAction,
                child: Text(primaryActionLabel),
              ),
            ),
          if (isAdmin &&
              (shouldShowFinanceAction || latestPayment != null)) ...[
            if (shouldShowPrimaryAction) const SizedBox(height: 10),
            Row(
              children: [
                if (shouldShowFinanceAction)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: financeTransaction.isPublished
                          ? null
                          : onFinanceAction,
                      child: Text(financeActionLabel),
                    ),
                  ),
                if (isAdmin && latestPayment != null) ...[
                  if (shouldShowFinanceAction) const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _openProof(latestPayment),
                      child: const Text('Bukti'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPendingPaymentCard(
    IuranBillModel bill,
    IuranPaymentModel payment, {
    required bool canReview,
    required bool isSelfPayment,
  }) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.verified_outlined,
                  color: AppTheme.accentColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bill.title,
                      style: AppTheme.heading3.copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${bill.kkHolderName?.trim().isNotEmpty == true ? bill.kkHolderName : bill.kkNumber} - ${AppConstants.iuranMethodLabel(payment.method)}',
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
          const SizedBox(height: 10),
          _infoRow('Tagihan', Formatters.rupiah(payment.amount)),
          _infoRow('No. KK', bill.kkNumber),
          if ((payment.note ?? '').isNotEmpty)
            _infoRow('Catatan warga', payment.note!),
          if (isSelfPayment) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.warningColor.withValues(alpha: 0.22),
                ),
              ),
              child: Text(
                'Pembayaran untuk KK Anda sendiri harus diverifikasi pengurus lain atau RW.',
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.warningColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
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
                  onPressed: canReview
                      ? () => _reviewPayment(payment, approve: true)
                      : null,
                  child: const Text('Verifikasi'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: canReview
                  ? () => _reviewPayment(payment, approve: false)
                  : null,
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
      padding: const EdgeInsets.all(12),
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
                      style: AppTheme.heading3.copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${period.typeLabel} - ${AppConstants.iuranFrequencyLabel(period.frequency)}',
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
          const SizedBox(height: 10),
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
      padding: const EdgeInsets.all(12),
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
                      style: AppTheme.heading3.copyWith(fontSize: 15),
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
          const SizedBox(height: 10),
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

  Widget _buildAdminContextNote() {
    String title;
    String message;
    IconData icon;
    Color tone;

    switch (_adminSection) {
      case _AdminIuranSection.operasional:
        switch (_operasionalTab) {
          case _AdminOperasionalTab.tagihan:
            title = 'Tagihan aktif';
            message =
                'Pantau tagihan berjalan, tunggakan, dan catat pembayaran cash untuk bill yang belum selesai.';
            icon = Icons.receipt_long_rounded;
            tone = AppTheme.primaryColor;
          case _AdminOperasionalTab.verifikasi:
            title = 'Verifikasi transfer';
            message =
                'Review bukti transfer warga yang masih menunggu persetujuan pengurus berwenang.';
            icon = Icons.verified_outlined;
            tone = AppTheme.accentColor;
          case _AdminOperasionalTab.lunas:
            title = 'Riwayat lunas';
            message =
                'Audit pembayaran yang sudah lunas dan lanjutkan publish kas bila ledger finance masih pending.';
            icon = Icons.paid_outlined;
            tone = AppTheme.successColor;
        }
      case _AdminIuranSection.master:
        switch (_masterTab) {
          case _AdminMasterTab.periode:
            title = 'Periode iuran';
            message =
                'Periode dipakai untuk generate tagihan per KK pada bulan atau kegiatan tertentu. Satu periode menentukan nominal, deadline, dan target KK yang ditagih.';
            icon = Icons.calendar_month_rounded;
            tone = AppTheme.primaryColor;
          case _AdminMasterTab.jenis:
            title = 'Jenis iuran';
            message =
                'Jenis iuran adalah master template seperti kebersihan, keamanan, atau kas sosial. Nilai default-nya bisa dipakai ulang setiap kali admin membuat periode baru.';
            icon = Icons.category_outlined;
            tone = AppTheme.accentColor;
        }
      case _AdminIuranSection.publikasi:
        switch (_publikasiTab) {
          case _AdminPublikasiTab.publishDataIuran:
            title = 'Publikasi data iuran';
            message =
                'Publish rekap aman per periode. Nama KK tidak ikut dipublikasikan.';
            icon = Icons.campaign_outlined;
            tone = AppTheme.primaryDark;
          case _AdminPublikasiTab.kasPendingPublish:
            title = 'Kas pending publish';
            message =
                'Transaksi kas iuran yang sudah masuk ledger tetapi belum diumumkan akan tampil di sini.';
            icon = Icons.account_balance_wallet_outlined;
            tone = AppTheme.toneTerracotta;
        }
    }

    return AppSurfaceCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: tone, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _IuranPeriodPublicationStats _periodPublicationStats(
    List<IuranBillModel> bills,
  ) {
    final totalTarget = bills.length;
    final paidCount = bills.where((item) => item.isPaid).length;
    final unpaidCount = totalTarget - paidCount;
    final totalCollected = bills
        .where((item) => item.isPaid)
        .fold<int>(0, (sum, item) => sum + item.amount);
    final completionPercent = totalTarget == 0
        ? 0
        : ((paidCount / totalTarget) * 100).round();

    return _IuranPeriodPublicationStats(
      totalTarget: totalTarget,
      paidCount: paidCount,
      unpaidCount: unpaidCount,
      totalCollected: totalCollected,
      completionPercent: completionPercent,
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
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

  Widget _buildBatchPublishCard({
    required IconData icon,
    required Color tone,
    required String title,
    required String description,
    required String summary,
    required String buttonLabel,
    required VoidCallback? onPressed,
  }) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: tone, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTheme.bodyMedium.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _metaChip(summary, tone.withValues(alpha: 0.10), tone),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onPressed,
              icon: Icon(icon),
              label: Text(buttonLabel),
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

  Future<void> _publishIuranSummary(
    IuranPeriodModel period,
    _IuranPeriodPublicationStats stats,
  ) async {
    final titleController = TextEditingController(
      text: 'Rekap ${period.title}',
    );
    final contentController = TextEditingController(
      text: [
        'Ringkasan iuran ${period.title}.',
        'Target KK: ${stats.totalTarget} KK.',
        'Sudah lunas: ${stats.paidCount} KK.',
        'Belum lunas: ${stats.unpaidCount} KK.',
        'Total nominal masuk: ${Formatters.rupiah(stats.totalCollected)}.',
        if (period.dueDate != null)
          'Batas pembayaran: ${Formatters.tanggalPendek(period.dueDate!)}.',
      ].join('\n'),
    );

    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Publish Data Iuran'),
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
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Isi Pengumuman Rekap',
              ),
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
          .publishPeriodSummary(
            ref.read(authProvider),
            period.id,
            announcementTitle: titleController.text.trim(),
            announcementContent: contentController.text.trim(),
          );
      if (mounted) {
        setState(() => _publishedSummaryPeriodIds.add(period.id));
      }
      ref.read(iuranRefreshTickProvider.notifier).bump();
      if (mounted) {
        ErrorClassifier.showSuccessSnackBar(
          context,
          'Rekap iuran berhasil dipublish.',
        );
      }
    } catch (error) {
      if (mounted) {
        ErrorClassifier.showErrorSnackBar(context, error);
      }
    }
  }

  Future<void> _publishAllIuranSummaries(List<IuranPeriodModel> periods) async {
    if (periods.isEmpty || _isPublishingSummaryBatch) {
      return;
    }

    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Batch Publish Rekap Iuran'),
        content: Text(
          'Publikasi ini akan membuat ${periods.length} pengumuman rekap untuk semua periode yang sedang tampil. Lanjutkan batch publish?',
          style: AppTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Batch Publish'),
          ),
        ],
      ),
    );

    if (proceed != true || !mounted) {
      return;
    }

    setState(() => _isPublishingSummaryBatch = true);
    var successCount = 0;
    String? firstFailureMessage;
    final publishedIds = <String>[];

    try {
      final service = ref.read(iuranServiceProvider);
      final auth = ref.read(authProvider);

      for (final period in periods) {
        try {
          await service.publishPeriodSummary(auth, period.id);
          publishedIds.add(period.id);
          successCount++;
        } catch (error) {
          firstFailureMessage ??= ErrorClassifier.classify(error).message;
        }
      }

      if (publishedIds.isNotEmpty && mounted) {
        setState(() {
          _publishedSummaryPeriodIds.addAll(publishedIds);
        });
      }

      if (successCount > 0) {
        ref.read(iuranRefreshTickProvider.notifier).bump();
      }

      if (!mounted) {
        return;
      }

      final failureCount = periods.length - successCount;
      if (successCount == 0) {
        ErrorClassifier.showErrorSnackBar(
          context,
          Exception(
            firstFailureMessage ??
                'Tidak ada rekap iuran yang berhasil dipublish.',
          ),
        );
        return;
      }

      ErrorClassifier.showSuccessSnackBar(
        context,
        failureCount == 0
            ? 'Batch publish rekap berhasil untuk $successCount periode.'
            : '$successCount periode berhasil dipublish, $failureCount periode masih perlu dicek ulang.',
      );
    } finally {
      if (mounted) {
        setState(() => _isPublishingSummaryBatch = false);
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

  Future<void> _publishAllFinanceBills(List<IuranBillModel> bills) async {
    if (bills.isEmpty || _isPublishingFinanceBatch) {
      return;
    }

    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Batch Publish Kas Iuran'),
        content: Text(
          'Semua transaksi kas iuran yang sedang tampil akan dipublish sekaligus. Lanjutkan proses batch publish?',
          style: AppTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Batch Publish'),
          ),
        ],
      ),
    );

    if (proceed != true || !mounted) {
      return;
    }

    setState(() => _isPublishingFinanceBatch = true);
    var successCount = 0;
    String? firstFailureMessage;

    try {
      final service = ref.read(iuranServiceProvider);
      final auth = ref.read(authProvider);

      for (final bill in bills) {
        try {
          await service.publishFinanceForBill(auth, bill.id);
          successCount++;
        } catch (error) {
          firstFailureMessage ??= ErrorClassifier.classify(error).message;
        }
      }

      if (successCount > 0) {
        ref.read(iuranRefreshTickProvider.notifier).bump();
      }

      if (!mounted) {
        return;
      }

      final failureCount = bills.length - successCount;
      if (successCount == 0) {
        ErrorClassifier.showErrorSnackBar(
          context,
          Exception(
            firstFailureMessage ??
                'Tidak ada transaksi kas yang berhasil dipublish.',
          ),
        );
        return;
      }

      ErrorClassifier.showSuccessSnackBar(
        context,
        failureCount == 0
            ? 'Batch publish kas berhasil untuk $successCount transaksi.'
            : '$successCount transaksi berhasil dipublish, $failureCount transaksi masih perlu dicek ulang.',
      );
    } finally {
      if (mounted) {
        setState(() => _isPublishingFinanceBatch = false);
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

class _IuranListSkeleton extends StatelessWidget {
  const _IuranListSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Hero skeleton
        const AppSkeleton(height: 140, borderRadius: 16),
        const SizedBox(height: 12),
        // Tab selector skeleton
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor.withValues(alpha: 0.76),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
          child: const Row(
            children: [
              Expanded(child: AppSkeleton(height: 36, borderRadius: 8)),
              SizedBox(width: 8),
              Expanded(child: AppSkeleton(height: 36, borderRadius: 8)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // List items
        Expanded(
          child: ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 5,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, _) => const AppSurfaceCard(
              padding: EdgeInsets.all(14),
              child: Row(
                children: [
                  AppSkeleton(width: 44, height: 44, borderRadius: 12),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppSkeleton(height: 16),
                        SizedBox(height: 6),
                        AppSkeleton(height: 14, width: 120),
                      ],
                    ),
                  ),
                  SizedBox(width: 8),
                  AppSkeleton(width: 70, height: 24, borderRadius: 999),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
