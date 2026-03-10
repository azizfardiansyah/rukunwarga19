import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/laporan_service.dart';
import '../../auth/providers/auth_provider.dart';

class LaporanRefreshTickNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final laporanRefreshTickProvider =
    NotifierProvider<LaporanRefreshTickNotifier, int>(
      LaporanRefreshTickNotifier.new,
    );

final laporanOperationalProvider =
    FutureProvider.autoDispose.family<LaporanOperationalData, LaporanRangePreset>(
      (ref, preset) async {
        final auth = ref.watch(authProvider);
        ref.watch(laporanRefreshTickProvider);
        return ref
            .watch(laporanServiceProvider)
            .fetchOperationalData(auth, preset: preset);
      },
    );
