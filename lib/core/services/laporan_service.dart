import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../shared/models/dokumen_model.dart';
import '../../shared/models/iuran_model.dart';
import '../../shared/models/kartu_keluarga_model.dart';
import '../../shared/models/surat_model.dart';
import '../../shared/models/warga_model.dart';
import '../constants/app_constants.dart';
import '../services/pocketbase_service.dart';
import '../utils/area_access.dart';
import 'iuran_service.dart';
import 'surat_service.dart';

enum LaporanRangePreset { today, week, month, year }

extension LaporanRangePresetX on LaporanRangePreset {
  String get label {
    switch (this) {
      case LaporanRangePreset.today:
        return 'Hari Ini';
      case LaporanRangePreset.week:
        return '7 Hari';
      case LaporanRangePreset.month:
        return 'Bulan Ini';
      case LaporanRangePreset.year:
        return 'Tahun Ini';
    }
  }
}

class DokumenDashboardSummary {
  const DokumenDashboardSummary({
    required this.total,
    required this.pending,
    required this.needRevision,
    required this.verified,
    required this.rejected,
  });

  final int total;
  final int pending;
  final int needRevision;
  final int verified;
  final int rejected;
}

class MutasiDashboardSummary {
  const MutasiDashboardSummary({
    required this.total,
    required this.masuk,
    required this.keluar,
    required this.kematian,
    required this.perubahanKk,
  });

  final int total;
  final int masuk;
  final int keluar;
  final int kematian;
  final int perubahanKk;
}

class LaporanOperationalData {
  const LaporanOperationalData({
    required this.role,
    required this.preset,
    required this.startedAt,
    required this.endedAt,
    required this.wargaRecords,
    required this.kkRecords,
    required this.suratData,
    required this.filteredSurat,
    required this.iuranData,
    required this.filteredBills,
    required this.filteredPendingPayments,
    required this.filteredDokumen,
    required this.dokumenWargaById,
    required this.mutasiRequests,
  });

  final String role;
  final LaporanRangePreset preset;
  final DateTime startedAt;
  final DateTime endedAt;
  final List<WargaModel> wargaRecords;
  final List<KartuKeluargaModel> kkRecords;
  final SuratListData suratData;
  final List<SuratModel> filteredSurat;
  final IuranListData iuranData;
  final List<IuranBillModel> filteredBills;
  final List<IuranPaymentModel> filteredPendingPayments;
  final List<DokumenModel> filteredDokumen;
  final Map<String, WargaModel> dokumenWargaById;
  final List<SuratModel> mutasiRequests;

  SuratDashboardSummary get suratSummary {
    final requests = filteredSurat;
    final normalizedRole = AppConstants.normalizeRole(role);
    int actionRequired = 0;
    for (final request in requests) {
      final needsAction = switch (normalizedRole) {
        AppConstants.roleAdminRt =>
          request.isSubmitted ||
              (!request.requiresRwApproval && request.isApprovedRt),
        AppConstants.roleAdminRw ||
        AppConstants.roleAdminRwPro ||
        AppConstants.roleSysadmin =>
          request.isForwardedToRw || request.isApprovedRw,
        _ => false,
      };
      if (needsAction) {
        actionRequired += 1;
      }
    }

    return SuratDashboardSummary(
      total: requests.length,
      submitted: requests.where((item) => item.isSubmitted).length,
      needRevision: requests.where((item) => item.isNeedRevision).length,
      forwardedToRw: requests.where((item) => item.isForwardedToRw).length,
      approved: requests
          .where((item) => item.isApprovedRt || item.isApprovedRw)
          .length,
      completed: requests.where((item) => item.isCompleted).length,
      rejected: requests.where((item) => item.isRejected).length,
      actionRequired: actionRequired,
    );
  }

  IuranDashboardSummary get iuranSummary {
    final bills = filteredBills;
    final totalTagihan = bills.fold<int>(0, (sum, item) => sum + item.amount);
    final totalLunas = bills
        .where((item) => item.isPaid)
        .fold<int>(0, (sum, item) => sum + item.amount);
    final totalTunggakan = bills
        .where((item) => !item.isPaid)
        .fold<int>(0, (sum, item) => sum + item.amount);

    return IuranDashboardSummary(
      totalBills: bills.length,
      paidBills: bills.where((item) => item.isPaid).length,
      outstandingBills: bills.where((item) => !item.isPaid).length,
      pendingVerificationBills: bills
          .where((item) => item.isSubmittedVerification)
          .length,
      totalTagihan: totalTagihan,
      totalLunas: totalLunas,
      totalTunggakan: totalTunggakan,
    );
  }

  DokumenDashboardSummary get dokumenSummary {
    return DokumenDashboardSummary(
      total: filteredDokumen.length,
      pending: filteredDokumen.where((item) => item.isPending).length,
      needRevision: filteredDokumen
          .where((item) => item.isNeedRevision)
          .length,
      verified: filteredDokumen.where((item) => item.isVerified).length,
      rejected: filteredDokumen.where((item) => item.isRejected).length,
    );
  }

  MutasiDashboardSummary get mutasiSummary {
    return MutasiDashboardSummary(
      total: mutasiRequests.length,
      masuk: mutasiMasuk.length,
      keluar: mutasiKeluar.length,
      kematian: mutasiKematian.length,
      perubahanKk: mutasiPerubahanKk.length,
    );
  }

  List<IuranBillModel> get unpaidBills =>
      filteredBills.where((item) => !item.isPaid).toList()
        ..sort((a, b) => _billTimeline(b).compareTo(_billTimeline(a)));

  List<IuranBillModel> get paidBills =>
      filteredBills.where((item) => item.isPaid).toList()
        ..sort((a, b) => _billTimeline(b).compareTo(_billTimeline(a)));

  List<IuranBillModel> get pendingVerificationBills =>
      filteredBills.where((item) => item.isSubmittedVerification).toList()
        ..sort((a, b) => _billTimeline(b).compareTo(_billTimeline(a)));

  List<IuranBillModel> get rejectedBills =>
      filteredBills.where((item) => item.isRejectedPayment).toList()
        ..sort((a, b) => _billTimeline(b).compareTo(_billTimeline(a)));

  List<SuratModel> get mutasiMasuk => _sortSurat(
    mutasiRequests
        .where((item) => item.jenisSurat == AppConstants.suratPindahDatang)
        .toList(),
  );

  List<SuratModel> get mutasiKeluar => _sortSurat(
    mutasiRequests
        .where((item) => item.jenisSurat == AppConstants.suratPindahKeluar)
        .toList(),
  );

  List<SuratModel> get mutasiKematian => _sortSurat(
    mutasiRequests
        .where(
          (item) =>
              item.jenisSurat == AppConstants.suratKematian ||
              item.jenisSurat == AppConstants.suratKematianLingkungan,
        )
        .toList(),
  );

  List<SuratModel> get mutasiPerubahanKk => _sortSurat(
    mutasiRequests
        .where(
          (item) =>
              item.jenisSurat == AppConstants.suratTambahAnggotaKk ||
              item.jenisSurat == AppConstants.suratPerubahanKk ||
              item.jenisSurat == AppConstants.suratPecahKk ||
              item.jenisSurat == AppConstants.suratGabungKk,
        )
        .toList(),
  );

  static DateTime _billTimeline(IuranBillModel bill) =>
      bill.dueDate ??
      bill.submittedAt ??
      bill.updated ??
      bill.created ??
      DateTime.now();

  static List<SuratModel> _sortSurat(List<SuratModel> data) {
    data.sort((a, b) {
      final aDate = a.submittedAt ?? a.updated ?? a.created ?? DateTime.now();
      final bDate = b.submittedAt ?? b.updated ?? b.created ?? DateTime.now();
      return bDate.compareTo(aDate);
    });
    return data;
  }
}

class LaporanService {
  final SuratService _suratService = SuratService();
  final IuranService _iuranService = IuranService();

  Future<LaporanOperationalData> fetchOperationalData(
    AuthState auth, {
    required LaporanRangePreset preset,
  }) async {
    if (auth.user == null || !AppConstants.isAdminRole(auth.role)) {
      throw Exception('Hanya admin yang dapat melihat laporan.');
    }

    final range = _rangeForPreset(preset);
    final access = await resolveAreaAccessContext(auth);

    final suratData = await _suratService.fetchList(auth);
    final iuranData = await _iuranService.fetchList(auth);

    final wargaRecords = await pb
        .collection(AppConstants.colWarga)
        .getFullList(
          sort: 'nama_lengkap',
          filter: buildWargaScopeFilter(auth, context: access),
        );
    final kkRecords = await pb
        .collection(AppConstants.colKartuKeluarga)
        .getFullList(
          sort: 'rw,rt,no_kk',
          filter: buildKkScopeFilter(auth, context: access),
        );

    final scopedWarga = {
      for (final record in wargaRecords) record.id: WargaModel.fromRecord(record),
    };

    final dokumenRecords = await pb
        .collection(AppConstants.colDokumen)
        .getFullList(sort: '-updated,-created');
    final filteredDokumen = dokumenRecords
        .map(DokumenModel.fromRecord)
        .where((item) => scopedWarga.containsKey(item.warga))
        .where(
          (item) => _matchesRange(
            item.updated ?? item.created,
            range.start,
            range.end,
          ),
        )
        .toList()
      ..sort(
        (a, b) =>
            (b.updated ?? b.created ?? DateTime.now()).compareTo(
              a.updated ?? a.created ?? DateTime.now(),
            ),
      );

    final filteredSurat = suratData.requests
        .where(
          (item) => _matchesRange(
            item.submittedAt ?? item.created ?? item.updated,
            range.start,
            range.end,
          ),
        )
        .toList()
      ..sort(
        (a, b) =>
            (b.submittedAt ?? b.updated ?? b.created ?? DateTime.now())
                .compareTo(
                  a.submittedAt ?? a.updated ?? a.created ?? DateTime.now(),
                ),
      );

    final filteredBills = iuranData.bills
        .where(
          (item) => _matchesRange(
            item.dueDate ?? item.updated ?? item.created,
            range.start,
            range.end,
          ),
        )
        .toList()
      ..sort(
        (a, b) =>
            (b.dueDate ?? b.updated ?? b.created ?? DateTime.now()).compareTo(
              a.dueDate ?? a.updated ?? a.created ?? DateTime.now(),
            ),
      );

    final filteredPendingPayments = iuranData.pendingPayments
        .where((item) => _matchesRange(item.timelineAt, range.start, range.end))
        .toList()
      ..sort((a, b) => b.timelineAt.compareTo(a.timelineAt));

    final mutasiRequests = filteredSurat
        .where((item) => _mutasiSuratCodes.contains(item.jenisSurat))
        .toList();

    return LaporanOperationalData(
      role: auth.role,
      preset: preset,
      startedAt: range.start,
      endedAt: range.end,
      wargaRecords: scopedWarga.values.toList(),
      kkRecords: kkRecords.map(KartuKeluargaModel.fromRecord).toList(),
      suratData: suratData,
      filteredSurat: filteredSurat,
      iuranData: iuranData,
      filteredBills: filteredBills,
      filteredPendingPayments: filteredPendingPayments,
      filteredDokumen: filteredDokumen,
      dokumenWargaById: scopedWarga,
      mutasiRequests: mutasiRequests,
    );
  }

  ({DateTime start, DateTime end}) _rangeForPreset(LaporanRangePreset preset) {
    final now = DateTime.now();
    switch (preset) {
      case LaporanRangePreset.today:
        final start = DateTime(now.year, now.month, now.day);
        return (start: start, end: now);
      case LaporanRangePreset.week:
        return (start: now.subtract(const Duration(days: 7)), end: now);
      case LaporanRangePreset.month:
        final start = DateTime(now.year, now.month, 1);
        return (start: start, end: now);
      case LaporanRangePreset.year:
        final start = DateTime(now.year, 1, 1);
        return (start: start, end: now);
    }
  }

  bool _matchesRange(DateTime? value, DateTime start, DateTime end) {
    if (value == null) {
      return false;
    }
    return !value.isBefore(start) && !value.isAfter(end);
  }

  static const Set<String> _mutasiSuratCodes = {
    AppConstants.suratPindahDatang,
    AppConstants.suratPindahKeluar,
    AppConstants.suratPecahKk,
    AppConstants.suratGabungKk,
    AppConstants.suratTambahAnggotaKk,
    AppConstants.suratPerubahanKk,
    AppConstants.suratKematian,
    AppConstants.suratKematianLingkungan,
  };
}

final laporanServiceProvider = Provider<LaporanService>(
  (ref) => LaporanService(),
);
