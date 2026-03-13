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
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/current_user_avatar.dart';
import '../../../shared/widgets/menu_item_card.dart';
import '../../surat/providers/surat_providers.dart';

// ═══════════════════════════════════════════════════════════════════
// DATA MODELS
// ═══════════════════════════════════════════════════════════════════

class DashboardStats {
  const DashboardStats({
    required this.totalWarga,
    required this.totalKk,
    required this.totalLakiLaki,
    required this.totalPerempuan,
  });

  final int totalWarga;
  final int totalKk;
  final int totalLakiLaki;
  final int totalPerempuan;
}

/// Represents a single menu entry with grouping info
class _MenuEntry {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color tone;
  final VoidCallback onTap;
  final Widget? badge;

  const _MenuEntry({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.tone,
    required this.onTap,
    this.badge,
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
    return const DashboardStats(
      totalWarga: 0,
      totalKk: 0,
      totalLakiLaki: 0,
      totalPerempuan: 0,
    );
  }

  final access = await resolveAreaAccessContext(auth);
  final wargaFilter = buildWargaScopeFilter(auth, context: access);
  final kkFilter = buildKkScopeFilter(auth, context: access);
  final lakiLakiFilter = _appendFilter(
    wargaFilter,
    'jenis_kelamin = "Laki-laki"',
  );
  final perempuanFilter = _appendFilter(
    wargaFilter,
    'jenis_kelamin = "Perempuan"',
  );

  final wargaResult = await pb
      .collection(AppConstants.colWarga)
      .getList(page: 1, perPage: 1, filter: wargaFilter);
  final kkResult = await pb
      .collection(AppConstants.colKartuKeluarga)
      .getList(page: 1, perPage: 1, filter: kkFilter);
  final lakiLakiResult = await pb
      .collection(AppConstants.colWarga)
      .getList(page: 1, perPage: 1, filter: lakiLakiFilter);
  final perempuanResult = await pb
      .collection(AppConstants.colWarga)
      .getList(page: 1, perPage: 1, filter: perempuanFilter);

  return DashboardStats(
    totalWarga: wargaResult.totalItems,
    totalKk: kkResult.totalItems,
    totalLakiLaki: lakiLakiResult.totalItems,
    totalPerempuan: perempuanResult.totalItems,
  );
});

String _appendFilter(String base, String condition) {
  final trimmedBase = base.trim();
  if (trimmedBase.isEmpty) {
    return condition;
  }
  return '($trimmedBase) && $condition';
}

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
    DashboardStats? stats,
    SuratDashboardSummary? suratSummary,
  }) {
    final wargaSubtitle = stats == null
        ? 'Kelola data penduduk'
        : 'L ${stats.totalLakiLaki} · P ${stats.totalPerempuan}';
    final kkSubtitle = stats == null
        ? 'Data KK warga'
        : '${stats.totalWarga} warga · L ${stats.totalLakiLaki} · P ${stats.totalPerempuan}';
    final suratSubtitle = suratSummary == null
        ? 'Ajukan & pantau surat'
        : '${suratSummary.total} total · ${suratSummary.needRevision} revisi · ${suratSummary.completed} selesai';
    // ── Group 1: Data Penduduk ──
    final dataItems = <_MenuEntry>[
      if (!isWarga)
        _MenuEntry(
          icon: Icons.people_rounded,
          label: 'Data Warga',
          subtitle: wargaSubtitle,
          tone: AppTheme.toneRose,
          onTap: () => context.push(Routes.warga),
          badge: stats == null
              ? null
              : AppBadge(
                  label: '${stats.totalWarga}',
                  type: AppBadgeType.info,
                  size: AppBadgeSize.small,
                ),
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
          subtitle: kkSubtitle,
          tone: AppTheme.toneAmber,
          onTap: () {
            final hasKK = ref
                .read(hasKartuKeluargaProvider)
                .maybeWhen(data: (d) => d, orElse: () => false);
            hasKK
                ? context.push(Routes.kartuKeluarga)
                : context.go(Routes.kkForm);
          },
          badge: stats == null
              ? null
              : AppBadge(
                  label: '${stats.totalKk} KK',
                  type: AppBadgeType.warning,
                  size: AppBadgeSize.small,
                ),
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
        subtitle: suratSubtitle,
        tone: AppTheme.toneCrimson,
        onTap: () => context.push(Routes.surat),
        badge: suratSummary == null
            ? null
            : AppBadge(
                label: suratSummary.actionRequired > 0
                    ? '${suratSummary.actionRequired} aksi'
                    : '${suratSummary.total} total',
                type: suratSummary.actionRequired > 0
                    ? AppBadgeType.warning
                    : AppBadgeType.info,
                size: AppBadgeSize.small,
              ),
      ),
      _MenuEntry(
        icon: Icons.payments_rounded,
        label: 'Iuran',
        subtitle: 'Tagihan, lunas, dan verifikasi',
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

    // ── Group 3: Info Lingkungan ──
    final lingkunganItems = <_MenuEntry>[
      _MenuEntry(
        icon: Icons.campaign_rounded,
        label: 'Pengumuman',
        subtitle: 'Info & berita warga',
        tone: AppTheme.tonePink,
        onTap: () => context.push(Routes.announcements),
      ),
      if (canOpenOrganization)
        _MenuEntry(
          icon: Icons.account_tree_rounded,
          label: 'Organisasi',
          subtitle: 'Pengurus RW, RT, DKM, Karang Taruna, dan Posyandu',
          tone: AppTheme.toneCharcoal,
          onTap: () => context.push(Routes.organization),
        ),
    ];

    // ── Group 4: Lainnya ──
    final lainnyaItems = <_MenuEntry>[
      if (!isWarga)
        _MenuEntry(
          icon: Icons.insights_rounded,
          label: 'Laporan',
          subtitle: 'Statistik & ringkasan',
          tone: AppTheme.toneSlate,
          onTap: () => context.push(Routes.laporan),
        ),
    ];

    final groups = <_MenuGroup>[];

    if (isWarga) {
      if (lingkunganItems.isNotEmpty) {
        groups.add(
          _MenuGroup(
            title: 'Info Lingkungan',
            icon: Icons.apartment_outlined,
            items: lingkunganItems,
          ),
        );
      }
      if (layananItems.isNotEmpty) {
        groups.add(
          _MenuGroup(
            title: 'Layanan',
            icon: Icons.handshake_outlined,
            items: layananItems,
          ),
        );
      }
      if (dataItems.isNotEmpty) {
        groups.add(
          _MenuGroup(
            title: 'Data Penduduk',
            icon: Icons.folder_shared_outlined,
            items: dataItems,
          ),
        );
      }
    } else {
      if (dataItems.isNotEmpty) {
        groups.add(
          _MenuGroup(
            title: 'Data Penduduk',
            icon: Icons.folder_shared_outlined,
            items: dataItems,
          ),
        );
      }
      if (layananItems.isNotEmpty) {
        groups.add(
          _MenuGroup(
            title: 'Layanan',
            icon: Icons.handshake_outlined,
            items: layananItems,
          ),
        );
      }
      if (lingkunganItems.isNotEmpty) {
        groups.add(
          _MenuGroup(
            title: 'Info Lingkungan',
            icon: Icons.apartment_outlined,
            items: lingkunganItems,
          ),
        );
      }
    }

    if (lainnyaItems.isNotEmpty) {
      groups.add(
        _MenuGroup(
          title: 'Lainnya',
          icon: Icons.more_horiz_rounded,
          items: lainnyaItems,
        ),
      );
    }

    return groups;
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
    final canOpenOrganization = authState.isAuthenticated;
    final canOpenFinance = authState.isOperator || authState.isSysadmin;
    final suratSummaryAsync = ref.watch(suratDashboardSummaryProvider);
    final stats = statsAsync.asData?.value;
    final suratSummary = suratSummaryAsync.asData?.value;

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
      stats: stats,
      suratSummary: suratSummary,
    );

    return Scaffold(
      backgroundColor: AppTheme.pageBackgroundFor(context),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ── Header hero ──
          _buildHeader(
            userName: userName,
            roleLabel: roleLabel,
            isWarga: isWarga,
          ),

          // ── Quick stat cards (admin only) ──

          // ── Setup hint ──
          if (showSetupMenu) _buildSetupHint(showSelfKkSetup: showSelfKkSetup),

          // ── Menu section header with view toggle ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
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

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  Widget _buildHeader({
    required String userName,
    required String roleLabel,
    required bool isWarga,
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
                    backgroundColor: Colors.white24,
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
                            AppBadge(
                              label: roleLabel,
                              type: AppBadgeType.info,
                              size: AppBadgeSize.small,
                              style: AppBadgeStyle.solid,
                              icon: isWarga
                                  ? Icons.person_outline_rounded
                                  : Icons.workspace_premium_outlined,
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
        decoration: AppTheme.cardDecorationFor(
          context,
          color: AppTheme.warningColor.withValues(alpha: 0.08),
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
                    ? MenuItemCard(
                        icon: rowItems[j].icon,
                        label: rowItems[j].label,
                        helperText: rowItems[j].subtitle,
                        badge: rowItems[j].badge,
                        iconColor: rowItems[j].tone,
                        onTap: rowItems[j].onTap,
                      )
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
      decoration: AppTheme.cardDecorationFor(context, borderRadius: 14),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            _ListRow(entry: items[i]),
            if (i < items.length - 1)
              Divider(
                height: 0,
                thickness: 0.5,
                indent: 52,
                color: AppTheme.cardBorderColorFor(context),
              ),
          ],
        ],
      ),
    );
  }
}

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
    final inactiveColor = AppTheme.tertiaryTextFor(context);
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
          color: isActive ? Colors.white : inactiveColor,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// GRID CARD — bold, warm-toned 3-column card
// ═══════════════════════════════════════════════════════════════════
// ═══════════════════════════════════════════════════════════════════
// LIST ROW — detailed row (icon + label + subtitle + chevron)
// ═══════════════════════════════════════════════════════════════════
class _ListRow extends StatelessWidget {
  final _MenuEntry entry;

  const _ListRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final subtitleColor = AppTheme.tertiaryTextFor(context);
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
                        color: subtitleColor,
                        fontSize: 11,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              if (entry.badge != null) ...[
                entry.badge!,
                const SizedBox(width: 8),
              ],
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
