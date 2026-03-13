// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:url_launcher/url_launcher.dart';

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
import '../../../shared/widgets/app_surface.dart';

typedef _KkDetailData = ({
  RecordModel kkRecord,
  KartuKeluargaModel kk,
  List<RecordModel> anggotaRecords,
});

class KkDetailScreen extends ConsumerStatefulWidget {
  final String kkId;
  const KkDetailScreen({super.key, required this.kkId});

  @override
  ConsumerState<KkDetailScreen> createState() => _KkDetailScreenState();
}

class _KkDetailScreenState extends ConsumerState<KkDetailScreen> {
  Future<_KkDetailData> _loadDetail() async {
    final auth = ref.read(authProvider);
    final access = await resolveAreaAccessContext(auth);
    final kkRecord = await pb
        .collection(AppConstants.colKartuKeluarga)
        .getOne(widget.kkId);
    final kk = KartuKeluargaModel.fromRecord(kkRecord);
    final ownerUserId = kkRecord.getStringValue('user_id');

    if (!canAccessKkRecord(
      auth,
      kk,
      context: access,
      ownerUserId: ownerUserId,
    )) {
      throw Exception('Anda tidak memiliki akses ke detail KK ini.');
    }

    final anggotaResult = await pb
        .collection(AppConstants.colAnggotaKk)
        .getList(
          page: 1,
          perPage: 100,
          filter: 'no_kk = "${widget.kkId}"',
          sort: 'created',
          expand: 'warga',
        );

    return (kkRecord: kkRecord, kk: kk, anggotaRecords: anggotaResult.items);
  }

  Future<void> _refreshAfter(Future<Object?> navigation) async {
    await navigation;
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _deleteKk() async {
    final shouldDelete =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Hapus Kartu Keluarga'),
              content: const Text(
                'Data KK dan relasi anggota keluarga akan dihapus. Lanjutkan?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Hapus'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldDelete) return;

    try {
      await pb.collection(AppConstants.colKartuKeluarga).delete(widget.kkId);
      if (!mounted) return;
      ErrorClassifier.showSuccessSnackBar(context, 'Data KK berhasil dihapus');
      context.go(Routes.kartuKeluarga);
    } catch (e) {
      if (!mounted) return;
      ErrorClassifier.showErrorSnackBar(context, e);
    }
  }

  Future<void> _openFileUrl(String url) async {
    final launched = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.platformDefault,
    );
    if (!launched && mounted) {
      ErrorClassifier.showErrorSnackBar(
        context,
        Exception('File KK tidak dapat dibuka.'),
      );
    }
  }

  Future<void> _showImagePreview(String imageUrl) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const SizedBox(
                        height: 220,
                        child: Center(
                          child: Text('Preview file tidak tersedia'),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton.filledTonal(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final isAdmin = auth.isAdmin;

    return Scaffold(
      appBar: AppBar(title: const Text('Detail KK')),
      body: AppPageBackground(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
        child: FutureBuilder<_KkDetailData>(
          future: _loadDetail(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
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
            final kk = data.kk;
            final kkOwnerId = data.kkRecord.getStringValue('user_id');
            final canManage =
                isAdmin ||
                (auth.user?.id != null && auth.user!.id == kkOwnerId);

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHero(kk, data.anggotaRecords.length),
                  const SizedBox(height: 12),
                  _buildSection(
                    icon: Icons.location_on_rounded,
                    title: 'Alamat KK',
                    child: Column(
                      children: [
                        _InfoRow(label: 'Alamat', value: kk.alamat),
                        _InfoRow(
                          label: 'RT / RW',
                          value: 'RT ${kk.rt} / RW ${kk.rw}',
                        ),
                        _InfoRow(
                          label: 'Desa/Kel.',
                          value: (kk.desaKelurahan ?? '').isEmpty
                              ? '-'
                              : kk.desaKelurahan!,
                        ),
                        _InfoRow(
                          label: 'Kecamatan',
                          value: (kk.kecamatan ?? '').isEmpty
                              ? '-'
                              : kk.kecamatan!,
                        ),
                        _InfoRow(
                          label: 'Kab./Kota',
                          value: (kk.kabupatenKota ?? '').isEmpty
                              ? '-'
                              : kk.kabupatenKota!,
                        ),
                        _InfoRow(
                          label: 'Provinsi',
                          value: (kk.provinsi ?? '').isEmpty
                              ? '-'
                              : kk.provinsi!,
                          isLast: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildSection(
                    icon: Icons.preview_rounded,
                    title: 'File KK',
                    child: _buildScanPreview(kkRecord: data.kkRecord, kk: kk),
                  ),
                  const SizedBox(height: 10),
                  if (canManage) ...[
                    _buildSection(
                      icon: Icons.auto_awesome_rounded,
                      title: 'Aksi Cepat',
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _actionButton(
                                  label: 'Edit KK',
                                  icon: Icons.edit_rounded,
                                  onTap: () => _refreshAfter(
                                    context.push(
                                      '${Routes.kkForm}?id=${kk.id}',
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _actionButton(
                                  label: 'Tambah Anggota',
                                  icon: Icons.person_add_alt_1_rounded,
                                  onTap: () => _refreshAfter(
                                    context.push(
                                      '${Routes.wargaForm}?noKk=${kk.id}',
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _deleteKk,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.errorColor,
                                side: BorderSide(
                                  color: AppTheme.errorColor.withValues(
                                    alpha: 0.35,
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                              ),
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                              ),
                              label: const Text('Hapus KK'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  _buildSection(
                    icon: Icons.groups_rounded,
                    title: 'Anggota Keluarga',
                    trailing: _countChip(data.anggotaRecords.length),
                    child: data.anggotaRecords.isEmpty
                        ? AppEmptyState(
                            icon: Icons.person_search_rounded,
                            title: 'Belum ada anggota',
                            message: 'Tambahkan anggota dari menu aksi cepat.',
                          )
                        : Column(
                            children: List.generate(
                              data.anggotaRecords.length,
                              (index) => Padding(
                                padding: EdgeInsets.only(
                                  bottom:
                                      index == data.anggotaRecords.length - 1
                                      ? 0
                                      : 8,
                                ),
                                child: _buildMemberCard(
                                  anggotaRecord: data.anggotaRecords[index],
                                  index: index,
                                  canManage: canManage,
                                ),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHero(KartuKeluargaModel kk, int totalAnggota) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.credit_card_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kartu Keluarga',
                      style: AppTheme.caption.copyWith(
                        color: Colors.white.withValues(alpha: 0.8),
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      Formatters.formatNoKk(kk.noKk),
                      style: AppTheme.heading3.copyWith(
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _heroChip(
                icon: Icons.people_alt_rounded,
                text: '$totalAnggota anggota',
              ),
              _heroChip(icon: Icons.home_rounded, text: 'RT ${kk.rt}/${kk.rw}'),
              if ((kk.kecamatan ?? '').isNotEmpty)
                _heroChip(
                  icon: Icons.location_city_rounded,
                  text: kk.kecamatan!,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            kk.alamat,
            style: AppTheme.bodySmall.copyWith(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: 13,
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
    Widget? trailing,
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
              Expanded(
                child: Text(
                  title,
                  style: AppTheme.heading3.copyWith(fontSize: 15),
                ),
              ),
              if (trailing case final Widget trailingWidget) trailingWidget,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildScanPreview({
    required RecordModel kkRecord,
    required KartuKeluargaModel kk,
  }) {
    final fileName = kk.scanKk ?? '';
    if (fileName.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.extraLightGray,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.dividerColor.withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.image_not_supported_outlined,
              size: 36,
              color: AppTheme.textSecondary.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 8),
            Text(
              'Belum ada file scan KK',
              style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              'Unggah file KK di form edit.',
              style: AppTheme.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final fileUrl = getFileUrl(kkRecord, fileName);
    final isPdf = fileName.toLowerCase().endsWith('.pdf');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 16 / 10,
            child: isPdf
                ? Container(
                    color: AppTheme.extraLightGray,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.picture_as_pdf_rounded,
                          size: 42,
                          color: AppTheme.errorColor,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Preview PDF belum tersedia.',
                          style: AppTheme.bodySmall.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _showImagePreview(fileUrl),
                      child: Image.network(
                        fileUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          color: AppTheme.extraLightGray,
                          child: const Center(
                            child: Text('Preview file tidak tersedia'),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ElevatedButton.icon(
              onPressed: () => _openFileUrl(fileUrl),
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: Text(isPdf ? 'Buka PDF' : 'Buka File'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              ),
            ),
            if (!isPdf)
              OutlinedButton.icon(
                onPressed: () => _showImagePreview(fileUrl),
                icon: const Icon(Icons.zoom_in_rounded, size: 16),
                label: const Text('Perbesar'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildMemberCard({
    required RecordModel anggotaRecord,
    required int index,
    required bool canManage,
  }) {
    final hubungan = anggotaRecord.getStringValue('hubungan');
    final status = anggotaRecord.getStringValue('status');
    final expanded = anggotaRecord.expand['warga'];
    final wargaRecord = expanded != null && expanded.isNotEmpty
        ? expanded.first
        : null;
    final warga = wargaRecord != null
        ? WargaModel.fromRecord(wargaRecord)
        : null;
    final isActive = status.toLowerCase() == 'aktif';

    Future<void> openDetail() async {
      if (warga == null) return;
      await _refreshAfter(context.push('${Routes.warga}/${warga.id}'));
    }

    Future<void> openEdit() async {
      if (warga == null) return;
      await _refreshAfter(context.push('${Routes.wargaForm}?id=${warga.id}'));
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: warga == null ? null : openDetail,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.extraLightGray,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppTheme.dividerColor.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: index == 0
                      ? AppTheme.primaryGradient
                      : const LinearGradient(
                          colors: [AppTheme.lightGray, AppTheme.textTertiary],
                        ),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${index + 1}',
                  style: AppTheme.bodyMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
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
                                warga?.namaLengkap ?? 'Belum terhubung',
                                style: AppTheme.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  _softChip(
                                    icon: Icons.family_restroom_rounded,
                                    label: hubungan.isEmpty ? '-' : hubungan,
                                    foregroundColor: AppTheme.secondaryColor,
                                    backgroundColor: AppTheme.secondaryColor
                                        .withValues(alpha: 0.1),
                                  ),
                                  _softChip(
                                    icon: isActive
                                        ? Icons.verified_rounded
                                        : Icons.pending_outlined,
                                    label: status.isEmpty ? '-' : status,
                                    foregroundColor: isActive
                                        ? AppTheme.successColor
                                        : AppTheme.textSecondary,
                                    backgroundColor:
                                        (isActive
                                                ? AppTheme.successColor
                                                : AppTheme.textSecondary)
                                            .withValues(alpha: 0.1),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (canManage && warga != null)
                          IconButton(
                            onPressed: openEdit,
                            tooltip: 'Edit warga',
                            icon: const Icon(Icons.edit_rounded, size: 16),
                            style: IconButton.styleFrom(
                              foregroundColor: AppTheme.primaryColor,
                              backgroundColor: AppTheme.primaryColor.withValues(
                                alpha: 0.08,
                              ),
                              padding: const EdgeInsets.all(6),
                              minimumSize: const Size(32, 32),
                            ),
                          ),
                      ],
                    ),
                    if (warga != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        '${Formatters.formatNik(warga.nik)}  ·  ${warga.jenisKelamin}',
                        style: AppTheme.caption.copyWith(
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (warga != null) ...[
                const SizedBox(width: 2),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppTheme.textSecondary.withValues(alpha: 0.5),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return FilledButton.icon(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13),
      ),
    );
  }

  Widget _heroChip({required IconData icon, required String text}) {
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

  Widget _countChip(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count data',
        style: AppTheme.caption.copyWith(
          color: AppTheme.primaryColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _softChip({
    required IconData icon,
    required String label,
    required Color foregroundColor,
    required Color backgroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: foregroundColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTheme.caption.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w600,
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

