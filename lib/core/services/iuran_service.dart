import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../shared/models/finance_model.dart';
import '../../shared/models/iuran_model.dart';
import '../../shared/models/kartu_keluarga_model.dart';
import '../../shared/models/workspace_access_model.dart';
import '../constants/app_constants.dart';
import '../services/finance_service.dart';
import '../services/pocketbase_service.dart';
import '../utils/area_access.dart';
import '../utils/formatters.dart';
import 'workspace_access_service.dart';

class IuranDashboardSummary {
  const IuranDashboardSummary({
    required this.totalBills,
    required this.paidBills,
    required this.outstandingBills,
    required this.pendingVerificationBills,
    required this.totalTagihan,
    required this.totalLunas,
    required this.totalTunggakan,
  });

  final int totalBills;
  final int paidBills;
  final int outstandingBills;
  final int pendingVerificationBills;
  final int totalTagihan;
  final int totalLunas;
  final int totalTunggakan;
}

class IuranKkOption {
  const IuranKkOption({required this.kk, this.holderName});

  final KartuKeluargaModel kk;
  final String? holderName;

  String get label {
    final holder = (holderName ?? '').trim();
    if (holder.isEmpty) {
      return 'No. KK ${kk.noKk}';
    }
    return '$holder • ${kk.noKk}';
  }
}

class IuranFormOptions {
  const IuranFormOptions({required this.types, required this.targets});

  final List<IuranTypeModel> types;
  final List<IuranKkOption> targets;
}

class IuranListData {
  const IuranListData({
    required this.types,
    required this.periods,
    required this.bills,
    required this.paymentsByBill,
    required this.financeTransactionsByBillId,
    required this.pendingPayments,
    required this.summary,
    required this.myKkId,
  });

  final List<IuranTypeModel> types;
  final List<IuranPeriodModel> periods;
  final List<IuranBillModel> bills;
  final Map<String, List<IuranPaymentModel>> paymentsByBill;
  final Map<String, FinanceTransactionModel> financeTransactionsByBillId;
  final List<IuranPaymentModel> pendingPayments;
  final IuranDashboardSummary summary;
  final String? myKkId;

  Map<String, IuranPeriodModel> get periodsById => {
    for (final period in periods) period.id: period,
  };

  Map<String, IuranTypeModel> get typesById => {
    for (final type in types) type.id: type,
  };

  FinanceTransactionModel? financeTransactionForBill(String billId) {
    return financeTransactionsByBillId[billId];
  }
}

class IuranTypeSubmitPayload {
  const IuranTypeSubmitPayload({
    required this.label,
    required this.defaultAmount,
    required this.defaultFrequency,
    this.description = '',
    this.isActive = true,
  });

  final String label;
  final int defaultAmount;
  final String defaultFrequency;
  final String description;
  final bool isActive;
}

class IuranPeriodTarget {
  const IuranPeriodTarget({required this.kkId, this.overrideAmount});

  final String kkId;
  final int? overrideAmount;
}

class IuranPeriodSubmitPayload {
  const IuranPeriodSubmitPayload({
    required this.typeId,
    required this.title,
    required this.frequency,
    required this.defaultAmount,
    required this.dueDate,
    required this.targetAllScope,
    this.description = '',
    this.targets = const [],
  });

  final String typeId;
  final String title;
  final String frequency;
  final int defaultAmount;
  final DateTime dueDate;
  final bool targetAllScope;
  final String description;
  final List<IuranPeriodTarget> targets;
}

class IuranTransferSubmitPayload {
  const IuranTransferSubmitPayload({
    required this.billId,
    required this.proofFile,
    this.note = '',
  });

  final String billId;
  final PlatformFile proofFile;
  final String note;
}

class IuranPaymentReviewPayload {
  const IuranPaymentReviewPayload({required this.paymentId, this.note = ''});

  final String paymentId;
  final String note;
}

class _IuranPostingContext {
  const _IuranPostingContext({
    required this.profile,
    required this.targetUnit,
    this.account,
  });

  final WorkspaceAccessProfile profile;
  final OrgUnitModel targetUnit;
  final FinanceAccountModel? account;
}

class _IuranFinanceEnsureResult {
  const _IuranFinanceEnsureResult({
    required this.transaction,
    required this.created,
  });

  final FinanceTransactionModel transaction;
  final bool created;
}

class IuranService {
  IuranService(this._ref);

  final Ref _ref;

  Future<IuranListData> fetchList(AuthState auth) async {
    if (auth.user == null) {
      return const IuranListData(
        types: [],
        periods: [],
        bills: [],
        paymentsByBill: {},
        financeTransactionsByBillId: {},
        pendingPayments: [],
        summary: IuranDashboardSummary(
          totalBills: 0,
          paidBills: 0,
          outstandingBills: 0,
          pendingVerificationBills: 0,
          totalTagihan: 0,
          totalLunas: 0,
          totalTunggakan: 0,
        ),
        myKkId: null,
      );
    }

    final viewerAuth = await _effectiveViewerAuth(auth);
    final access = await resolveAreaAccessContext(auth);
    final billFilter = buildIuranBillScopeFilter(viewerAuth, context: access);

    final billRecords = await pb
        .collection(AppConstants.colIuranBills)
        .getFullList(sort: '-updated,-created', filter: billFilter);
    final bills = billRecords.map(IuranBillModel.fromRecord).toList();

    List<IuranPeriodModel> periods = const [];
    final periodIds = bills
        .map((item) => item.periodId)
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (periodIds.isNotEmpty) {
      final periodRecords = await pb
          .collection(AppConstants.colIuranPeriods)
          .getFullList(sort: '-created', filter: _orFilter('id', periodIds));
      periods = periodRecords.map(IuranPeriodModel.fromRecord).toList();
    } else if (viewerAuth.isOperator || viewerAuth.isSysadmin) {
      final periodRecords = await pb
          .collection(AppConstants.colIuranPeriods)
          .getFullList(
            sort: '-created',
            filter: buildIuranPeriodScopeFilter(viewerAuth, context: access),
          );
      periods = periodRecords.map(IuranPeriodModel.fromRecord).toList();
    }

    final typeRecords = await pb
        .collection(AppConstants.colIuranTypes)
        .getFullList(
          sort: 'sort_order,label',
          filter: viewerAuth.isOperator || viewerAuth.isSysadmin
              ? ''
              : 'is_active = true',
        );
    final types = typeRecords.map(IuranTypeModel.fromRecord).toList();

    final paymentsByBill = <String, List<IuranPaymentModel>>{};
    if (bills.isNotEmpty) {
      final paymentRecords = await pb
          .collection(AppConstants.colIuranPayments)
          .getFullList(
            sort: '-created',
            filter: _orFilter('bill', bills.map((item) => item.id).toList()),
          );
      for (final record in paymentRecords) {
        final payment = IuranPaymentModel.fromRecord(record);
        paymentsByBill.putIfAbsent(payment.billId, () => []).add(payment);
      }
    }

    for (final entry in paymentsByBill.entries) {
      entry.value.sort((a, b) => b.timelineAt.compareTo(a.timelineAt));
    }

    final financeTransactionsByBillId = await _loadFinanceTransactionsByBillId(
      paymentsByBill,
    );

    final enrichedBills = bills
        .map(
          (bill) => _deriveBillStateFromPayments(
            bill,
            paymentsByBill[bill.id] ?? const [],
          ),
        )
        .toList();

    final pendingPayments =
        paymentsByBill.values
            .expand((entries) => entries)
            .where((item) => item.isSubmitted)
            .toList()
          ..sort((a, b) => b.timelineAt.compareTo(a.timelineAt));

    final totalTagihan = enrichedBills.fold<int>(
      0,
      (sum, item) => sum + item.amount,
    );
    final totalLunas = enrichedBills
        .where((item) => item.isPaid)
        .fold<int>(0, (sum, item) => sum + item.amount);
    final totalTunggakan = enrichedBills
        .where((item) => !item.isPaid)
        .fold<int>(0, (sum, item) => sum + item.amount);

    return IuranListData(
      types: types,
      periods: periods,
      bills: enrichedBills,
      paymentsByBill: paymentsByBill,
      financeTransactionsByBillId: financeTransactionsByBillId,
      pendingPayments: pendingPayments,
      myKkId: access.kkId,
      summary: IuranDashboardSummary(
        totalBills: enrichedBills.length,
        paidBills: enrichedBills.where((item) => item.isPaid).length,
        outstandingBills: enrichedBills.where((item) => !item.isPaid).length,
        pendingVerificationBills: enrichedBills
            .where((item) => item.isSubmittedVerification)
            .length,
        totalTagihan: totalTagihan,
        totalLunas: totalLunas,
        totalTunggakan: totalTunggakan,
      ),
    );
  }

  Future<IuranFormOptions> fetchFormOptions(AuthState auth) async {
    await _assertIuranWorkspaceManagerAccess(auth);

    final types =
        (await pb
                .collection(AppConstants.colIuranTypes)
                .getFullList(sort: 'sort_order,label'))
            .map(IuranTypeModel.fromRecord)
            .toList();
    final targets = await _fetchScopedKkOptions(auth);

    return IuranFormOptions(types: types, targets: targets);
  }

  Future<void> createType(
    AuthState auth,
    IuranTypeSubmitPayload payload,
  ) async {
    await _assertIuranWorkspaceManagerAccess(auth);

    final label = payload.label.trim();
    if (label.isEmpty) {
      throw Exception('Nama jenis iuran wajib diisi.');
    }
    final code = _slugify(label);
    final existing = await _tryFindFirst(
      AppConstants.colIuranTypes,
      'code = "${_escapeFilterValue(code)}"',
    );
    if (existing != null) {
      throw Exception('Jenis iuran dengan nama serupa sudah ada.');
    }

    await pb
        .collection(AppConstants.colIuranTypes)
        .create(
          body: {
            'code': code,
            'label': label,
            'description': payload.description.trim(),
            'default_amount': payload.defaultAmount,
            'default_frequency': payload.defaultFrequency,
            'is_active': payload.isActive,
            'sort_order': DateTime.now().millisecondsSinceEpoch,
          },
        );
  }

  Future<void> createPeriod(
    AuthState auth,
    IuranPeriodSubmitPayload payload,
  ) async {
    await _assertIuranWorkspaceManagerAccess(auth);
    if (payload.defaultAmount <= 0) {
      throw Exception('Nominal default harus lebih besar dari nol.');
    }

    final access = await resolveAreaAccessContext(auth);
    if (!access.hasRegionalScope) {
      throw Exception('Data wilayah admin belum lengkap.');
    }

    final typeRecord = await pb
        .collection(AppConstants.colIuranTypes)
        .getOne(payload.typeId);
    final type = IuranTypeModel.fromRecord(typeRecord);
    final kkOptions = await _fetchScopedKkOptions(auth);
    final kkById = {for (final option in kkOptions) option.kk.id: option};

    final targetOptions = payload.targetAllScope
        ? kkOptions
        : payload.targets
              .map((target) => kkById[target.kkId])
              .whereType<IuranKkOption>()
              .toList();
    if (targetOptions.isEmpty) {
      throw Exception('Pilih minimal satu KK target.');
    }

    final periodRecord = await pb
        .collection(AppConstants.colIuranPeriods)
        .create(
          body: {
            'iuran_type': type.id,
            'type_label': type.label,
            'title': payload.title.trim(),
            'description': payload.description.trim(),
            'frequency': payload.frequency,
            'default_amount': payload.defaultAmount,
            'due_date': payload.dueDate.toIso8601String(),
            'status': AppConstants.iuranPeriodPublished,
            'target_mode': payload.targetAllScope
                ? AppConstants.iuranTargetAllScope
                : AppConstants.iuranTargetCustomTargets,
            'created_by': auth.user!.id,
            'published_at': DateTime.now().toIso8601String(),
            'rt': access.rt,
            'rw': access.rw,
            'desa_code': access.desaCode ?? '',
            'kecamatan_code': access.kecamatanCode ?? '',
            'kabupaten_code': access.kabupatenCode ?? '',
            'provinsi_code': access.provinsiCode ?? '',
            'desa_kelurahan': access.desaKelurahan ?? '',
            'kecamatan': access.kecamatan ?? '',
            'kabupaten_kota': access.kabupatenKota ?? '',
            'provinsi': access.provinsi ?? '',
          },
        );

    final overrideMap = {
      for (final target in payload.targets) target.kkId: target.overrideAmount,
    };

    for (final option in targetOptions) {
      final kk = option.kk;
      final amount = overrideMap[kk.id] ?? payload.defaultAmount;
      final billNumber = _buildBillNumber(
        typeCode: type.code,
        periodId: periodRecord.id,
        kkNumber: kk.noKk,
      );

      await pb
          .collection(AppConstants.colIuranBills)
          .create(
            body: {
              'period': periodRecord.id,
              'iuran_type': type.id,
              'kk': kk.id,
              'bill_number': billNumber,
              'title': payload.title.trim(),
              'type_label': type.label,
              'kk_number': kk.noKk,
              'kk_holder_name': option.holderName ?? '',
              'frequency': payload.frequency,
              'amount': amount,
              'status': AppConstants.iuranBillUnpaid,
              'due_date': payload.dueDate.toIso8601String(),
              'rt': int.tryParse(kk.rt),
              'rw': int.tryParse(kk.rw),
              'desa_code': kk.desaCode ?? '',
              'kecamatan_code': kk.kecamatanCode ?? '',
              'kabupaten_code': kk.kabupatenCode ?? '',
              'provinsi_code': kk.provinsiCode ?? '',
              'desa_kelurahan': kk.desaKelurahan ?? '',
              'kecamatan': kk.kecamatan ?? '',
              'kabupaten_kota': kk.kabupatenKota ?? '',
              'provinsi': kk.provinsi ?? '',
            },
          );
    }
  }

  Future<void> submitTransfer(
    AuthState auth,
    IuranTransferSubmitPayload payload,
  ) async {
    if (auth.user == null) {
      throw Exception('User belum login.');
    }

    final access = await resolveAreaAccessContext(auth);
    final billRecord = await _loadAuthorizedBillRecord(auth, payload.billId);
    final bill = IuranBillModel.fromRecord(billRecord);
    if ((access.kkId ?? '').isEmpty || access.kkId != bill.kkId) {
      throw Exception('Tagihan ini bukan milik KK Anda.');
    }
    if (bill.isPaid) {
      throw Exception('Tagihan ini sudah lunas.');
    }
    if (bill.isSubmittedVerification) {
      throw Exception('Bukti transfer masih menunggu verifikasi admin.');
    }
    await _assertNoBlockingPayment(bill.id);

    final file = _toMultipartFile('proof_file', payload.proofFile);
    await pb
        .collection(AppConstants.colIuranPayments)
        .create(
          body: {
            'bill': bill.id,
            'kk': bill.kkId,
            'submitted_by': auth.user!.id,
            'method': AppConstants.iuranMethodTransfer,
            'amount': bill.amount,
            'note': payload.note.trim(),
            'status': AppConstants.iuranPaymentSubmitted,
            'submitted_at': DateTime.now().toIso8601String(),
          },
          files: [file],
        );

    // Best-effort sync only. Warga is blocked by collection rule and the UI
    // derives the effective state from the latest payment record instead.
    try {
      await pb
          .collection(AppConstants.colIuranBills)
          .update(
            bill.id,
            body: {
              'status': AppConstants.iuranBillSubmittedVerification,
              'payment_method': AppConstants.iuranMethodTransfer,
              'payer_note': payload.note.trim(),
              'submitted_by': auth.user!.id,
              'submitted_at': DateTime.now().toIso8601String(),
              'rejection_note': '',
            },
          );
    } catch (_) {}
  }

  Future<void> recordCashPayment(
    AuthState auth,
    String billId, {
    String note = '',
  }) async {
    _assertAdminAccess(auth);
    final billRecord = await _loadAuthorizedBillRecord(auth, billId);
    final bill = IuranBillModel.fromRecord(billRecord);
    await _assertCanRecordOrVerifyBillPayment(auth, bill);
    await _assertNotSelfHandledPayment(auth, bill);
    if (bill.isPaid) {
      throw Exception('Tagihan ini sudah lunas.');
    }
    final postingContext = await _preparePostingContext(
      bill: bill,
      paymentMethod: AppConstants.iuranMethodCash,
    );

    final now = DateTime.now().toIso8601String();
    final paymentRecord = await pb
        .collection(AppConstants.colIuranPayments)
        .create(
          body: {
            'bill': bill.id,
            'kk': bill.kkId,
            'submitted_by': auth.user!.id,
            'method': AppConstants.iuranMethodCash,
            'amount': bill.amount,
            'note': note.trim(),
            'review_note': 'Pembayaran cash dicatat admin.',
            'status': AppConstants.iuranPaymentVerified,
            'submitted_at': now,
            'verified_by': auth.user!.id,
            'verified_at': now,
          },
        );
    final payment = IuranPaymentModel.fromRecord(paymentRecord);
    _IuranFinanceEnsureResult? financeResult;
    try {
      financeResult = await _ensureFinanceTransactionForPayment(
        auth: auth,
        bill: bill,
        payment: payment,
        note: note.trim(),
        postingContext: postingContext,
      );
      await pb
          .collection(AppConstants.colIuranBills)
          .update(
            bill.id,
            body: {
              'status': AppConstants.iuranBillPaid,
              'payment_method': AppConstants.iuranMethodCash,
              'payer_note': note.trim(),
              'submitted_by': auth.user!.id,
              'submitted_at': now,
              'verified_by': auth.user!.id,
              'verified_at': now,
              'paid_at': now,
              'rejection_note': '',
            },
          );
    } catch (_) {
      await _rollbackRecordedCashPayment(
        paymentId: payment.id,
        financeResult: financeResult,
      );
      rethrow;
    }
  }

  Future<void> verifyPayment(
    AuthState auth,
    IuranPaymentReviewPayload payload,
  ) async {
    _assertAdminAccess(auth);
    final paymentRecord = await pb
        .collection(AppConstants.colIuranPayments)
        .getOne(payload.paymentId);
    final payment = IuranPaymentModel.fromRecord(paymentRecord);
    final billRecord = await _loadAuthorizedBillRecord(auth, payment.billId);
    final bill = IuranBillModel.fromRecord(billRecord);
    await _assertCanRecordOrVerifyBillPayment(auth, bill);
    await _assertNotSelfHandledPayment(auth, bill, payment: payment);
    if (payment.isVerified) {
      throw Exception('Pembayaran ini sudah diverifikasi.');
    }
    if (!payment.isSubmitted) {
      throw Exception(
        'Hanya pembayaran yang sedang menunggu verifikasi yang bisa diproses.',
      );
    }
    final postingContext = await _preparePostingContext(
      bill: bill,
      paymentMethod: payment.method,
    );

    final now = DateTime.now().toIso8601String();
    _IuranFinanceEnsureResult? financeResult;
    try {
      final updatedPaymentRecord = await pb
          .collection(AppConstants.colIuranPayments)
          .update(
            payment.id,
            body: {
              'status': AppConstants.iuranPaymentVerified,
              'review_note': payload.note.trim(),
              'verified_by': auth.user!.id,
              'verified_at': now,
              'rejection_note': '',
            },
          );
      final verifiedPayment = IuranPaymentModel.fromRecord(
        updatedPaymentRecord,
      );
      financeResult = await _ensureFinanceTransactionForPayment(
        auth: auth,
        bill: bill,
        payment: verifiedPayment,
        note: payload.note.trim(),
        postingContext: postingContext,
      );
      await pb
          .collection(AppConstants.colIuranBills)
          .update(
            bill.id,
            body: {
              'status': AppConstants.iuranBillPaid,
              'payment_method': payment.method,
              'submitted_by': payment.submittedBy,
              'submitted_at': payment.submittedAt?.toIso8601String(),
              'verified_by': auth.user!.id,
              'verified_at': now,
              'paid_at': now,
              'payer_note': payment.note ?? '',
              'rejection_note': '',
            },
          );
    } catch (_) {
      await _rollbackVerifiedPayment(
        payment: payment,
        financeResult: financeResult,
      );
      rethrow;
    }
  }

  Future<void> rejectPayment(
    AuthState auth,
    IuranPaymentReviewPayload payload,
  ) async {
    _assertAdminAccess(auth);
    final paymentRecord = await pb
        .collection(AppConstants.colIuranPayments)
        .getOne(payload.paymentId);
    final payment = IuranPaymentModel.fromRecord(paymentRecord);
    final billRecord = await _loadAuthorizedBillRecord(auth, payment.billId);
    final bill = IuranBillModel.fromRecord(billRecord);
    await _assertCanRecordOrVerifyBillPayment(auth, bill);
    await _assertNotSelfHandledPayment(auth, bill, payment: payment);
    if (!payment.isSubmitted) {
      throw Exception(
        'Hanya pembayaran yang sedang menunggu verifikasi yang bisa ditolak.',
      );
    }
    final note = payload.note.trim();
    if (note.isEmpty) {
      throw Exception('Catatan penolakan wajib diisi.');
    }

    final now = DateTime.now().toIso8601String();
    await pb
        .collection(AppConstants.colIuranPayments)
        .update(
          payment.id,
          body: {
            'status': AppConstants.iuranPaymentRejected,
            'review_note': note,
            'verified_by': auth.user!.id,
            'verified_at': now,
            'rejection_note': note,
          },
        );

    await pb
        .collection(AppConstants.colIuranBills)
        .update(
          bill.id,
          body: {
            'status': AppConstants.iuranBillRejectedPayment,
            'payment_method': payment.method,
            'verified_by': auth.user!.id,
            'verified_at': now,
            'rejection_note': note,
          },
        );
  }

  Future<List<IuranKkOption>> _fetchScopedKkOptions(AuthState auth) async {
    final access = await resolveAreaAccessContext(auth);
    final kkRecords = await pb
        .collection(AppConstants.colKartuKeluarga)
        .getFullList(
          sort: 'rw,rt,no_kk',
          filter: buildKkScopeFilter(auth, context: access),
        );
    if (kkRecords.isEmpty) {
      return const [];
    }

    final kepalaIds = kkRecords
        .map((record) => record.getStringValue('kepala_keluarga'))
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final wargaNameById = <String, String>{};
    if (kepalaIds.isNotEmpty) {
      final wargaRecords = await pb
          .collection(AppConstants.colWarga)
          .getFullList(filter: _orFilter('id', kepalaIds));
      for (final record in wargaRecords) {
        wargaNameById[record.id] = record.getStringValue('nama_lengkap');
      }
    }

    return kkRecords.map((record) {
      final kk = KartuKeluargaModel.fromRecord(record);
      final kepalaId = record.getStringValue('kepala_keluarga');
      return IuranKkOption(kk: kk, holderName: wargaNameById[kepalaId]);
    }).toList();
  }

  Future<RecordModel> _loadAuthorizedBillRecord(
    AuthState auth,
    String billId,
  ) async {
    final access = await resolveAreaAccessContext(auth);
    final billRecord = await pb
        .collection(AppConstants.colIuranBills)
        .getOne(billId);
    final bill = IuranBillModel.fromRecord(billRecord);
    if (!canAccessIuranBillRecord(auth, bill, context: access)) {
      throw Exception('Anda tidak memiliki akses ke tagihan ini.');
    }
    return billRecord;
  }

  void _assertAdminAccess(AuthState auth) {
    if (auth.user == null || (!auth.isOperator && !auth.isSysadmin)) {
      throw Exception('Hanya admin yang dapat mengelola iuran.');
    }
  }

  Future<AuthState> _effectiveViewerAuth(AuthState auth) async {
    if (await _canUseAdminIuranView(auth)) {
      return auth;
    }
    return auth.copyWith(
      role: AppConstants.roleWarga,
      systemRole: AppConstants.systemRoleWarga,
      planCode: AppConstants.planFree,
    );
  }

  Future<bool> _canUseAdminIuranView(AuthState auth) async {
    if (auth.user == null) {
      return false;
    }
    if (auth.isSysadmin) {
      return true;
    }
    if (!auth.isOperator) {
      return false;
    }
    final profile = await _ref
        .read(workspaceAccessServiceProvider)
        .getCurrentAccessProfile();
    if (profile == null || !profile.member.hasActiveSubscription) {
      return false;
    }
    return profile.orgMemberships.any(
      (membership) =>
          membership.isActive &&
          (membership.canManageIuran || membership.canVerifyIuranPayment),
    );
  }

  http.MultipartFile _toMultipartFile(String field, PlatformFile file) {
    final bytes = file.bytes;
    if (bytes == null) {
      throw Exception('File ${file.name} tidak dapat dibaca.');
    }
    return http.MultipartFile.fromBytes(field, bytes, filename: file.name);
  }

  Future<RecordModel?> _tryFindFirst(String collection, String filter) async {
    try {
      return await pb.collection(collection).getFirstListItem(filter);
    } catch (_) {
      return null;
    }
  }

  String _buildBillNumber({
    required String typeCode,
    required String periodId,
    required String kkNumber,
  }) {
    final suffix = kkNumber.length >= 4
        ? kkNumber.substring(kkNumber.length - 4)
        : kkNumber;
    return 'IUR-${typeCode.toUpperCase()}-${periodId.substring(0, 4).toUpperCase()}-$suffix';
  }

  String _slugify(String value) {
    final lower = value.trim().toLowerCase();
    final sanitized = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    return sanitized.replaceAll(RegExp(r'^_+|_+$'), '');
  }

  String _orFilter(String field, List<String> ids) {
    return ids
        .where((id) => id.trim().isNotEmpty)
        .map((id) => '$field = "${_escapeFilterValue(id)}"')
        .join(' || ');
  }

  String _escapeFilterValue(String value) {
    return value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
  }

  Future<void> _assertNoBlockingPayment(String billId) async {
    final paymentRecords = await pb
        .collection(AppConstants.colIuranPayments)
        .getFullList(
          sort: '-created',
          filter: 'bill = "${_escapeFilterValue(billId)}"',
        );
    if (paymentRecords.isEmpty) {
      return;
    }

    final latestPayment = IuranPaymentModel.fromRecord(paymentRecords.first);
    if (latestPayment.isSubmitted) {
      throw Exception('Bukti transfer masih menunggu verifikasi admin.');
    }
    if (latestPayment.isVerified) {
      throw Exception('Tagihan ini sudah tercatat lunas.');
    }
  }

  IuranBillModel _deriveBillStateFromPayments(
    IuranBillModel bill,
    List<IuranPaymentModel> payments,
  ) {
    if (payments.isEmpty) {
      return bill;
    }

    final latestPayment = payments.first;
    if (latestPayment.isVerified) {
      return bill.copyWith(
        status: AppConstants.iuranBillPaid,
        paymentMethod: latestPayment.method,
        payerNote: latestPayment.note ?? bill.payerNote,
        submittedBy: latestPayment.submittedBy,
        submittedAt: latestPayment.submittedAt,
        verifiedBy: latestPayment.verifiedBy,
        verifiedAt: latestPayment.verifiedAt,
        rejectionNote: '',
        paidAt: latestPayment.verifiedAt ?? latestPayment.submittedAt,
        updated: latestPayment.updated ?? bill.updated,
      );
    }
    if (latestPayment.isSubmitted) {
      return bill.copyWith(
        status: AppConstants.iuranBillSubmittedVerification,
        paymentMethod: latestPayment.method,
        payerNote: latestPayment.note ?? bill.payerNote,
        submittedBy: latestPayment.submittedBy,
        submittedAt: latestPayment.submittedAt,
        rejectionNote: '',
        updated: latestPayment.updated ?? bill.updated,
      );
    }
    if (latestPayment.isRejected && !bill.isPaid) {
      return bill.copyWith(
        status: AppConstants.iuranBillRejectedPayment,
        paymentMethod: latestPayment.method,
        payerNote: latestPayment.note ?? bill.payerNote,
        submittedBy: latestPayment.submittedBy,
        submittedAt: latestPayment.submittedAt,
        verifiedBy: latestPayment.verifiedBy,
        verifiedAt: latestPayment.verifiedAt,
        rejectionNote:
            latestPayment.rejectionNote ??
            latestPayment.reviewNote ??
            bill.rejectionNote,
        updated: latestPayment.updated ?? bill.updated,
      );
    }

    return bill;
  }

  Future<Map<String, FinanceTransactionModel>> _loadFinanceTransactionsByBillId(
    Map<String, List<IuranPaymentModel>> paymentsByBill,
  ) async {
    if (paymentsByBill.isEmpty) {
      return const {};
    }
    final profile = await _ref
        .read(workspaceAccessServiceProvider)
        .getCurrentAccessProfile();
    if (profile == null) {
      return const {};
    }

    final latestPaymentByBill = <String, IuranPaymentModel>{};
    for (final entry in paymentsByBill.entries) {
      if (entry.value.isNotEmpty) {
        latestPaymentByBill[entry.key] = entry.value.first;
      }
    }
    final sourceReferences = latestPaymentByBill.values
        .map((payment) => payment.id)
        .where((id) => id.trim().isNotEmpty)
        .toList(growable: false);
    if (sourceReferences.isEmpty) {
      return const {};
    }

    final records = await pb
        .collection(AppConstants.colFinanceTransactions)
        .getFullList(
          sort: '-created',
          filter: [
            'workspace = "${_escapeFilterValue(profile.workspace.id)}"',
            'source_module = "iuran"',
            '(${_orFilter('source_reference', sourceReferences)})',
          ].join(' && '),
        );

    final financeBySourceReference = <String, FinanceTransactionModel>{};
    for (final record in records) {
      final transaction = FinanceTransactionModel.fromRecord(record);
      if ((transaction.sourceReference ?? '').isNotEmpty) {
        financeBySourceReference[transaction.sourceReference!] = transaction;
      }
    }

    final financeByBillId = <String, FinanceTransactionModel>{};
    for (final entry in latestPaymentByBill.entries) {
      final transaction = financeBySourceReference[entry.value.id];
      if (transaction != null) {
        financeByBillId[entry.key] = transaction;
      }
    }
    return financeByBillId;
  }

  Future<void> publishFinanceForBill(
    AuthState auth,
    String billId, {
    String? announcementTitle,
    String? announcementContent,
  }) async {
    _assertAdminAccess(auth);
    final billRecord = await _loadAuthorizedBillRecord(auth, billId);
    final bill = IuranBillModel.fromRecord(billRecord);
    final payment = await _loadLatestVerifiedPayment(bill.id);
    if (payment == null) {
      throw Exception(
        'Pembayaran terverifikasi untuk tagihan ini belum ditemukan.',
      );
    }

    final financeService = _ref.read(financeServiceProvider);
    final transaction = await financeService.getTransactionBySourceReference(
      sourceModule: 'iuran',
      sourceReference: payment.id,
    );
    if (transaction == null) {
      throw Exception(
        'Ledger finance untuk tagihan iuran ini belum tersedia. Verifikasi ulang pembayaran atau cek akun kas unit.',
      );
    }

    await financeService.publishTransaction(
      transactionId: transaction.id,
      announcementTitle: announcementTitle,
      announcementContent: announcementContent,
    );
  }

  Future<void> publishPeriodSummary(
    AuthState auth,
    String periodId, {
    String? announcementTitle,
    String? announcementContent,
  }) async {
    _assertAdminAccess(auth);
    await _assertIuranWorkspaceManagerAccess(auth);
    final profile = await _requireProfile();
    final access = await resolveAreaAccessContext(auth);
    final viewerAuth = await _effectiveViewerAuth(auth);
    final periodRecord = await pb
        .collection(AppConstants.colIuranPeriods)
        .getOne(periodId);
    final period = IuranPeriodModel.fromRecord(periodRecord);

    final billRecords = await pb
        .collection(AppConstants.colIuranBills)
        .getFullList(
          sort: '-updated,-created',
          filter: [
            buildIuranBillScopeFilter(viewerAuth, context: access),
            'period = "${_escapeFilterValue(periodId)}"',
          ].join(' && '),
        );
    if (billRecords.isEmpty) {
      throw Exception(
        'Tidak ada data tagihan iuran yang dapat dipublikasikan untuk periode ini.',
      );
    }

    final bills = billRecords
        .map(IuranBillModel.fromRecord)
        .toList(growable: false);
    final paymentsByBill = <String, List<IuranPaymentModel>>{};
    final paymentRecords = await pb
        .collection(AppConstants.colIuranPayments)
        .getFullList(
          sort: '-created',
          filter: _orFilter('bill', bills.map((item) => item.id).toList()),
        );
    for (final record in paymentRecords) {
      final payment = IuranPaymentModel.fromRecord(record);
      paymentsByBill.putIfAbsent(payment.billId, () => []).add(payment);
    }
    for (final entry in paymentsByBill.entries) {
      entry.value.sort((a, b) => b.timelineAt.compareTo(a.timelineAt));
    }

    final enrichedBills = bills
        .map(
          (bill) => _deriveBillStateFromPayments(
            bill,
            paymentsByBill[bill.id] ?? const [],
          ),
        )
        .toList(growable: false);

    final totalTarget = enrichedBills.length;
    final paidCount = enrichedBills.where((item) => item.isPaid).length;
    final unpaidCount = totalTarget - paidCount;
    final totalCollected = enrichedBills
        .where((item) => item.isPaid)
        .fold<int>(0, (sum, item) => sum + item.amount);
    final completionPercent = totalTarget == 0
        ? 0
        : ((paidCount / totalTarget) * 100).round();

    final orgUnits = await _ref
        .read(workspaceAccessServiceProvider)
        .getOrgUnits(profile.workspace.id);
    final targetUnit = _pickIuranAnnouncementUnit(
      orgUnits: orgUnits,
      period: period,
      bills: enrichedBills,
    );
    final title = (announcementTitle ?? 'Rekap ${period.title}').trim();
    final content =
        (announcementContent ??
                _buildPeriodSummaryAnnouncement(
                  period: period,
                  totalTarget: totalTarget,
                  paidCount: paidCount,
                  unpaidCount: unpaidCount,
                  totalCollected: totalCollected,
                  completionPercent: completionPercent,
                ))
            .trim();

    await pb
        .collection(AppConstants.colAnnouncements)
        .create(
          body: {
            'workspace': profile.workspace.id,
            if (targetUnit != null) 'org_unit': targetUnit.id,
            'author': auth.user!.id,
            'title': title,
            'content': content,
            'target_type': (period.rt ?? 0) > 0 ? 'rt' : 'rw',
            'rt': period.rt ?? 0,
            'rw': period.rw ?? profile.workspace.rw,
            'source_module': 'iuran',
            'publish_state': 'published',
            'published_by_member': profile.member.id,
            'is_published': true,
            'desa_code': period.desaCode ?? profile.workspace.desaCode ?? '',
            'kecamatan_code':
                period.kecamatanCode ?? profile.workspace.kecamatanCode ?? '',
            'kabupaten_code':
                period.kabupatenCode ?? profile.workspace.kabupatenCode ?? '',
            'provinsi_code':
                period.provinsiCode ?? profile.workspace.provinsiCode ?? '',
            'desa_kelurahan':
                period.desaKelurahan ?? profile.workspace.desaKelurahan ?? '',
            'kecamatan': period.kecamatan ?? profile.workspace.kecamatan ?? '',
            'kabupaten_kota':
                period.kabupatenKota ?? profile.workspace.kabupatenKota ?? '',
            'provinsi': period.provinsi ?? profile.workspace.provinsi ?? '',
          },
        );
  }

  Future<IuranPaymentModel?> _loadLatestVerifiedPayment(String billId) async {
    final records = await pb
        .collection(AppConstants.colIuranPayments)
        .getFullList(
          sort: '-verified_at,-created',
          filter:
              'bill = "${_escapeFilterValue(billId)}" && status = "${AppConstants.iuranPaymentVerified}"',
        );
    if (records.isEmpty) {
      return null;
    }
    return IuranPaymentModel.fromRecord(records.first);
  }

  String _buildPeriodSummaryAnnouncement({
    required IuranPeriodModel period,
    required int totalTarget,
    required int paidCount,
    required int unpaidCount,
    required int totalCollected,
    required int completionPercent,
  }) {
    final lines = <String>[
      'Ringkasan iuran ${period.title}.',
      'Target KK: $totalTarget KK.',
      'Sudah lunas: $paidCount KK.',
      'Belum lunas: $unpaidCount KK.',
      'Total nominal masuk: ${Formatters.rupiah(totalCollected)}.',
      'Tingkat penyelesaian: $completionPercent%.',
    ];
    if (period.dueDate != null) {
      lines.add(
        'Batas pembayaran: ${Formatters.tanggalPendek(period.dueDate!)}.',
      );
    }
    return lines.join('\n');
  }

  Future<_IuranFinanceEnsureResult> _ensureFinanceTransactionForPayment({
    required AuthState auth,
    required IuranBillModel bill,
    required IuranPaymentModel payment,
    required String note,
    _IuranPostingContext? postingContext,
  }) async {
    final context =
        postingContext ??
        await _preparePostingContext(bill: bill, paymentMethod: payment.method);
    final financeService = _ref.read(financeServiceProvider);
    final existing = await financeService.getTransactionBySourceReference(
      sourceModule: 'iuran',
      sourceReference: payment.id,
    );
    if (existing != null) {
      return _IuranFinanceEnsureResult(transaction: existing, created: false);
    }

    final title =
        'Iuran ${bill.typeLabel} - ${bill.kkHolderName?.trim().isNotEmpty == true ? bill.kkHolderName : bill.kkNumber}';
    final descriptionParts = <String>[
      'Tagihan ${bill.title}',
      'No. KK ${bill.kkNumber}',
      if ((bill.kkHolderName ?? '').trim().isNotEmpty)
        'Kepala KK ${bill.kkHolderName}',
      if (note.trim().isNotEmpty) 'Catatan: ${note.trim()}',
    ];

    final transaction = await financeService.createRecordedIncomingTransaction(
      orgUnitId: context.targetUnit.id,
      accountId: context.account!.id,
      category: 'iuran',
      title: title,
      amount: payment.amount,
      paymentMethod: payment.method,
      sourceModule: 'iuran',
      sourceReference: payment.id,
      description: descriptionParts.join(' - '),
    );
    return _IuranFinanceEnsureResult(transaction: transaction, created: true);
  }

  Future<void> _assertIuranWorkspaceManagerAccess(AuthState auth) async {
    _assertAdminAccess(auth);
    final profile = await _requireProfile();
    if (profile.member.isSysadmin) {
      return;
    }
    if (!profile.member.hasActiveSubscription) {
      throw Exception(
        'Subscription operator belum aktif. Kelola iuran dikunci sampai subscription aktif.',
      );
    }
    final canManageAnyIuran = profile.orgMemberships.any(
      (membership) => membership.isActive && membership.canManageIuran,
    );
    if (!canManageAnyIuran) {
      throw Exception(
        'Anda tidak memiliki hak kelola iuran pada workspace ini.',
      );
    }
  }

  Future<void> _assertCanRecordOrVerifyBillPayment(
    AuthState auth,
    IuranBillModel bill,
  ) async {
    _assertAdminAccess(auth);
    final context = await _preparePostingContext(
      bill: bill,
      paymentMethod: bill.paymentMethod ?? AppConstants.iuranMethodTransfer,
      requireAccount: false,
    );
    if (context.profile.member.isSysadmin) {
      return;
    }
    if (!context.profile.member.hasActiveSubscription) {
      throw Exception(
        'Subscription operator belum aktif. Verifikasi iuran harus dilakukan pengurus lain yang aktif atau RW.',
      );
    }
    final canManage = context.profile.canManageIuranForUnit(
      context.targetUnit.id,
    );
    final canVerify = context.profile.canVerifyIuranForUnit(
      context.targetUnit.id,
    );
    if (!canManage && !canVerify) {
      throw Exception(
        'Anda tidak memiliki hak verifikasi pembayaran iuran untuk unit ${context.targetUnit.name}.',
      );
    }
  }

  Future<void> _assertNotSelfHandledPayment(
    AuthState auth,
    IuranBillModel bill, {
    IuranPaymentModel? payment,
  }) async {
    if (auth.user == null) {
      return;
    }
    final area = await resolveAreaAccessContext(auth);
    final isOwnBill = (area.kkId ?? '').isNotEmpty && area.kkId == bill.kkId;
    final isOwnSubmission =
        payment != null && payment.submittedBy == auth.user!.id;
    if (isOwnBill || isOwnSubmission) {
      throw Exception(
        'Pembayaran untuk KK Anda sendiri harus diverifikasi pengurus lain atau diekskalasi ke RW.',
      );
    }
  }

  Future<_IuranPostingContext> _preparePostingContext({
    required IuranBillModel bill,
    required String paymentMethod,
    bool requireAccount = true,
  }) async {
    final profile = await _requireProfile();
    final orgUnits = await _ref
        .read(workspaceAccessServiceProvider)
        .getOrgUnits(profile.workspace.id);
    final targetUnit = _pickIuranOrgUnit(orgUnits, bill);
    if (targetUnit == null) {
      throw Exception(
        'Unit organisasi untuk tagihan iuran ini belum ditemukan. Pastikan unit RT/RW resmi tersedia.',
      );
    }

    final accounts = await _ref.read(financeServiceProvider).getAccounts();
    final account = _pickFinanceAccount(
      accounts: accounts,
      orgUnits: orgUnits,
      targetUnit: targetUnit,
      paymentMethod: paymentMethod,
    );
    if (requireAccount && account == null) {
      throw Exception(
        'Akun kas aktif untuk unit ${targetUnit.name} belum tersedia. Tambahkan dulu di menu Keuangan > Kelola Akun Kas.',
      );
    }

    return _IuranPostingContext(
      profile: profile,
      targetUnit: targetUnit,
      account: account,
    );
  }

  Future<WorkspaceAccessProfile> _requireProfile() async {
    final profile = await _ref
        .read(workspaceAccessServiceProvider)
        .getCurrentAccessProfile();
    if (profile == null) {
      throw Exception('Workspace aktif belum tersedia.');
    }
    return profile;
  }

  Future<void> _rollbackRecordedCashPayment({
    required String paymentId,
    required _IuranFinanceEnsureResult? financeResult,
  }) async {
    if (financeResult?.created == true) {
      try {
        await pb
            .collection(AppConstants.colFinanceTransactions)
            .delete(financeResult!.transaction.id);
      } catch (_) {}
    }
    try {
      await pb.collection(AppConstants.colIuranPayments).delete(paymentId);
    } catch (_) {}
  }

  Future<void> _rollbackVerifiedPayment({
    required IuranPaymentModel payment,
    required _IuranFinanceEnsureResult? financeResult,
  }) async {
    if (financeResult?.created == true) {
      try {
        await pb
            .collection(AppConstants.colFinanceTransactions)
            .delete(financeResult!.transaction.id);
      } catch (_) {}
    }
    try {
      await pb
          .collection(AppConstants.colIuranPayments)
          .update(
            payment.id,
            body: {
              'status': AppConstants.iuranPaymentSubmitted,
              'review_note': payment.reviewNote ?? '',
              'verified_by': '',
              'verified_at': '',
              'rejection_note': '',
            },
          );
    } catch (_) {}
  }

  FinanceAccountModel? _pickFinanceAccount({
    required List<FinanceAccountModel> accounts,
    required List<OrgUnitModel> orgUnits,
    required OrgUnitModel targetUnit,
    required String paymentMethod,
  }) {
    FinanceAccountModel? byUnitAndType(String unitId, String type) {
      for (final account in accounts) {
        if (account.orgUnitId == unitId && account.type == type) {
          return account;
        }
      }
      return null;
    }

    FinanceAccountModel? byUnit(String unitId) {
      for (final account in accounts) {
        if (account.orgUnitId == unitId) {
          return account;
        }
      }
      return null;
    }

    final preferredType = paymentMethod == AppConstants.iuranMethodTransfer
        ? 'bank'
        : 'cash';
    final direct =
        byUnitAndType(targetUnit.id, preferredType) ?? byUnit(targetUnit.id);
    if (direct != null) {
      return direct;
    }

    OrgUnitModel? fallbackRwUnit;
    for (final unit in orgUnits) {
      if (unit.type == AppConstants.unitTypeRw &&
          unit.scopeRw != null &&
          unit.scopeRw == targetUnit.scopeRw) {
        fallbackRwUnit = unit;
        break;
      }
    }
    if (fallbackRwUnit != null) {
      return byUnitAndType(fallbackRwUnit.id, preferredType) ??
          byUnit(fallbackRwUnit.id);
    }

    for (final account in accounts) {
      if (account.type == preferredType) {
        return account;
      }
    }
    return accounts.isNotEmpty ? accounts.first : null;
  }

  OrgUnitModel? _pickIuranAnnouncementUnit({
    required List<OrgUnitModel> orgUnits,
    required IuranPeriodModel period,
    required List<IuranBillModel> bills,
  }) {
    if (bills.isNotEmpty) {
      final fromBill = _pickIuranOrgUnit(orgUnits, bills.first);
      if (fromBill != null) {
        return fromBill;
      }
    }

    for (final unit in orgUnits) {
      if ((period.rt ?? 0) > 0 &&
          unit.type == AppConstants.unitTypeRt &&
          unit.scopeRw == (period.rw ?? 0) &&
          unit.scopeRt == period.rt &&
          unit.status == 'active') {
        return unit;
      }
    }
    for (final unit in orgUnits) {
      if (unit.type == AppConstants.unitTypeRw &&
          unit.scopeRw == (period.rw ?? 0) &&
          unit.status == 'active') {
        return unit;
      }
    }
    return null;
  }

  OrgUnitModel? _pickIuranOrgUnit(
    List<OrgUnitModel> orgUnits,
    IuranBillModel bill,
  ) {
    for (final unit in orgUnits) {
      if (bill.rt != null &&
          bill.rt! > 0 &&
          unit.type == AppConstants.unitTypeRt &&
          unit.scopeRw == (bill.rw ?? 0) &&
          unit.scopeRt == bill.rt &&
          unit.status == 'active') {
        return unit;
      }
    }
    for (final unit in orgUnits) {
      if (unit.type == AppConstants.unitTypeRw &&
          unit.scopeRw == (bill.rw ?? 0) &&
          unit.status == 'active') {
        return unit;
      }
    }
    return null;
  }
}

final iuranServiceProvider = Provider<IuranService>((ref) => IuranService(ref));
