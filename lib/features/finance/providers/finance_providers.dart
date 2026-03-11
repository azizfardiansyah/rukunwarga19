import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/finance_service.dart';
import '../../../core/services/workspace_access_service.dart';
import '../../../shared/models/finance_model.dart';
import '../../../shared/models/workspace_access_model.dart';

class FinanceRefreshTickNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final financeRefreshTickProvider =
    NotifierProvider<FinanceRefreshTickNotifier, int>(
      FinanceRefreshTickNotifier.new,
    );

class FinanceOverviewData {
  const FinanceOverviewData({
    required this.profile,
    required this.orgUnits,
    required this.accounts,
    required this.transactions,
  });

  final WorkspaceAccessProfile profile;
  final List<OrgUnitModel> orgUnits;
  final List<FinanceAccountModel> accounts;
  final List<FinanceTransactionModel> transactions;

  List<OrgUnitModel> get visibleUnits => orgUnits
      .where(
        (unit) =>
            profile.canSubmitFinanceForUnit(unit.id) ||
            profile.canApproveFinanceForUnit(unit.id) ||
            profile.canPublishFinanceForUnit(unit.id) ||
            profile.canBroadcastUnit(unit.id),
      )
      .toList(growable: false);

  List<OrgUnitModel> get creatableUnits => orgUnits
      .where((unit) => profile.canSubmitFinanceForUnit(unit.id))
      .toList(growable: false);

  OrgUnitModel? unitById(String unitId) {
    for (final unit in orgUnits) {
      if (unit.id == unitId) {
        return unit;
      }
    }
    return null;
  }

  FinanceAccountModel? accountById(String accountId) {
    for (final account in accounts) {
      if (account.id == accountId) {
        return account;
      }
    }
    return null;
  }

  List<FinanceAccountModel> accountsForUnit(String orgUnitId) {
    return accounts
        .where((account) => account.orgUnitId == orgUnitId)
        .toList(growable: false);
  }
}

class FinanceDetailData {
  const FinanceDetailData({
    required this.overview,
    required this.transaction,
    required this.approvals,
  });

  final FinanceOverviewData overview;
  final FinanceTransactionModel transaction;
  final List<FinanceApprovalModel> approvals;

  OrgUnitModel? get orgUnit => overview.unitById(transaction.orgUnitId);

  FinanceAccountModel? get account => overview.accountById(transaction.accountId);
}

final financeOverviewProvider =
    FutureProvider.autoDispose<FinanceOverviewData>((ref) async {
      ref.watch(financeRefreshTickProvider);
      final profile = await ref
          .watch(workspaceAccessServiceProvider)
          .getCurrentAccessProfile();
      if (profile == null) {
        throw StateError('Workspace aktif belum tersedia.');
      }
      final orgUnits = await ref
          .watch(workspaceAccessServiceProvider)
          .getOrgUnits(profile.workspace.id);
      final accounts = await ref.watch(financeServiceProvider).getAccounts();
      final transactions = await ref.watch(financeServiceProvider).getTransactions();
      return FinanceOverviewData(
        profile: profile,
        orgUnits: orgUnits,
        accounts: accounts,
        transactions: transactions,
      );
    });

final financeDetailProvider =
    FutureProvider.autoDispose.family<FinanceDetailData, String>((
      ref,
      transactionId,
    ) async {
      ref.watch(financeRefreshTickProvider);
      final overview = await ref.watch(financeOverviewProvider.future);
      final transaction = await ref
          .watch(financeServiceProvider)
          .getTransaction(transactionId);
      final approvals = await ref
          .watch(financeServiceProvider)
          .getApprovals(transactionId);
      return FinanceDetailData(
        overview: overview,
        transaction: transaction,
        approvals: approvals,
      );
    });
