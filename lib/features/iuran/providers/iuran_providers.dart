import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/iuran_service.dart';
import '../../../core/services/workspace_access_service.dart';
import '../../auth/providers/auth_provider.dart';

class IuranRefreshTickNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final iuranRefreshTickProvider =
    NotifierProvider<IuranRefreshTickNotifier, int>(
      IuranRefreshTickNotifier.new,
    );

class IuranAccessState {
  const IuranAccessState({
    required this.canOpenAdminView,
    required this.canManageSetup,
    required this.canReviewPayments,
    required this.canPublishIuranData,
    required this.canPublishFinance,
    required this.showOperatorFallbackNotice,
  });

  final bool canOpenAdminView;
  final bool canManageSetup;
  final bool canReviewPayments;
  final bool canPublishIuranData;
  final bool canPublishFinance;
  final bool showOperatorFallbackNotice;

  bool get isWargaMode => !canOpenAdminView;
}

final iuranAccessProvider = FutureProvider.autoDispose<IuranAccessState>((
  ref,
) async {
  final auth = ref.watch(authProvider);
  if (auth.user == null) {
    return const IuranAccessState(
      canOpenAdminView: false,
      canManageSetup: false,
      canReviewPayments: false,
      canPublishIuranData: false,
      canPublishFinance: false,
      showOperatorFallbackNotice: false,
    );
  }
  if (auth.isSysadmin) {
    return const IuranAccessState(
      canOpenAdminView: true,
      canManageSetup: true,
      canReviewPayments: true,
      canPublishIuranData: true,
      canPublishFinance: true,
      showOperatorFallbackNotice: false,
    );
  }
  if (!auth.isOperator) {
    return const IuranAccessState(
      canOpenAdminView: false,
      canManageSetup: false,
      canReviewPayments: false,
      canPublishIuranData: false,
      canPublishFinance: false,
      showOperatorFallbackNotice: false,
    );
  }

  try {
    final profile = await ref
        .watch(workspaceAccessServiceProvider)
        .getCurrentAccessProfile();
    if (profile == null || !profile.member.hasActiveSubscription) {
      return const IuranAccessState(
        canOpenAdminView: false,
        canManageSetup: false,
        canReviewPayments: false,
        canPublishIuranData: false,
        canPublishFinance: false,
        showOperatorFallbackNotice: true,
      );
    }

    final canManageSetup = profile.orgMemberships.any(
      (membership) => membership.isActive && membership.canManageIuran,
    );
    final canReviewPayments = profile.orgMemberships.any(
      (membership) =>
          membership.isActive &&
          (membership.canManageIuran || membership.canVerifyIuranPayment),
    );
    final canPublishIuranData = canManageSetup;
    final canPublishFinance =
        profile.canPublishFinanceByPlan &&
        profile.orgMemberships.any(
          (membership) => membership.isActive && membership.canPublishFinance,
        );
    final canOpenAdminView = canManageSetup || canReviewPayments;

    return IuranAccessState(
      canOpenAdminView: canOpenAdminView,
      canManageSetup: canManageSetup,
      canReviewPayments: canReviewPayments,
      canPublishIuranData: canPublishIuranData,
      canPublishFinance: canPublishFinance,
      showOperatorFallbackNotice: !canOpenAdminView,
    );
  } catch (_) {
    return const IuranAccessState(
      canOpenAdminView: false,
      canManageSetup: false,
      canReviewPayments: false,
      canPublishIuranData: false,
      canPublishFinance: false,
      showOperatorFallbackNotice: true,
    );
  }
});

final iuranListDataProvider = FutureProvider.autoDispose<IuranListData>((ref) {
  final auth = ref.watch(authProvider);
  ref.watch(iuranRefreshTickProvider);
  return ref.watch(iuranServiceProvider).fetchList(auth);
});

final iuranFormOptionsProvider = FutureProvider.autoDispose<IuranFormOptions>((
  ref,
) async {
  final auth = ref.watch(authProvider);
  return ref.watch(iuranServiceProvider).fetchFormOptions(auth);
});
