import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/organization_service.dart';

class OrganizationRefreshTickNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final organizationRefreshTickProvider =
    NotifierProvider<OrganizationRefreshTickNotifier, int>(
      OrganizationRefreshTickNotifier.new,
    );

final organizationOverviewProvider =
    FutureProvider.autoDispose<OrganizationOverviewData>((ref) async {
      ref.watch(organizationRefreshTickProvider);
      return ref.watch(organizationServiceProvider).fetchOverview();
    });

final organizationStructureOverviewProvider =
    FutureProvider.autoDispose<OrganizationOverviewData?>((ref) async {
      ref.watch(organizationRefreshTickProvider);
      return ref.watch(organizationServiceProvider).fetchReadableOverview();
    });
