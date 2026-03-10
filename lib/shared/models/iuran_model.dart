import 'package:pocketbase/pocketbase.dart';

import '../../core/constants/app_constants.dart';

class IuranTypeModel {
  const IuranTypeModel({
    required this.id,
    required this.record,
    required this.code,
    required this.label,
    required this.defaultAmount,
    required this.defaultFrequency,
    this.description,
    this.isActive = true,
    this.sortOrder,
    this.created,
    this.updated,
  });

  final String id;
  final RecordModel record;
  final String code;
  final String label;
  final int defaultAmount;
  final String defaultFrequency;
  final String? description;
  final bool isActive;
  final int? sortOrder;
  final DateTime? created;
  final DateTime? updated;

  factory IuranTypeModel.fromRecord(RecordModel record) {
    return IuranTypeModel(
      id: record.id,
      record: record,
      code: record.getStringValue('code'),
      label: record.getStringValue('label'),
      defaultAmount: _parseInt(record.data['default_amount']) ?? 0,
      defaultFrequency: record.getStringValue('default_frequency'),
      description: _textOrNull(record, 'description'),
      isActive: record.data['is_active'] == true,
      sortOrder: _parseInt(record.data['sort_order']),
      created: _dateOrNull(record, 'created'),
      updated: _dateOrNull(record, 'updated'),
    );
  }
}

class IuranPeriodModel {
  const IuranPeriodModel({
    required this.id,
    required this.record,
    required this.iuranTypeId,
    required this.typeLabel,
    required this.title,
    required this.frequency,
    required this.defaultAmount,
    required this.status,
    required this.targetMode,
    required this.createdBy,
    this.description,
    this.dueDate,
    this.publishedAt,
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
    this.created,
    this.updated,
  });

  final String id;
  final RecordModel record;
  final String iuranTypeId;
  final String typeLabel;
  final String title;
  final String frequency;
  final int defaultAmount;
  final String status;
  final String targetMode;
  final String createdBy;
  final String? description;
  final DateTime? dueDate;
  final DateTime? publishedAt;
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
  final DateTime? created;
  final DateTime? updated;

  factory IuranPeriodModel.fromRecord(RecordModel record) {
    return IuranPeriodModel(
      id: record.id,
      record: record,
      iuranTypeId: record.getStringValue('iuran_type'),
      typeLabel: record.getStringValue('type_label'),
      title: record.getStringValue('title'),
      frequency: record.getStringValue('frequency'),
      defaultAmount: _parseInt(record.data['default_amount']) ?? 0,
      status: record.getStringValue('status'),
      targetMode: record.getStringValue('target_mode'),
      createdBy: record.getStringValue('created_by'),
      description: _textOrNull(record, 'description'),
      dueDate: _dateOrNull(record, 'due_date'),
      publishedAt: _dateOrNull(record, 'published_at'),
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
      created: _dateOrNull(record, 'created'),
      updated: _dateOrNull(record, 'updated'),
    );
  }

  bool get isDraft => status == AppConstants.iuranPeriodDraft;
  bool get isPublished => status == AppConstants.iuranPeriodPublished;
  bool get isClosed => status == AppConstants.iuranPeriodClosed;
}

class IuranBillModel {
  const IuranBillModel({
    required this.id,
    required this.record,
    required this.periodId,
    required this.iuranTypeId,
    required this.kkId,
    required this.billNumber,
    required this.title,
    required this.typeLabel,
    required this.kkNumber,
    required this.amount,
    required this.status,
    this.kkHolderName,
    this.frequency,
    this.paymentMethod,
    this.payerNote,
    this.submittedBy,
    this.submittedAt,
    this.verifiedBy,
    this.verifiedAt,
    this.rejectionNote,
    this.paidAt,
    this.dueDate,
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
    this.created,
    this.updated,
  });

  final String id;
  final RecordModel record;
  final String periodId;
  final String iuranTypeId;
  final String kkId;
  final String billNumber;
  final String title;
  final String typeLabel;
  final String kkNumber;
  final int amount;
  final String status;
  final String? kkHolderName;
  final String? frequency;
  final String? paymentMethod;
  final String? payerNote;
  final String? submittedBy;
  final DateTime? submittedAt;
  final String? verifiedBy;
  final DateTime? verifiedAt;
  final String? rejectionNote;
  final DateTime? paidAt;
  final DateTime? dueDate;
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
  final DateTime? created;
  final DateTime? updated;

  IuranBillModel copyWith({
    String? status,
    String? paymentMethod,
    String? payerNote,
    String? submittedBy,
    DateTime? submittedAt,
    String? verifiedBy,
    DateTime? verifiedAt,
    String? rejectionNote,
    DateTime? paidAt,
    DateTime? updated,
  }) {
    return IuranBillModel(
      id: id,
      record: record,
      periodId: periodId,
      iuranTypeId: iuranTypeId,
      kkId: kkId,
      billNumber: billNumber,
      title: title,
      typeLabel: typeLabel,
      kkNumber: kkNumber,
      amount: amount,
      status: status ?? this.status,
      kkHolderName: kkHolderName,
      frequency: frequency,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      payerNote: payerNote ?? this.payerNote,
      submittedBy: submittedBy ?? this.submittedBy,
      submittedAt: submittedAt ?? this.submittedAt,
      verifiedBy: verifiedBy ?? this.verifiedBy,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      rejectionNote: rejectionNote ?? this.rejectionNote,
      paidAt: paidAt ?? this.paidAt,
      dueDate: dueDate,
      rt: rt,
      rw: rw,
      desaCode: desaCode,
      kecamatanCode: kecamatanCode,
      kabupatenCode: kabupatenCode,
      provinsiCode: provinsiCode,
      desaKelurahan: desaKelurahan,
      kecamatan: kecamatan,
      kabupatenKota: kabupatenKota,
      provinsi: provinsi,
      created: created,
      updated: updated ?? this.updated,
    );
  }

  factory IuranBillModel.fromRecord(RecordModel record) {
    return IuranBillModel(
      id: record.id,
      record: record,
      periodId: record.getStringValue('period'),
      iuranTypeId: record.getStringValue('iuran_type'),
      kkId: record.getStringValue('kk'),
      billNumber: record.getStringValue('bill_number'),
      title: record.getStringValue('title'),
      typeLabel: record.getStringValue('type_label'),
      kkNumber: record.getStringValue('kk_number'),
      amount: _parseInt(record.data['amount']) ?? 0,
      status: record.getStringValue('status'),
      kkHolderName: _textOrNull(record, 'kk_holder_name'),
      frequency: _textOrNull(record, 'frequency'),
      paymentMethod: _textOrNull(record, 'payment_method'),
      payerNote: _textOrNull(record, 'payer_note'),
      submittedBy: _textOrNull(record, 'submitted_by'),
      submittedAt: _dateOrNull(record, 'submitted_at'),
      verifiedBy: _textOrNull(record, 'verified_by'),
      verifiedAt: _dateOrNull(record, 'verified_at'),
      rejectionNote: _textOrNull(record, 'rejection_note'),
      paidAt: _dateOrNull(record, 'paid_at'),
      dueDate: _dateOrNull(record, 'due_date'),
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
      created: _dateOrNull(record, 'created'),
      updated: _dateOrNull(record, 'updated'),
    );
  }

  bool get isUnpaid => status == AppConstants.iuranBillUnpaid;
  bool get isSubmittedVerification =>
      status == AppConstants.iuranBillSubmittedVerification;
  bool get isPaid => status == AppConstants.iuranBillPaid;
  bool get isRejectedPayment => status == AppConstants.iuranBillRejectedPayment;
}

class IuranPaymentModel {
  const IuranPaymentModel({
    required this.id,
    required this.record,
    required this.billId,
    required this.kkId,
    required this.submittedBy,
    required this.method,
    required this.amount,
    required this.status,
    this.proofFile,
    this.note,
    this.reviewNote,
    this.submittedAt,
    this.verifiedBy,
    this.verifiedAt,
    this.rejectionNote,
    this.created,
    this.updated,
  });

  final String id;
  final RecordModel record;
  final String billId;
  final String kkId;
  final String submittedBy;
  final String method;
  final int amount;
  final String status;
  final String? proofFile;
  final String? note;
  final String? reviewNote;
  final DateTime? submittedAt;
  final String? verifiedBy;
  final DateTime? verifiedAt;
  final String? rejectionNote;
  final DateTime? created;
  final DateTime? updated;

  factory IuranPaymentModel.fromRecord(RecordModel record) {
    return IuranPaymentModel(
      id: record.id,
      record: record,
      billId: record.getStringValue('bill'),
      kkId: record.getStringValue('kk'),
      submittedBy: record.getStringValue('submitted_by'),
      method: record.getStringValue('method'),
      amount: _parseInt(record.data['amount']) ?? 0,
      status: record.getStringValue('status'),
      proofFile: _textOrNull(record, 'proof_file'),
      note: _textOrNull(record, 'note'),
      reviewNote: _textOrNull(record, 'review_note'),
      submittedAt: _dateOrNull(record, 'submitted_at'),
      verifiedBy: _textOrNull(record, 'verified_by'),
      verifiedAt: _dateOrNull(record, 'verified_at'),
      rejectionNote: _textOrNull(record, 'rejection_note'),
      created: _dateOrNull(record, 'created'),
      updated: _dateOrNull(record, 'updated'),
    );
  }

  bool get isSubmitted => status == AppConstants.iuranPaymentSubmitted;
  bool get isVerified => status == AppConstants.iuranPaymentVerified;
  bool get isRejected => status == AppConstants.iuranPaymentRejected;

  DateTime get timelineAt =>
      verifiedAt ?? submittedAt ?? updated ?? created ?? DateTime.now();
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
