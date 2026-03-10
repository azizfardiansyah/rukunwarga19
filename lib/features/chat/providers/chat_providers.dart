import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/chat_service.dart';
import '../../../shared/models/chat_model.dart';
import '../../auth/providers/auth_provider.dart';

class ChatRefreshTickNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final chatRefreshTickProvider =
    NotifierProvider<ChatRefreshTickNotifier, int>(ChatRefreshTickNotifier.new);

final chatBootstrapProvider = FutureProvider.autoDispose<ChatBootstrapData>((
  ref,
) async {
  ref.watch(authProvider);
  ref.watch(chatRefreshTickProvider);
  final service = ref.watch(chatServiceProvider);
  return service.bootstrap();
});

final chatAnnouncementsProvider =
    FutureProvider.autoDispose<ChatAnnouncementsData>((ref) async {
      ref.watch(authProvider);
      ref.watch(chatRefreshTickProvider);
      final service = ref.watch(chatServiceProvider);
      return service.getAnnouncements();
    });

final chatUnreadCountProvider = Provider<int>((ref) {
  final bootstrap = ref.watch(chatBootstrapProvider).asData?.value;
  return bootstrap?.totalUnreadCount ?? 0;
});
