import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/services/organization_service.dart';
import '../../../core/utils/error_classifier.dart';
import '../../../shared/widgets/app_surface.dart';
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
              const SizedBox(height: 12),
              _StatsGrid(overview: overview),
              const SizedBox(height: 12),
              OrganizationSectionCard(
                title: 'Navigasi organisasi',
                subtitle:
                    'Kelola unit, struktur pengurus, dan membership dari satu jalur.',
                child: Column(
                  children: [
                    _NavTile(
                      icon: Icons.account_tree_outlined,
                      title: 'Kelola Unit',
                      subtitle:
                          'Atur RT, DKM, Posyandu, dan unit custom di workspace.',
                      onTap: () => context.push(Routes.organizationUnits),
                    ),
                    const Divider(height: 1),
                    _NavTile(
                      icon: Icons.badge_outlined,
                      title: 'Kelola Pengurus',
                      subtitle:
                          'Assign jabatan, masa bakti, primary membership, dan status aktif.',
                      onTap: () => context.push(Routes.organizationMemberships),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              OrganizationSectionCard(
                title: 'Detail workspace',
                subtitle: 'Informasi inti workspace aktif dan pemilik seat.',
                action: overview.profile.canManageWorkspace
                    ? FilledButton.icon(
                        onPressed: () => _editWorkspace(context, ref, overview),
                        icon: const Icon(Icons.edit_outlined, size: 18),
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
              const SizedBox(height: 12),
              OrganizationSectionCard(
                title: 'Operator aktif',
                subtitle:
                    'Seat operator yang sedang bergabung di workspace aktif.',
                child: overview.workspaceActors.isEmpty
                    ? const OrganizationEmptyState(
                        icon: Icons.group_off_outlined,
                        title: 'Belum ada operator',
                        message:
                            'Tambahkan workspace member aktif agar organisasi bisa dikelola.',
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
    return AppHeroPanel(
      eyebrow: workspace.status.toUpperCase(),
      icon: Icons.apartment_outlined,
      title: workspace.name,
      subtitle: 'Kode ${workspace.code} • RW ${workspace.rw}',
      chips: [
        if ((workspace.desaKelurahan ?? '').isNotEmpty)
          AppHeroBadge(
            label: workspace.desaKelurahan!,
            foregroundColor: AppTheme.textSecondary,
            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.06),
          ),
        if ((workspace.kecamatan ?? '').isNotEmpty)
          AppHeroBadge(
            label: workspace.kecamatan!,
            foregroundColor: AppTheme.textSecondary,
            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.06),
          ),
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.overview});

  final OrganizationOverviewData overview;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final cardWidth = (screenWidth - (AppTheme.paddingMedium * 2) - 12) / 2;
    final stats = [
      (
        'Seat aktif',
        '${overview.workspaceActors.length}',
        Icons.groups_rounded,
      ),
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
      spacing: 12,
      runSpacing: 12,
      children: stats
          .map((item) {
            return SizedBox(
              width: cardWidth,
              child: Container(
                padding: const EdgeInsets.all(AppTheme.paddingMedium),
                decoration: AppTheme.cardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(item.$3, color: AppTheme.primaryColor),
                    const SizedBox(height: 10),
                    Text(item.$2, style: AppTheme.heading2),
                    Text(item.$1, style: AppTheme.bodySmall),
                  ],
                ),
              ),
            );
          })
          .toList(growable: false),
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
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppTheme.primaryColor),
      ),
      title: Text(
        title,
        style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(subtitle, style: AppTheme.bodySmall),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

class _ActorTile extends StatelessWidget {
  const _ActorTile({required this.actor});

  final OrganizationWorkspaceActor actor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
        child: Text(
          actor.displayName.isNotEmpty
              ? actor.displayName[0].toUpperCase()
              : '?',
          style: AppTheme.bodyMedium.copyWith(
            color: AppTheme.primaryColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      title: Text(
        actor.displayName,
        style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${actor.email}\n${actor.shortScope}',
        style: AppTheme.bodySmall,
      ),
      isThreeLine: true,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          OrganizationBadge(label: actor.member.planCode.toUpperCase()),
          const SizedBox(height: 6),
          if (actor.member.isOwner)
            const OrganizationBadge(
              label: 'OWNER',
              color: AppTheme.accentColor,
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 96, child: Text(label, style: AppTheme.bodySmall)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
