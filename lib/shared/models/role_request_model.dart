import 'package:pocketbase/pocketbase.dart';

class RoleRequestModel {
  const RoleRequestModel({
    required this.id,
    required this.requester,
    required this.requestedRole,
    required this.currentRole,
    required this.reason,
    required this.status,
    this.reviewNote,
    this.reviewer,
    this.created,
    this.updated,
    this.requesterName,
    this.requesterEmail,
    this.reviewerName,
  });

  final String id;
  final String requester;
  final String requestedRole;
  final String currentRole;
  final String reason;
  final String status;
  final String? reviewNote;
  final String? reviewer;
  final DateTime? created;
  final DateTime? updated;
  final String? requesterName;
  final String? requesterEmail;
  final String? reviewerName;

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  factory RoleRequestModel.fromRecord(RecordModel record) {
    final requesterExpand = record.get<List<RecordModel>?>('expand.requester');
    final reviewerExpand = record.get<List<RecordModel>?>('expand.reviewer');
    final requesterRecord =
        requesterExpand != null && requesterExpand.isNotEmpty
            ? requesterExpand.first
            : null;
    final reviewerRecord =
        reviewerExpand != null && reviewerExpand.isNotEmpty
            ? reviewerExpand.first
            : null;

    return RoleRequestModel(
      id: record.id,
      requester: record.getStringValue('requester'),
      requestedRole: record.getStringValue('requested_role'),
      currentRole: record.getStringValue('current_role'),
      reason: record.getStringValue('reason'),
      status: record.getStringValue('status'),
      reviewNote: record.getStringValue('review_note'),
      reviewer: record.getStringValue('reviewer'),
      created: DateTime.tryParse(record.getStringValue('created')),
      updated: DateTime.tryParse(record.getStringValue('updated')),
      requesterName: requesterRecord?.getStringValue('name').isNotEmpty == true
          ? requesterRecord!.getStringValue('name')
          : requesterRecord?.getStringValue('nama'),
      requesterEmail: requesterRecord?.getStringValue('email'),
      reviewerName: reviewerRecord?.getStringValue('name').isNotEmpty == true
          ? reviewerRecord!.getStringValue('name')
          : reviewerRecord?.getStringValue('nama'),
    );
  }
}
