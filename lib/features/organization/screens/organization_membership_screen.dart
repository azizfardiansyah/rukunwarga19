import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/organization_service.dart';
import '../../../core/utils/error_classifier.dart';
import '../../../shared/models/workspace_access_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/organization_providers.dart';
import '../widgets/organization_widgets.dart';

class OrganizationMembershipScreen extends ConsumerStatefulWidget {
  const OrganizationMembershipScreen({super.key});

  @override
  ConsumerState<OrganizationMembershipScreen> createState() =>
      _OrganizationMembershipScreenState();
}

class _OrganizationMembershipScreenState
    extends ConsumerState<OrganizationMembershipScreen> {
  String _unitFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    if (!auth.isSysadmin && !auth.hasRwWideAccess) {
      return const OrganizationAccessDenied(
        appBarTitle: 'Kelola Pengurus',
        title: 'Akses kelola pengurus tidak tersedia',
      );
    }

    final overviewAsync = ref.watch(organizationOverviewProvider);
    return OrganizationScreenShell(
      title: 'Kelola Pengurus',
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
      floatingActionButton:
          overviewAsync.asData?.value.profile.canManageMembership == true
          ? FloatingActionButton.extended(
              onPressed: () => _openMembershipDialog(
                context,
                ref,
                overviewAsync.asData!.value,
                initialUnitId: _unitFilter == 'all' ? null : _unitFilter,
              ),
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text('Tambah Pengurus'),
            )
          : null,
      child: overviewAsync.when(
        data: (overview) {
          final units = _sortedActiveUnits(overview.orgUnits);
          final currentUnitFilter =
              _unitFilter == 'all' ||
                  units.any((unit) => unit.id == _unitFilter)
              ? _unitFilter
              : 'all';
          final visibleUnits = currentUnitFilter == 'all'
              ? units
              : units
                    .where((unit) => unit.id == currentUnitFilter)
                    .toList(growable: false);
          final membershipCounts = <String, int>{};
          for (final membership in overview.orgMemberships) {
            membershipCounts.update(
              membership.orgUnitId,
              (count) => count + 1,
              ifAbsent: () => 1,
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.read(organizationRefreshTickProvider.notifier).bump();
              await ref.read(organizationOverviewProvider.future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
              children: [
                DropdownButtonFormField<String>(
                  initialValue: currentUnitFilter,
                  decoration: const InputDecoration(
                    labelText: 'Filter unit',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: 'all',
                      child: Text('Semua unit'),
                    ),
                    ...units.map(
                      (unit) => DropdownMenuItem<String>(
                        value: unit.id,
                        child: Text(
                          '${unit.name} (${membershipCounts[unit.id] ?? 0})',
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _unitFilter = value ?? 'all');
                  },
                ),
                const SizedBox(height: 10),
                if (visibleUnits.isEmpty)
                  const OrganizationEmptyState(
                    icon: Icons.account_tree_outlined,
                    title: 'Belum ada unit organisasi',
                    message: 'Tambahkan unit dulu sebelum mengisi pengurus.',
                  )
                else
                  ...visibleUnits.map(
                    (unit) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _UnitMembershipSection(
                        unit: unit,
                        memberships: _sortMemberships(
                          overview.orgMemberships
                              .where((item) => item.orgUnitId == unit.id)
                              .toList(growable: false),
                        ),
                        actorByMemberId: overview.actorByMemberId,
                        canManage: overview.profile.canManageMembership,
                        onAdd: () => _openMembershipDialog(
                          context,
                          ref,
                          overview,
                          initialUnitId: unit.id,
                        ),
                        onEdit: (membership) => _openMembershipDialog(
                          context,
                          ref,
                          overview,
                          existing: membership,
                        ),
                        onDeactivate: (membership) =>
                            _deactivateMembership(context, ref, membership.id),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.paddingLarge),
            child: isOrganizationSetupMissingError(error)
                ? OrganizationEmptyState(
                    icon: Icons.badge_outlined,
                    title: 'Pengurus belum bisa diinput',
                    message:
                        'Organisasi RW belum dibuat. Buka Kelola Organisasi untuk membuat workspace RW lebih dulu.',
                    action: FilledButton.icon(
                      onPressed: () => context.go(Routes.organizationManage),
                      icon: const Icon(Icons.settings_outlined),
                      label: const Text('Kelola Organisasi'),
                    ),
                  )
                : Text(
                    'Gagal memuat pengurus.\n${error.toString()}',
                    textAlign: TextAlign.center,
                    style: AppTheme.bodySmall,
                  ),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Future<void> _deactivateMembership(
    BuildContext context,
    WidgetRef ref,
    String membershipId,
  ) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Nonaktifkan pengurus'),
            content: const Text(
              'Status pengurus akan diubah menjadi inactive dan masa bakti diakhiri sekarang.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Nonaktifkan'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !context.mounted) {
      return;
    }

    try {
      await ref
          .read(organizationServiceProvider)
          .setOrgMembershipStatus(
            membershipId: membershipId,
            status: 'inactive',
            endedAt: DateTime.now(),
          );
      ref.read(organizationRefreshTickProvider.notifier).bump();
      if (!context.mounted) {
        return;
      }
      ErrorClassifier.showSuccessSnackBar(
        context,
        'Pengurus berhasil dinonaktifkan.',
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ErrorClassifier.showErrorSnackBar(context, error);
    }
  }

  Future<void> _openMembershipDialog(
    BuildContext context,
    WidgetRef ref,
    OrganizationOverviewData overview, {
    OrgMembershipModel? existing,
    String? initialUnitId,
  }) async {
    List<OrganizationMembershipCandidate> candidates;
    try {
      candidates = await ref
          .read(organizationServiceProvider)
          .fetchMembershipCandidates();
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ErrorClassifier.showErrorSnackBar(context, error);
      return;
    }
    if (!context.mounted) {
      return;
    }

    final selectableUnits = _sortedActiveUnits(overview.orgUnits);

    if (candidates.isEmpty ||
        selectableUnits.isEmpty ||
        overview.jabatanMaster.isEmpty) {
      ErrorClassifier.showErrorSnackBar(
        context,
        const FormatException('Daftar akun, unit, atau jabatan belum siap.'),
      );
      return;
    }

    String candidateKey = _resolveCandidateKey(
      candidates,
      workspaceMemberId: existing?.workspaceMemberId,
      userId: existing?.userId,
    );
    final preferredUnitId = (initialUnitId ?? '').trim();
    String orgUnitId = existing?.orgUnitId.isNotEmpty == true
        ? existing!.orgUnitId
        : selectableUnits.any((unit) => unit.id == preferredUnitId)
        ? preferredUnitId
        : selectableUnits.first.id;
    String jabatanId = existing?.jabatanId ?? '';
    bool isPrimary = existing?.isPrimary ?? false;
    String status = existing?.status ?? 'active';
    final periodCtrl = TextEditingController(text: existing?.periodLabel ?? '');
    DateTime? startedAt = existing?.startedAt;
    DateTime? endedAt = existing?.endedAt;

    String resolveDefaultJabatan() {
      final unit = selectableUnits.firstWhere(
        (item) => item.id == orgUnitId,
        orElse: () => selectableUnits.first,
      );
      final options = overview.jabatanMaster
          .where((item) => item.unitType == unit.type)
          .toList(growable: false);
      if (options.isEmpty) {
        return jabatanId;
      }
      if (options.any((item) => item.id == jabatanId)) {
        return jabatanId;
      }
      return options.first.id;
    }

    jabatanId = resolveDefaultJabatan();

    final saved =
        await showDialog<bool>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setState) {
              final selectedUnit = selectableUnits.firstWhere(
                (item) => item.id == orgUnitId,
                orElse: () => selectableUnits.first,
              );
              final jabatanOptions = overview.jabatanMaster
                  .where((item) => item.unitType == selectedUnit.type)
                  .toList(growable: false);
              if (jabatanOptions.isNotEmpty &&
                  !jabatanOptions.any((item) => item.id == jabatanId)) {
                jabatanId = jabatanOptions.first.id;
              }

              return AlertDialog(
                title: Text(
                  existing == null ? 'Tambah Pengurus' : 'Edit Pengurus',
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: candidateKey,
                        decoration: const InputDecoration(
                          labelText: 'Nama pengurus / akun',
                        ),
                        items: candidates
                            .map(
                              (candidate) => DropdownMenuItem<String>(
                                value: candidate.key,
                                child: Text(candidate.displayName),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          setState(() => candidateKey = value ?? candidateKey);
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: orgUnitId,
                        decoration: const InputDecoration(
                          labelText: 'Unit organisasi',
                        ),
                        items: selectableUnits
                            .map(
                              (unit) => DropdownMenuItem<String>(
                                value: unit.id,
                                child: Text(unit.name),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          setState(() {
                            orgUnitId = value ?? orgUnitId;
                            jabatanId = resolveDefaultJabatan();
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: jabatanId.isEmpty ? null : jabatanId,
                        decoration: const InputDecoration(labelText: 'Jabatan'),
                        items: jabatanOptions
                            .map(
                              (jabatan) => DropdownMenuItem<String>(
                                value: jabatan.id,
                                child: Text(jabatan.label),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          setState(() => jabatanId = value ?? '');
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: periodCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Label masa bakti',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: status,
                        decoration: const InputDecoration(labelText: 'Status'),
                        items: const [
                          DropdownMenuItem(
                            value: 'active',
                            child: Text('Active'),
                          ),
                          DropdownMenuItem(
                            value: 'inactive',
                            child: Text('Inactive'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() => status = value ?? 'active');
                        },
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: isPrimary,
                        onChanged: (value) {
                          setState(() => isPrimary = value);
                        },
                        title: const Text('Jabatan utama di unit ini'),
                      ),
                      const SizedBox(height: 8),
                      _DateRow(
                        label: 'Mulai',
                        value: startedAt,
                        onPick: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: startedAt ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() => startedAt = picked);
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      _DateRow(
                        label: 'Selesai',
                        value: endedAt,
                        onPick: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: endedAt ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() => endedAt = picked);
                          }
                        },
                        onClear: endedAt == null
                            ? null
                            : () => setState(() => endedAt = null),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Batal'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Simpan'),
                  ),
                ],
              );
            },
          ),
        ) ??
        false;

    if (!saved || !context.mounted) {
      periodCtrl.dispose();
      return;
    }

    try {
      final selectedCandidate = candidates.firstWhere(
        (item) => item.key == candidateKey,
        orElse: () => candidates.first,
      );
      await ref
          .read(organizationServiceProvider)
          .saveOrgMembership(
            membershipId: existing?.id,
            workspaceMemberId: selectedCandidate.workspaceMemberId,
            userId: selectedCandidate.userId,
            displayName: selectedCandidate.displayName,
            email: selectedCandidate.email,
            scopeRt: selectedCandidate.scopeRt,
            scopeRw: selectedCandidate.scopeRw,
            orgUnitId: orgUnitId,
            jabatanId: jabatanId,
            isPrimary: isPrimary,
            status: status,
            periodLabel: periodCtrl.text.trim(),
            startedAt: startedAt,
            endedAt: endedAt,
          );
      ref.read(organizationRefreshTickProvider.notifier).bump();
      if (!context.mounted) {
        return;
      }
      ErrorClassifier.showSuccessSnackBar(
        context,
        existing == null
            ? 'Pengurus berhasil ditambahkan.'
            : 'Pengurus berhasil diperbarui.',
      );
    } catch (error) {
      if (!context.mounted) {
        periodCtrl.dispose();
        return;
      }
      ErrorClassifier.showErrorSnackBar(context, error);
    }
    periodCtrl.dispose();
  }
}

class _MembershipCard extends StatelessWidget {
  const _MembershipCard({
    required this.membership,
    required this.actor,
    required this.canManage,
    required this.onEdit,
    required this.onDeactivate,
  });

  final OrgMembershipModel membership;
  final OrganizationWorkspaceActor? actor;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onDeactivate;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecoration(),
      padding: const EdgeInsets.all(10),
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
                      actor?.displayName ?? 'Akun tidak dikenal',
                      style: AppTheme.bodySmall.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${membership.jabatan?.label ?? "-"} • ${membership.orgUnit?.name ?? "-"}',
                      style: AppTheme.caption,
                    ),
                  ],
                ),
              ),
              if (canManage)
                PopupMenuButton<String>(
                  iconSize: 18,
                  padding: EdgeInsets.zero,
                  onSelected: (value) {
                    if (value == 'edit') {
                      onEdit();
                    } else if (value == 'inactive') {
                      onDeactivate();
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit pengurus')),
                    PopupMenuItem(
                      value: 'inactive',
                      child: Text('Nonaktifkan'),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              OrganizationBadge(
                label: membership.status.toUpperCase(),
                color: AppTheme.statusColor(membership.status),
              ),
              if (membership.isPrimary)
                const OrganizationBadge(
                  label: 'UTAMA',
                  color: AppTheme.primaryDark,
                ),
              if ((membership.periodLabel ?? '').isNotEmpty)
                OrganizationBadge(
                  label: membership.periodLabel!,
                  color: AppTheme.accentColor,
                ),
            ],
          ),
          const SizedBox(height: 6),
          _MembershipInfo(label: 'Akun', value: _membershipAccountLabel(actor)),
          _MembershipInfo(
            label: 'Mulai',
            value: _formatDate(membership.startedAt),
          ),
          _MembershipInfo(
            label: 'Selesai',
            value: _formatDate(membership.endedAt),
          ),
        ],
      ),
    );
  }
}

class _UnitMembershipSection extends StatelessWidget {
  const _UnitMembershipSection({
    required this.unit,
    required this.memberships,
    required this.actorByMemberId,
    required this.canManage,
    required this.onAdd,
    required this.onEdit,
    required this.onDeactivate,
  });

  final OrgUnitModel unit;
  final List<OrgMembershipModel> memberships;
  final OrganizationWorkspaceActor? Function(String memberId) actorByMemberId;
  final bool canManage;
  final VoidCallback onAdd;
  final ValueChanged<OrgMembershipModel> onEdit;
  final ValueChanged<OrgMembershipModel> onDeactivate;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecoration(),
      padding: const EdgeInsets.all(10),
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
                    const SizedBox(height: 2),
                    Text('Kode ${unit.code}', style: AppTheme.caption),
                  ],
                ),
              ),
              if (canManage)
                TextButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.person_add_alt_1_outlined, size: 16),
                  label: const Text('Tambah'),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              OrganizationBadge(label: _unitTypeLabel(unit.type)),
              OrganizationBadge(
                label: '${memberships.length} Pengurus',
                color: AppTheme.accentColor,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (memberships.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.dividerColor.withValues(alpha: 0.7),
                ),
              ),
              child: Text(
                'Belum ada pengurus untuk unit ini.',
                style: AppTheme.caption.copyWith(color: AppTheme.textTertiary),
              ),
            )
          else
            ...memberships.map(
              (membership) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _MembershipCard(
                  membership: membership,
                  actor: actorByMemberId(membership.workspaceMemberId),
                  canManage: canManage,
                  onEdit: () => onEdit(membership),
                  onDeactivate: () => onDeactivate(membership),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _membershipAccountLabel(OrganizationWorkspaceActor? actor) {
  if (actor == null) {
    return '-';
  }
  final email = actor.email.trim();
  if (email.isNotEmpty) {
    return email;
  }
  final displayName = actor.displayName.trim();
  if (displayName.isNotEmpty) {
    return displayName;
  }
  return '-';
}

String _resolveCandidateKey(
  List<OrganizationMembershipCandidate> candidates, {
  String? workspaceMemberId,
  String? userId,
}) {
  final normalizedMemberId = (workspaceMemberId ?? '').trim();
  if (normalizedMemberId.isNotEmpty) {
    for (final candidate in candidates) {
      if ((candidate.workspaceMemberId ?? '').trim() == normalizedMemberId) {
        return candidate.key;
      }
    }
  }

  final normalizedUserId = (userId ?? '').trim();
  if (normalizedUserId.isNotEmpty) {
    for (final candidate in candidates) {
      if (candidate.userId == normalizedUserId) {
        return candidate.key;
      }
    }
  }

  return candidates.first.key;
}

class _MembershipInfo extends StatelessWidget {
  const _MembershipInfo({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: RichText(
        text: TextSpan(
          style: AppTheme.caption,
          children: [
            TextSpan(
              text: '$label: ',
              style: AppTheme.caption.copyWith(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.label,
    required this.value,
    required this.onPick,
    this.onClear,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onPick,
            icon: const Icon(Icons.calendar_today_outlined, size: 16),
            label: Text('$label: ${_formatDate(value)}'),
          ),
        ),
        if (onClear != null) ...[
          const SizedBox(width: 8),
          IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.clear_rounded),
            tooltip: 'Kosongkan tanggal',
          ),
        ],
      ],
    );
  }
}

String _formatDate(DateTime? value) {
  if (value == null) {
    return '-';
  }
  final date = value.toLocal();
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

List<OrgUnitModel> _sortedActiveUnits(List<OrgUnitModel> units) {
  final result = units
      .where((unit) => unit.status.trim().toLowerCase() == 'active')
      .toList(growable: false);
  result.sort(_compareOrgUnit);
  return result;
}

List<OrgMembershipModel> _sortMemberships(
  List<OrgMembershipModel> memberships,
) {
  final sorted = [...memberships];
  sorted.sort((left, right) {
    final statusCompare = _membershipStatusRank(
      left.status,
    ).compareTo(_membershipStatusRank(right.status));
    if (statusCompare != 0) {
      return statusCompare;
    }
    if (left.isPrimary != right.isPrimary) {
      return left.isPrimary ? -1 : 1;
    }
    final sortOrderCompare = (left.jabatan?.sortOrder ?? 999).compareTo(
      right.jabatan?.sortOrder ?? 999,
    );
    if (sortOrderCompare != 0) {
      return sortOrderCompare;
    }
    final startedAtCompare = (left.startedAt ?? DateTime(2100)).compareTo(
      right.startedAt ?? DateTime(2100),
    );
    if (startedAtCompare != 0) {
      return startedAtCompare;
    }
    return (left.jabatan?.label ?? '').compareTo(right.jabatan?.label ?? '');
  });
  return sorted;
}

int _compareOrgUnit(OrgUnitModel left, OrgUnitModel right) {
  final typeCompare = _unitTypeRank(
    left.type,
  ).compareTo(_unitTypeRank(right.type));
  if (typeCompare != 0) {
    return typeCompare;
  }
  final scopeRwCompare = (left.scopeRw ?? 0).compareTo(right.scopeRw ?? 0);
  if (scopeRwCompare != 0) {
    return scopeRwCompare;
  }
  final scopeRtCompare = (left.scopeRt ?? 0).compareTo(right.scopeRt ?? 0);
  if (scopeRtCompare != 0) {
    return scopeRtCompare;
  }
  return left.name.toLowerCase().compareTo(right.name.toLowerCase());
}

int _unitTypeRank(String type) {
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

int _membershipStatusRank(String status) {
  switch (status.trim().toLowerCase()) {
    case 'active':
      return 0;
    case 'inactive':
      return 1;
    default:
      return 2;
  }
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
      return 'Custom';
    default:
      return type.toUpperCase();
  }
}
