import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../shared/models/kartu_keluarga_model.dart';
import '../../shared/models/surat_model.dart';
import '../../shared/models/warga_model.dart';
import '../constants/app_constants.dart';
import '../services/pocketbase_service.dart';
import '../utils/area_access.dart';

class SuratListData {
  const SuratListData({
    required this.requests,
    required this.wargaById,
    required this.myWargaId,
  });

  final List<SuratModel> requests;
  final Map<String, WargaModel> wargaById;
  final String? myWargaId;
}

class SuratDetailData {
  const SuratDetailData({
    required this.requestRecord,
    required this.request,
    required this.attachments,
    required this.logs,
    this.warga,
    this.kk,
  });

  final RecordModel requestRecord;
  final SuratModel request;
  final List<SuratAttachmentModel> attachments;
  final List<SuratLogModel> logs;
  final WargaModel? warga;
  final KartuKeluargaModel? kk;
}

class SuratDashboardSummary {
  const SuratDashboardSummary({
    required this.total,
    required this.submitted,
    required this.needRevision,
    required this.forwardedToRw,
    required this.approved,
    required this.completed,
    required this.rejected,
    required this.actionRequired,
  });

  final int total;
  final int submitted;
  final int needRevision;
  final int forwardedToRw;
  final int approved;
  final int completed;
  final int rejected;
  final int actionRequired;
}

class SuratNotificationItem {
  const SuratNotificationItem({
    required this.log,
    required this.request,
    required this.wargaName,
  });

  final SuratLogModel log;
  final SuratModel request;
  final String wargaName;
}

class SuratSubmitPayload {
  const SuratSubmitPayload({
    required this.typeCode,
    required this.purpose,
    required this.dynamicValues,
    this.notes = '',
    this.requestId,
    this.attachments = const [],
  });

  final String typeCode;
  final String purpose;
  final Map<String, String> dynamicValues;
  final String notes;
  final String? requestId;
  final List<PlatformFile> attachments;
}

class SuratReviewAction {
  const SuratReviewAction({required this.requestId, required this.note});

  final String requestId;
  final String note;
}

class SuratFinalizePayload {
  const SuratFinalizePayload({
    required this.requestId,
    required this.outputNumber,
    required this.file,
    this.note = '',
  });

  final String requestId;
  final String outputNumber;
  final PlatformFile file;
  final String note;
}

class SuratService {
  Future<SuratListData> fetchList(AuthState auth) async {
    if (auth.user == null) {
      return const SuratListData(requests: [], wargaById: {}, myWargaId: null);
    }

    final access = await resolveAreaAccessContext(auth);
    final records = await pb
        .collection(AppConstants.colSurat)
        .getFullList(
          sort: '-updated,-created',
          filter: buildSuratScopeFilter(auth, context: access),
        );

    final wargaRecords = await pb
        .collection(AppConstants.colWarga)
        .getFullList(
          sort: 'nama_lengkap',
          filter: buildWargaScopeFilter(auth, context: access),
        );

    return SuratListData(
      requests: records.map(SuratModel.fromRecord).toList(),
      wargaById: {
        for (final record in wargaRecords)
          record.id: WargaModel.fromRecord(record),
      },
      myWargaId: access.wargaId,
    );
  }

  Future<SuratDetailData> getDetail(AuthState auth, String requestId) async {
    final requestRecord = await _loadAuthorizedRequestRecord(auth, requestId);
    final request = SuratModel.fromRecord(requestRecord);

    WargaModel? warga;
    KartuKeluargaModel? kk;

    if (request.wargaId.isNotEmpty) {
      try {
        final wargaRecord = await pb
            .collection(AppConstants.colWarga)
            .getOne(request.wargaId);
        warga = WargaModel.fromRecord(wargaRecord);
      } catch (_) {}
    }

    if (request.kkId.isNotEmpty) {
      try {
        final kkRecord = await pb
            .collection(AppConstants.colKartuKeluarga)
            .getOne(request.kkId);
        kk = KartuKeluargaModel.fromRecord(kkRecord);
      } catch (_) {}
    }

    final attachments = await pb
        .collection(AppConstants.colSuratAttachments)
        .getFullList(sort: 'created', filter: 'request = "$requestId"');

    final logs = await pb
        .collection(AppConstants.colSuratLogs)
        .getFullList(sort: '-created', filter: 'request = "$requestId"');

    return SuratDetailData(
      requestRecord: requestRecord,
      request: request,
      attachments: attachments.map(SuratAttachmentModel.fromRecord).toList(),
      logs: logs.map(SuratLogModel.fromRecord).toList(),
      warga: warga,
      kk: kk,
    );
  }

  Future<SuratDashboardSummary> fetchDashboardSummary(AuthState auth) async {
    final listData = await fetchList(auth);
    final role = AppConstants.normalizeRole(auth.role);
    final requests = listData.requests;

    int actionRequired = 0;
    for (final request in requests) {
      final needsAction = switch (role) {
        AppConstants.roleWarga => request.isNeedRevision,
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

  Future<List<SuratNotificationItem>> fetchNotifications(
    AuthState auth, {
    int limit = 40,
  }) async {
    final listData = await fetchList(auth);
    if (listData.requests.isEmpty) {
      return const [];
    }

    final requestsById = {
      for (final request in listData.requests) request.id: request,
    };

    final logs = await pb
        .collection(AppConstants.colSuratLogs)
        .getFullList(sort: '-created');

    final items = <SuratNotificationItem>[];
    for (final logRecord in logs) {
      final log = SuratLogModel.fromRecord(logRecord);
      final request = requestsById[log.requestId];
      if (request == null) {
        continue;
      }
      items.add(
        SuratNotificationItem(
          log: log,
          request: request,
          wargaName:
              listData.wargaById[request.wargaId]?.namaLengkap ?? 'Warga',
        ),
      );
      if (items.length >= limit) {
        break;
      }
    }
    return items;
  }

  Future<String> submitRequest(
    AuthState auth,
    SuratSubmitPayload payload,
  ) async {
    if (auth.user == null) {
      throw Exception('User belum login.');
    }

    final access = await resolveAreaAccessContext(auth);
    final wargaId = access.wargaId ?? '';
    if (wargaId.isEmpty) {
      throw Exception('Akun belum terhubung ke data warga.');
    }

    final config = AppConstants.suratTypeOption(payload.typeCode);
    final normalizedPayload = <String, dynamic>{};
    for (final field in config.fields) {
      final value = (payload.dynamicValues[field.key] ?? '').trim();
      if (field.required && value.isEmpty) {
        throw Exception('${field.label} wajib diisi.');
      }
      normalizedPayload[field.key] = value;
    }

    final body = <String, dynamic>{
      'warga': wargaId,
      'kk': access.kkId ?? '',
      'jenis_surat': config.code,
      'category': config.category,
      'title': config.label,
      'purpose': payload.purpose.trim(),
      'status': AppConstants.suratSubmitted,
      'approval_level': config.approvalLevel,
      'submitted_by': auth.user!.id,
      'submitted_at': DateTime.now().toIso8601String(),
      'request_payload': jsonEncode(normalizedPayload),
      'applicant_note': payload.notes.trim(),
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
    };

    String requestId = payload.requestId ?? '';
    if (requestId.isEmpty) {
      final created = await pb
          .collection(AppConstants.colSurat)
          .create(body: body);
      requestId = created.id;
      await _addLog(
        requestId: requestId,
        actorId: auth.user!.id,
        action: 'submitted',
        description: 'Pengajuan surat dibuat oleh warga.',
      );
    } else {
      final existing = await _loadAuthorizedRequestRecord(auth, requestId);
      final existingRequest = SuratModel.fromRecord(existing);
      if (existingRequest.submittedBy != auth.user!.id) {
        throw Exception('Anda tidak bisa mengubah pengajuan ini.');
      }
      await pb.collection(AppConstants.colSurat).update(requestId, body: body);
      await _addLog(
        requestId: requestId,
        actorId: auth.user!.id,
        action: 'resubmitted',
        description: 'Pengajuan surat diperbarui dan dikirim ulang.',
      );
    }

    for (final file in payload.attachments) {
      final multipart = _toMultipartFile('file', file);
      await pb
          .collection(AppConstants.colSuratAttachments)
          .create(
            body: {'request': requestId, 'label': file.name},
            files: [multipart],
          );
    }

    return requestId;
  }

  Future<void> requestRevision(AuthState auth, SuratReviewAction action) async {
    await _updateReviewStatus(
      auth,
      action,
      status: AppConstants.suratNeedRevision,
      rtDescription: 'Admin RT meminta revisi pengajuan surat.',
      rwDescription: 'Admin RW meminta revisi pengajuan surat.',
    );
  }

  Future<void> reject(AuthState auth, SuratReviewAction action) async {
    await _updateReviewStatus(
      auth,
      action,
      status: AppConstants.suratRejected,
      rtDescription: 'Admin RT menolak pengajuan surat.',
      rwDescription: 'Admin RW menolak pengajuan surat.',
    );
  }

  Future<void> approve(AuthState auth, SuratReviewAction action) async {
    final record = await _loadAuthorizedRequestRecord(auth, action.requestId);
    final request = SuratModel.fromRecord(record);
    final normalizedRole = AppConstants.normalizeRole(auth.role);

    if (!AppConstants.isAdminRole(normalizedRole)) {
      throw Exception('Hanya admin yang dapat memproses pengajuan surat.');
    }

    if (normalizedRole == AppConstants.roleAdminRt) {
      final nextStatus = request.requiresRwApproval
          ? AppConstants.suratForwardedToRw
          : AppConstants.suratApprovedRt;
      await pb
          .collection(AppConstants.colSurat)
          .update(
            action.requestId,
            body: {
              'status': nextStatus,
              'reviewed_by_rt': auth.user!.id,
              'reviewed_at_rt': DateTime.now().toIso8601String(),
              'review_note_rt': action.note.trim(),
            },
          );
      await _addLog(
        requestId: action.requestId,
        actorId: auth.user!.id,
        action: nextStatus,
        description: request.requiresRwApproval
            ? 'Admin RT menyetujui dan meneruskan surat ke RW.'
            : 'Admin RT menyetujui surat.',
      );
      return;
    }

    await pb
        .collection(AppConstants.colSurat)
        .update(
          action.requestId,
          body: {
            'status': AppConstants.suratApprovedRw,
            'reviewed_by_rw': auth.user!.id,
            'reviewed_at_rw': DateTime.now().toIso8601String(),
            'review_note_rw': action.note.trim(),
          },
        );
    await _addLog(
      requestId: action.requestId,
      actorId: auth.user!.id,
      action: AppConstants.suratApprovedRw,
      description: 'Admin RW menyetujui surat.',
    );
  }

  Future<void> finalize(AuthState auth, SuratFinalizePayload payload) async {
    if (auth.user == null) {
      throw Exception('User belum login.');
    }

    final requestRecord = await _loadAuthorizedRequestRecord(
      auth,
      payload.requestId,
    );
    final request = SuratModel.fromRecord(requestRecord);
    final normalizedRole = AppConstants.normalizeRole(auth.role);
    final canFinalizeAsRt =
        normalizedRole == AppConstants.roleAdminRt &&
        request.status == AppConstants.suratApprovedRt;
    final canFinalizeAsRw =
        (AppConstants.hasRwWideAccess(normalizedRole) ||
            AppConstants.isSysadminRole(normalizedRole)) &&
        (request.status == AppConstants.suratApprovedRw ||
            request.status == AppConstants.suratApprovedRt);

    if (!canFinalizeAsRt && !canFinalizeAsRw) {
      throw Exception('Surat belum siap difinalisasi pada tahap ini.');
    }

    final multipart = _toMultipartFile('output_file', payload.file);
    await pb
        .collection(AppConstants.colSurat)
        .update(
          payload.requestId,
          body: {
            'status': AppConstants.suratCompleted,
            'output_number': payload.outputNumber.trim(),
            'finalized_at': DateTime.now().toIso8601String(),
          },
          files: [multipart],
        );
    await _addLog(
      requestId: payload.requestId,
      actorId: auth.user!.id,
      action: AppConstants.suratCompleted,
      description: payload.note.trim().isEmpty
          ? 'Surat difinalisasi dan file hasil diunggah.'
          : payload.note.trim(),
    );
  }

  Future<void> _updateReviewStatus(
    AuthState auth,
    SuratReviewAction action, {
    required String status,
    required String rtDescription,
    required String rwDescription,
  }) async {
    if (auth.user == null) {
      throw Exception('User belum login.');
    }
    final normalizedRole = AppConstants.normalizeRole(auth.role);
    if (!AppConstants.isAdminRole(normalizedRole)) {
      throw Exception('Hanya admin yang dapat memproses pengajuan surat.');
    }
    await _loadAuthorizedRequestRecord(auth, action.requestId);
    final isRw =
        AppConstants.hasRwWideAccess(normalizedRole) &&
        normalizedRole != AppConstants.roleAdminRt;

    await pb
        .collection(AppConstants.colSurat)
        .update(
          action.requestId,
          body: {
            'status': status,
            if (isRw) ...{
              'reviewed_by_rw': auth.user!.id,
              'reviewed_at_rw': DateTime.now().toIso8601String(),
              'review_note_rw': action.note.trim(),
            } else ...{
              'reviewed_by_rt': auth.user!.id,
              'reviewed_at_rt': DateTime.now().toIso8601String(),
              'review_note_rt': action.note.trim(),
            },
          },
        );

    await _addLog(
      requestId: action.requestId,
      actorId: auth.user!.id,
      action: status,
      description: isRw ? rwDescription : rtDescription,
    );
  }

  Future<void> _addLog({
    required String requestId,
    required String actorId,
    required String action,
    required String description,
  }) async {
    await pb
        .collection(AppConstants.colSuratLogs)
        .create(
          body: {
            'request': requestId,
            'actor': actorId,
            'action': action,
            'description': description,
          },
        );
  }

  Future<RecordModel> _loadAuthorizedRequestRecord(
    AuthState auth,
    String requestId,
  ) async {
    final access = await resolveAreaAccessContext(auth);
    final requestRecord = await pb
        .collection(AppConstants.colSurat)
        .getOne(requestId);
    final request = SuratModel.fromRecord(requestRecord);
    if (!canAccessSuratRecord(auth, request, context: access)) {
      throw Exception('Anda tidak memiliki akses ke surat ini.');
    }
    return requestRecord;
  }

  http.MultipartFile _toMultipartFile(String fieldName, PlatformFile file) {
    final bytes = file.bytes;
    if (bytes == null) {
      throw Exception('File ${file.name} tidak dapat dibaca.');
    }
    return http.MultipartFile.fromBytes(fieldName, bytes, filename: file.name);
  }
}

final suratServiceProvider = Provider<SuratService>((ref) => SuratService());
