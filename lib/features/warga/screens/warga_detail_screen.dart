import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/pocketbase_service.dart';
import '../../../core/utils/error_classifier.dart';
import '../../../core/utils/formatters.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/models/warga_model.dart';

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
    final wargaRecord = await pb
        .collection(AppConstants.colWarga)
        .getOne(widget.wargaId);
    final warga = WargaModel.fromRecord(wargaRecord);

    if (!auth.isAdmin &&
        auth.user?.id != null &&
        warga.userId != null &&
        warga.userId != auth.user!.id) {
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Detail Warga'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFEAF3FF), Color(0xFFF7FBFF), Color(0xFFF5FFFC)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -70,
              right: -40,
              child: _blob(const Color(0x3326A69A), 180),
            ),
            Positioned(
              top: 120,
              left: -60,
              child: _blob(const Color(0x331565C0), 150),
            ),
            FutureBuilder<_WargaDetailData>(
              future: _loadDetail(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppTheme.paddingLarge),
                      child: AppTheme.glassContainer(
                        opacity: 0.78,
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

                return SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildOverviewCard(
                          warga: warga,
                          avatarUrl: avatarUrl,
                          canEdit: canEdit,
                          onEdit: canEdit ? _openEdit : null,
                        ),
                        const SizedBox(height: 16),
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
                                label: 'Status Pernikahan',
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
                                label: 'Golongan Darah',
                                value: warga.golonganDarah.isEmpty
                                    ? '-'
                                    : warga.golonganDarah,
                                isLast: true,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
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
                        const SizedBox(height: 14),
                        _buildSection(
                          icon: Icons.photo_library_rounded,
                          title: 'Dokumen & Foto',
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _PhotoCard(
                                      title: 'Avatar User',
                                      subtitle: avatarUrl == null
                                          ? 'Belum ada avatar'
                                          : 'Dari collection users',
                                      imageUrl: avatarUrl,
                                      placeholderIcon:
                                          Icons.account_circle_rounded,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _PhotoCard(
                                      title: 'Foto Warga',
                                      subtitle: fotoWargaUrl == null
                                          ? 'Belum ada foto warga'
                                          : 'Dokumen warga',
                                      imageUrl: fotoWargaUrl,
                                      placeholderIcon: Icons.person_rounded,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
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
                          const SizedBox(height: 18),
                          Container(
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusLarge,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryColor.withValues(
                                    alpha: 0.25,
                                  ),
                                  blurRadius: 18,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              onPressed: _openEdit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusLarge,
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.edit_rounded),
                              label: const Text('Edit Data Warga'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.small(
        onPressed: () => context.pop(),
        child: const Icon(Icons.arrow_back_rounded),
      ),
    );
  }

  Widget _buildOverviewCard({
    required WargaModel warga,
    required String? avatarUrl,
    required bool canEdit,
    required VoidCallback? onEdit,
  }) {
    return AppTheme.glassContainer(
      opacity: 0.78,
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryColor.withValues(alpha: 0.95),
              AppTheme.primaryLight.withValues(alpha: 0.92),
              AppTheme.secondaryColor.withValues(alpha: 0.88),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AvatarCircle(
              size: 84,
              imageUrl: avatarUrl,
              fallbackText: Formatters.inisial(warga.namaLengkap),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _headerChip(
                              icon: warga.jenisKelamin == 'Perempuan'
                                  ? Icons.female_rounded
                                  : Icons.male_rounded,
                              text: warga.jenisKelamin,
                            ),
                            if (warga.golonganDarah.isNotEmpty)
                              _headerChip(
                                icon: Icons.water_drop_rounded,
                                text: warga.golonganDarah,
                              ),
                            _headerChip(
                              icon: Icons.home_work_rounded,
                              text: 'RT ${warga.rt}/RW ${warga.rw}',
                            ),
                          ],
                        ),
                      ),
                      if (canEdit)
                        IconButton(
                          onPressed: onEdit,
                          tooltip: 'Edit warga',
                          icon: const Icon(Icons.edit_rounded),
                          style: IconButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.16,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    warga.namaLengkap,
                    style: AppTheme.heading2.copyWith(
                      color: Colors.white,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    Formatters.formatNik(warga.nik),
                    style: AppTheme.bodySmall.copyWith(
                      color: Colors.white.withValues(alpha: 0.88),
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    canEdit
                        ? 'Foto utama mengikuti avatar user bila tersedia.'
                        : 'Detail data warga dan dokumen identitas.',
                    style: AppTheme.caption.copyWith(
                      color: Colors.white.withValues(alpha: 0.82),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return AppTheme.glassContainer(
      opacity: 0.74,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 18, color: AppTheme.primaryColor),
              ),
              const SizedBox(width: 10),
              Text(title, style: AppTheme.heading3),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _headerChip({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            text,
            style: AppTheme.caption.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _blob(Color color, double size) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
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
    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: AppTheme.bodySmall.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.92)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(subtitle, style: AppTheme.caption),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(
              aspectRatio: wide ? 16 / 9 : 1,
              child: imageUrl == null
                  ? Container(
                      color: AppTheme.backgroundColor,
                      child: Icon(
                        placeholderIcon,
                        size: 42,
                        color: AppTheme.textSecondary.withValues(alpha: 0.5),
                      ),
                    )
                  : Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: AppTheme.backgroundColor,
                        child: Icon(
                          placeholderIcon,
                          size: 42,
                          color: AppTheme.textSecondary.withValues(alpha: 0.5),
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
          color: Colors.white.withValues(alpha: 0.4),
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
        style: AppTheme.heading2.copyWith(color: Colors.white),
      ),
    );
  }
}
