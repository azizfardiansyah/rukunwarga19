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

class AnnouncementRefreshTickNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final announcementRefreshTickProvider =
    NotifierProvider<AnnouncementRefreshTickNotifier, int>(
      AnnouncementRefreshTickNotifier.new,
    );

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
      ref.watch(announcementRefreshTickProvider);
      final service = ref.watch(chatServiceProvider);
      return service.getAnnouncements();
    });

class AnnouncementDetailRequest {
  const AnnouncementDetailRequest({
    required this.announcementId,
    this.markAsViewed = true,
  });

  final String announcementId;
  final bool markAsViewed;

  @override
  bool operator ==(Object other) {
    return other is AnnouncementDetailRequest &&
        other.announcementId == announcementId &&
        other.markAsViewed == markAsViewed;
  }

  @override
  int get hashCode => Object.hash(announcementId, markAsViewed);
}

final announcementDetailProvider =
    FutureProvider.autoDispose.family<AnnouncementModel, AnnouncementDetailRequest>(
      (ref, request) async {
        ref.watch(authProvider);
        ref.watch(announcementRefreshTickProvider);
        final service = ref.watch(chatServiceProvider);
        return service.getAnnouncementDetail(
          request.announcementId,
          markAsViewed: request.markAsViewed,
        );
      },
    );

final announcementStatsProvider =
    FutureProvider.autoDispose.family<AnnouncementStatsModel, String>((
      ref,
      announcementId,
    ) async {
      ref.watch(authProvider);
      ref.watch(announcementRefreshTickProvider);
      final service = ref.watch(chatServiceProvider);
      return service.getAnnouncementStats(announcementId);
    });

final chatUnreadCountProvider = Provider<int>((ref) {
  final bootstrap =
      ref.watch(chatBootstrapProvider).maybeWhen(
        data: (value) => value,
        orElse: () => null,
      ) ??
      ref.watch(chatServiceProvider).getCachedBootstrap();
  return bootstrap?.totalUnreadCount ?? 0;
});
