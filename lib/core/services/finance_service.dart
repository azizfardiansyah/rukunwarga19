import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';

import '../../shared/models/finance_model.dart';
import '../../shared/models/workspace_access_model.dart';
import '../constants/app_constants.dart';
import 'pocketbase_service.dart';
import 'workspace_access_service.dart';

final financeServiceProvider = Provider<FinanceService>((ref) {
  return FinanceService(ref);
});

class FinanceService {
  FinanceService(this._ref);

  final Ref _ref;

  Future<List<FinanceAccountModel>> getAccounts({
    String? workspaceId,
    String? orgUnitId,
    bool includeInactive = false,
  }) async {
    final profile = await _requireAccessProfile();
    final effectiveWorkspaceId = workspaceId ?? profile.workspace.id;
    final filters = <String>[
      'workspace = "${_escapeFilterValue(effectiveWorkspaceId)}"',
    ];
    if (!includeInactive) {
      filters.add('is_active = true');
    }
    if ((orgUnitId ?? '').isNotEmpty) {
      filters.add('org_unit = "${_escapeFilterValue(orgUnitId!)}"');
    }

    final records = await pb
        .collection(AppConstants.colFinanceAccounts)
        .getFullList(filter: filters.join(' && '), sort: 'label,created');
    return records.map(FinanceAccountModel.fromRecord).toList(growable: false);
  }

  Future<FinanceAccountModel> getAccount(String accountId) async {
    final profile = await _requireAccessProfile();
    final record = await pb
        .collection(AppConstants.colFinanceAccounts)
        .getOne(accountId);
    final account = FinanceAccountModel.fromRecord(record);
    if (account.workspaceId != profile.workspace.id) {
      throw ClientException(
        statusCode: 403,
        response: const {'message': 'Akses akun kas ditolak.'},
      );
    }
    return account;
  }

  Future<FinanceAccountModel> createAccount({
    required String orgUnitId,
    required String code,
    required String label,
    required String type,
    bool isActive = true,
  }) async {
    final profile = await _requireAccessProfile();
    final sanitizedCode = code.trim().toLowerCase();
    final sanitizedLabel = label.trim();
    final sanitizedType = type.trim().toLowerCase();
    _assertCanManageAccount(profile, orgUnitId);
    await _requireFinanceUnit(profile.workspace.id, orgUnitId);
    await _assertUniqueAccountCode(
      workspaceId: profile.workspace.id,
      code: sanitizedCode,
    );

    final record = await pb
        .collection(AppConstants.colFinanceAccounts)
        .create(
          body: {
            'workspace': profile.workspace.id,
            'org_unit': orgUnitId,
            'code': sanitizedCode,
            'label': sanitizedLabel,
            'type': sanitizedType,
            'is_active': isActive,
          },
        );
    return FinanceAccountModel.fromRecord(record);
  }

  Future<FinanceAccountModel> updateAccount({
    required String accountId,
    required String orgUnitId,
    required String code,
    required String label,
    required String type,
    required bool isActive,
  }) async {
    final profile = await _requireAccessProfile();
    final existing = await getAccount(accountId);
    final sanitizedCode = code.trim().toLowerCase();
    final sanitizedLabel = label.trim();
    final sanitizedType = type.trim().toLowerCase();

    if (!profile.member.isSysadmin) {
      _assertCanManageAccount(profile, existing.orgUnitId);
    }
    _assertCanManageAccount(profile, orgUnitId);
    await _requireFinanceUnit(profile.workspace.id, orgUnitId);
    await _assertUniqueAccountCode(
      workspaceId: profile.workspace.id,
      code: sanitizedCode,
      excludingAccountId: existing.id,
    );

    final record = await pb
        .collection(AppConstants.colFinanceAccounts)
        .update(
          accountId,
          body: {
            'org_unit': orgUnitId,
            'code': sanitizedCode,
            'label': sanitizedLabel,
            'type': sanitizedType,
            'is_active': isActive,
          },
        );
    return FinanceAccountModel.fromRecord(record);
  }

  Future<FinanceAccountModel> setAccountActive({
    required String accountId,
    required bool isActive,
  }) async {
    final profile = await _requireAccessProfile();
    final existing = await getAccount(accountId);
    _assertCanManageAccount(profile, existing.orgUnitId);

    final record = await pb
        .collection(AppConstants.colFinanceAccounts)
        .update(accountId, body: {'is_active': isActive});
    return FinanceAccountModel.fromRecord(record);
  }

  Future<List<FinanceTransactionModel>> getTransactions({
    String? workspaceId,
    String? orgUnitId,
    String? direction,
    String? approvalStatus,
    String? publishStatus,
  }) async {
    final profile = await _requireAccessProfile();
    final effectiveWorkspaceId = workspaceId ?? profile.workspace.id;
    final filters = <String>[
      'workspace = "${_escapeFilterValue(effectiveWorkspaceId)}"',
    ];
    if ((orgUnitId ?? '').isNotEmpty) {
      filters.add('org_unit = "${_escapeFilterValue(orgUnitId!)}"');
    }
    if ((direction ?? '').isNotEmpty) {
      filters.add('direction = "${_escapeFilterValue(direction!)}"');
    }
    if ((approvalStatus ?? '').isNotEmpty) {
      filters.add('approval_status = "${_escapeFilterValue(approvalStatus!)}"');
    }
    if ((publishStatus ?? '').isNotEmpty) {
      filters.add('publish_status = "${_escapeFilterValue(publishStatus!)}"');
    }

    final records = await pb
        .collection(AppConstants.colFinanceTransactions)
        .getFullList(filter: filters.join(' && '), sort: '-created');
    return records
        .map(FinanceTransactionModel.fromRecord)
        .where((item) => _canReadTransaction(profile, item))
        .toList(growable: false);
  }

  Future<List<FinanceApprovalModel>> getApprovals(String transactionId) async {
    final profile = await _requireAccessProfile();
    final transaction = await getTransaction(transactionId);
    if (!_canReadTransaction(profile, transaction)) {
      throw ClientException(
        statusCode: 403,
        response: const {'message': 'Akses transaksi keuangan ditolak.'},
      );
    }

    final records = await pb
        .collection(AppConstants.colFinanceApprovals)
        .getFullList(
          filter: 'transaction = "${_escapeFilterValue(transactionId)}"',
          sort: '-created',
        );
    return records.map(FinanceApprovalModel.fromRecord).toList(growable: false);
  }

  Future<FinanceTransactionModel> getTransaction(String transactionId) async {
    final record = await pb
        .collection(AppConstants.colFinanceTransactions)
        .getOne(transactionId);
    return FinanceTransactionModel.fromRecord(record);
  }

  Future<FinanceTransactionModel?> getTransactionBySourceReference({
    required String sourceModule,
    required String sourceReference,
  }) async {
    final profile = await _requireAccessProfile();
    if (sourceReference.trim().isEmpty) {
      return null;
    }

    final record = await _tryFindFirst(
      AppConstants.colFinanceTransactions,
      [
        'workspace = "${_escapeFilterValue(profile.workspace.id)}"',
        'source_module = "${_escapeFilterValue(sourceModule.trim().toLowerCase())}"',
        'source_reference = "${_escapeFilterValue(sourceReference.trim())}"',
      ].join(' && '),
    );
    return record == null ? null : FinanceTransactionModel.fromRecord(record);
  }

  Future<FinanceTransactionModel> createTransaction({
    required String orgUnitId,
    required String accountId,
    required String direction,
    required String category,
    required String title,
    required int amount,
    required String paymentMethod,
    String sourceModule = 'manual',
    String? description,
    PlatformFile? proofFile,
  }) async {
    final profile = await _requireAccessProfile();
    if (!profile.canSubmitFinanceForUnit(orgUnitId)) {
      throw ClientException(
        statusCode: 403,
        response: const {'message': 'Anda tidak memiliki hak input keuangan.'},
      );
    }

    final makerMembership = profile.primaryMembershipForUnit(orgUnitId);
    if (makerMembership == null && !profile.member.isSysadmin) {
      throw ClientException(
        statusCode: 403,
        response: const {
          'message': 'Jabatan maker untuk unit belum ditemukan.',
        },
      );
    }

    final now = DateTime.now();
    final needsChecker = _requiresTwoWayVerification(
      direction: direction,
      paymentMethod: paymentMethod,
    );
    final approvalStatus = needsChecker ? 'submitted' : 'approved';
    final body = <String, dynamic>{
      'workspace': profile.workspace.id,
      'org_unit': orgUnitId,
      'account': accountId,
      'source_module': sourceModule,
      'direction': direction.trim().toLowerCase(),
      'category': category.trim(),
      'title': title.trim(),
      'description': (description ?? '').trim(),
      'amount': amount,
      'payment_method': paymentMethod.trim().toLowerCase(),
      'maker_member': profile.member.id,
      'maker_jabatan_snapshot':
          makerMembership?.jabatan?.label ??
          (profile.member.isSysadmin ? 'Sysadmin' : 'Operator'),
      'approval_status': approvalStatus,
      'publish_status': 'pending',
      'submitted_at': now.toIso8601String(),
      if (!needsChecker) 'approved_at': now.toIso8601String(),
    };

    final files = <http.MultipartFile>[];
    if (proofFile != null) {
      files.add(await _multipartFromPlatformFile('proof_file', proofFile));
    }

    final record = await pb
        .collection(AppConstants.colFinanceTransactions)
        .create(body: body, files: files);
    return FinanceTransactionModel.fromRecord(record);
  }

  Future<FinanceTransactionModel> saveDraftTransaction({
    String? transactionId,
    required String orgUnitId,
    required String accountId,
    required String direction,
    required String category,
    required String title,
    required int amount,
    required String paymentMethod,
    String sourceModule = 'manual',
    String? description,
    PlatformFile? proofFile,
  }) async {
    final profile = await _requireAccessProfile();
    if (!profile.canSubmitFinanceForUnit(orgUnitId)) {
      throw ClientException(
        statusCode: 403,
        response: const {'message': 'Anda tidak memiliki hak input keuangan.'},
      );
    }

    final makerMembership = profile.primaryMembershipForUnit(orgUnitId);
    if (makerMembership == null && !profile.member.isSysadmin) {
      throw ClientException(
        statusCode: 403,
        response: const {
          'message': 'Jabatan maker untuk unit belum ditemukan.',
        },
      );
    }

    final body = <String, dynamic>{
      'workspace': profile.workspace.id,
      'org_unit': orgUnitId,
      'account': accountId,
      'source_module': sourceModule,
      'direction': direction.trim().toLowerCase(),
      'category': category.trim(),
      'title': title.trim(),
      'description': (description ?? '').trim(),
      'amount': amount,
      'payment_method': paymentMethod.trim().toLowerCase(),
      'maker_member': profile.member.id,
      'maker_jabatan_snapshot':
          makerMembership?.jabatan?.label ??
          (profile.member.isSysadmin ? 'Sysadmin' : 'Operator'),
      'approval_status': 'draft',
      'publish_status': 'pending',
      'submitted_at': '',
      'approved_at': '',
      'published_at': '',
    };

    final files = <http.MultipartFile>[];
    if (proofFile != null) {
      files.add(await _multipartFromPlatformFile('proof_file', proofFile));
    }

    if ((transactionId ?? '').trim().isEmpty) {
      final record = await pb
          .collection(AppConstants.colFinanceTransactions)
          .create(body: body, files: files);
      return FinanceTransactionModel.fromRecord(record);
    }

    final existing = await getTransaction(transactionId!);
    if (existing.approvalStatus != 'draft') {
      throw ClientException(
        statusCode: 400,
        response: const {'message': 'Hanya draft yang bisa diedit.'},
      );
    }
    if (!profile.member.isSysadmin &&
        existing.makerMemberId != profile.member.id) {
      throw ClientException(
        statusCode: 403,
        response: const {
          'message': 'Hanya maker yang bisa mengedit draft ini.',
        },
      );
    }

    final record = await pb
        .collection(AppConstants.colFinanceTransactions)
        .update(transactionId, body: body, files: files);
    return FinanceTransactionModel.fromRecord(record);
  }

  Future<FinanceTransactionModel> createRecordedIncomingTransaction({
    required String orgUnitId,
    required String accountId,
    required String category,
    required String title,
    required int amount,
    required String paymentMethod,
    required String sourceModule,
    required String sourceReference,
    String? description,
  }) async {
    final profile = await _requireAccessProfile();
    final existing = await getTransactionBySourceReference(
      sourceModule: sourceModule,
      sourceReference: sourceReference,
    );
    if (existing != null) {
      return existing;
    }

    final makerMembership = profile.primaryMembershipForUnit(orgUnitId);
    final now = DateTime.now().toIso8601String();
    final record = await pb
        .collection(AppConstants.colFinanceTransactions)
        .create(
          body: {
            'workspace': profile.workspace.id,
            'org_unit': orgUnitId,
            'account': accountId,
            'source_module': sourceModule.trim().toLowerCase(),
            'source_reference': sourceReference.trim(),
            'direction': 'in',
            'category': category.trim(),
            'title': title.trim(),
            'description': (description ?? '').trim(),
            'amount': amount,
            'payment_method': paymentMethod.trim().toLowerCase(),
            'maker_member': profile.member.id,
            'maker_jabatan_snapshot':
                makerMembership?.jabatan?.label ??
                (profile.member.isSysadmin ? 'Sysadmin' : 'Operator'),
            'approval_status': 'approved',
            'publish_status': 'pending',
            'submitted_at': now,
            'approved_at': now,
          },
        );
    return FinanceTransactionModel.fromRecord(record);
  }

  Future<FinanceTransactionModel> submitTransaction({
    required String transactionId,
  }) async {
    final profile = await _requireAccessProfile();
    final transaction = await getTransaction(transactionId);

    if (transaction.approvalStatus != 'draft') {
      throw ClientException(
        statusCode: 400,
        response: const {'message': 'Hanya draft yang bisa disubmit.'},
      );
    }
    if (!profile.canSubmitFinanceForUnit(transaction.orgUnitId)) {
      throw ClientException(
        statusCode: 403,
        response: const {'message': 'Anda tidak memiliki hak submit keuangan.'},
      );
    }
    if (!profile.member.isSysadmin &&
        transaction.makerMemberId != profile.member.id) {
      throw ClientException(
        statusCode: 403,
        response: const {
          'message': 'Hanya maker yang bisa submit draft transaksi ini.',
        },
      );
    }

    final now = DateTime.now().toIso8601String();
    final needsChecker = _requiresTwoWayVerification(
      direction: transaction.direction,
      paymentMethod: transaction.paymentMethod,
    );
    final record = await pb
        .collection(AppConstants.colFinanceTransactions)
        .update(
          transaction.id,
          body: {
            'approval_status': needsChecker ? 'submitted' : 'approved',
            'submitted_at': now,
            'approved_at': needsChecker ? '' : now,
          },
        );
    return FinanceTransactionModel.fromRecord(record);
  }

  Future<FinanceTransactionModel> approveTransaction({
    required String transactionId,
    String note = '',
  }) {
    return _decideTransaction(
      transactionId: transactionId,
      decision: 'approved',
      note: note,
    );
  }

  Future<FinanceTransactionModel> rejectTransaction({
    required String transactionId,
    String note = '',
  }) {
    return _decideTransaction(
      transactionId: transactionId,
      decision: 'rejected',
      note: note,
    );
  }

  Future<FinanceTransactionModel> publishTransaction({
    required String transactionId,
    String? announcementTitle,
    String? announcementContent,
  }) async {
    final profile = await _requireAccessProfile();
    final transaction = await getTransaction(transactionId);

    if (!transaction.isApproved) {
      throw ClientException(
        statusCode: 400,
        response: const {'message': 'Transaksi belum approved.'},
      );
    }
    if (transaction.isPublished) {
      throw ClientException(
        statusCode: 400,
        response: const {'message': 'Transaksi ini sudah dipublikasikan.'},
      );
    }
    if (!profile.canPublishFinanceByPlan ||
        !profile.canPublishFinanceForUnit(transaction.orgUnitId)) {
      throw ClientException(
        statusCode: 403,
        response: const {'message': 'Anda tidak dapat publish transaksi ini.'},
      );
    }

    final updatedRecord = await pb
        .collection(AppConstants.colFinanceTransactions)
        .update(
          transaction.id,
          body: {
            'publish_status': 'published',
            'published_at': DateTime.now().toIso8601String(),
          },
        );
    final published = FinanceTransactionModel.fromRecord(updatedRecord);

    await _createFinanceAnnouncement(
      profile: profile,
      transaction: published,
      title: announcementTitle,
      content: announcementContent,
    );

    return published;
  }

  Future<FinanceTransactionModel> _decideTransaction({
    required String transactionId,
    required String decision,
    required String note,
  }) async {
    final profile = await _requireAccessProfile();
    final transaction = await getTransaction(transactionId);

    if (!_requiresTwoWayVerification(
      direction: transaction.direction,
      paymentMethod: transaction.paymentMethod,
    )) {
      throw ClientException(
        statusCode: 400,
        response: const {
          'message': 'Transaksi ini tidak memerlukan checker tambahan.',
        },
      );
    }
    if (!transaction.isSubmitted) {
      throw ClientException(
        statusCode: 400,
        response: const {
          'message': 'Hanya transaksi submitted yang bisa diproses.',
        },
      );
    }
    if (!profile.canApproveFinanceForUnit(transaction.orgUnitId)) {
      throw ClientException(
        statusCode: 403,
        response: const {'message': 'Anda tidak memiliki hak approve.'},
      );
    }
    if (profile.member.id == transaction.makerMemberId) {
      throw ClientException(
        statusCode: 403,
        response: const {
          'message': 'Maker tidak boleh meng-approve transaksi.',
        },
      );
    }

    final checkerMembership = profile.primaryMembershipForUnit(
      transaction.orgUnitId,
    );
    if (checkerMembership == null && !profile.member.isSysadmin) {
      throw ClientException(
        statusCode: 403,
        response: const {
          'message': 'Jabatan checker untuk unit belum ditemukan.',
        },
      );
    }

    await pb
        .collection(AppConstants.colFinanceApprovals)
        .create(
          body: {
            'transaction': transaction.id,
            'checker_member': profile.member.id,
            'checker_jabatan_snapshot':
                checkerMembership?.jabatan?.label ??
                (profile.member.isSysadmin ? 'Sysadmin' : 'Operator'),
            'decision': decision,
            'note': note.trim(),
          },
        );

    final updatedRecord = await pb
        .collection(AppConstants.colFinanceTransactions)
        .update(
          transaction.id,
          body: {
            'approval_status': decision,
            if (decision == 'approved')
              'approved_at': DateTime.now().toIso8601String(),
          },
        );
    return FinanceTransactionModel.fromRecord(updatedRecord);
  }

  Future<void> _createFinanceAnnouncement({
    required WorkspaceAccessProfile profile,
    required FinanceTransactionModel transaction,
    String? title,
    String? content,
  }) async {
    final unitRecord = await pb
        .collection(AppConstants.colOrgUnits)
        .getOne(transaction.orgUnitId);
    final unit = OrgUnitModel.fromRecord(unitRecord);
    final amountLabel = 'Rp ${transaction.amount}';
    final defaultTitle =
        '${transaction.direction == 'out' ? 'Pengeluaran' : 'Pemasukan'} ${unit.name}';
    final defaultContent =
        '${transaction.title} sebesar $amountLabel sudah ${transaction.approvalStatus} dan dipublikasikan.';

    await pb
        .collection(AppConstants.colAnnouncements)
        .create(
          body: {
            'workspace': profile.workspace.id,
            'org_unit': transaction.orgUnitId,
            'author': _currentUserId,
            'title': (title ?? defaultTitle).trim(),
            'content': (content ?? defaultContent).trim(),
            'target_type': unit.type == AppConstants.unitTypeRt ? 'rt' : 'rw',
            'rt': unit.scopeRt ?? 0,
            'rw': unit.scopeRw ?? profile.workspace.rw,
            'source_module': 'finance',
            'publish_state': 'published',
            'published_by_member': profile.member.id,
            'is_published': true,
            'desa_code': profile.workspace.desaCode ?? '',
            'kecamatan_code': profile.workspace.kecamatanCode ?? '',
            'kabupaten_code': profile.workspace.kabupatenCode ?? '',
            'provinsi_code': profile.workspace.provinsiCode ?? '',
            'desa_kelurahan': profile.workspace.desaKelurahan ?? '',
            'kecamatan': profile.workspace.kecamatan ?? '',
            'kabupaten_kota': profile.workspace.kabupatenKota ?? '',
            'provinsi': profile.workspace.provinsi ?? '',
          },
        );
  }

  void _assertCanManageAccount(
    WorkspaceAccessProfile profile,
    String? orgUnitId,
  ) {
    if (profile.member.isSysadmin) {
      return;
    }
    final unitId = (orgUnitId ?? '').trim();
    if (unitId.isEmpty || !profile.canSubmitFinanceForUnit(unitId)) {
      throw ClientException(
        statusCode: 403,
        response: const {
          'message': 'Anda tidak memiliki hak kelola akun kas untuk unit ini.',
        },
      );
    }
  }

  Future<void> _assertUniqueAccountCode({
    required String workspaceId,
    required String code,
    String? excludingAccountId,
  }) async {
    if (code.trim().isEmpty) {
      throw ClientException(
        statusCode: 400,
        response: const {'message': 'Kode akun kas wajib diisi.'},
      );
    }

    final filters = <String>[
      'workspace = "${_escapeFilterValue(workspaceId)}"',
      'code = "${_escapeFilterValue(code.trim().toLowerCase())}"',
    ];
    if ((excludingAccountId ?? '').trim().isNotEmpty) {
      filters.add('id != "${_escapeFilterValue(excludingAccountId!.trim())}"');
    }

    final existing = await _tryFindFirst(
      AppConstants.colFinanceAccounts,
      filters.join(' && '),
    );
    if (existing != null) {
      throw ClientException(
        statusCode: 400,
        response: const {
          'message': 'Kode akun kas sudah dipakai. Gunakan kode lain.',
        },
      );
    }
  }

  Future<void> _requireFinanceUnit(String workspaceId, String orgUnitId) async {
    final record = await _tryFindFirst(
      AppConstants.colOrgUnits,
      [
        'workspace = "${_escapeFilterValue(workspaceId)}"',
        'id = "${_escapeFilterValue(orgUnitId)}"',
        'status = "active"',
      ].join(' && '),
    );
    if (record == null) {
      throw ClientException(
        statusCode: 400,
        response: const {
          'message': 'Unit organisasi aktif untuk akun kas belum ditemukan.',
        },
      );
    }
  }

  bool _canReadTransaction(
    WorkspaceAccessProfile profile,
    FinanceTransactionModel transaction,
  ) {
    if (profile.member.isSysadmin) {
      return true;
    }
    return transaction.workspaceId == profile.workspace.id &&
        (profile.canSubmitFinanceForUnit(transaction.orgUnitId) ||
            profile.canApproveFinanceForUnit(transaction.orgUnitId) ||
            profile.canPublishFinanceForUnit(transaction.orgUnitId) ||
            profile.canBroadcastUnit(transaction.orgUnitId));
  }

  bool _requiresTwoWayVerification({
    required String direction,
    required String paymentMethod,
  }) {
    final normalizedDirection = direction.trim().toLowerCase();
    final normalizedMethod = paymentMethod.trim().toLowerCase();
    if (normalizedDirection == 'out') {
      return true;
    }
    if (normalizedDirection == 'in' && normalizedMethod == 'transfer') {
      return true;
    }
    return false;
  }

  Future<WorkspaceAccessProfile> _requireAccessProfile() async {
    final profile = await _ref
        .read(workspaceAccessServiceProvider)
        .getCurrentAccessProfile();
    if (profile == null) {
      throw ClientException(
        statusCode: 403,
        response: const {'message': 'Workspace aktif belum tersedia.'},
      );
    }
    return profile;
  }

  String get _currentUserId => pb.authStore.record?.id ?? '';

  Future<RecordModel?> _tryFindFirst(String collection, String filter) async {
    try {
      return await pb.collection(collection).getFirstListItem(filter);
    } catch (_) {
      return null;
    }
  }
}

Future<http.MultipartFile> _multipartFromPlatformFile(
  String field,
  PlatformFile file,
) async {
  if (file.bytes != null) {
    return http.MultipartFile.fromBytes(
      field,
      file.bytes!,
      filename: file.name,
    );
  }
  if ((file.path ?? '').isNotEmpty) {
    return http.MultipartFile.fromPath(field, file.path!, filename: file.name);
  }
  throw ClientException(
    statusCode: 400,
    response: const {'message': 'Bukti transaksi tidak valid.'},
  );
}

String _escapeFilterValue(String value) {
  return value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
}
