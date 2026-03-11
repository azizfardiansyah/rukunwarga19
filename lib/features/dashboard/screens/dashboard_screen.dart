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
  bool _isGridView = true; // default: grid view (compact cards)

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
          tone: AppTheme.primaryColor,
          onTap: () => context.go(Routes.warga),
        ),
      if (showSelfWargaSetup)
        _MenuEntry(
          icon: Icons.person_add_alt_1_rounded,
          label: 'Lengkapi Warga',
          subtitle: 'Isi data diri Anda',
          tone: AppTheme.primaryColor,
          onTap: () => context.push(Routes.wargaForm),
        ),
      if (!isWarga)
        _MenuEntry(
          icon: Icons.family_restroom_rounded,
          label: 'Kartu Keluarga',
          subtitle: 'Data KK warga',
          tone: AppTheme.infoColor,
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
          tone: AppTheme.infoColor,
          onTap: () => context.go(Routes.kkForm),
        ),
      _MenuEntry(
        icon: Icons.badge_rounded,
        label: 'Dokumen',
        subtitle: 'Arsip dokumen warga',
        tone: AppTheme.accentColor,
        onTap: () => context.push(Routes.dokumen),
      ),
    ];

    // ── Group 2: Layanan ──
    final layananItems = <_MenuEntry>[
      _MenuEntry(
        icon: Icons.mail_rounded,
        label: 'Surat Pengantar',
        subtitle: 'Ajukan & pantau surat',
        tone: const Color(0xFF6366F1),
        onTap: () => context.push(Routes.surat),
      ),
      _MenuEntry(
        icon: Icons.payments_rounded,
        label: 'Iuran',
        subtitle: 'Tagihan & pembayaran',
        tone: AppTheme.primaryDark,
        onTap: () => context.push(Routes.iuran),
      ),
      if (canOpenFinance)
        _MenuEntry(
          icon: Icons.account_balance_wallet_rounded,
          label: 'Keuangan',
          subtitle: 'Arus kas & transaksi',
          tone: const Color(0xFF0891B2),
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
          tone: const Color(0xFF7C3AED),
          onTap: () => context.push(Routes.organization),
        ),
      _MenuEntry(
        icon: Icons.campaign_rounded,
        label: 'Pengumuman',
        subtitle: 'Info & berita warga',
        tone: const Color(0xFFDB2777),
        onTap: () => context.push(Routes.announcements),
      ),
      if (!isWarga)
        _MenuEntry(
          icon: Icons.insights_rounded,
          label: 'Laporan',
          subtitle: 'Statistik & ringkasan',
          tone: const Color(0xFF475569),
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
          // ── Header hero with stats ──
          _buildHeader(
            authState: authState,
            userName: userName,
            roleLabel: roleLabel,
            isWarga: isWarga,
            statsAsync: statsAsync,
            suratSummaryAsync: suratSummaryAsync,
          ),

          // ── Setup hint ──
          if (showSetupMenu) _buildSetupHint(showSelfKkSetup: showSelfKkSetup),

          // ── Menu section header with view toggle ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 0),
            child: Row(
              children: [
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
  // Header — compact, with real avatar
  // ─────────────────────────────────────────────────────────
  Widget _buildHeader({
    required AuthState authState,
    required String userName,
    required String roleLabel,
    required bool isWarga,
    required AsyncValue<DashboardStats> statsAsync,
    required AsyncValue<SuratDashboardSummary> suratSummaryAsync,
  }) {
    // Build avatar URL from PocketBase user record
    final user = authState.user;
    final avatarFile = user?.getStringValue('avatar') ?? '';
    final avatarUrl = (avatarFile.isNotEmpty && user != null)
        ? getFileUrl(user, avatarFile)
        : null;

    return Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.headerGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 8, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Row 1: Avatar + Name + Role + Notification ──
              Row(
                children: [
                  // Avatar with network image or fallback initial
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    backgroundImage: avatarUrl != null
                        ? NetworkImage(avatarUrl)
                        : null,
                    child: avatarUrl == null
                        ? Text(
                            userName.isNotEmpty
                                ? userName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  // Name + role badge inline
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            userName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            roleLabel,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Notification icon
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.notifications_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: () => context.push(Routes.notifikasi),
                    ),
                  ),
                ],
              ),
              // ── Row 2: Inline stats (admin only) ──
              if (!isWarga) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _InlineStat(
                        value: statsAsync.maybeWhen(
                          data: (s) => s.totalWarga.toString(),
                          orElse: () => '—',
                        ),
                        label: 'Warga',
                        onTap: () =>
                            context.push('${Routes.laporan}?focus=warga_total'),
                      ),
                      _statDivider(),
                      _InlineStat(
                        value: statsAsync.maybeWhen(
                          data: (s) => s.totalKk.toString(),
                          orElse: () => '—',
                        ),
                        label: 'KK',
                        onTap: () =>
                            context.push('${Routes.laporan}?focus=kk_total'),
                      ),
                      _statDivider(),
                      _InlineStat(
                        value: suratSummaryAsync.maybeWhen(
                          data: (s) => s.total.toString(),
                          orElse: () => '—',
                        ),
                        label: 'Surat',
                        onTap: () =>
                            context.push('${Routes.laporan}?focus=surat_total'),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _statDivider() {
    return Container(
      width: 1,
      height: 24,
      color: Colors.white.withValues(alpha: 0.15),
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
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.warningColor.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: AppTheme.warningColor,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                showSelfKkSetup
                    ? 'Lengkapi data KK terlebih dahulu.'
                    : 'Lengkapi data warga Anda.',
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w500,
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
          // Section label
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              children: [
                Icon(group.icon, size: 13, color: AppTheme.textTertiary),
                const SizedBox(width: 5),
                Text(
                  group.title.toUpperCase(),
                  style: AppTheme.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
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
// GRID CARD — compact 3-column card (icon + label)
// ═══════════════════════════════════════════════════════════════════
class _GridCard extends StatelessWidget {
  final _MenuEntry entry;

  const _GridCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: entry.onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: entry.tone.withValues(alpha: 0.12)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      entry.tone.withValues(alpha: 0.12),
                      entry.tone.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(entry.icon, size: 21, color: entry.tone),
              ),
              const SizedBox(height: 8),
              Text(
                entry.label,
                style: AppTheme.caption.copyWith(
                  fontWeight: FontWeight.w600,
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
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: entry.tone.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
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
                        fontWeight: FontWeight.w600,
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
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textTertiary,
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
// INLINE STAT — compact stat inside header
// ═══════════════════════════════════════════════════════════════════
class _InlineStat extends StatelessWidget {
  const _InlineStat({required this.value, required this.label, this.onTap});

  final String value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// SURAT SUMMARY — compact horizontal chips
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.mail_outline_rounded,
                size: 16,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 6),
              Text(
                'Ringkasan Surat',
                style: AppTheme.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _chip(
                'Total',
                summary.total,
                AppTheme.primaryColor,
                () => onOpenFocus('surat_total'),
              ),
              const SizedBox(width: 5),
              _chip(
                'Aksi',
                summary.actionRequired,
                AppTheme.accentColor,
                () => onOpenFocus('surat_action'),
              ),
              const SizedBox(width: 5),
              _chip(
                'Revisi',
                summary.needRevision,
                AppTheme.warningColor,
                () => onOpenFocus('surat_revision'),
              ),
              const SizedBox(width: 5),
              _chip(
                'Selesai',
                summary.completed,
                AppTheme.successColor,
                () => onOpenFocus('surat_completed'),
              ),
              const SizedBox(width: 5),
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
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value.toString(),
                style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                label,
                style: AppTheme.caption.copyWith(fontSize: 9, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
