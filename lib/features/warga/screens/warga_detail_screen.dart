import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/pocketbase_service.dart';
import '../../../core/utils/area_access.dart';
import '../../../core/utils/error_classifier.dart';
import '../../../core/utils/formatters.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/models/kartu_keluarga_model.dart';
import '../../../shared/models/warga_model.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../../../shared/widgets/app_surface.dart';

typedef _WargaDetailData = ({
  RecordModel wargaRecord,
  WargaModel warga,
  RecordModel? userRecord,
});

class WargaDetailScreen extends ConsumerStatefulWidget {
  final String wargaId;
  const WargaDetailScreen({super.key, required this.wargaId});

  @override
  ConsumerState<WargaDetailScreen> createState() => _WargaDetailScreenState();
}

class _WargaDetailScreenState extends ConsumerState<WargaDetailScreen> {
  Future<_WargaDetailData> _loadDetail() async {
    final auth = ref.read(authProvider);
    final access = await resolveAreaAccessContext(auth);
    final wargaRecord = await pb
        .collection(AppConstants.colWarga)
        .getOne(widget.wargaId);
    final warga = WargaModel.fromRecord(wargaRecord);
    KartuKeluargaModel? linkedKk;

    if (warga.noKkId.isNotEmpty) {
      try {
        final kkRecord = await pb
            .collection(AppConstants.colKartuKeluarga)
            .getOne(warga.noKkId);
        linkedKk = KartuKeluargaModel.fromRecord(kkRecord);
      } catch (_) {}
    }

    if (!canAccessWargaRecord(
      auth,
      warga,
      context: access,
      linkedKk: linkedKk,
    )) {
      throw Exception('Anda tidak memiliki akses ke detail warga ini.');
    }

    RecordModel? userRecord;
    if ((warga.userId ?? '').isNotEmpty) {
      try {
        userRecord = await pb
            .collection(AppConstants.colUsers)
            .getOne(warga.userId!);
      } catch (_) {
        userRecord = null;
      }
    }

    return (wargaRecord: wargaRecord, warga: warga, userRecord: userRecord);
  }

  Future<void> _openEdit() async {
    await context.push('${Routes.wargaForm}?id=${widget.wargaId}');
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Warga')),
      body: AppPageBackground(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
        child: FutureBuilder<_WargaDetailData>(
          future: _loadDetail(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _WargaDetailSkeleton();
            }
            if (snapshot.hasError) {
              return Center(
                child: AppSurfaceCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 48,
                        color: AppTheme.errorColor,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        ErrorClassifier.classify(snapshot.error).message,
                        style: AppTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            final data = snapshot.data!;
            final warga = data.warga;
            final auth = ref.watch(authProvider);
            final canEdit =
                auth.isAdmin ||
                (auth.user?.id != null && auth.user!.id == warga.userId);
            final avatarFilename =
                data.userRecord?.getStringValue('avatar') ?? '';
            final avatarUrl = avatarFilename.isNotEmpty
                ? getFileUrl(data.userRecord!, avatarFilename)
                : null;
            final fotoWargaUrl = (warga.fotoWarga ?? '').isNotEmpty
                ? getFileUrl(data.wargaRecord, warga.fotoWarga!)
                : null;
            final fotoKtpUrl = (warga.fotoKtp ?? '').isNotEmpty
                ? getFileUrl(data.wargaRecord, warga.fotoKtp!)
                : null;

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildOverviewCard(
                    warga: warga,
                    avatarUrl: avatarUrl,
                    canEdit: canEdit,
                    onEdit: canEdit ? _openEdit : null,
                  ),
                  const SizedBox(height: 12),
                  _buildSection(
                    icon: Icons.badge_rounded,
                    title: 'Identitas',
                    child: Column(
                      children: [
                        _InfoRow(
                          label: 'NIK',
                          value: Formatters.formatNik(warga.nik),
                        ),
                        _InfoRow(
                          label: 'Tempat/Tgl Lahir',
                          value:
                              '${warga.tempatLahir.isEmpty ? "-" : warga.tempatLahir}, '
                              '${warga.tanggalLahir != null ? Formatters.tanggalLengkap(warga.tanggalLahir!) : "-"}',
                        ),
                        _InfoRow(
                          label: 'Jenis Kelamin',
                          value: warga.jenisKelamin,
                        ),
                        _InfoRow(label: 'Agama', value: warga.agama),
                        _InfoRow(
                          label: 'Status',
                          value: warga.statusPernikahan,
                        ),
                        _InfoRow(
                          label: 'Pendidikan',
                          value: warga.pendidikan.isEmpty
                              ? '-'
                              : warga.pendidikan,
                        ),
                        _InfoRow(
                          label: 'Pekerjaan',
                          value: warga.pekerjaan.isEmpty
                              ? '-'
                              : warga.pekerjaan,
                        ),
                        _InfoRow(
                          label: 'Gol. Darah',
                          value: warga.golonganDarah.isEmpty
                              ? '-'
                              : warga.golonganDarah,
                          isLast: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildSection(
                    icon: Icons.home_rounded,
                    title: 'Alamat & Kontak',
                    child: Column(
                      children: [
                        _InfoRow(label: 'Alamat', value: warga.alamat),
                        _InfoRow(
                          label: 'RT/RW',
                          value: 'RT ${warga.rt} / RW ${warga.rw}',
                        ),
                        _InfoRow(
                          label: 'No. HP',
                          value: warga.noHp.isEmpty
                              ? '-'
                              : Formatters.formatNoHp(warga.noHp),
                        ),
                        _InfoRow(
                          label: 'Email',
                          value: (warga.email ?? '').isEmpty
                              ? '-'
                              : warga.email!,
                          isLast: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildSection(
                    icon: Icons.photo_library_rounded,
                    title: 'Dokumen & Foto',
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _PhotoCard(
                                title: 'Avatar',
                                subtitle: avatarUrl == null
                                    ? 'Belum ada'
                                    : 'Dari akun user',
                                imageUrl: avatarUrl,
                                placeholderIcon: Icons.account_circle_rounded,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _PhotoCard(
                                title: 'Foto Warga',
                                subtitle: fotoWargaUrl == null
                                    ? 'Belum ada'
                                    : 'Dokumen',
                                imageUrl: fotoWargaUrl,
                                placeholderIcon: Icons.person_rounded,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _PhotoCard(
                          title: 'Foto KTP',
                          subtitle: fotoKtpUrl == null
                              ? 'Belum ada foto KTP'
                              : 'Dokumen identitas',
                          imageUrl: fotoKtpUrl,
                          placeholderIcon: Icons.badge_outlined,
                          wide: true,
                        ),
                      ],
                    ),
                  ),
                  if (canEdit) ...[
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: _openEdit,
                      icon: const Icon(Icons.edit_rounded),
                      label: const Text('Edit Data Warga'),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildOverviewCard({
    required WargaModel warga,
    required String? avatarUrl,
    required bool canEdit,
    required VoidCallback? onEdit,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.95),
            AppTheme.primaryLight.withValues(alpha: 0.90),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AvatarCircle(
            size: 62,
            imageUrl: avatarUrl,
            fallbackText: Formatters.inisial(warga.namaLengkap),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Chips row
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _headerChip(
                      icon: warga.jenisKelamin == 'Perempuan'
                          ? Icons.female_rounded
                          : Icons.male_rounded,
                      text: warga.jenisKelamin,
                    ),
                    _headerChip(
                      icon: Icons.home_work_rounded,
                      text: 'RT ${warga.rt}/${warga.rw}',
                    ),
                    if (warga.golonganDarah.isNotEmpty)
                      _headerChip(
                        icon: Icons.water_drop_rounded,
                        text: warga.golonganDarah,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            warga.namaLengkap,
                            style: AppTheme.heading3.copyWith(
                              color: Colors.white,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            Formatters.formatNik(warga.nik),
                            style: AppTheme.caption.copyWith(
                              color: Colors.white.withValues(alpha: 0.85),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (canEdit)
                      IconButton(
                        onPressed: onEdit,
                        tooltip: 'Edit warga',
                        icon: const Icon(Icons.edit_rounded, size: 18),
                        style: IconButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.white.withValues(alpha: 0.16),
                          padding: const EdgeInsets.all(8),
                          minimumSize: const Size(36, 36),
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

  Widget _buildSection({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 16, color: AppTheme.primaryColor),
              ),
              const SizedBox(width: 8),
              Text(title, style: AppTheme.heading3.copyWith(fontSize: 15)),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _headerChip({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            text,
            style: AppTheme.caption.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;

  const _InfoRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: AppTheme.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.textTertiary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: AppTheme.bodyMedium.copyWith(
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? imageUrl;
  final IconData placeholderIcon;
  final bool wide;

  const _PhotoCard({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.placeholderIcon,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.extraLightGray,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTheme.caption.copyWith(
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 1),
          Text(subtitle, style: AppTheme.caption.copyWith(fontSize: 10)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: AspectRatio(
              aspectRatio: wide ? 16 / 9 : 1,
              child: imageUrl == null
                  ? Container(
                      color: AppTheme.backgroundColor,
                      child: Icon(
                        placeholderIcon,
                        size: 32,
                        color: AppTheme.textSecondary.withValues(alpha: 0.4),
                      ),
                    )
                  : Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: AppTheme.backgroundColor,
                        child: Icon(
                          placeholderIcon,
                          size: 32,
                          color: AppTheme.textSecondary.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  final double size;
  final String? imageUrl;
  final String fallbackText;

  const _AvatarCircle({
    required this.size,
    required this.imageUrl,
    required this.fallbackText,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = (imageUrl ?? '').isNotEmpty;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.35),
          width: 2,
        ),
      ),
      child: ClipOval(
        child: hasImage
            ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _fallback(),
              )
            : _fallback(),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      color: Colors.white.withValues(alpha: 0.12),
      alignment: Alignment.center,
      child: Text(
        fallbackText,
        style: AppTheme.heading3.copyWith(color: Colors.white),
      ),
    );
  }
}

class _WargaDetailSkeleton extends StatelessWidget {
  const _WargaDetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Overview card skeleton
          const AppSkeleton(height: 180, borderRadius: 16),
          const SizedBox(height: 12),
          // Identitas section
          AppSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    AppSkeleton(width: 28, height: 28, borderRadius: 8),
                    SizedBox(width: 10),
                    AppSkeleton(width: 80, height: 18),
                  ],
                ),
                const SizedBox(height: 14),
                ...List.generate(
                  6,
                  (_) => const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Expanded(flex: 2, child: AppSkeleton(height: 14)),
                        SizedBox(width: 12),
                        Expanded(flex: 3, child: AppSkeleton(height: 14)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Alamat section
          AppSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    AppSkeleton(width: 28, height: 28, borderRadius: 8),
                    SizedBox(width: 10),
                    AppSkeleton(width: 100, height: 18),
                  ],
                ),
                const SizedBox(height: 14),
                ...List.generate(
                  4,
                  (_) => const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Expanded(flex: 2, child: AppSkeleton(height: 14)),
                        SizedBox(width: 12),
                        Expanded(flex: 3, child: AppSkeleton(height: 14)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

