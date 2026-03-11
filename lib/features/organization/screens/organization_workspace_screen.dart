import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/services/organization_service.dart';
import '../../../core/utils/error_classifier.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/organization_providers.dart';
import '../widgets/organization_widgets.dart';

class OrganizationWorkspaceScreen extends ConsumerWidget {
  const OrganizationWorkspaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    if (!auth.isSysadmin && !auth.hasRwWideAccess) {
      return const OrganizationAccessDenied();
    }

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
              _WorkspaceHero(overview: overview),
              const SizedBox(height: 10),
              _StatsGrid(overview: overview),
              const SizedBox(height: 10),
              OrganizationSectionCard(
                title: 'Navigasi organisasi',
                subtitle:
                    'Kelola unit, struktur pengurus, dan membership.',
                child: Column(
                  children: [
                    _NavTile(
                      icon: Icons.account_tree_outlined,
                      title: 'Kelola Unit',
                      subtitle:
                          'Atur RT, DKM, Posyandu, dan unit custom.',
                      onTap: () => context.push(Routes.organizationUnits),
                    ),
                    const Divider(height: 1),
                    _NavTile(
                      icon: Icons.badge_outlined,
                      title: 'Kelola Pengurus',
                      subtitle:
                          'Assign jabatan, masa bakti, primary membership.',
                      onTap: () => context.push(Routes.organizationMemberships),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              OrganizationSectionCard(
                title: 'Detail workspace',
                subtitle: 'Informasi inti workspace aktif.',
                action: overview.profile.canManageWorkspace
                    ? FilledButton.icon(
                        onPressed: () => _editWorkspace(context, ref, overview),
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Edit'),
                      )
                    : null,
                child: Column(
                  children: [
                    _DetailRow(
                      label: 'Nama',
                      value: overview.profile.workspace.name,
                    ),
                    _DetailRow(
                      label: 'Kode',
                      value: overview.profile.workspace.code,
                    ),
                    _DetailRow(
                      label: 'RW',
                      value: '${overview.profile.workspace.rw}',
                    ),
                    _DetailRow(
                      label: 'Status',
                      value: overview.profile.workspace.status,
                    ),
                    _DetailRow(
                      label: 'Owner',
                      value: overview.ownerActor?.displayName ?? '-',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              OrganizationSectionCard(
                title: 'Operator aktif',
                subtitle:
                    'Seat operator di workspace.',
                child: overview.workspaceActors.isEmpty
                    ? const OrganizationEmptyState(
                        icon: Icons.group_off_outlined,
                        title: 'Belum ada operator',
                        message:
                            'Tambahkan workspace member aktif.',
                      )
                    : Column(
                        children: overview.workspaceActors
                            .map((actor) => _ActorTile(actor: actor))
                            .toList(growable: false),
                      ),
              ),
            ],
          ),
        ),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.paddingLarge),
            child: Text(
              'Gagal memuat organisasi.\n${error.toString()}',
              textAlign: TextAlign.center,
              style: AppTheme.bodySmall,
            ),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Future<void> _editWorkspace(
    BuildContext context,
    WidgetRef ref,
    OrganizationOverviewData overview,
  ) async {
    final nameCtrl = TextEditingController(
      text: overview.profile.workspace.name,
    );
    String status = overview.profile.workspace.status;
    final saved =
        await showDialog<bool>(
          context: context,
          builder: (context) {
            return StatefulBuilder(
              builder: (context, setState) {
                return AlertDialog(
                  title: const Text('Edit Workspace'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Nama workspace',
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: status,
                          decoration: const InputDecoration(
                            labelText: 'Status',
                          ),
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
            );
          },
        ) ??
        false;

    if (!saved || !context.mounted) {
      return;
    }

    try {
      await ref
          .read(organizationServiceProvider)
          .updateWorkspace(name: nameCtrl.text.trim(), status: status);
      ref.read(organizationRefreshTickProvider.notifier).bump();
      if (!context.mounted) {
        return;
      }
      ErrorClassifier.showSuccessSnackBar(
        context,
        'Workspace berhasil diperbarui.',
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ErrorClassifier.showErrorSnackBar(context, error);
    }
  }
}

class _WorkspaceHero extends StatelessWidget {
  const _WorkspaceHero({required this.overview});

  final OrganizationOverviewData overview;

  @override
  Widget build(BuildContext context) {
    final workspace = overview.profile.workspace;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: AppTheme.cardDecoration(),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor.withValues(alpha: 0.12),
                  AppTheme.accentColor.withValues(alpha: 0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.apartment_outlined,
              color: AppTheme.primaryColor,
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
                  style: AppTheme.bodySmall.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Kode ${workspace.code} • RW ${workspace.rw}',
                  style: AppTheme.caption.copyWith(
                    color: AppTheme.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              workspace.status.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.overview});

  final OrganizationOverviewData overview;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final cardWidth = (screenWidth - 28 - 10) / 2;
    final stats = [
      ('Seat aktif', '${overview.workspaceActors.length}', Icons.groups_rounded),
      ('Unit', '${overview.orgUnits.length}', Icons.account_tree_outlined),
      (
        'Pengurus',
        '${overview.orgMemberships.where((item) => item.isActive).length}',
        Icons.badge_outlined,
      ),
      (
        'Unit resmi',
        '${overview.orgUnits.where((item) => item.isOfficial).length}',
        Icons.apartment_outlined,
      ),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: stats.map((item) {
        return SizedBox(
          width: cardWidth,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: AppTheme.cardDecoration(),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(item.$3, color: AppTheme.primaryColor, size: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.$2,
                        style: AppTheme.bodyMedium.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        item.$1,
                        style: AppTheme.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(growable: false),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppTheme.primaryColor, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.bodySmall.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTheme.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActorTile extends StatelessWidget {
  const _ActorTile({required this.actor});

  final OrganizationWorkspaceActor actor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
            child: Text(
              actor.displayName.isNotEmpty
                  ? actor.displayName[0].toUpperCase()
                  : '?',
              style: AppTheme.caption.copyWith(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  actor.displayName,
                  style: AppTheme.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  actor.email,
                  style: AppTheme.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    OrganizationBadge(label: actor.member.planCode.toUpperCase()),
                    if (actor.member.isOwner)
                      const OrganizationBadge(
                        label: 'OWNER',
                        color: AppTheme.accentColor,
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
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(label, style: AppTheme.caption),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: AppTheme.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
