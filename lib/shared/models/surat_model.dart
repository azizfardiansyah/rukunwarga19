import 'dart:convert';

import 'package:pocketbase/pocketbase.dart';

import '../../core/constants/app_constants.dart';

class SuratModel {
  const SuratModel({
    required this.id,
    required this.record,
    required this.wargaId,
    required this.kkId,
    required this.jenisSurat,
    required this.category,
    required this.title,
    required this.purpose,
    required this.status,
    required this.approvalLevel,
    required this.submittedBy,
    required this.requestPayload,
    this.applicantNote,
    this.rt,
    this.rw,
    this.desaCode,
    this.kecamatanCode,
    this.kabupatenCode,
    this.provinsiCode,
    this.desaKelurahan,
    this.kecamatan,
    this.kabupatenKota,
    this.provinsi,
    this.submittedAt,
    this.reviewedByRt,
    this.reviewedAtRt,
    this.reviewNoteRt,
    this.reviewedByRw,
    this.reviewedAtRw,
    this.reviewNoteRw,
    this.outputNumber,
    this.outputFile,
    this.finalizedAt,
    this.created,
    this.updated,
  });

  final String id;
  final RecordModel record;
  final String wargaId;
  final String kkId;
  final String jenisSurat;
  final String category;
  final String title;
  final String purpose;
  final String status;
  final String approvalLevel;
  final String submittedBy;
  final Map<String, dynamic> requestPayload;
  final String? applicantNote;
  final int? rt;
  final int? rw;
  final String? desaCode;
  final String? kecamatanCode;
  final String? kabupatenCode;
  final String? provinsiCode;
  final String? desaKelurahan;
  final String? kecamatan;
  final String? kabupatenKota;
  final String? provinsi;
  final DateTime? submittedAt;
  final String? reviewedByRt;
  final DateTime? reviewedAtRt;
  final String? reviewNoteRt;
  final String? reviewedByRw;
  final DateTime? reviewedAtRw;
  final String? reviewNoteRw;
  final String? outputNumber;
  final String? outputFile;
  final DateTime? finalizedAt;
  final DateTime? created;
  final DateTime? updated;

  factory SuratModel.fromRecord(RecordModel record) {
    return SuratModel(
      id: record.id,
      record: record,
      wargaId: record.getStringValue('warga'),
      kkId: record.getStringValue('kk'),
      jenisSurat: record.getStringValue('jenis_surat'),
      category: record.getStringValue('category'),
      title: record.getStringValue('title'),
      purpose: record.getStringValue('purpose'),
      status: record.getStringValue('status'),
      approvalLevel: record.getStringValue('approval_level'),
      submittedBy: record.getStringValue('submitted_by'),
      requestPayload: _parseJsonMap(record.getStringValue('request_payload')),
      applicantNote: _textOrNull(record, 'applicant_note'),
      rt: _parseInt(record.data['rt']),
      rw: _parseInt(record.data['rw']),
      desaCode: _textOrNull(record, 'desa_code'),
      kecamatanCode: _textOrNull(record, 'kecamatan_code'),
      kabupatenCode: _textOrNull(record, 'kabupaten_code'),
      provinsiCode: _textOrNull(record, 'provinsi_code'),
      desaKelurahan: _textOrNull(record, 'desa_kelurahan'),
      kecamatan: _textOrNull(record, 'kecamatan'),
      kabupatenKota: _textOrNull(record, 'kabupaten_kota'),
      provinsi: _textOrNull(record, 'provinsi'),
      submittedAt: _dateOrNull(record, 'submitted_at'),
      reviewedByRt: _textOrNull(record, 'reviewed_by_rt'),
      reviewedAtRt: _dateOrNull(record, 'reviewed_at_rt'),
      reviewNoteRt: _textOrNull(record, 'review_note_rt'),
      reviewedByRw: _textOrNull(record, 'reviewed_by_rw'),
      reviewedAtRw: _dateOrNull(record, 'reviewed_at_rw'),
      reviewNoteRw: _textOrNull(record, 'review_note_rw'),
      outputNumber: _textOrNull(record, 'output_number'),
      outputFile: _textOrNull(record, 'output_file'),
      finalizedAt: _dateOrNull(record, 'finalized_at'),
      created: _dateOrNull(record, 'created'),
      updated: _dateOrNull(record, 'updated'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'warga': wargaId,
      'kk': kkId,
      'jenis_surat': jenisSurat,
      'category': category,
      'title': title,
      'purpose': purpose,
      'status': status,
      'approval_level': approvalLevel,
      'submitted_by': submittedBy,
      'request_payload': jsonEncode(requestPayload),
      'applicant_note': applicantNote,
      'rt': rt,
      'rw': rw,
      'desa_code': desaCode,
      'kecamatan_code': kecamatanCode,
      'kabupaten_code': kabupatenCode,
      'provinsi_code': provinsiCode,
      'desa_kelurahan': desaKelurahan,
      'kecamatan': kecamatan,
      'kabupaten_kota': kabupatenKota,
      'provinsi': provinsi,
      'submitted_at': submittedAt?.toIso8601String(),
      'reviewed_by_rt': reviewedByRt,
      'reviewed_at_rt': reviewedAtRt?.toIso8601String(),
      'review_note_rt': reviewNoteRt,
      'reviewed_by_rw': reviewedByRw,
      'reviewed_at_rw': reviewedAtRw?.toIso8601String(),
      'review_note_rw': reviewNoteRw,
      'output_number': outputNumber,
      'finalized_at': finalizedAt?.toIso8601String(),
    };
  }

  bool get isDraft => status == AppConstants.suratDraft;
  bool get isSubmitted => status == AppConstants.suratSubmitted;
  bool get isNeedRevision => status == AppConstants.suratNeedRevision;
  bool get isApprovedRt => status == AppConstants.suratApprovedRt;
  bool get isForwardedToRw => status == AppConstants.suratForwardedToRw;
  bool get isApprovedRw => status == AppConstants.suratApprovedRw;
  bool get isCompleted => status == AppConstants.suratCompleted;
  bool get isRejected => status == AppConstants.suratRejected;
  bool get requiresRwApproval => approvalLevel == AppConstants.suratApprovalRw;
}

class SuratAttachmentModel {
  const SuratAttachmentModel({
    required this.id,
    required this.record,
    required this.requestId,
    required this.file,
    required this.label,
    this.created,
  });

  final String id;
  final RecordModel record;
  final String requestId;
  final String file;
  final String label;
  final DateTime? created;

  factory SuratAttachmentModel.fromRecord(RecordModel record) {
    return SuratAttachmentModel(
      id: record.id,
      record: record,
      requestId: record.getStringValue('request'),
      file: record.getStringValue('file'),
      label: record.getStringValue('label'),
      created: _dateOrNull(record, 'created'),
    );
  }
}

class SuratLogModel {
  const SuratLogModel({
    required this.id,
    required this.requestId,
    required this.actorId,
    required this.action,
    required this.description,
    this.created,
  });

  final String id;
  final String requestId;
  final String actorId;
  final String action;
  final String description;
  final DateTime? created;

  factory SuratLogModel.fromRecord(RecordModel record) {
    return SuratLogModel(
      id: record.id,
      requestId: record.getStringValue('request'),
      actorId: record.getStringValue('actor'),
      action: record.getStringValue('action'),
      description: record.getStringValue('description'),
      created: _dateOrNull(record, 'created'),
    );
  }
}

Map<String, dynamic> _parseJsonMap(String raw) {
  if (raw.trim().isEmpty) {
    return <String, dynamic>{};
  }
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    }
  } catch (_) {}
  return <String, dynamic>{};
}

int? _parseInt(Object? raw) {
  if (raw is int) {
    return raw;
  }
  return int.tryParse(raw?.toString() ?? '');
}

String? _textOrNull(RecordModel record, String field) {
  final value = record.getStringValue(field).trim();
  return value.isEmpty ? null : value;
}

DateTime? _dateOrNull(RecordModel record, String field) {
  return DateTime.tryParse(record.getStringValue(field));
}
