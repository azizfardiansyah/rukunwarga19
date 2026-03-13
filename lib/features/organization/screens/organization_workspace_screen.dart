import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/organization_service.dart';
import '../../../core/utils/area_access.dart';
import '../../../core/utils/error_classifier.dart';
import '../../../shared/models/workspace_access_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/organization_providers.dart';
import '../widgets/organization_widgets.dart';

class OrganizationManageScreen extends ConsumerWidget {
  const OrganizationManageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    if (!auth.isSysadmin && !auth.hasRwWideAccess) {
      return const OrganizationAccessDenied(
        appBarTitle: 'Kelola Organisasi',
        title: 'Akses kelola organisasi tidak tersedia',
      );
    }

    final overviewAsync = ref.watch(organizationOverviewProvider);
    return OrganizationScreenShell(
      title: 'Kelola Organisasi',
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
        data: (overview) => RefreshIndicator(
          onRefresh: () async {
            ref.read(organizationRefreshTickProvider.notifier).bump();
            await ref.read(organizationOverviewProvider.future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
            children: [
              _ManageHero(overview: overview),
              const SizedBox(height: 10),
              _StatsGrid(overview: overview),
              const SizedBox(height: 10),
              OrganizationSectionCard(
                title: 'Sub-menu pengelolaan',
                subtitle:
                    'Input struktur organisasi dilakukan lewat unit dan pengurus.',
                child: Column(
                  children: [
                    _NavTile(
                      icon: Icons.account_tree_outlined,
                      title: 'Kelola Unit',
                      subtitle:
                          'Input RT, DKM, Karang Taruna, Posyandu, dan unit custom.',
                      onTap: () => context.push(Routes.organizationUnits),
                    ),
                    const Divider(height: 1),
                    _NavTile(
                      icon: Icons.badge_outlined,
                      title: 'Kelola Pengurus',
                      subtitle:
                          'Input jabatan pengurus, masa bakti, dan statusnya.',
                      onTap: () => context.push(Routes.organizationMemberships),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              OrganizationSectionCard(
                title: 'Preview Bagan Organisasi',
                subtitle:
                    'Pratinjau struktur aktif agar admin bisa cek hierarki unit tanpa keluar dari menu kelola.',
                child: _OrganizationChartPreview(overview: overview),
              ),
            ],
          ),
        ),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.paddingLarge),
            child: isOrganizationSetupMissingError(error)
                ? OrganizationEmptyState(
                    icon: Icons.account_tree_outlined,
                    title: 'Organisasi belum siap dikelola',
                    message:
                        'Organisasi RW belum dibuat. Tekan tombol di bawah untuk membuat workspace RW dan struktur awalnya.',
                    action: FilledButton.icon(
                      onPressed: () => _openBootstrapDialog(context, ref),
                      icon: const Icon(Icons.add_home_work_outlined),
                      label: const Text('Buat Organisasi RW'),
                    ),
                  )
                : Text(
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
}

class _ManageHero extends StatelessWidget {
  const _ManageHero({required this.overview});

  final OrganizationOverviewData overview;

  @override
  Widget build(BuildContext context) {
    final workspace = overview.profile.workspace;
    final locationParts = [
      workspace.desaKelurahan,
      workspace.kecamatan,
      workspace.kabupatenKota,
    ].whereType<String>().where((part) => part.trim().isNotEmpty).toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: AppTheme.cardDecorationFor(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
              Icons.account_tree_outlined,
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
                ),
                const SizedBox(height: 2),
                Text(
                  'Input unit dan susunan pengurus RW ${workspace.rw}',
                  style: AppTheme.caption.copyWith(
                    color: AppTheme.textTertiary,
                  ),
                ),
                if (locationParts.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    locationParts.join(' - '),
                    style: AppTheme.caption.copyWith(
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ],
              ],
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
      (
        'RT',
        '${overview.unitsByType(AppConstants.unitTypeRt).length}',
        Icons.holiday_village_outlined,
      ),
      (
        'DKM',
        '${overview.unitsByType(AppConstants.unitTypeDkm).length}',
        Icons.mosque_outlined,
      ),
      (
        'Karang Taruna',
        '${overview.unitsByType(AppConstants.unitTypeKarangTaruna).length}',
        Icons.groups_2_outlined,
      ),
      (
        'Posyandu',
        '${overview.unitsByType(AppConstants.unitTypePosyandu).length}',
        Icons.favorite_border_rounded,
      ),
      ('Pengurus', '${overview.orgMemberships.length}', Icons.badge_outlined),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: stats
          .map(
            (item) => SizedBox(
              width: cardWidth,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: AppTheme.cardDecorationFor(context),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        item.$3,
                        color: AppTheme.primaryColor,
                        size: 16,
                      ),
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
            ),
          )
          .toList(growable: false),
    );
  }
}

class _OrganizationChartPreview extends StatelessWidget {
  const _OrganizationChartPreview({required this.overview});

  final OrganizationOverviewData overview;

  @override
  Widget build(BuildContext context) {
    final activeUnits = overview.orgUnits
        .where((unit) => unit.status == 'active')
        .toList(growable: false);
    if (activeUnits.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Belum ada unit aktif untuk ditampilkan di preview.',
          style: AppTheme.caption,
        ),
      );
    }

    final unitById = {for (final unit in activeUnits) unit.id: unit};
    final childrenByParent = <String, List<OrgUnitModel>>{};
    final roots = <OrgUnitModel>[];
    for (final unit in activeUnits) {
      final parentId = (unit.parentUnitId ?? '').trim();
      if (parentId.isEmpty || !unitById.containsKey(parentId)) {
        roots.add(unit);
        continue;
      }
      childrenByParent.putIfAbsent(parentId, () => <OrgUnitModel>[]).add(unit);
    }

    final levels = <List<OrgUnitModel>>[];
    var frontier = _sortUnits(roots).take(1).toList(growable: false);
    var depth = 0;
    while (frontier.isNotEmpty && depth < 3) {
      levels.add(frontier);
      final next = <OrgUnitModel>[];
      for (final unit in frontier) {
        next.addAll(childrenByParent[unit.id] ?? const <OrgUnitModel>[]);
      }
      frontier = _sortUnits(next).take(3).toList(growable: false);
      depth++;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 520;
        final itemWidth = wide
            ? (constraints.maxWidth - 24) / 3
            : (constraints.maxWidth - 12) / 2;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (
              var levelIndex = 0;
              levelIndex < levels.length;
              levelIndex++
            ) ...[
              if (levelIndex > 0) const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      levelIndex == 0
                          ? 'Puncak organisasi'
                          : 'Level ${levelIndex + 1}',
                      style: AppTheme.caption.copyWith(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: levels[levelIndex]
                    .map(
                      (unit) => SizedBox(
                        width: itemWidth.clamp(140.0, 220.0),
                        child: _OrganizationPreviewUnitCard(
                          unit: unit,
                          leadMembership: _leadMembership(unit.id),
                          actor: _leadActor(unit.id),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
          ],
        );
      },
    );
  }

  List<OrgUnitModel> _sortUnits(List<OrgUnitModel> units) {
    final sorted = [...units];
    sorted.sort((a, b) {
      final typeCompare = _typeRank(a.type).compareTo(_typeRank(b.type));
      if (typeCompare != 0) {
        return typeCompare;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return sorted;
  }

  int _typeRank(String type) {
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
      default:
        return 5;
    }
  }

  OrgMembershipModel? _leadMembership(String unitId) {
    final memberships = overview.orgMemberships
        .where(
          (membership) => membership.isActive && membership.orgUnitId == unitId,
        )
        .toList(growable: false);
    if (memberships.isEmpty) {
      return null;
    }
    final sorted = [...memberships];
    sorted.sort((a, b) {
      final primaryCompare = (a.isPrimary ? 0 : 1).compareTo(
        b.isPrimary ? 0 : 1,
      );
      if (primaryCompare != 0) {
        return primaryCompare;
      }
      return (a.jabatan?.sortOrder ?? 999).compareTo(
        b.jabatan?.sortOrder ?? 999,
      );
    });
    return sorted.first;
  }

  OrganizationWorkspaceActor? _leadActor(String unitId) {
    final membership = _leadMembership(unitId);
    if (membership == null) {
      return null;
    }
    return overview.actorByMemberId(membership.workspaceMemberId);
  }
}

class _OrganizationPreviewUnitCard extends StatelessWidget {
  const _OrganizationPreviewUnitCard({
    required this.unit,
    required this.leadMembership,
    required this.actor,
  });

  final OrgUnitModel unit;
  final OrgMembershipModel? leadMembership;
  final OrganizationWorkspaceActor? actor;

  @override
  Widget build(BuildContext context) {
    final tone = _toneForUnitType(unit.type);
    final scopeLabel = [
      if ((unit.scopeRw ?? 0) > 0) 'RW ${unit.scopeRw}',
      if ((unit.scopeRt ?? 0) > 0) 'RT ${unit.scopeRt}',
    ].join(' / ');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.cardDecorationFor(context, borderRadius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  unit.name,
                  style: AppTheme.bodySmall.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryTextFor(context),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _unitTypeLabel(unit.type),
                  style: AppTheme.caption.copyWith(
                    color: tone,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (scopeLabel.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              scopeLabel,
              style: AppTheme.caption.copyWith(
                color: AppTheme.tertiaryTextFor(context),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  actor?.displayName ?? 'Pengurus belum diisi',
                  style: AppTheme.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryTextFor(context),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  leadMembership?.jabatan?.label ?? 'Belum ada jabatan utama',
                  style: AppTheme.caption.copyWith(
                    color: AppTheme.secondaryTextFor(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _toneForUnitType(String type) {
    switch (type.trim().toLowerCase()) {
      case AppConstants.unitTypeRw:
        return AppTheme.primaryColor;
      case AppConstants.unitTypeRt:
        return AppTheme.toneTerracotta;
      case AppConstants.unitTypeDkm:
        return AppTheme.toneSienna;
      case AppConstants.unitTypeKarangTaruna:
        return AppTheme.tonePink;
      case AppConstants.unitTypePosyandu:
        return AppTheme.successColor;
      default:
        return AppTheme.toneCharcoal;
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
      default:
        return 'Unit';
    }
  }
}

Future<void> _openBootstrapDialog(BuildContext context, WidgetRef ref) async {
  final defaults = await _resolveBootstrapDefaults(ref.read(authProvider));
  if (!context.mounted) {
    return;
  }

  final result = await showDialog<OrganizationBootstrapResult?>(
    context: context,
    builder: (_) => _OrganizationBootstrapDialog(defaults: defaults),
  );

  if (result == null || !context.mounted) {
    return;
  }

  ref.read(organizationRefreshTickProvider.notifier).bump();

  if (!context.mounted) {
    return;
  }
  ErrorClassifier.showSuccessSnackBar(
    context,
    result.created
        ? 'Organisasi RW berhasil dibuat.'
        : 'Binding organisasi berhasil dipulihkan.',
  );
}

class _OrganizationBootstrapDefaults {
  const _OrganizationBootstrapDefaults({
    required this.workspaceName,
    required this.rwText,
    required this.desaKelurahan,
    required this.kecamatan,
    required this.kabupatenKota,
    required this.provinsi,
  });

  final String workspaceName;
  final String rwText;
  final String desaKelurahan;
  final String kecamatan;
  final String kabupatenKota;
  final String provinsi;
}

class _OrganizationBootstrapDialog extends ConsumerStatefulWidget {
  const _OrganizationBootstrapDialog({required this.defaults});

  final _OrganizationBootstrapDefaults defaults;

  @override
  ConsumerState<_OrganizationBootstrapDialog> createState() =>
      _OrganizationBootstrapDialogState();
}

class _OrganizationBootstrapDialogState
    extends ConsumerState<_OrganizationBootstrapDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _rwCtrl;
  late final TextEditingController _desaCtrl;
  late final TextEditingController _kecamatanCtrl;
  late final TextEditingController _kabupatenCtrl;
  late final TextEditingController _provinsiCtrl;

  bool _isSubmitting = false;
  bool _isNameCustomized = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.defaults.workspaceName);
    _rwCtrl = TextEditingController(text: widget.defaults.rwText);
    _desaCtrl = TextEditingController(text: widget.defaults.desaKelurahan);
    _kecamatanCtrl = TextEditingController(text: widget.defaults.kecamatan);
    _kabupatenCtrl = TextEditingController(text: widget.defaults.kabupatenKota);
    _provinsiCtrl = TextEditingController(text: widget.defaults.provinsi);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _rwCtrl.dispose();
    _desaCtrl.dispose();
    _kecamatanCtrl.dispose();
    _kabupatenCtrl.dispose();
    _provinsiCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final workspaceName = _nameCtrl.text.trim();
    final rw = int.tryParse(_rwCtrl.text.trim()) ?? 0;

    if (workspaceName.isEmpty || rw <= 0) {
      ErrorClassifier.showErrorSnackBar(
        context,
        const FormatException('Nama organisasi dan nomor RW wajib diisi.'),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final bootstrap = await ref
          .read(organizationServiceProvider)
          .bootstrapOrganization(
            workspaceName: workspaceName,
            rw: rw,
            desaKelurahan: _desaCtrl.text,
            kecamatan: _kecamatanCtrl.text,
            kabupatenKota: _kabupatenCtrl.text,
            provinsi: _provinsiCtrl.text,
          );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(bootstrap);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isSubmitting = false);
      ErrorClassifier.showErrorSnackBar(context, error);
    }
  }

  void _handleNameChanged() {
    _isNameCustomized =
        _nameCtrl.text.trim() != _defaultBootstrapWorkspaceName(_rwCtrl.text);
  }

  void _handleRwChanged(String value) {
    if (_isNameCustomized) {
      return;
    }
    final nextName = _defaultBootstrapWorkspaceName(value);
    _nameCtrl.value = _nameCtrl.value.copyWith(
      text: nextName,
      selection: TextSelection.collapsed(offset: nextName.length),
      composing: TextRange.empty,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Buat Organisasi RW'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameCtrl,
              onChanged: (_) => _handleNameChanged(),
              decoration: const InputDecoration(
                labelText: 'Nama organisasi',
                hintText: 'Contoh: Jajaran Pengurus RW 19',
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _rwCtrl,
              onChanged: _handleRwChanged,
              decoration: const InputDecoration(
                labelText: 'Nomor RW',
                hintText: 'Contoh: 19',
              ),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _desaCtrl,
              decoration: const InputDecoration(labelText: 'Kelurahan / Desa'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _kecamatanCtrl,
              decoration: const InputDecoration(labelText: 'Kecamatan'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _kabupatenCtrl,
              decoration: const InputDecoration(labelText: 'Kota / Kabupaten'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _provinsiCtrl,
              decoration: const InputDecoration(labelText: 'Provinsi'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Buat'),
        ),
      ],
    );
  }
}

Future<_OrganizationBootstrapDefaults> _resolveBootstrapDefaults(
  AuthState auth,
) async {
  if (auth.user == null) {
    return _OrganizationBootstrapDefaults(
      workspaceName: _defaultBootstrapWorkspaceName(''),
      rwText: '',
      desaKelurahan: '',
      kecamatan: '',
      kabupatenKota: '',
      provinsi: '',
    );
  }

  final area = await resolveAreaAccessContext(auth);
  final rwValue = _firstPositiveInt([
    area.rw,
    recordNumericField(auth.user!, 'scope_rw'),
    recordNumericField(auth.user!, 'rw'),
  ]);
  final rwText = rwValue == null ? '' : '$rwValue';

  return _OrganizationBootstrapDefaults(
    workspaceName: _defaultBootstrapWorkspaceName(rwText),
    rwText: rwText,
    desaKelurahan: _firstNonEmptyText([
      area.desaKelurahan,
      recordTextField(auth.user!, 'desa_kelurahan'),
    ]),
    kecamatan: _firstNonEmptyText([
      area.kecamatan,
      recordTextField(auth.user!, 'kecamatan'),
    ]),
    kabupatenKota: _firstNonEmptyText([
      area.kabupatenKota,
      recordTextField(auth.user!, 'kabupaten_kota'),
    ]),
    provinsi: _firstNonEmptyText([
      area.provinsi,
      recordTextField(auth.user!, 'provinsi'),
    ]),
  );
}

int? _firstPositiveInt(List<int?> values) {
  for (final value in values) {
    if (value != null && value > 0) {
      return value;
    }
  }
  return null;
}

String _firstNonEmptyText(List<String?> values) {
  for (final value in values) {
    final normalized = (value ?? '').trim();
    if (normalized.isNotEmpty) {
      return normalized;
    }
  }
  return '';
}

String _defaultBootstrapWorkspaceName(String rwText) {
  final normalizedRw = rwText.trim();
  if (normalizedRw.isEmpty) {
    return 'Jajaran Pengurus RW';
  }
  return 'Jajaran Pengurus RW $normalizedRw';
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
