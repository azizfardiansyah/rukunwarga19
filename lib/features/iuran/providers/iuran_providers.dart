import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/iuran_service.dart';
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
