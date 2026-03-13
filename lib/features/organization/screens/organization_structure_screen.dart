import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/organization_service.dart';
import '../../../shared/models/workspace_access_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/organization_providers.dart';
import '../widgets/organization_widgets.dart';

class OrganizationStructureScreen extends ConsumerWidget {
  const OrganizationStructureScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final overviewAsync = ref.watch(organizationStructureOverviewProvider);
    return OrganizationScreenShell(
      title: 'Organisasi',
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: () async {
            await ref.read(authProvider.notifier).refreshAuth();
            ref.read(organizationRefreshTickProvider.notifier).bump();
          },
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      child: overviewAsync.when(
        data: (overview) {
          if (overview == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.paddingLarge),
                child: _buildUnavailableState(context, auth),
              ),
            );
          }

          final chartData = _buildOrganizationChartData(overview);
          return RefreshIndicator(
            onRefresh: () async {
              ref.read(organizationRefreshTickProvider.notifier).bump();
              await ref.read(organizationStructureOverviewProvider.future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
              children: [
                _StructureHero(
                  overview: overview,
                  canManage: _canManageOrganization(overview),
                  chartData: chartData,
                ),
                if (_canManageOrganization(overview)) ...[
                  const SizedBox(height: 10),
                  OrganizationSectionCard(
                    title: 'Kelola Organisasi',
                    subtitle:
                        'Buka sub-menu untuk input unit organisasi dan susunan pengurus.',
                    child: _ManageOrganizationTile(
                      onTap: () => context.push(Routes.organizationManage),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                _HierarchyPyramidSection(
                  overview: overview,
                  chartData: chartData,
                ),
              ],
            ),
          );
        },
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.paddingLarge),
            child: isOrganizationSetupMissingError(error)
                ? _buildUnavailableState(context, auth)
                : OrganizationEmptyState(
                    icon: Icons.account_tree_outlined,
                    title: 'Struktur organisasi belum tersedia',
                    message: _errorMessage(error),
                  ),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildUnavailableState(BuildContext context, AuthState auth) {
    return OrganizationEmptyState(
      icon: Icons.account_tree_outlined,
      title: 'Struktur organisasi belum dibuat',
      message: auth.hasRwWideAccess || auth.isSysadmin
          ? 'Organisasi RW belum dibuat. Buka Kelola Organisasi untuk membuat workspace RW, unit RW, dan susunan pengurus awal.'
          : 'Struktur kepengurusan RW belum tersedia saat ini.',
      action: auth.hasRwWideAccess || auth.isSysadmin
          ? FilledButton.icon(
              onPressed: () => context.push(Routes.organizationManage),
              icon: const Icon(Icons.settings_outlined),
              label: const Text('Kelola Organisasi'),
            )
          : null,
    );
  }
}

class _StructureHero extends StatelessWidget {
  const _StructureHero({
    required this.overview,
    required this.canManage,
    required this.chartData,
  });

  final OrganizationOverviewData overview;
  final bool canManage;
  final _OrganizationChartData chartData;

  @override
  Widget build(BuildContext context) {
    final workspace = overview.profile.workspace;
    final locationParts = [
      workspace.desaKelurahan,
      workspace.kecamatan,
      workspace.kabupatenKota,
    ].where((part) => (part ?? '').trim().isNotEmpty).cast<String>().toList();
    final stats = <_HeroStatData>[
      _HeroStatData(
        label: 'RT',
        value: chartData.unitCountByType(AppConstants.unitTypeRt),
      ),
      _HeroStatData(
        label: 'DKM',
        value: chartData.unitCountByType(AppConstants.unitTypeDkm),
      ),
      _HeroStatData(
        label: 'Karang Taruna',
        value: chartData.unitCountByType(AppConstants.unitTypeKarangTaruna),
      ),
      _HeroStatData(
        label: 'Posyandu',
        value: chartData.unitCountByType(AppConstants.unitTypePosyandu),
      ),
      _HeroStatData(label: 'Pengurus', value: chartData.totalMemberships),
    ].where((item) => item.value > 0).toList(growable: false);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.96),
            AppTheme.primaryDark.withValues(alpha: 0.92),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: const Icon(
                    Icons.account_tree_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        workspace.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Bagan organisasi RW ${workspace.rw}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (locationParts.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          locationParts.join(' | '),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.68),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (canManage)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Kelola tersedia',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (stats.isEmpty)
              Text(
                'Unit aktif akan muncul setelah susunan pengurus diatur.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: stats
                    .map(
                      (stat) => _HeroStatChip(
                        label: stat.label,
                        value: '${stat.value}',
                      ),
                    )
                    .toList(growable: false),
              ),
          ],
        ),
      ),
    );
  }
}

class _HeroStatData {
  const _HeroStatData({required this.label, required this.value});

  final String label;
  final int value;
}

class _HeroStatChip extends StatelessWidget {
  const _HeroStatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ManageOrganizationTile extends StatelessWidget {
  const _ManageOrganizationTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.primaryColor.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.settings_outlined,
                color: AppTheme.primaryColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Buka Kelola Organisasi',
                    style: AppTheme.bodySmall.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Input unit organisasi dan susunan pengurus dari satu tempat.',
                    style: AppTheme.caption.copyWith(
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: AppTheme.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _HierarchyPyramidSection extends StatelessWidget {
  const _HierarchyPyramidSection({
    required this.overview,
    required this.chartData,
  });

  final OrganizationOverviewData overview;
  final _OrganizationChartData chartData;

  @override
  Widget build(BuildContext context) {
    return OrganizationSectionCard(
      title: 'Bagan Organisasi',
      subtitle:
          'Chart hierarkis berbentuk piramida. Hanya unit dan pengurus aktif yang sudah diatur yang ditampilkan.',
      child: chartData.isEmpty
          ? const OrganizationEmptyState(
              icon: Icons.groups_2_outlined,
              title: 'Belum ada struktur yang siap tampil',
              message:
                  'Unit akan muncul otomatis setelah unit aktif dan pengurus aktif ditetapkan.',
            )
          : Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: chartData.availableTypes
                        .map(
                          (type) => OrganizationBadge(
                            label: _unitTypeLabel(type),
                            color: _unitTypeColor(type),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
                const SizedBox(height: 12),
                _HierarchyPyramidChart(
                  overview: overview,
                  chartData: chartData,
                ),
              ],
            ),
    );
  }
}

class _HierarchyPyramidChart extends StatelessWidget {
  const _HierarchyPyramidChart({
    required this.overview,
    required this.chartData,
  });

  final OrganizationOverviewData overview;
  final _OrganizationChartData chartData;

  @override
  Widget build(BuildContext context) {
    final totalLevels = chartData.levels.length;
    return Column(
      children: [
        for (var depth = 0; depth < totalLevels; depth++) ...[
          FractionallySizedBox(
            widthFactor: _bandWidthFactor(
              depth: depth,
              levelCount: totalLevels,
            ),
            child: _PyramidLevelBand(
              overview: overview,
              nodes: chartData.levels[depth],
              depth: depth,
              totalLevels: totalLevels,
            ),
          ),
          if (depth < totalLevels - 1) const _LevelConnector(),
        ],
      ],
    );
  }
}

class _PyramidLevelBand extends StatelessWidget {
  const _PyramidLevelBand({
    required this.overview,
    required this.nodes,
    required this.depth,
    required this.totalLevels,
  });

  final OrganizationOverviewData overview;
  final List<_OrganizationChartNode> nodes;
  final int depth;
  final int totalLevels;

  @override
  Widget build(BuildContext context) {
    final tone = _levelTone(depth: depth, totalLevels: totalLevels);
    final isTopLevel = depth == 0;
    final label = isTopLevel ? 'Puncak Organisasi' : 'Level ${depth + 1}';
    final levelIcon = isTopLevel
        ? Icons.flag_circle_rounded
        : Icons.account_tree_rounded;

    return LayoutBuilder(
      builder: (context, constraints) {
        final singleWidth = depth == 0 ? 300.0 : 250.0;
        final multiWidth = depth == 0 ? 240.0 : 210.0;
        final cardWidth = math.min(
          constraints.maxWidth,
          nodes.length == 1 ? singleWidth : multiWidth,
        );

        return Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white, tone.withValues(alpha: 0.06)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(depth == 0 ? 22 : 18),
            border: Border.all(color: tone.withValues(alpha: 0.18)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(levelIcon, size: 13, color: tone),
                        const SizedBox(width: 6),
                        Text(
                          label,
                          style: AppTheme.caption.copyWith(
                            color: tone,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${nodes.length} unit organisasi aktif',
                      style: AppTheme.caption.copyWith(
                        color: tone.withValues(alpha: 0.72),
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                runAlignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: nodes
                    .map(
                      (node) => SizedBox(
                        width: cardWidth,
                        child: _PyramidNodeCard(overview: overview, node: node),
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PyramidNodeCard extends StatelessWidget {
  const _PyramidNodeCard({required this.overview, required this.node});

  final OrganizationOverviewData overview;
  final _OrganizationChartNode node;

  @override
  Widget build(BuildContext context) {
    final tone = _unitTypeColor(node.unit.type);
    final leadMembership = _primaryMembership(node.memberships);
    final supportMemberships = leadMembership == null
        ? node.memberships
        : node.memberships
              .where((membership) => membership.id != leadMembership.id)
              .toList(growable: false);
    final isTopLevel = node.depth == 0;
    final supportLimit = isTopLevel ? 4 : 2;
    final visibleSupportMemberships = supportMemberships
        .take(supportLimit)
        .toList(growable: false);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: isTopLevel
            ? LinearGradient(
                colors: [
                  tone.withValues(alpha: 0.95),
                  AppTheme.primaryDark.withValues(alpha: 0.94),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : LinearGradient(
                colors: [Colors.white, tone.withValues(alpha: 0.05)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
        borderRadius: BorderRadius.circular(isTopLevel ? 20 : 16),
        border: Border.all(
          color: isTopLevel
              ? Colors.white.withValues(alpha: 0.12)
              : tone.withValues(alpha: 0.16),
        ),
        boxShadow: [
          BoxShadow(
            color: tone.withValues(alpha: isTopLevel ? 0.24 : 0.1),
            blurRadius: isTopLevel ? 24 : 14,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      node.unit.name,
                      style: AppTheme.bodySmall.copyWith(
                        color: isTopLevel ? Colors.white : AppTheme.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: isTopLevel ? 14 : 13,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _unitSubtitle(node.unit),
                      style: AppTheme.caption.copyWith(
                        color: isTopLevel
                            ? Colors.white.withValues(alpha: 0.72)
                            : AppTheme.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _NodePill(
                label: _unitTypeShortLabel(node.unit.type),
                foreground: isTopLevel ? Colors.white : tone,
                background: isTopLevel
                    ? Colors.white.withValues(alpha: 0.14)
                    : tone.withValues(alpha: 0.12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (leadMembership != null)
            _LeadMemberBlock(
              membership: leadMembership,
              actor: overview.actorByMemberId(leadMembership.workspaceMemberId),
              tone: tone,
              inverted: isTopLevel,
            ),
          if (supportMemberships.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              height: 1,
              color: isTopLevel
                  ? Colors.white.withValues(alpha: 0.12)
                  : tone.withValues(alpha: 0.12),
            ),
            const SizedBox(height: 10),
            Text(
              'Tim pendukung',
              style: AppTheme.caption.copyWith(
                color: isTopLevel
                    ? Colors.white.withValues(alpha: 0.82)
                    : AppTheme.textSecondary,
                fontWeight: FontWeight.w800,
                fontSize: 10,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 8),
            if (isTopLevel && visibleSupportMemberships.length > 1)
              GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.95,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: visibleSupportMemberships
                    .map(
                      (membership) => _SupportMemberChip(
                        membership: membership,
                        actor: overview.actorByMemberId(
                          membership.workspaceMemberId,
                        ),
                        inverted: true,
                        isCompact: false,
                      ),
                    )
                    .toList(growable: false),
              )
            else
              Column(
                children: visibleSupportMemberships
                    .map(
                      (membership) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _SupportMemberChip(
                          membership: membership,
                          actor: overview.actorByMemberId(
                            membership.workspaceMemberId,
                          ),
                          inverted: isTopLevel,
                          isCompact: true,
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            if (supportMemberships.length > supportLimit)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '+${supportMemberships.length - supportLimit} pengurus lainnya',
                  style: AppTheme.caption.copyWith(
                    color: isTopLevel
                        ? Colors.white.withValues(alpha: 0.72)
                        : AppTheme.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _LeadMemberBlock extends StatelessWidget {
  const _LeadMemberBlock({
    required this.membership,
    required this.actor,
    required this.tone,
    required this.inverted,
  });

  final OrgMembershipModel membership;
  final OrganizationWorkspaceActor? actor;
  final Color tone;
  final bool inverted;

  @override
  Widget build(BuildContext context) {
    final displayName = actor?.displayName ?? 'Pengurus belum dikenali';
    final jabatanLabel = membership.jabatan?.label ?? 'Jabatan belum diisi';
    final avatarUrl = actor?.avatarUrl;
    final roleTone = _getJabatanColor(jabatanLabel);
    final roleIcon = _getRoleIcon(jabatanLabel);
    final metadata = [
      if ((membership.periodLabel ?? '').trim().isNotEmpty)
        membership.periodLabel!,
      if (_dateRangeLabel(membership).isNotEmpty) _dateRangeLabel(membership),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: inverted ? Colors.white.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: inverted
              ? Colors.white.withValues(alpha: 0.14)
              : roleTone.withValues(alpha: 0.16),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (inverted ? Colors.black : tone).withValues(
              alpha: inverted ? 0.1 : 0.08,
            ),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: inverted
                ? Colors.white.withValues(alpha: 0.14)
                : roleTone.withValues(alpha: 0.12),
            backgroundImage: avatarUrl == null ? null : NetworkImage(avatarUrl),
            child: avatarUrl == null
                ? Text(
                    _initials(displayName),
                    style: AppTheme.caption.copyWith(
                      color: inverted ? Colors.white : roleTone,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: AppTheme.bodySmall.copyWith(
                    color: inverted ? Colors.white : AppTheme.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      roleIcon,
                      size: 14,
                      color: inverted
                          ? Colors.white.withValues(alpha: 0.88)
                          : roleTone,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        jabatanLabel,
                        style: AppTheme.caption.copyWith(
                          color: inverted
                              ? Colors.white.withValues(alpha: 0.84)
                              : AppTheme.textSecondary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                if (metadata.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 12,
                        color: inverted
                            ? Colors.white.withValues(alpha: 0.62)
                            : AppTheme.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          metadata.join(' | '),
                          style: AppTheme.caption.copyWith(
                            color: inverted
                                ? Colors.white.withValues(alpha: 0.68)
                                : AppTheme.textTertiary,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (membership.isPrimary) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: inverted
                    ? Colors.white.withValues(alpha: 0.14)
                    : roleTone.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: inverted
                      ? Colors.white.withValues(alpha: 0.24)
                      : roleTone.withValues(alpha: 0.22),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 11,
                    color: inverted ? Colors.white : roleTone,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Utama',
                    style: AppTheme.caption.copyWith(
                      color: inverted ? Colors.white : roleTone,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SupportMemberChip extends StatelessWidget {
  const _SupportMemberChip({
    required this.membership,
    required this.actor,
    required this.inverted,
    required this.isCompact,
  });

  final OrgMembershipModel membership;
  final OrganizationWorkspaceActor? actor;
  final bool inverted;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final displayName = actor?.displayName ?? 'Pengurus belum dikenali';
    final jabatanLabel = membership.jabatan?.label ?? 'Jabatan belum diisi';
    final avatarUrl = actor?.avatarUrl;
    final roleTone = _getJabatanColor(jabatanLabel);
    final roleIcon = _getRoleIcon(jabatanLabel);

    if (isCompact) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: inverted
              ? Colors.white.withValues(alpha: 0.08)
              : roleTone.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: inverted
                ? Colors.white.withValues(alpha: 0.12)
                : roleTone.withValues(alpha: 0.16),
          ),
          boxShadow: inverted
              ? const []
              : [
                  BoxShadow(
                    color: roleTone.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: inverted
                  ? Colors.white.withValues(alpha: 0.14)
                  : roleTone.withValues(alpha: 0.12),
              backgroundImage: avatarUrl == null
                  ? null
                  : NetworkImage(avatarUrl),
              child: avatarUrl == null
                  ? Text(
                      _initials(displayName),
                      style: AppTheme.caption.copyWith(
                        color: inverted ? Colors.white : roleTone,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.caption.copyWith(
                      color: inverted
                          ? Colors.white.withValues(alpha: 0.88)
                          : AppTheme.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(
                        roleIcon,
                        size: 11,
                        color: inverted
                            ? Colors.white.withValues(alpha: 0.74)
                            : roleTone,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          jabatanLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.caption.copyWith(
                            color: inverted
                                ? Colors.white.withValues(alpha: 0.68)
                                : AppTheme.textSecondary,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: inverted ? Colors.white.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: inverted
              ? Colors.white.withValues(alpha: 0.12)
              : roleTone.withValues(alpha: 0.18),
        ),
        boxShadow: inverted
            ? const []
            : [
                BoxShadow(
                  color: roleTone.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: inverted
                ? Colors.white.withValues(alpha: 0.14)
                : roleTone.withValues(alpha: 0.12),
            backgroundImage: avatarUrl == null ? null : NetworkImage(avatarUrl),
            child: avatarUrl == null
                ? Text(
                    _initials(displayName),
                    style: AppTheme.caption.copyWith(
                      color: inverted ? Colors.white : roleTone,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 10),
          Text(
            displayName,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.caption.copyWith(
              color: inverted
                  ? Colors.white.withValues(alpha: 0.88)
                  : AppTheme.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                roleIcon,
                size: 12,
                color: inverted
                    ? Colors.white.withValues(alpha: 0.78)
                    : roleTone,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  jabatanLabel,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.caption.copyWith(
                    color: inverted
                        ? Colors.white.withValues(alpha: 0.7)
                        : AppTheme.textSecondary,
                    fontSize: 8.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NodePill extends StatelessWidget {
  const _NodePill({
    required this.label,
    required this.foreground,
    required this.background,
  });

  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _LevelConnector extends StatelessWidget {
  const _LevelConnector();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 22,
      child: Column(
        children: [
          Container(
            width: 2,
            height: 12,
            color: AppTheme.primaryColor.withValues(alpha: 0.18),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrganizationChartData {
  const _OrganizationChartData({
    required this.visibleUnits,
    required this.membershipsByUnitId,
    required this.levels,
  });

  final List<OrgUnitModel> visibleUnits;
  final Map<String, List<OrgMembershipModel>> membershipsByUnitId;
  final List<List<_OrganizationChartNode>> levels;

  bool get isEmpty => visibleUnits.isEmpty || levels.isEmpty;

  int unitCountByType(String type) {
    final normalizedType = type.trim().toLowerCase();
    return visibleUnits
        .where((unit) => unit.type.trim().toLowerCase() == normalizedType)
        .length;
  }

  int get totalMemberships {
    return membershipsByUnitId.values.fold<int>(
      0,
      (total, memberships) => total + memberships.length,
    );
  }

  List<String> get availableTypes {
    final orderedTypes = <String>[
      AppConstants.unitTypeRw,
      AppConstants.unitTypeRt,
      AppConstants.unitTypeDkm,
      AppConstants.unitTypeKarangTaruna,
      AppConstants.unitTypePosyandu,
      AppConstants.unitTypeCustom,
    ];
    return orderedTypes
        .where((type) => unitCountByType(type) > 0)
        .toList(growable: false);
  }
}

class _OrganizationChartNode {
  const _OrganizationChartNode({
    required this.unit,
    required this.memberships,
    required this.depth,
    this.parentUnitId,
  });

  final OrgUnitModel unit;
  final List<OrgMembershipModel> memberships;
  final int depth;
  final String? parentUnitId;
}

bool _canManageOrganization(OrganizationOverviewData overview) {
  return overview.profile.canManageWorkspace ||
      overview.profile.canManageUnit ||
      overview.profile.canManageMembership;
}

_OrganizationChartData _buildOrganizationChartData(
  OrganizationOverviewData overview,
) {
  final allUnits = _sortUnits(overview.orgUnits);
  final allUnitsById = {for (final unit in allUnits) unit.id: unit};
  final membershipsByUnitId = <String, List<OrgMembershipModel>>{};

  for (final unit in allUnits) {
    final activeMemberships = _membershipsForUnit(
      overview,
      unit.id,
      activeOnly: true,
    );
    if (unit.status.trim().toLowerCase() != 'active' ||
        activeMemberships.isEmpty) {
      continue;
    }
    membershipsByUnitId[unit.id] = activeMemberships;
  }

  final visibleUnits = allUnits
      .where((unit) => membershipsByUnitId.containsKey(unit.id))
      .toList(growable: false);
  if (visibleUnits.isEmpty) {
    return const _OrganizationChartData(
      visibleUnits: [],
      membershipsByUnitId: {},
      levels: [],
    );
  }

  final visibleUnitIds = visibleUnits.map((unit) => unit.id).toSet();
  final childrenByParentId = <String?, List<OrgUnitModel>>{};
  final resolvedParentByUnitId = <String, String?>{};

  for (final unit in visibleUnits) {
    final parentId = _resolveVisibleParentId(
      unit: unit,
      allUnits: allUnits,
      allUnitsById: allUnitsById,
      visibleUnitIds: visibleUnitIds,
    );
    resolvedParentByUnitId[unit.id] = parentId;
    childrenByParentId.putIfAbsent(parentId, () => []).add(unit);
  }

  for (final children in childrenByParentId.values) {
    children.sort(_hierarchyCompare);
  }

  final levels = <List<_OrganizationChartNode>>[];
  final visited = <String>{};

  void addNode(OrgUnitModel unit, int depth) {
    if (!visited.add(unit.id)) {
      return;
    }

    while (levels.length <= depth) {
      levels.add(<_OrganizationChartNode>[]);
    }

    levels[depth].add(
      _OrganizationChartNode(
        unit: unit,
        memberships: membershipsByUnitId[unit.id] ?? const [],
        depth: depth,
        parentUnitId: resolvedParentByUnitId[unit.id],
      ),
    );

    for (final child in childrenByParentId[unit.id] ?? const <OrgUnitModel>[]) {
      addNode(child, depth + 1);
    }
  }

  for (final root in childrenByParentId[null] ?? const <OrgUnitModel>[]) {
    addNode(root, 0);
  }

  for (final unit in visibleUnits) {
    if (!visited.contains(unit.id)) {
      addNode(unit, 0);
    }
  }

  return _OrganizationChartData(
    visibleUnits: visibleUnits,
    membershipsByUnitId: membershipsByUnitId,
    levels: levels,
  );
}

String? _resolveVisibleParentId({
  required OrgUnitModel unit,
  required List<OrgUnitModel> allUnits,
  required Map<String, OrgUnitModel> allUnitsById,
  required Set<String> visibleUnitIds,
}) {
  final visited = <String>{unit.id};
  String? currentParentId = _resolvePreferredParentId(
    unit: unit,
    allUnits: allUnits,
  );

  while ((currentParentId ?? '').isNotEmpty) {
    if (visited.contains(currentParentId)) {
      return null;
    }
    if (visibleUnitIds.contains(currentParentId)) {
      return currentParentId;
    }

    visited.add(currentParentId!);
    final parentUnit = allUnitsById[currentParentId];
    if (parentUnit == null) {
      return null;
    }
    currentParentId = _resolvePreferredParentId(
      unit: parentUnit,
      allUnits: allUnits,
    );
  }

  return null;
}

String? _resolvePreferredParentId({
  required OrgUnitModel unit,
  required List<OrgUnitModel> allUnits,
}) {
  final explicitParentId = (unit.parentUnitId ?? '').trim();
  if (explicitParentId.isNotEmpty &&
      allUnits.any((candidate) => candidate.id == explicitParentId)) {
    return explicitParentId;
  }

  final normalizedType = unit.type.trim().toLowerCase();
  if (normalizedType == AppConstants.unitTypeRw) {
    return null;
  }

  final rwUnits =
      allUnits
          .where(
            (candidate) =>
                candidate.id != unit.id &&
                candidate.type.trim().toLowerCase() == AppConstants.unitTypeRw,
          )
          .toList(growable: false)
        ..sort(_hierarchyCompare);

  if (normalizedType == AppConstants.unitTypeRt) {
    return _findNearestRwUnit(unit: unit, rwUnits: rwUnits)?.id;
  }

  final scopedRtParent = _findNearestRtUnit(unit: unit, allUnits: allUnits);
  if (scopedRtParent != null) {
    return scopedRtParent.id;
  }

  return _findNearestRwUnit(unit: unit, rwUnits: rwUnits)?.id;
}

OrgUnitModel? _findNearestRtUnit({
  required OrgUnitModel unit,
  required List<OrgUnitModel> allUnits,
}) {
  final targetRt = unit.scopeRt ?? 0;
  if (targetRt <= 0) {
    return null;
  }

  final candidates =
      allUnits
          .where(
            (candidate) =>
                candidate.id != unit.id &&
                candidate.type.trim().toLowerCase() ==
                    AppConstants.unitTypeRt &&
                (candidate.scopeRt ?? 0) == targetRt,
          )
          .toList(growable: false)
        ..sort(_hierarchyCompare);

  if (candidates.isEmpty) {
    return null;
  }

  final targetRw = unit.scopeRw ?? 0;
  if (targetRw > 0) {
    for (final candidate in candidates) {
      if ((candidate.scopeRw ?? 0) == targetRw) {
        return candidate;
      }
    }
  }

  return candidates.first;
}

OrgUnitModel? _findNearestRwUnit({
  required OrgUnitModel unit,
  required List<OrgUnitModel> rwUnits,
}) {
  if (rwUnits.isEmpty) {
    return null;
  }

  final targetRw = unit.scopeRw ?? 0;
  if (targetRw > 0) {
    for (final candidate in rwUnits) {
      if ((candidate.scopeRw ?? 0) == targetRw) {
        return candidate;
      }
    }
  }

  return rwUnits.first;
}

double _bandWidthFactor({required int depth, required int levelCount}) {
  if (levelCount <= 1) {
    return 1;
  }
  const baseFactor = 0.56;
  final step = (1 - baseFactor) / (levelCount - 1);
  return (baseFactor + (step * depth)).clamp(baseFactor, 1).toDouble();
}

Color _levelTone({required int depth, required int totalLevels}) {
  if (depth == 0) {
    return AppTheme.primaryColor;
  }
  if (depth >= totalLevels - 1) {
    return AppTheme.accentColor;
  }
  return AppTheme.primaryDark;
}

Color _unitTypeColor(String type) {
  switch (type.trim().toLowerCase()) {
    case AppConstants.unitTypeRw:
      return AppTheme.primaryColor;
    case AppConstants.unitTypeRt:
      return AppTheme.primaryDark;
    case AppConstants.unitTypeDkm:
      return AppTheme.secondaryColor;
    case AppConstants.unitTypeKarangTaruna:
      return AppTheme.accentColor;
    case AppConstants.unitTypePosyandu:
      return AppTheme.warningColor;
    case AppConstants.unitTypeCustom:
      return AppTheme.toneTerracotta;
    default:
      return AppTheme.textSecondary;
  }
}

OrgMembershipModel? _primaryMembership(List<OrgMembershipModel> memberships) {
  if (memberships.isEmpty) return null;

  final activeMembers = memberships
      .where((m) => m.isActive)
      .toList(growable: false);

  return activeMembers.isNotEmpty ? activeMembers.first : memberships.first;
}

List<OrgUnitModel> _sortUnits(List<OrgUnitModel> units) {
  final sorted = [...units];
  sorted.sort((a, b) {
    final statusCompare = _statusWeight(
      a.status,
    ).compareTo(_statusWeight(b.status));
    if (statusCompare != 0) {
      return statusCompare;
    }

    final rtCompare = (a.scopeRt ?? 0).compareTo(b.scopeRt ?? 0);
    if (rtCompare != 0) {
      return rtCompare;
    }

    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return sorted;
}

int _hierarchyCompare(OrgUnitModel a, OrgUnitModel b) {
  final typeCompare = _unitHierarchyWeight(
    a.type,
  ).compareTo(_unitHierarchyWeight(b.type));
  if (typeCompare != 0) {
    return typeCompare;
  }

  final rwCompare = (a.scopeRw ?? 0).compareTo(b.scopeRw ?? 0);
  if (rwCompare != 0) {
    return rwCompare;
  }

  final rtCompare = (a.scopeRt ?? 0).compareTo(b.scopeRt ?? 0);
  if (rtCompare != 0) {
    return rtCompare;
  }

  return a.name.toLowerCase().compareTo(b.name.toLowerCase());
}

int _unitHierarchyWeight(String type) {
  switch (type.trim().toLowerCase()) {
    case AppConstants.unitTypeRw:
      return 0;
    case AppConstants.unitTypeRt:
      return 1;
    case AppConstants.unitTypeDkm:
      return 2;
    case AppConstants.unitTypeKarangTaruna:
      return 3;
    case AppConstants.unitTypePosyandu:
      return 4;
    case AppConstants.unitTypeCustom:
      return 5;
    default:
      return 99;
  }
}

List<OrgMembershipModel> _membershipsForUnit(
  OrganizationOverviewData overview,
  String unitId, {
  bool activeOnly = false,
}) {
  var memberships = overview.orgMemberships
      .where((item) => item.orgUnitId == unitId)
      .toList(growable: false);

  if (activeOnly) {
    memberships = memberships
        .where((membership) => membership.isActive)
        .toList(growable: false);
  }

  memberships.sort((a, b) {
    final statusCompare = _statusWeight(
      a.status,
    ).compareTo(_statusWeight(b.status));
    if (statusCompare != 0) {
      return statusCompare;
    }

    final jabatanCompare = _jabatanWeight(a).compareTo(_jabatanWeight(b));
    if (jabatanCompare != 0) {
      return jabatanCompare;
    }

    final primaryCompare = (a.isPrimary ? 0 : 1).compareTo(b.isPrimary ? 0 : 1);
    if (primaryCompare != 0) {
      return primaryCompare;
    }

    final periodCompare = _dateSortValue(
      a.startedAt,
    ).compareTo(_dateSortValue(b.startedAt));
    if (periodCompare != 0) {
      return periodCompare;
    }

    final actorA =
        overview
            .actorByMemberId(a.workspaceMemberId)
            ?.displayName
            .toLowerCase() ??
        '';
    final actorB =
        overview
            .actorByMemberId(b.workspaceMemberId)
            ?.displayName
            .toLowerCase() ??
        '';
    return actorA.compareTo(actorB);
  });

  return memberships;
}

int _statusWeight(String status) =>
    status.trim().toLowerCase() == 'active' ? 0 : 1;

int _jabatanWeight(OrgMembershipModel membership) {
  final explicit = membership.jabatan?.sortOrder;
  if (explicit != null && explicit > 0) {
    return explicit;
  }

  final label = (membership.jabatan?.label ?? '').trim().toLowerCase();
  if (label.startsWith('ketua')) return 10;
  if (label.startsWith('wakil')) return 20;
  if (label.startsWith('sekretaris')) return 30;
  if (label.startsWith('bendahara')) return 40;
  if (label.contains('admin')) return 50;
  if (label.contains('kader')) return 60;
  if (label.contains('pengurus')) return 70;
  return 9999;
}

int _dateSortValue(DateTime? value) {
  if (value == null) {
    return 99999999;
  }
  final local = value.toLocal();
  return (local.year * 10000) + (local.month * 100) + local.day;
}

String _unitSubtitle(OrgUnitModel unit) {
  final parts = <String>[
    if (unit.scopeRw != null && unit.scopeRw! > 0) 'RW ${unit.scopeRw}',
    if (unit.scopeRt != null && unit.scopeRt! > 0) 'RT ${unit.scopeRt}',
    if (unit.code.trim().isNotEmpty) 'Kode ${unit.code}',
  ];
  if (parts.isEmpty) {
    return 'Unit organisasi';
  }
  return parts.join(' | ');
}

String _dateRangeLabel(OrgMembershipModel membership) {
  final started = _formatDate(membership.startedAt);
  final ended = _formatDate(membership.endedAt);
  if (started.isEmpty && ended.isEmpty) {
    return '';
  }
  if (started.isNotEmpty && ended.isNotEmpty) {
    return '$started - $ended';
  }
  if (started.isNotEmpty) {
    return 'Mulai $started';
  }
  return 'Selesai $ended';
}

String _formatDate(DateTime? value) {
  if (value == null) {
    return '';
  }
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day/$month/${local.year}';
}

String _initials(String value) {
  final parts = value
      .split(RegExp(r'\s+'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);

  if (parts.isEmpty) {
    return '?';
  }
  if (parts.length == 1) {
    return parts.first.substring(0, 1).toUpperCase();
  }
  return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
      .toUpperCase();
}

String _unitTypeLabel(String type) {
  switch (type.trim().toLowerCase()) {
    case AppConstants.unitTypeRw:
      return 'RW';
    case AppConstants.unitTypeRt:
      return 'RT';
    case AppConstants.unitTypeDkm:
      return 'DKM';
    case AppConstants.unitTypeKarangTaruna:
      return 'Karang Taruna';
    case AppConstants.unitTypePosyandu:
      return 'Posyandu';
    case AppConstants.unitTypeCustom:
      return 'Tambahan';
    default:
      return 'Unit';
  }
}

String _unitTypeShortLabel(String type) {
  switch (type.trim().toLowerCase()) {
    case AppConstants.unitTypeRw:
      return 'RW';
    case AppConstants.unitTypeRt:
      return 'RT';
    case AppConstants.unitTypeDkm:
      return 'DKM';
    case AppConstants.unitTypeKarangTaruna:
      return 'KT';
    case AppConstants.unitTypePosyandu:
      return 'Posyandu';
    case AppConstants.unitTypeCustom:
      return 'Tambahan';
    default:
      return 'Unit';
  }
}

IconData _getRoleIcon(String jabatan) {
  final label = jabatan.trim().toLowerCase();

  if (label.startsWith('ketua')) {
    return Icons.workspace_premium_rounded;
  }
  if (label.startsWith('wakil')) {
    return Icons.military_tech_rounded;
  }
  if (label.startsWith('sekretaris')) {
    return Icons.edit_note_rounded;
  }
  if (label.startsWith('bendahara')) {
    return Icons.account_balance_wallet_rounded;
  }
  if (label.contains('admin')) {
    return Icons.admin_panel_settings_rounded;
  }
  if (label.contains('kader')) {
    return Icons.groups_rounded;
  }
  if (label.contains('pengurus')) {
    return Icons.badge_rounded;
  }
  return Icons.person_rounded;
}

Color _getJabatanColor(String jabatan) {
  final label = jabatan.trim().toLowerCase();

  if (label.startsWith('ketua')) {
    return AppTheme.primaryColor;
  }
  if (label.startsWith('wakil')) {
    return AppTheme.primaryDark;
  }
  if (label.startsWith('sekretaris')) {
    return AppTheme.secondaryColor;
  }
  if (label.startsWith('bendahara')) {
    return AppTheme.accentColor;
  }
  if (label.contains('admin')) {
    return Colors.orange;
  }
  if (label.contains('kader')) {
    return AppTheme.warningColor;
  }
  return AppTheme.textSecondary;
}

String _errorMessage(Object error) {
  if (error is ClientException) {
    final message = (error.response['message'] ?? '').toString().trim();
    if (message.isNotEmpty) {
      return message;
    }
  }
  return 'Pastikan RW aktif dan data pengurus sudah tersedia.';
}
