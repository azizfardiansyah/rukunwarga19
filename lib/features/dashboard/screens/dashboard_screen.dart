// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../core/services/pocketbase_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/area_access.dart';

class DashboardStats {
  const DashboardStats({required this.totalWarga, required this.totalKk});

  final int totalWarga;
  final int totalKk;
}

// Tambahkan provider untuk cek data warga user
final hasWargaDataProvider = FutureProvider<bool>((ref) async {
  final auth = ref.watch(authProvider);
  debugPrint(
    '[DEBUG PROVIDER] hasWargaDataProvider dipanggil, userId: ${auth.user?.id}',
  );
  if (auth.user == null) return false;
  final result = await pb
      .collection(AppConstants.colWarga)
      .getList(page: 1, perPage: 1, filter: 'user_id = "${auth.user!.id}"');
  debugPrint('[DEBUG PROVIDER] warga result: ${result.items.length}');
  return result.items.isNotEmpty;
});

// Tambahkan provider untuk cek data kartu keluarga user
final hasKartuKeluargaProvider = FutureProvider<bool>((ref) async {
  final auth = ref.watch(authProvider);
  debugPrint(
    '[DEBUG PROVIDER] hasKartuKeluargaProvider dipanggil, userId: ${auth.user?.id}',
  );
  if (auth.user == null) return false;
  final access = await resolveAreaAccessContext(auth);
  final result = await pb
      .collection(AppConstants.colKartuKeluarga)
      .getList(
        page: 1,
        perPage: 1,
        filter: buildKkScopeFilter(auth, context: access),
      );
  debugPrint('[DEBUG PROVIDER] kartu_keluarga result: ${result.items.length}');
  return result.items.isNotEmpty;
});

final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  final auth = ref.watch(authProvider);
  if (auth.user == null) {
    return const DashboardStats(totalWarga: 0, totalKk: 0);
  }

  final access = await resolveAreaAccessContext(auth);
  final wargaFilter = buildWargaScopeFilter(auth, context: access);
  final kkFilter = buildKkScopeFilter(auth, context: access);

  final wargaResult = await pb
      .collection(AppConstants.colWarga)
      .getList(page: 1, perPage: 1, filter: wargaFilter);
  final kkResult = await pb
      .collection(AppConstants.colKartuKeluarga)
      .getList(page: 1, perPage: 1, filter: kkFilter);

  return DashboardStats(
    totalWarga: wargaResult.totalItems,
    totalKk: kkResult.totalItems,
  );
});

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _hasNavigatedToKkForm = false;

  void _navigateToKkFormIfNeeded(bool hasKartuKeluarga) {
    if (_hasNavigatedToKkForm || !mounted || hasKartuKeluarga) return;
    final auth = ref.read(authProvider);
    if (!auth.isAdmin) return;
    _hasNavigatedToKkForm = true;
    debugPrint('[DEBUG] No KK data - navigating to KK form');
    context.go(Routes.kkForm);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final statsAsync = ref.watch(dashboardStatsProvider);
    final hasWargaDataAsync = ref.watch(hasWargaDataProvider);
    final userName = authState.user?.getStringValue('name').isNotEmpty == true
        ? authState.user!.getStringValue('name')
        : (authState.user?.getStringValue('nama').isNotEmpty == true
              ? authState.user!.getStringValue('nama')
              : 'User');
    final roleLabel = AppConstants.roleLabel(authState.role);
    final isWarga =
        AppConstants.normalizeRole(authState.role) == AppConstants.roleWarga;

    // Listen for hasKartuKeluarga changes and navigate if needed
    ref.listen<AsyncValue<bool>>(hasKartuKeluargaProvider, (prev, next) {
      next.whenData(_navigateToKkFormIfNeeded);
    });

    // Also check current value on first build
    final hasKkAsync = ref.watch(hasKartuKeluargaProvider);
    hasKkAsync.whenData(_navigateToKkFormIfNeeded);
    final hasKkData = hasKkAsync.maybeWhen(
      data: (value) => value,
      orElse: () => false,
    );
    final hasWargaData = hasWargaDataAsync.maybeWhen(
      data: (value) => value,
      orElse: () => false,
    );
    final showSelfWargaSetup = isWarga && hasKkData && !hasWargaData;
    final showSelfKkSetup = isWarga && !hasKkData;
    final showSetupMenu = showSelfWargaSetup || showSelfKkSetup;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Modern gradient AppBar
          SliverAppBar(
            expandedHeight: 160,
            floating: false,
            pinned: true,
            backgroundColor: AppTheme.primaryColor,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: AppTheme.headerGradient,
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  width: 2,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.2,
                                ),
                                child: Text(
                                  userName.isNotEmpty
                                      ? userName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Selamat datang,',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.75,
                                      ),
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    userName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                roleLabel,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(
                  Icons.notifications_outlined,
                  color: Colors.white,
                ),
                onPressed: () => context.push(Routes.notifikasi),
              ),
            ],
          ),

          SliverPadding(
            padding: const EdgeInsets.all(AppTheme.paddingMedium),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (!isWarga) ...[
                  Row(
                    children: [
                      _StatCard(
                        icon: Icons.people_rounded,
                        label: 'Warga',
                        value: statsAsync.maybeWhen(
                          data: (stats) => stats.totalWarga.toString(),
                          orElse: () => '...',
                        ),
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 10),
                      _StatCard(
                        icon: Icons.family_restroom_rounded,
                        label: 'KK',
                        value: statsAsync.maybeWhen(
                          data: (stats) => stats.totalKk.toString(),
                          orElse: () => '...',
                        ),
                        color: AppTheme.secondaryColor,
                      ),
                      const SizedBox(width: 10),
                      _StatCard(
                        icon: Icons.description_rounded,
                        label: 'Surat',
                        value: '-',
                        color: AppTheme.accentColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],

                // Menu Grid
                Text('Menu', style: AppTheme.heading3),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  children: [
                    if (!isWarga)
                      _MenuCard(
                        icon: Icons.people_rounded,
                        label: 'Data Warga',
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                        ),
                        onTap: () => context.go(Routes.warga),
                      ),
                    if (showSelfWargaSetup)
                      _MenuCard(
                        icon: Icons.person_add_alt_1_rounded,
                        label: 'Lengkapi Warga',
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                        ),
                        onTap: () => context.push(Routes.wargaForm),
                      ),
                    if (!isWarga)
                      _MenuCard(
                        icon: Icons.family_restroom_rounded,
                        label: 'Kartu Keluarga',
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00897B), Color(0xFF4DB6AC)],
                        ),
                        onTap: () {
                          final hasKK = ref
                              .read(hasKartuKeluargaProvider)
                              .maybeWhen(
                                data: (hasData) => hasData,
                                orElse: () => false,
                              );
                          if (hasKK) {
                            context.push(Routes.kartuKeluarga);
                          } else {
                            context.go(Routes.kkForm);
                          }
                        },
                      ),
                    if (showSelfKkSetup)
                      _MenuCard(
                        icon: Icons.add_home_work_rounded,
                        label: 'Lengkapi KK',
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00897B), Color(0xFF4DB6AC)],
                        ),
                        onTap: () => context.go(Routes.kkForm),
                      ),
                    _MenuCard(
                      icon: Icons.badge_rounded,
                      label: 'Dokumen',
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE65100), Color(0xFFFFA726)],
                      ),
                      onTap: () => context.push(Routes.dokumen),
                    ),
                    if (!isWarga)
                      _MenuCard(
                        icon: Icons.description_rounded,
                        label: 'Surat',
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6A1B9A), Color(0xFFAB47BC)],
                        ),
                        onTap: () => context.push(Routes.surat),
                      ),
                    _MenuCard(
                      icon: Icons.payments_rounded,
                      label: 'Iuran',
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
                      ),
                      onTap: () => context.push(Routes.iuran),
                    ),
                    _MenuCard(
                      icon: Icons.campaign_rounded,
                      label: 'Pengumuman',
                      gradient: const LinearGradient(
                        colors: [Color(0xFFC62828), Color(0xFFEF5350)],
                      ),
                      onTap: () => context.push(Routes.announcements),
                    ),
                  ],
                ),
                if (showSetupMenu) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusMedium,
                      ),
                      border: Border.all(
                        color: AppTheme.primaryColor.withValues(alpha: 0.14),
                      ),
                    ),
                    child: Text(
                      showSelfKkSetup
                          ? 'Akun baru ini belum punya data KK. Lengkapi KK dulu, lalu lanjut isi data warga.'
                          : 'Data warga Anda belum lengkap. Isi data warga agar akun bisa dipakai penuh.',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 4),
              Text(value, style: AppTheme.heading2.copyWith(color: color)),
              Text(label, style: AppTheme.caption),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final LinearGradient? gradient;

  const _MenuCard({
    required this.icon,
    required this.label,
    required this.onTap,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: Container(
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            boxShadow: [
              BoxShadow(
                color: (gradient?.colors.first ?? AppTheme.primaryColor)
                    .withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: Colors.white),
              const SizedBox(height: 8),
              Text(
                label,
                style: AppTheme.bodySmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
