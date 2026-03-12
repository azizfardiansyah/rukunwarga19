import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/organization_service.dart';
import '../../../core/utils/area_access.dart';
import '../../../core/utils/error_classifier.dart';
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
              const OrganizationSectionCard(
                title: 'Batas Modul',
                subtitle:
                    'Yang jadi master sysadmin hanya daftar jabatan. Data organisasi lain adalah hasil input operasional.',
                child: _ScopeNote(),
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
      decoration: AppTheme.cardDecoration(),
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
                    locationParts.join(' • '),
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
                decoration: AppTheme.cardDecoration(),
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

class _ScopeNote extends StatelessWidget {
  const _ScopeNote();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        _ScopeLine(
          title: 'jabatan_master',
          subtitle: 'Konfigurasi awal oleh sysadmin sebagai master jabatan.',
        ),
        SizedBox(height: 8),
        _ScopeLine(
          title: 'org_units',
          subtitle: 'Hasil input dari menu Kelola Unit.',
        ),
        SizedBox(height: 8),
        _ScopeLine(
          title: 'org_memberships',
          subtitle: 'Hasil input dari menu Kelola Pengurus.',
        ),
      ],
    );
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

class _ScopeLine extends StatelessWidget {
  const _ScopeLine({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.7),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
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
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTheme.caption.copyWith(color: AppTheme.textTertiary),
              ),
            ],
          ),
        ),
      ],
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
