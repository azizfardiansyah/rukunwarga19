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
import '../../../shared/widgets/current_user_avatar.dart';
import '../../surat/providers/surat_providers.dart';

// ═══════════════════════════════════════════════════════════════════
// DATA MODELS
// ═══════════════════════════════════════════════════════════════════

class DashboardStats {
  const DashboardStats({required this.totalWarga, required this.totalKk});

  final int totalWarga;
  final int totalKk;
}

/// Represents a single menu entry with grouping info
class _MenuEntry {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color tone;
  final VoidCallback onTap;

  const _MenuEntry({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.tone,
    required this.onTap,
  });
}

/// A group of menu entries under a section header
class _MenuGroup {
  final String title;
  final IconData icon;
  final List<_MenuEntry> items;

  const _MenuGroup({
    required this.title,
    required this.icon,
    required this.items,
  });
}

// ═══════════════════════════════════════════════════════════════════
// PROVIDERS
// ═══════════════════════════════════════════════════════════════════

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

// ═══════════════════════════════════════════════════════════════════
// DASHBOARD SCREEN
// ═══════════════════════════════════════════════════════════════════

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _hasNavigatedToKkForm = false;
  bool _isGridView = true;

  void _navigateToKkFormIfNeeded(bool hasKartuKeluarga) {
    if (_hasNavigatedToKkForm || !mounted || hasKartuKeluarga) return;
    final auth = ref.read(authProvider);
    if (!auth.isOperator && !auth.isSysadmin) return;
    _hasNavigatedToKkForm = true;
    debugPrint('[DEBUG] No KK data - navigating to KK form');
    context.go(Routes.kkForm);
  }

  /// Build grouped menu entries based on user role
  List<_MenuGroup> _buildMenuGroups({
    required bool isWarga,
    required bool showSelfWargaSetup,
    required bool showSelfKkSetup,
    required bool canOpenFinance,
    required bool canOpenOrganization,
  }) {
    // ── Group 1: Data Penduduk ──
    final dataItems = <_MenuEntry>[
      if (!isWarga)
        _MenuEntry(
          icon: Icons.people_rounded,
          label: 'Data Warga',
          subtitle: 'Kelola data penduduk',
          tone: AppTheme.toneRose,
          onTap: () => context.go(Routes.warga),
        ),
      if (showSelfWargaSetup)
        _MenuEntry(
          icon: Icons.person_add_alt_1_rounded,
          label: 'Lengkapi Warga',
          subtitle: 'Isi data diri Anda',
          tone: AppTheme.tonePink,
          onTap: () => context.push(Routes.wargaForm),
        ),
      if (!isWarga)
        _MenuEntry(
          icon: Icons.family_restroom_rounded,
          label: 'Kartu Keluarga',
          subtitle: 'Data KK warga',
          tone: AppTheme.toneAmber,
          onTap: () {
            final hasKK = ref
                .read(hasKartuKeluargaProvider)
                .maybeWhen(data: (d) => d, orElse: () => false);
            hasKK
                ? context.push(Routes.kartuKeluarga)
                : context.go(Routes.kkForm);
          },
        ),
      if (showSelfKkSetup)
        _MenuEntry(
          icon: Icons.add_home_work_rounded,
          label: 'Lengkapi KK',
          subtitle: 'Isi data Kartu Keluarga',
          tone: AppTheme.toneAmber,
          onTap: () => context.go(Routes.kkForm),
        ),
      _MenuEntry(
        icon: Icons.badge_rounded,
        label: 'Dokumen',
        subtitle: 'Arsip dokumen warga',
        tone: AppTheme.toneSienna,
        onTap: () => context.push(Routes.dokumen),
      ),
    ];

    // ── Group 2: Layanan ──
    final layananItems = <_MenuEntry>[
      _MenuEntry(
        icon: Icons.mail_rounded,
        label: 'Surat Pengantar',
        subtitle: 'Ajukan & pantau surat',
        tone: AppTheme.toneCrimson,
        onTap: () => context.push(Routes.surat),
      ),
      _MenuEntry(
        icon: Icons.payments_rounded,
        label: 'Iuran',
        subtitle: 'Tagihan & pembayaran',
        tone: AppTheme.toneGold,
        onTap: () => context.push(Routes.iuran),
      ),
      if (canOpenFinance)
        _MenuEntry(
          icon: Icons.account_balance_wallet_rounded,
          label: 'Keuangan',
          subtitle: 'Arus kas & transaksi',
          tone: AppTheme.toneTerracotta,
          onTap: () => context.push(Routes.finance),
        ),
    ];

    // ── Group 3: Lainnya ──
    final lainnyaItems = <_MenuEntry>[
      if (canOpenOrganization)
        _MenuEntry(
          icon: Icons.account_tree_rounded,
          label: 'Organisasi',
          subtitle: 'Struktur & pengurus',
          tone: AppTheme.toneCharcoal,
          onTap: () => context.push(Routes.organization),
        ),
      _MenuEntry(
        icon: Icons.campaign_rounded,
        label: 'Pengumuman',
        subtitle: 'Info & berita warga',
        tone: AppTheme.tonePink,
        onTap: () => context.push(Routes.announcements),
      ),
      if (!isWarga)
        _MenuEntry(
          icon: Icons.insights_rounded,
          label: 'Laporan',
          subtitle: 'Statistik & ringkasan',
          tone: AppTheme.toneSlate,
          onTap: () => context.push(Routes.laporan),
        ),
    ];

    return [
      if (dataItems.isNotEmpty)
        _MenuGroup(
          title: 'Data Penduduk',
          icon: Icons.folder_shared_outlined,
          items: dataItems,
        ),
      if (layananItems.isNotEmpty)
        _MenuGroup(
          title: 'Layanan',
          icon: Icons.handshake_outlined,
          items: layananItems,
        ),
      if (lainnyaItems.isNotEmpty)
        _MenuGroup(
          title: 'Lainnya',
          icon: Icons.more_horiz_rounded,
          items: lainnyaItems,
        ),
    ];
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
    final isWarga = !authState.isOperator && !authState.isSysadmin;
    final canOpenOrganization =
        authState.isSysadmin || authState.hasRwWideAccess;
    final canOpenFinance = authState.isOperator || authState.isSysadmin;
    final suratSummaryAsync = ref.watch(suratDashboardSummaryProvider);

    ref.listen<AsyncValue<bool>>(hasKartuKeluargaProvider, (prev, next) {
      next.whenData(_navigateToKkFormIfNeeded);
    });

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

    final menuGroups = _buildMenuGroups(
      isWarga: isWarga,
      showSelfWargaSetup: showSelfWargaSetup,
      showSelfKkSetup: showSelfKkSetup,
      canOpenFinance: canOpenFinance,
      canOpenOrganization: canOpenOrganization,
    );

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ── Header hero ──
          _buildHeader(
            authState: authState,
            userName: userName,
            roleLabel: roleLabel,
            isWarga: isWarga,
            statsAsync: statsAsync,
            suratSummaryAsync: suratSummaryAsync,
          ),

          // ── Quick stat cards (admin only) ──
          if (!isWarga) ...[
            const SizedBox(height: 16),
            _buildQuickStats(statsAsync, suratSummaryAsync),
          ],

          // ── Setup hint ──
          if (showSetupMenu) _buildSetupHint(showSelfKkSetup: showSelfKkSetup),

          // ── Menu section header with view toggle ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
            child: Row(
              children: [
                // Accent bar
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Menu',
                    style: AppTheme.heading3.copyWith(
                      fontSize: 16,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                // View toggle
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ViewToggleButton(
                        icon: Icons.grid_view_rounded,
                        isActive: _isGridView,
                        onTap: () => setState(() => _isGridView = true),
                      ),
                      _ViewToggleButton(
                        icon: Icons.view_list_rounded,
                        isActive: !_isGridView,
                        onTap: () => setState(() => _isGridView = false),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Menu groups ──
          const SizedBox(height: 12),
          for (final group in menuGroups) ...[_buildGroupSection(group)],

          // ── Surat summary (admin only) ──
          if (!isWarga)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: suratSummaryAsync.when(
                data: (summary) => _SuratSummaryCard(
                  summary: summary,
                  onOpenFocus: (focus) =>
                      context.push('${Routes.laporan}?focus=$focus'),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
            ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // Quick stat cards — signature horizontal cards below header
  // ─────────────────────────────────────────────────────────
  Widget _buildQuickStats(
    AsyncValue<DashboardStats> statsAsync,
    AsyncValue<SuratDashboardSummary> suratSummaryAsync,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _QuickStatCard(
              label: 'Warga',
              value: statsAsync.maybeWhen(
                data: (s) => s.totalWarga.toString(),
                orElse: () => '—',
              ),
              icon: Icons.people_rounded,
              color: AppTheme.toneRose,
              onTap: () => context.push('${Routes.laporan}?focus=warga_total'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _QuickStatCard(
              label: 'KK',
              value: statsAsync.maybeWhen(
                data: (s) => s.totalKk.toString(),
                orElse: () => '—',
              ),
              icon: Icons.family_restroom_rounded,
              color: AppTheme.toneAmber,
              onTap: () => context.push('${Routes.laporan}?focus=kk_total'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _QuickStatCard(
              label: 'Surat',
              value: suratSummaryAsync.maybeWhen(
                data: (s) => s.total.toString(),
                orElse: () => '—',
              ),
              icon: Icons.mail_rounded,
              color: AppTheme.toneCrimson,
              onTap: () => context.push('${Routes.laporan}?focus=surat_total'),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // Header — dark, bold, with warm accent
  // ─────────────────────────────────────────────────────────
  Widget _buildHeader({
    required AuthState authState,
    required String userName,
    required String roleLabel,
    required bool isWarga,
    required AsyncValue<DashboardStats> statsAsync,
    required AsyncValue<SuratDashboardSummary> suratSummaryAsync,
  }) {
    // Time-based greeting
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Selamat Pagi'
        : hour < 17
        ? 'Selamat Siang'
        : 'Selamat Malam';

    return Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.headerGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 12, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Row: Avatar + Greeting + Notification ──
              Row(
                children: [
                  const CurrentUserAvatar(
                    size: 40,
                    showRing: true,
                    ringColor: Colors.white24,
                    backgroundColor: Color(0x33FFFFFF),
                    textColor: Colors.white,
                  ),
                  const SizedBox(width: 12),
                  // Name + greeting
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          greeting,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                userName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                gradient: AppTheme.warmGradient,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                roleLabel,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Notification icon
                  SizedBox(
                    width: 38,
                    height: 38,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.notifications_outlined,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      onPressed: () => context.push(Routes.notifikasi),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // Setup hint banner
  // ─────────────────────────────────────────────────────────
  Widget _buildSetupHint({required bool showSelfKkSetup}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.warningColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppTheme.warningColor.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: AppTheme.warningColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                showSelfKkSetup
                    ? 'Lengkapi data KK terlebih dahulu.'
                    : 'Lengkapi data warga Anda.',
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // Menu group section (renders grid or list based on toggle)
  // ─────────────────────────────────────────────────────────
  Widget _buildGroupSection(_MenuGroup group) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section label with accent dot
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  group.title.toUpperCase(),
                  style: AppTheme.caption.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    fontSize: 10,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          // Grid or list
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: _isGridView
                ? _buildGrid(group.items, key: ValueKey('grid_${group.title}'))
                : _buildList(group.items, key: ValueKey('list_${group.title}')),
          ),
        ],
      ),
    );
  }

  // ─── Grid layout (3 columns) ───
  Widget _buildGrid(List<_MenuEntry> items, {Key? key}) {
    final rows = <Widget>[];
    for (int i = 0; i < items.length; i += 3) {
      final rowItems = items.sublist(i, (i + 3).clamp(0, items.length));
      rows.add(
        Row(
          children: [
            for (int j = 0; j < 3; j++) ...[
              if (j > 0) const SizedBox(width: 10),
              Expanded(
                child: j < rowItems.length
                    ? _GridCard(entry: rowItems[j])
                    : const SizedBox.shrink(),
              ),
            ],
          ],
        ),
      );
      if (i + 3 < items.length) rows.add(const SizedBox(height: 10));
    }
    return Column(key: key, children: rows);
  }

  // ─── List layout (detailed rows) ───
  Widget _buildList(List<_MenuEntry> items, {Key? key}) {
    return Container(
      key: key,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            _ListRow(entry: items[i]),
            if (i < items.length - 1)
              Divider(
                height: 0,
                thickness: 0.5,
                indent: 52,
                color: AppTheme.dividerColor.withValues(alpha: 0.4),
              ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// QUICK STAT CARD — signature stat tile
// ═══════════════════════════════════════════════════════════════════
class _QuickStatCard extends StatelessWidget {
  const _QuickStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.15),
                    color.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 17, color: color),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppTheme.textPrimary,
                letterSpacing: -0.5,
                height: 1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTheme.caption.copyWith(
                color: AppTheme.textTertiary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// VIEW TOGGLE BUTTON
// ═══════════════════════════════════════════════════════════════════
class _ViewToggleButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _ViewToggleButton({
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 17,
          color: isActive ? Colors.white : AppTheme.textTertiary,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// GRID CARD — bold, warm-toned 3-column card
// ═══════════════════════════════════════════════════════════════════
class _GridCard extends StatelessWidget {
  final _MenuEntry entry;

  const _GridCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: entry.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: entry.tone.withValues(alpha: 0.12)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      entry.tone.withValues(alpha: 0.14),
                      entry.tone.withValues(alpha: 0.04),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(entry.icon, size: 22, color: entry.tone),
              ),
              const SizedBox(height: 10),
              Text(
                entry.label,
                style: AppTheme.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  fontSize: 11,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// LIST ROW — detailed row (icon + label + subtitle + chevron)
// ═══════════════════════════════════════════════════════════════════
class _ListRow extends StatelessWidget {
  final _MenuEntry entry;

  const _ListRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: entry.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      entry.tone.withValues(alpha: 0.14),
                      entry.tone.withValues(alpha: 0.04),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(entry.icon, size: 18, color: entry.tone),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.label,
                      style: AppTheme.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      entry.subtitle,
                      style: AppTheme.caption.copyWith(
                        color: AppTheme.textTertiary,
                        fontSize: 11,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: entry.tone.withValues(alpha: 0.4),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// SURAT SUMMARY — warm-toned horizontal chips
// ═══════════════════════════════════════════════════════════════════
class _SuratSummaryCard extends StatelessWidget {
  const _SuratSummaryCard({required this.summary, required this.onOpenFocus});

  final SuratDashboardSummary summary;
  final ValueChanged<String> onOpenFocus;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerColor.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(
                  Icons.mail_outline_rounded,
                  size: 14,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Ringkasan Surat',
                style: AppTheme.caption.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _chip(
                'Total',
                summary.total,
                AppTheme.toneRose,
                () => onOpenFocus('surat_total'),
              ),
              const SizedBox(width: 6),
              _chip(
                'Aksi',
                summary.actionRequired,
                AppTheme.toneAmber,
                () => onOpenFocus('surat_action'),
              ),
              const SizedBox(width: 6),
              _chip(
                'Revisi',
                summary.needRevision,
                AppTheme.toneGold,
                () => onOpenFocus('surat_revision'),
              ),
              const SizedBox(width: 6),
              _chip(
                'Selesai',
                summary.completed,
                AppTheme.successColor,
                () => onOpenFocus('surat_completed'),
              ),
              const SizedBox(width: 6),
              _chip(
                'Tolak',
                summary.rejected,
                AppTheme.errorColor,
                () => onOpenFocus('surat_rejected'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, int value, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value.toString(),
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                label,
                style: AppTheme.caption.copyWith(
                  fontSize: 9,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
