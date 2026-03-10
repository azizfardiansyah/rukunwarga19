// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../core/services/pocketbase_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/surat_service.dart';
import '../../../core/utils/area_access.dart';
import '../../surat/providers/surat_providers.dart';

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
    final suratSummaryAsync = ref.watch(suratDashboardSummaryProvider);

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
                        label: 'Surat Pengantar',
                        value: suratSummaryAsync.maybeWhen(
                          data: (summary) => summary.actionRequired.toString(),
                          orElse: () => '...',
                        ),
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
                        tone: AppTheme.primaryColor,
                        onTap: () => context.go(Routes.warga),
                      ),
                    if (showSelfWargaSetup)
                      _MenuCard(
                        icon: Icons.person_add_alt_1_rounded,
                        label: 'Lengkapi Warga',
                        tone: AppTheme.primaryColor,
                        onTap: () => context.push(Routes.wargaForm),
                      ),
                    if (!isWarga)
                      _MenuCard(
                        icon: Icons.family_restroom_rounded,
                        label: 'Kartu Keluarga',
                        tone: AppTheme.secondaryColor,
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
                        tone: AppTheme.secondaryColor,
                        onTap: () => context.go(Routes.kkForm),
                      ),
                    _MenuCard(
                      icon: Icons.badge_rounded,
                      label: 'Dokumen',
                      tone: AppTheme.accentColor,
                      onTap: () => context.push(Routes.dokumen),
                    ),
                    _MenuCard(
                      icon: Icons.description_rounded,
                      label: 'Surat Pengantar',
                      tone: const Color(0xFF64748B),
                      onTap: () => context.push(Routes.surat),
                    ),
                    _MenuCard(
                      icon: Icons.payments_rounded,
                      label: 'Iuran',
                      tone: AppTheme.primaryDark,
                      onTap: () => context.push(Routes.iuran),
                    ),
                    _MenuCard(
                      icon: Icons.campaign_rounded,
                      label: 'Pengumuman',
                      tone: const Color(0xFF8D6E63),
                      onTap: () => context.push(Routes.announcements),
                    ),
                  ],
                ),
                if (!isWarga) ...[
                  const SizedBox(height: 18),
                  suratSummaryAsync.when(
                    data: (summary) => _SuratSummaryCard(summary: summary),
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                ],
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
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: AppTheme.cardDecoration(),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 10),
            Text(value, style: AppTheme.heading2.copyWith(color: color)),
            Text(label, style: AppTheme.caption),
          ],
        ),
      ),
    );
  }
}

class _SuratSummaryCard extends StatelessWidget {
  const _SuratSummaryCard({required this.summary});

  final SuratDashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.analytics_outlined,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ringkasan Surat Pengantar', style: AppTheme.heading3),
                    const SizedBox(height: 2),
                    Text(
                      'Pantau antrean surat dan progres penyelesaiannya.',
                      style: AppTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _summaryChip(
                'Total',
                summary.total.toString(),
                AppTheme.primaryColor,
              ),
              _summaryChip(
                'Perlu Aksi',
                summary.actionRequired.toString(),
                AppTheme.accentColor,
              ),
              _summaryChip(
                'Revisi',
                summary.needRevision.toString(),
                AppTheme.warningColor,
              ),
              _summaryChip(
                'Selesai',
                summary.completed.toString(),
                AppTheme.successColor,
              ),
              _summaryChip(
                'Ditolak',
                summary.rejected.toString(),
                AppTheme.errorColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(String label, String value, Color color) {
    return Container(
      width: 108,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: AppTheme.heading3.copyWith(color: color)),
          const SizedBox(height: 4),
          Text(label, style: AppTheme.caption),
        ],
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color tone;

  const _MenuCard({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.tone,
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
            gradient: LinearGradient(
              colors: [
                tone.withValues(alpha: 0.92),
                tone.withValues(alpha: 0.78),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            boxShadow: [
              BoxShadow(
                color: tone.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 22, color: Colors.white),
              ),
              const SizedBox(height: 12),
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
