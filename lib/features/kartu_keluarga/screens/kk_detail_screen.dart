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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Detail Kartu Keluarga'),
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
              right: -36,
              child: _blob(const Color(0x331565C0), 180),
            ),
            Positioned(
              top: 150,
              left: -60,
              child: _blob(const Color(0x3326A69A), 150),
            ),
            FutureBuilder<_KkDetailData>(
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
                final kk = data.kk;
                final kkOwnerId = data.kkRecord.getStringValue('user_id');
                final canManage =
                    isAdmin ||
                    (auth.user?.id != null && auth.user!.id == kkOwnerId);

                return SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHero(kk, data.anggotaRecords.length),
                        const SizedBox(height: 16),
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
                                label: 'Desa/Kelurahan',
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
                                label: 'Kabupaten/Kota',
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
                        const SizedBox(height: 14),
                        _buildSection(
                          icon: Icons.preview_rounded,
                          title: 'Preview File KK',
                          child: _buildScanPreview(
                            kkRecord: data.kkRecord,
                            kk: kk,
                          ),
                        ),
                        const SizedBox(height: 14),
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
                                        gradient: AppTheme.primaryGradient,
                                        onTap: () => _refreshAfter(
                                          context.push(
                                            '${Routes.kkForm}?id=${kk.id}',
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _actionButton(
                                        label: 'Tambah Anggota',
                                        icon: Icons.person_add_alt_1_rounded,
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF1CA39B),
                                            Color(0xFF45C0B7),
                                          ],
                                        ),
                                        onTap: () => _refreshAfter(
                                          context.push(
                                            '${Routes.wargaForm}?noKk=${kk.id}',
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: _deleteKk,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.errorColor,
                                      side: BorderSide(
                                        color: AppTheme.errorColor.withValues(
                                          alpha: 0.45,
                                        ),
                                      ),
                                      backgroundColor: Colors.white.withValues(
                                        alpha: 0.45,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                    ),
                                    label: const Text('Hapus KK'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                        _buildSection(
                          icon: Icons.groups_rounded,
                          title: 'Anggota Keluarga',
                          trailing: _countChip(data.anggotaRecords.length),
                          child: data.anggotaRecords.isEmpty
                              ? Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(22),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.9,
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.person_search_rounded,
                                        size: 40,
                                        color: AppTheme.textSecondary
                                            .withValues(alpha: 0.4),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Belum ada anggota keluarga',
                                        style: AppTheme.bodyMedium,
                                      ),
                                    ],
                                  ),
                                )
                              : Column(
                                  children: List.generate(
                                    data.anggotaRecords.length,
                                    (index) => Padding(
                                      padding: EdgeInsets.only(
                                        bottom:
                                            index ==
                                                data.anggotaRecords.length - 1
                                            ? 0
                                            : 12,
                                      ),
                                      child: _buildMemberCard(
                                        anggotaRecord:
                                            data.anggotaRecords[index],
                                        index: index,
                                        canManage: canManage,
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(KartuKeluargaModel kk, int totalAnggota) {
    return AppTheme.glassContainer(
      opacity: 0.78,
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryColor.withValues(alpha: 0.95),
              AppTheme.primaryLight.withValues(alpha: 0.92),
              AppTheme.secondaryColor.withValues(alpha: 0.9),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.credit_card_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kartu Keluarga',
                        style: AppTheme.caption.copyWith(
                          color: Colors.white.withValues(alpha: 0.82),
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        Formatters.formatNoKk(kk.noKk),
                        style: AppTheme.heading2.copyWith(
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _heroChip(
                  icon: Icons.people_alt_rounded,
                  text: '$totalAnggota anggota',
                ),
                _heroChip(
                  icon: Icons.home_rounded,
                  text: 'RT ${kk.rt}/${kk.rw}',
                ),
                if ((kk.kecamatan ?? '').isNotEmpty)
                  _heroChip(
                    icon: Icons.location_city_rounded,
                    text: kk.kecamatan!,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              kk.alamat,
              style: AppTheme.bodyMedium.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
                height: 1.35,
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
    Widget? trailing,
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
              Expanded(child: Text(title, style: AppTheme.heading3)),
              if (trailing case final Widget trailingWidget) trailingWidget,
            ],
          ),
          const SizedBox(height: 14),
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
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.68),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
        ),
        child: Column(
          children: [
            Icon(
              Icons.image_not_supported_outlined,
              size: 42,
              color: AppTheme.textSecondary.withValues(alpha: 0.42),
            ),
            const SizedBox(height: 10),
            Text('Belum ada file scan KK', style: AppTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(
              'Unggah file KK di form edit agar preview dapat ditampilkan di sini.',
              style: AppTheme.bodySmall,
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
          borderRadius: BorderRadius.circular(18),
          child: AspectRatio(
            aspectRatio: 16 / 10,
            child: isPdf
                ? Container(
                    color: Colors.white.withValues(alpha: 0.74),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.picture_as_pdf_rounded,
                          size: 56,
                          color: AppTheme.errorColor,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Preview langsung untuk PDF belum tersedia.',
                          style: AppTheme.bodyMedium.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Buka file untuk melihat dokumen lengkap.',
                          style: AppTheme.bodySmall,
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
                          color: Colors.white.withValues(alpha: 0.74),
                          child: const Center(
                            child: Text('Preview file tidak tersedia'),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ElevatedButton.icon(
              onPressed: () => _openFileUrl(fileUrl),
              icon: const Icon(Icons.open_in_new_rounded),
              label: Text(isPdf ? 'Buka PDF KK' : 'Buka File KK'),
            ),
            if (!isPdf)
              OutlinedButton.icon(
                onPressed: () => _showImagePreview(fileUrl),
                icon: const Icon(Icons.zoom_in_rounded),
                label: const Text('Perbesar Preview'),
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
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.74),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.95)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: index == 0
                      ? AppTheme.primaryGradient
                      : LinearGradient(
                          colors: [
                            AppTheme.secondaryColor.withValues(alpha: 0.9),
                            AppTheme.primaryLight.withValues(alpha: 0.85),
                          ],
                        ),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${index + 1}',
                  style: AppTheme.bodyLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
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
                                warga?.namaLengkap ??
                                    'Data warga belum terhubung',
                                style: AppTheme.bodyLarge.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _softChip(
                                    icon: Icons.family_restroom_rounded,
                                    label: hubungan.isEmpty ? '-' : hubungan,
                                    foregroundColor: AppTheme.secondaryColor,
                                    backgroundColor: AppTheme.secondaryColor
                                        .withValues(alpha: 0.12),
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
                                            .withValues(alpha: 0.12),
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
                            icon: const Icon(Icons.edit_rounded),
                            style: IconButton.styleFrom(
                              foregroundColor: AppTheme.primaryColor,
                              backgroundColor: AppTheme.primaryColor.withValues(
                                alpha: 0.08,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (warga != null) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _dataChip(
                            icon: Icons.badge_outlined,
                            text: Formatters.formatNik(warga.nik),
                          ),
                          if (warga.jenisKelamin.isNotEmpty)
                            _dataChip(
                              icon: warga.jenisKelamin == 'Perempuan'
                                  ? Icons.female_rounded
                                  : Icons.male_rounded,
                              text: warga.jenisKelamin,
                            ),
                          if (warga.tempatLahir.isNotEmpty)
                            _dataChip(
                              icon: Icons.location_city_rounded,
                              text: warga.tempatLahir,
                            ),
                          if (warga.tanggalLahir != null)
                            _dataChip(
                              icon: Icons.cake_rounded,
                              text: Formatters.tanggalPendek(
                                warga.tanggalLahir!,
                              ),
                            ),
                          if (warga.golonganDarah.isNotEmpty)
                            _dataChip(
                              icon: Icons.water_drop_rounded,
                              text: warga.golonganDarah,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (warga != null) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.textSecondary.withValues(alpha: 0.55),
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
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          ),
        ),
        icon: Icon(icon, size: 18),
        label: Text(label, textAlign: TextAlign.center),
      ),
    );
  }

  Widget _heroChip({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
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

  Widget _countChip(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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

  Widget _dataChip({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FB),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.95)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.textSecondary),
          const SizedBox(width: 6),
          Text(
            text,
            style: AppTheme.caption.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foregroundColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTheme.caption.copyWith(
              color: foregroundColor,
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
        border: Border.all(color: Colors.white.withValues(alpha: 0.92)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(value, style: AppTheme.bodyMedium)),
        ],
      ),
    );
  }
}
