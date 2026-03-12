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

class OrganizationUnitScreen extends ConsumerStatefulWidget {
  const OrganizationUnitScreen({super.key});

  @override
  ConsumerState<OrganizationUnitScreen> createState() =>
      _OrganizationUnitScreenState();
}

class _OrganizationUnitScreenState
    extends ConsumerState<OrganizationUnitScreen> {
  String _selectedType = 'all';

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    if (!auth.isSysadmin && !auth.hasRwWideAccess) {
      return const OrganizationAccessDenied(
        appBarTitle: 'Kelola Unit',
        title: 'Akses kelola unit tidak tersedia',
      );
    }

    final overviewAsync = ref.watch(organizationOverviewProvider);
    return OrganizationScreenShell(
      title: 'Kelola Unit',
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
          overviewAsync.asData?.value.profile.canManageUnit == true
          ? FloatingActionButton.extended(
              onPressed: () =>
                  _openUnitDialog(context, ref, overviewAsync.asData!.value),
              icon: const Icon(Icons.add),
              label: const Text('Tambah Unit'),
            )
          : null,
      child: overviewAsync.when(
        data: (overview) {
          final units = _selectedType == 'all'
              ? overview.orgUnits
              : overview.unitsByType(_selectedType);
          final parentNames = {
            for (final unit in overview.orgUnits) unit.id: unit.name,
          };

          return RefreshIndicator(
            onRefresh: () async {
              ref.read(organizationRefreshTickProvider.notifier).bump();
              await ref.read(organizationOverviewProvider.future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final filter in const [
                      'all',
                      AppConstants.unitTypeRw,
                      AppConstants.unitTypeRt,
                      AppConstants.unitTypeDkm,
                      AppConstants.unitTypeKarangTaruna,
                      AppConstants.unitTypePosyandu,
                      AppConstants.unitTypeCustom,
                    ])
                      ChoiceChip(
                        label: Text(_unitTypeLabel(filter)),
                        selected: _selectedType == filter,
                        onSelected: (_) {
                          setState(() => _selectedType = filter);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                if (units.isEmpty)
                  const OrganizationEmptyState(
                    icon: Icons.account_tree_outlined,
                    title: 'Belum ada unit',
                    message:
                        'Tambahkan unit untuk membentuk struktur organisasi.',
                  )
                else
                  ...units.map(
                    (unit) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        unit.name,
                                        style: AppTheme.bodySmall.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Kode ${unit.code}',
                                        style: AppTheme.caption,
                                      ),
                                    ],
                                  ),
                                ),
                                if (overview.profile.canManageUnit)
                                  PopupMenuButton<String>(
                                    iconSize: 18,
                                    padding: EdgeInsets.zero,
                                    onSelected: (value) {
                                      if (value == 'edit') {
                                        _openUnitDialog(
                                          context,
                                          ref,
                                          overview,
                                          unit,
                                        );
                                      } else if (value == 'archive') {
                                        _archiveUnit(context, ref, unit.id);
                                      }
                                    },
                                    itemBuilder: (context) => const [
                                      PopupMenuItem(
                                        value: 'edit',
                                        child: Text('Edit unit'),
                                      ),
                                      PopupMenuItem(
                                        value: 'archive',
                                        child: Text('Arsipkan'),
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
                                  label: _unitTypeLabel(unit.type),
                                ),
                                OrganizationBadge(
                                  label: unit.status.toUpperCase(),
                                  color: AppTheme.statusColor(unit.status),
                                ),
                                OrganizationBadge(
                                  label: unit.isOfficial ? 'RESMI' : 'TAMBAHAN',
                                  color: unit.isOfficial
                                      ? AppTheme.primaryDark
                                      : AppTheme.accentColor,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            _InfoLine(
                              label: 'Induk',
                              value: parentNames[unit.parentUnitId] ?? '-',
                            ),
                            _InfoLine(
                              label: 'Wilayah',
                              value: _scopeLabel(unit),
                            ),
                          ],
                        ),
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
                    icon: Icons.account_tree_outlined,
                    title: 'Unit organisasi belum bisa diinput',
                    message:
                        'Organisasi RW belum dibuat. Buka Kelola Organisasi untuk membuat workspace RW lebih dulu.',
                    action: FilledButton.icon(
                      onPressed: () => context.go(Routes.organizationManage),
                      icon: const Icon(Icons.settings_outlined),
                      label: const Text('Kelola Organisasi'),
                    ),
                  )
                : Text(
                    'Gagal memuat unit.\n${error.toString()}',
                    textAlign: TextAlign.center,
                    style: AppTheme.bodySmall,
                  ),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Future<void> _archiveUnit(
    BuildContext context,
    WidgetRef ref,
    String unitId,
  ) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Arsipkan unit'),
            content: const Text('Unit akan ditandai inactive. Lanjutkan?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Arsipkan'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !context.mounted) {
      return;
    }

    try {
      await ref.read(organizationServiceProvider).archiveOrgUnit(unitId);
      ref.read(organizationRefreshTickProvider.notifier).bump();
      if (!context.mounted) {
        return;
      }
      ErrorClassifier.showSuccessSnackBar(context, 'Unit berhasil diarsipkan.');
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ErrorClassifier.showErrorSnackBar(context, error);
    }
  }

  Future<void> _openUnitDialog(
    BuildContext context,
    WidgetRef ref,
    OrganizationOverviewData overview, [
    OrgUnitModel? existing,
  ]) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final codeCtrl = TextEditingController(text: existing?.code ?? '');
    String type = existing?.type ?? AppConstants.unitTypeRt;
    String status = existing?.status ?? 'active';
    String parentUnitId = existing?.parentUnitId ?? '';
    bool isOfficial = existing?.isOfficial ?? true;
    int? scopeRt = existing?.scopeRt;
    int? scopeRw = existing?.scopeRw ?? overview.profile.workspace.rw;

    final saved =
        await showDialog<bool>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setState) {
              final parentCandidates = overview.orgUnits
                  .where((unit) => unit.id != existing?.id)
                  .toList(growable: false);
              return AlertDialog(
                title: Text(existing == null ? 'Tambah Unit' : 'Edit Unit'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: type,
                        decoration: const InputDecoration(
                          labelText: 'Tipe unit',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: AppConstants.unitTypeRw,
                            child: Text('RW'),
                          ),
                          DropdownMenuItem(
                            value: AppConstants.unitTypeRt,
                            child: Text('RT'),
                          ),
                          DropdownMenuItem(
                            value: AppConstants.unitTypeDkm,
                            child: Text('DKM'),
                          ),
                          DropdownMenuItem(
                            value: AppConstants.unitTypeKarangTaruna,
                            child: Text('Karang Taruna'),
                          ),
                          DropdownMenuItem(
                            value: AppConstants.unitTypePosyandu,
                            child: Text('Posyandu'),
                          ),
                          DropdownMenuItem(
                            value: AppConstants.unitTypeCustom,
                            child: Text('Custom'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            type = value ?? AppConstants.unitTypeRt;
                            if (type == AppConstants.unitTypeCustom) {
                              isOfficial = false;
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nama unit',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: codeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Kode unit (opsional)',
                          hintText: 'Kosongkan untuk generate otomatis',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: parentUnitId.isEmpty ? '' : parentUnitId,
                        decoration: const InputDecoration(
                          labelText: 'Parent unit',
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: '',
                            child: Text('Tanpa parent'),
                          ),
                          ...parentCandidates.map(
                            (unit) => DropdownMenuItem<String>(
                              value: unit.id,
                              child: Text(unit.name),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() => parentUnitId = value ?? '');
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        initialValue: scopeRt?.toString() ?? '',
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Scope RT',
                        ),
                        onChanged: (value) {
                          scopeRt = int.tryParse(value.trim());
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        initialValue: scopeRw?.toString() ?? '',
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Scope RW',
                        ),
                        onChanged: (value) {
                          scopeRw = int.tryParse(value.trim());
                        },
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
                        value: isOfficial,
                        onChanged: type == AppConstants.unitTypeCustom
                            ? null
                            : (value) => setState(() => isOfficial = value),
                        title: const Text('Unit resmi'),
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
          .saveOrgUnit(
            unitId: existing?.id,
            type: type,
            name: nameCtrl.text.trim(),
            code: _resolveUnitCodeInput(
              rawCode: codeCtrl.text,
              name: nameCtrl.text,
              type: type,
              existingCode: existing?.code,
            ),
            parentUnitId: parentUnitId,
            scopeRt: scopeRt,
            scopeRw: scopeRw,
            isOfficial: type == AppConstants.unitTypeCustom
                ? false
                : isOfficial,
            status: status,
          );
      ref.read(organizationRefreshTickProvider.notifier).bump();
      if (!context.mounted) {
        return;
      }
      ErrorClassifier.showSuccessSnackBar(
        context,
        existing == null
            ? 'Unit berhasil dibuat.'
            : 'Unit berhasil diperbarui.',
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ErrorClassifier.showErrorSnackBar(context, error);
    }
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

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

String _scopeLabel(OrgUnitModel unit) {
  final parts = <String>[];
  if ((unit.scopeRw ?? 0) > 0) {
    parts.add('RW ${unit.scopeRw}');
  }
  if ((unit.scopeRt ?? 0) > 0) {
    parts.add('RT ${unit.scopeRt}');
  }
  if (parts.isEmpty) {
    return 'RW aktif';
  }
  return parts.join(' • ');
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
    case 'all':
    default:
      return 'Semua';
  }
}

String _slugify(String value) {
  final lower = value.trim().toLowerCase();
  final sanitized = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  return sanitized.replaceAll(RegExp(r'^_+|_+$'), '');
}

String _resolveUnitCodeInput({
  required String rawCode,
  required String name,
  required String type,
  String? existingCode,
}) {
  final normalizedCode = rawCode.trim();
  if (normalizedCode.isNotEmpty) {
    return normalizedCode;
  }
  final preservedCode = (existingCode ?? '').trim();
  if (preservedCode.isNotEmpty) {
    return preservedCode;
  }
  final slug = _slugify(name);
  if (slug.isEmpty) {
    return type.trim().toLowerCase();
  }
  return '${type.trim().toLowerCase()}_$slug';
}
