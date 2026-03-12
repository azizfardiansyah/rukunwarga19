import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/organization_service.dart';
import '../../../shared/models/workspace_access_model.dart';
import '../providers/organization_providers.dart';
import '../widgets/organization_widgets.dart';

class OrganizationStructureScreen extends ConsumerWidget {
  const OrganizationStructureScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overviewAsync = ref.watch(organizationOverviewProvider);
    return OrganizationScreenShell(
      title: 'Organisasi',
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: () =>
              ref.read(organizationRefreshTickProvider.notifier).bump(),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      child: overviewAsync.when(
        data: (overview) => RefreshIndicator(
          onRefresh: () async {
            ref.read(organizationRefreshTickProvider.notifier).bump();
            await ref.read(organizationOverviewProvider.future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
            children: [
              _StructureHero(
                overview: overview,
                canManage: _canManageOrganization(overview),
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
              ..._buildSections(overview),
            ],
          ),
        ),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.paddingLarge),
            child: OrganizationEmptyState(
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

  List<Widget> _buildSections(OrganizationOverviewData overview) {
    final sections = [
      _UnitSectionData(
        title: 'Pengurus RW',
        subtitle: 'Struktur inti kepengurusan tingkat RW.',
        emptyTitle: 'Unit RW belum tersedia',
        emptyMessage:
            'Tambahkan unit RW agar struktur kepengurusan bisa tampil.',
        units: _sortUnits(overview.unitsByType(AppConstants.unitTypeRw)),
      ),
      _UnitSectionData(
        title: 'Pengurus RT',
        subtitle: 'Ketua RT, wakil, dan pengurus per RT.',
        emptyTitle: 'Belum ada unit RT',
        emptyMessage: 'Daftar RT akan tampil per unit saat sudah dibuat.',
        units: _sortUnits(overview.unitsByType(AppConstants.unitTypeRt)),
      ),
      _UnitSectionData(
        title: 'Pengurus DKM',
        subtitle: 'Struktur kepengurusan DKM per unit.',
        emptyTitle: 'Belum ada unit DKM',
        emptyMessage:
            'Pengurus DKM akan tampil setelah unit dan jabatannya dibuat.',
        units: _sortUnits(overview.unitsByType(AppConstants.unitTypeDkm)),
      ),
      _UnitSectionData(
        title: 'Pengurus Posyandu',
        subtitle: 'Struktur ketua dan pengurus Posyandu per unit.',
        emptyTitle: 'Belum ada unit Posyandu',
        emptyMessage:
            'Pengurus Posyandu akan tampil setelah unit dan jabatannya dibuat.',
        units: _sortUnits(overview.unitsByType(AppConstants.unitTypePosyandu)),
      ),
      _UnitSectionData(
        title: 'Unit Lainnya',
        subtitle:
            'Unit tambahan di luar struktur resmi RW, RT, DKM, dan Posyandu.',
        emptyTitle: 'Tidak ada unit tambahan',
        emptyMessage: 'Jika ada unit custom, strukturnya akan tampil di sini.',
        units: _sortUnits(overview.unitsByType(AppConstants.unitTypeCustom)),
      ),
    ];

    return sections
        .map(
          (section) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: OrganizationSectionCard(
              title: section.title,
              subtitle: section.subtitle,
              child: section.units.isEmpty
                  ? OrganizationEmptyState(
                      icon: Icons.groups_2_outlined,
                      title: section.emptyTitle,
                      message: section.emptyMessage,
                    )
                  : Column(
                      children: section.units
                          .map(
                            (unit) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _OrganizationUnitCard(
                                unit: unit,
                                memberships: _membershipsForUnit(
                                  overview,
                                  unit.id,
                                ),
                                overview: overview,
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
            ),
          ),
        )
        .toList(growable: false);
  }
}

class _StructureHero extends StatelessWidget {
  const _StructureHero({required this.overview, required this.canManage});

  final OrganizationOverviewData overview;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final workspace = overview.profile.workspace;
    final locationParts = [
      workspace.desaKelurahan,
      workspace.kecamatan,
      workspace.kabupatenKota,
    ].where((part) => (part ?? '').trim().isNotEmpty).cast<String>().toList();

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
                        'Struktur kepengurusan RW ${workspace.rw}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (locationParts.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          locationParts.join(' • '),
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
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _HeroStatChip(
                  label: 'RT',
                  value:
                      '${overview.unitsByType(AppConstants.unitTypeRt).length}',
                ),
                _HeroStatChip(
                  label: 'DKM',
                  value:
                      '${overview.unitsByType(AppConstants.unitTypeDkm).length}',
                ),
                _HeroStatChip(
                  label: 'Posyandu',
                  value:
                      '${overview.unitsByType(AppConstants.unitTypePosyandu).length}',
                ),
                _HeroStatChip(
                  label: 'Pengurus',
                  value: '${overview.orgMemberships.length}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
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

class _OrganizationUnitCard extends StatelessWidget {
  const _OrganizationUnitCard({
    required this.unit,
    required this.memberships,
    required this.overview,
  });

  final OrgUnitModel unit;
  final List<OrgMembershipModel> memberships;
  final OrganizationOverviewData overview;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.dividerColor.withValues(alpha: 0.45),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
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
                        unit.name,
                        style: AppTheme.bodySmall.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _unitSubtitle(unit),
                        style: AppTheme.caption.copyWith(
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    OrganizationBadge(label: _unitTypeLabel(unit.type)),
                    if (unit.status.trim().toLowerCase() != 'active')
                      OrganizationBadge(
                        label: 'NONAKTIF',
                        color: AppTheme.warningColor,
                      ),
                    if (!unit.isOfficial)
                      const OrganizationBadge(
                        label: 'TAMBAHAN',
                        color: AppTheme.accentColor,
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (memberships.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Belum ada pengurus yang ditetapkan pada unit ini.',
                  style: AppTheme.caption,
                ),
              )
            else
              Column(
                children: memberships
                    .map(
                      (membership) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _MembershipTile(
                          membership: membership,
                          actor: overview.actorByMemberId(
                            membership.workspaceMemberId,
                          ),
                        ),
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

class _MembershipTile extends StatelessWidget {
  const _MembershipTile({required this.membership, required this.actor});

  final OrgMembershipModel membership;
  final OrganizationWorkspaceActor? actor;

  @override
  Widget build(BuildContext context) {
    final displayName = actor?.displayName ?? 'Pengurus belum dikenali';
    final jabatanLabel = membership.jabatan?.label ?? 'Jabatan belum diisi';
    final metadata = [
      if ((membership.periodLabel ?? '').trim().isNotEmpty)
        membership.periodLabel!,
      if (_dateRangeLabel(membership).isNotEmpty) _dateRangeLabel(membership),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
          child: Text(
            displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
            style: AppTheme.caption.copyWith(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                style: AppTheme.bodySmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                jabatanLabel,
                style: AppTheme.caption.copyWith(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (metadata.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  metadata.join(' • '),
                  style: AppTheme.caption.copyWith(
                    color: AppTheme.textTertiary,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  OrganizationBadge(
                    label: membership.isActive ? 'AKTIF' : 'NONAKTIF',
                    color: membership.isActive
                        ? AppTheme.successColor
                        : AppTheme.warningColor,
                  ),
                  if (membership.isPrimary)
                    const OrganizationBadge(
                      label: 'UTAMA',
                      color: AppTheme.primaryDark,
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _UnitSectionData {
  const _UnitSectionData({
    required this.title,
    required this.subtitle,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.units,
  });

  final String title;
  final String subtitle;
  final String emptyTitle;
  final String emptyMessage;
  final List<OrgUnitModel> units;
}

bool _canManageOrganization(OrganizationOverviewData overview) {
  return overview.profile.canManageWorkspace ||
      overview.profile.canManageUnit ||
      overview.profile.canManageMembership;
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

List<OrgMembershipModel> _membershipsForUnit(
  OrganizationOverviewData overview,
  String unitId,
) {
  final memberships = overview.orgMemberships
      .where((item) => item.orgUnitId == unitId)
      .toList(growable: false);

  memberships.sort((a, b) {
    final statusCompare = _statusWeight(
      a.status,
    ).compareTo(_statusWeight(b.status));
    if (statusCompare != 0) {
      return statusCompare;
    }

    final primaryCompare = (a.isPrimary ? 0 : 1).compareTo(b.isPrimary ? 0 : 1);
    if (primaryCompare != 0) {
      return primaryCompare;
    }

    final jabatanCompare = (a.jabatan?.sortOrder ?? 9999).compareTo(
      b.jabatan?.sortOrder ?? 9999,
    );
    if (jabatanCompare != 0) {
      return jabatanCompare;
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

String _unitSubtitle(OrgUnitModel unit) {
  final parts = <String>[
    if (unit.scopeRw != null && unit.scopeRw! > 0) 'RW ${unit.scopeRw}',
    if (unit.scopeRt != null && unit.scopeRt! > 0) 'RT ${unit.scopeRt}',
    if (unit.code.trim().isNotEmpty) 'Kode ${unit.code}',
  ];
  if (parts.isEmpty) {
    return 'Unit organisasi';
  }
  return parts.join(' • ');
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

String _unitTypeLabel(String type) {
  switch (type.trim().toLowerCase()) {
    case AppConstants.unitTypeRw:
      return 'RW';
    case AppConstants.unitTypeRt:
      return 'RT';
    case AppConstants.unitTypeDkm:
      return 'DKM';
    case AppConstants.unitTypePosyandu:
      return 'Posyandu';
    case AppConstants.unitTypeCustom:
      return 'Tambahan';
    default:
      return 'Unit';
  }
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
