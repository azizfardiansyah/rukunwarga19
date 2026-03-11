import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
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
        title: 'Akses kelola pengurus tidak tersedia',
      );
    }

    final overviewAsync = ref.watch(organizationOverviewProvider);
    return OrganizationScreenShell(
      title: 'Kelola Pengurus',
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: () =>
              ref.read(organizationRefreshTickProvider.notifier).bump(),
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
              ),
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text('Tambah Pengurus'),
            )
          : null,
      child: overviewAsync.when(
        data: (overview) {
          final units = overview.orgUnits;
          final memberships = _unitFilter == 'all'
              ? overview.orgMemberships
              : overview.orgMemberships
                    .where((item) => item.orgUnitId == _unitFilter)
                    .toList(growable: false);

          return RefreshIndicator(
            onRefresh: () async {
              ref.read(organizationRefreshTickProvider.notifier).bump();
              await ref.read(organizationOverviewProvider.future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _unitFilter,
                  decoration: const InputDecoration(labelText: 'Filter unit'),
                  items: [
                    const DropdownMenuItem<String>(
                      value: 'all',
                      child: Text('Semua unit'),
                    ),
                    ...units.map(
                      (unit) => DropdownMenuItem<String>(
                        value: unit.id,
                        child: Text(unit.name),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _unitFilter = value ?? 'all');
                  },
                ),
                const SizedBox(height: 16),
                if (memberships.isEmpty)
                  const OrganizationEmptyState(
                    icon: Icons.badge_outlined,
                    title: 'Belum ada pengurus',
                    message:
                        'Assign jabatan ke member workspace untuk mulai membentuk struktur organisasi.',
                  )
                else
                  ...memberships.map(
                    (membership) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _MembershipCard(
                        membership: membership,
                        actor: overview.actorByMemberId(
                          membership.workspaceMemberId,
                        ),
                        canManage: overview.profile.canManageMembership,
                        onEdit: () => _openMembershipDialog(
                          context,
                          ref,
                          overview,
                          membership,
                        ),
                        onDeactivate: () =>
                            _deactivateMembership(context, ref, membership.id),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
        error: (error, _) => Center(
          child: Text(
            'Gagal memuat pengurus.\n${error.toString()}',
            textAlign: TextAlign.center,
            style: AppTheme.bodySmall,
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
    OrganizationOverviewData overview, [
    OrgMembershipModel? existing,
  ]) async {
    if (overview.workspaceActors.isEmpty ||
        overview.orgUnits.isEmpty ||
        overview.jabatanMaster.isEmpty) {
      ErrorClassifier.showErrorSnackBar(
        context,
        const FormatException(
          'Workspace member, unit, atau jabatan belum siap.',
        ),
      );
      return;
    }

    String workspaceMemberId = existing?.workspaceMemberId.isNotEmpty == true
        ? existing!.workspaceMemberId
        : overview.workspaceActors.first.member.id;
    String orgUnitId = existing?.orgUnitId.isNotEmpty == true
        ? existing!.orgUnitId
        : overview.orgUnits.first.id;
    String jabatanId = existing?.jabatanId ?? '';
    bool isPrimary = existing?.isPrimary ?? false;
    String status = existing?.status ?? 'active';
    final periodCtrl = TextEditingController(text: existing?.periodLabel ?? '');
    DateTime? startedAt = existing?.startedAt;
    DateTime? endedAt = existing?.endedAt;

    String resolveDefaultJabatan() {
      final unit = overview.orgUnits.firstWhere(
        (item) => item.id == orgUnitId,
        orElse: () => overview.orgUnits.first,
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
              final selectedUnit = overview.orgUnits.firstWhere(
                (item) => item.id == orgUnitId,
                orElse: () => overview.orgUnits.first,
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
                        initialValue: workspaceMemberId,
                        decoration: const InputDecoration(
                          labelText: 'Member workspace',
                        ),
                        items: overview.workspaceActors
                            .map(
                              (actor) => DropdownMenuItem<String>(
                                value: actor.member.id,
                                child: Text(actor.displayName),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          setState(() => workspaceMemberId = value ?? '');
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: orgUnitId,
                        decoration: const InputDecoration(
                          labelText: 'Unit organisasi',
                        ),
                        items: overview.orgUnits
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
      return;
    }

    try {
      await ref
          .read(organizationServiceProvider)
          .saveOrgMembership(
            membershipId: existing?.id,
            workspaceMemberId: workspaceMemberId,
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
        return;
      }
      ErrorClassifier.showErrorSnackBar(context, error);
    }
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
      padding: const EdgeInsets.all(AppTheme.paddingMedium),
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
                      actor?.displayName ?? 'Member tidak dikenal',
                      style: AppTheme.bodyLarge.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${membership.jabatan?.label ?? "-"} • ${membership.orgUnit?.name ?? "-"}',
                      style: AppTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (canManage)
                PopupMenuButton<String>(
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
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OrganizationBadge(
                label: membership.status.toUpperCase(),
                color: AppTheme.statusColor(membership.status),
              ),
              if (membership.isPrimary)
                const OrganizationBadge(
                  label: 'PRIMARY',
                  color: AppTheme.primaryDark,
                ),
              if ((membership.periodLabel ?? '').isNotEmpty)
                OrganizationBadge(
                  label: membership.periodLabel!,
                  color: AppTheme.accentColor,
                ),
            ],
          ),
          const SizedBox(height: 12),
          _MembershipInfo(label: 'Akun', value: actor?.email ?? '-'),
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

class _MembershipInfo extends StatelessWidget {
  const _MembershipInfo({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: AppTheme.bodySmall,
          children: [
            TextSpan(
              text: '$label: ',
              style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.w700),
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
