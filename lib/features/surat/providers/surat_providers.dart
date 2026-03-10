import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/surat_service.dart';
import '../../auth/providers/auth_provider.dart';

class SuratRefreshTickNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final suratRefreshTickProvider =
    NotifierProvider<SuratRefreshTickNotifier, int>(
      SuratRefreshTickNotifier.new,
    );

final suratDashboardSummaryProvider =
    FutureProvider.autoDispose<SuratDashboardSummary>((ref) async {
      final auth = ref.watch(authProvider);
      ref.watch(suratRefreshTickProvider);
      return ref.watch(suratServiceProvider).fetchDashboardSummary(auth);
    });

final suratNotificationsProvider =
    FutureProvider.autoDispose<List<SuratNotificationItem>>((ref) async {
      final auth = ref.watch(authProvider);
      ref.watch(suratRefreshTickProvider);
      return ref.watch(suratServiceProvider).fetchNotifications(auth);
    });
