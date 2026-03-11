import 'package:pocketbase/pocketbase.dart';

class FinanceAccountModel {
  const FinanceAccountModel({
    required this.id,
    required this.record,
    required this.workspaceId,
    required this.code,
    required this.label,
    required this.type,
    required this.isActive,
    this.orgUnitId,
  });

  final String id;
  final RecordModel record;
  final String workspaceId;
  final String code;
  final String label;
  final String type;
  final bool isActive;
  final String? orgUnitId;

  factory FinanceAccountModel.fromRecord(RecordModel record) {
    return FinanceAccountModel(
      id: record.id,
      record: record,
      workspaceId: record.getStringValue('workspace'),
      code: record.getStringValue('code'),
      label: record.getStringValue('label'),
      type: record.getStringValue('type'),
      isActive: record.data['is_active'] == true,
      orgUnitId: _textOrNull(record, 'org_unit'),
    );
  }
}

class FinanceApprovalModel {
  const FinanceApprovalModel({
    required this.id,
    required this.record,
    required this.transactionId,
    required this.checkerMemberId,
    required this.decision,
    this.checkerJabatanSnapshot,
    this.note,
    this.created,
  });

  final String id;
  final RecordModel record;
  final String transactionId;
  final String checkerMemberId;
  final String decision;
  final String? checkerJabatanSnapshot;
  final String? note;
  final DateTime? created;

  factory FinanceApprovalModel.fromRecord(RecordModel record) {
    return FinanceApprovalModel(
      id: record.id,
      record: record,
      transactionId: record.getStringValue('transaction'),
      checkerMemberId: record.getStringValue('checker_member'),
      decision: record.getStringValue('decision'),
      checkerJabatanSnapshot: _textOrNull(record, 'checker_jabatan_snapshot'),
      note: _textOrNull(record, 'note'),
      created: _dateOrNull(record, 'created'),
    );
  }
}

class FinanceTransactionModel {
  const FinanceTransactionModel({
    required this.id,
    required this.record,
    required this.workspaceId,
    required this.orgUnitId,
    required this.accountId,
    required this.sourceModule,
    required this.direction,
    required this.category,
    required this.title,
    required this.amount,
    required this.paymentMethod,
    required this.makerMemberId,
    required this.approvalStatus,
    required this.publishStatus,
    this.sourceReference,
    this.description,
    this.proofFile,
    this.makerJabatanSnapshot,
    this.submittedAt,
    this.approvedAt,
    this.publishedAt,
    this.created,
    this.updated,
  });

  final String id;
  final RecordModel record;
  final String workspaceId;
  final String orgUnitId;
  final String accountId;
  final String sourceModule;
  final String direction;
  final String category;
  final String title;
  final int amount;
  final String paymentMethod;
  final String makerMemberId;
  final String approvalStatus;
  final String publishStatus;
  final String? sourceReference;
  final String? description;
  final String? proofFile;
  final String? makerJabatanSnapshot;
  final DateTime? submittedAt;
  final DateTime? approvedAt;
  final DateTime? publishedAt;
  final DateTime? created;
  final DateTime? updated;

  factory FinanceTransactionModel.fromRecord(RecordModel record) {
    return FinanceTransactionModel(
      id: record.id,
      record: record,
      workspaceId: record.getStringValue('workspace'),
      orgUnitId: record.getStringValue('org_unit'),
      accountId: record.getStringValue('account'),
      sourceModule: record.getStringValue('source_module'),
      direction: record.getStringValue('direction'),
      category: record.getStringValue('category'),
      title: record.getStringValue('title'),
      amount: _recordInt(record, 'amount'),
      paymentMethod: record.getStringValue('payment_method'),
      makerMemberId: record.getStringValue('maker_member'),
      approvalStatus: record.getStringValue('approval_status'),
      publishStatus: record.getStringValue('publish_status'),
      sourceReference: _textOrNull(record, 'source_reference'),
      description: _textOrNull(record, 'description'),
      proofFile: _textOrNull(record, 'proof_file'),
      makerJabatanSnapshot: _textOrNull(record, 'maker_jabatan_snapshot'),
      submittedAt: _dateOrNull(record, 'submitted_at'),
      approvedAt: _dateOrNull(record, 'approved_at'),
      publishedAt: _dateOrNull(record, 'published_at'),
      created: _dateOrNull(record, 'created'),
      updated: _dateOrNull(record, 'updated'),
    );
  }

  bool get isIncoming => direction == 'in';

  bool get isOutgoing => direction == 'out';

  bool get isApproved => approvalStatus == 'approved';

  bool get isRejected => approvalStatus == 'rejected';

  bool get isSubmitted => approvalStatus == 'submitted';

  bool get isPublished => publishStatus == 'published';

  bool get requiresTwoWayVerification =>
      isOutgoing || paymentMethod == 'transfer';
}

int _recordInt(RecordModel record, String field) {
  final raw = record.data[field];
  if (raw is int) {
    return raw;
  }
  return int.tryParse(record.getStringValue(field)) ?? 0;
}

String? _textOrNull(RecordModel record, String field) {
  final value = record.getStringValue(field).trim();
  if (value.isNotEmpty) {
    return value;
  }
  final raw = record.data[field]?.toString().trim() ?? '';
  return raw.isEmpty ? null : raw;
}

DateTime? _dateOrNull(RecordModel record, String field) {
  return DateTime.tryParse(record.getStringValue(field));
}
