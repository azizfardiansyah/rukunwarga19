import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/pocketbase_service.dart';
import '../../../core/utils/area_access.dart';
import '../../../core/utils/error_classifier.dart';
import '../../../core/utils/formatters.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/models/dokumen_model.dart';
import '../../../shared/models/warga_model.dart';
import '../../../shared/widgets/app_surface.dart';
import '../../../shared/widgets/floating_action_pill.dart';

class DokumenListData {
  const DokumenListData({
    required this.documents,
    required this.wargaById,
    required this.scopedWargaIds,
    required this.myWargaId,
  });

  final List<DokumenModel> documents;
  final Map<String, WargaModel> wargaById;
  final Set<String> scopedWargaIds;
  final String? myWargaId;
}

enum _DokumenSection { mine, verification }

final dokumenListProvider = FutureProvider.autoDispose<DokumenListData>((
  ref,
) async {
  final auth = ref.watch(authProvider);
  if (auth.user == null) {
    return const DokumenListData(
      documents: [],
      wargaById: {},
      scopedWargaIds: {},
      myWargaId: null,
    );
  }

  final access = await resolveAreaAccessContext(auth);
  final dokumenRecords = await pb
      .collection(AppConstants.colDokumen)
      .getFullList(sort: '-created');
  final scopedWargaRecords = await pb
      .collection(AppConstants.colWarga)
      .getFullList(
        sort: 'nama_lengkap',
        filter: buildWargaScopeFilter(auth, context: access),
      );

  return DokumenListData(
    documents: dokumenRecords.map(DokumenModel.fromRecord).toList(),
    wargaById: {
      for (final record in scopedWargaRecords)
        record.id: WargaModel.fromRecord(record),
    },
    scopedWargaIds: scopedWargaRecords.map((record) => record.id).toSet(),
    myWargaId: access.wargaId,
  );
});

class DokumenListScreen extends ConsumerStatefulWidget {
  const DokumenListScreen({super.key});

  @override
  ConsumerState<DokumenListScreen> createState() => _DokumenListScreenState();
}

class _DokumenListScreenState extends ConsumerState<DokumenListScreen> {
  _DokumenSection _section = _DokumenSection.mine;
  String _verificationStatusFilter = AppConstants.statusPending;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final dokumenAsync = ref.watch(dokumenListProvider);
    final canVerify =
        AppConstants.normalizeRole(auth.role) == AppConstants.roleAdminRt ||
        AppConstants.hasRwWideAccess(auth.role) ||
        auth.isSysadmin;
    final activeSection = canVerify ? _section : _DokumenSection.mine;

    return Scaffold(
      appBar: AppBar(title: const Text('Dokumen')),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: activeSection == _DokumenSection.mine
          ? FloatingActionPill(
              onTap: () async {
                await context.push(Routes.dokumenUpload);
                if (mounted) {
                  ref.invalidate(dokumenListProvider);
                }
              },
              icon: Icons.upload_file_rounded,
              label: 'Upload Dokumen',
              gradientColors: const [
                AppTheme.primaryDark,
                AppTheme.primaryColor,
              ],
            )
          : null,
      body: AppPageBackground(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          children: [
            _buildHero(canVerify, activeSection),
            const SizedBox(height: 8),
            _buildSectionSelector(canVerify, activeSection),
            const SizedBox(height: 10),
            Expanded(
              child: dokumenAsync.when(
                data: (data) => RefreshIndicator(
                  onRefresh: _refresh,
                  child: activeSection == _DokumenSection.mine
                      ? _buildMyDocuments(data)
                      : _buildVerificationDocuments(data),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: AppSurfaceCard(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          ErrorClassifier.classify(error).message,
                          style: AppTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        FilledButton(
                          onPressed: () => ref.invalidate(dokumenListProvider),
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(bool canVerify, _DokumenSection activeSection) {
    final title = activeSection == _DokumenSection.mine
        ? 'Arsip dan unggah dokumen pribadi'
        : 'Antrean verifikasi dokumen warga';
    final subtitle = activeSection == _DokumenSection.mine
        ? 'Pantau status dokumen Anda, lalu unggah dokumen baru jika dibutuhkan.'
        : 'Review dokumen warga sesuai wilayah akses Anda dan tindak lanjuti statusnya.';

    return AppHeroPanel(
      eyebrow: activeSection == _DokumenSection.mine
          ? 'Dokumen Saya'
          : 'Verifikasi Dokumen',
      icon: activeSection == _DokumenSection.mine
          ? Icons.folder_outlined
          : Icons.fact_check_outlined,
      title: title,
      subtitle: subtitle,
      chips: canVerify && activeSection == _DokumenSection.verification
          ? [
              _heroChip(Icons.pending_actions_rounded, 'Pending'),
              _heroChip(Icons.edit_note_rounded, 'Perlu Revisi'),
              _heroChip(Icons.verified_rounded, 'Terverifikasi'),
              _heroChip(Icons.cancel_outlined, 'Ditolak'),
            ]
          : const [],
    );
  }

  Widget _buildSectionSelector(bool canVerify, _DokumenSection activeSection) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          Expanded(
            child: _SegmentButton(
              label: 'Dokumen Saya',
              selected: activeSection == _DokumenSection.mine,
              onTap: () => setState(() => _section = _DokumenSection.mine),
            ),
          ),
          if (canVerify) ...[
            const SizedBox(width: 8),
            Expanded(
              child: _SegmentButton(
                label: 'Verifikasi Dokumen',
                selected: activeSection == _DokumenSection.verification,
                onTap: () =>
                    setState(() => _section = _DokumenSection.verification),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMyDocuments(DokumenListData data) {
    final myWargaId = data.myWargaId ?? '';
    if (myWargaId.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 80),
          _EmptyStateCard(
            icon: Icons.person_search_rounded,
            title: 'Data warga belum terhubung',
            subtitle:
                'Hubungkan akun Anda ke data warga terlebih dahulu agar dokumen dapat dikelola dari menu ini.',
          ),
        ],
      );
    }

    final docs = data.documents.where((doc) => doc.warga == myWargaId).toList()
      ..sort(
        (a, b) => (b.created ?? DateTime(1900)).compareTo(
          a.created ?? DateTime(1900),
        ),
      );

    if (docs.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 80),
          _EmptyStateCard(
            icon: Icons.upload_file_rounded,
            title: 'Belum ada dokumen pribadi',
            subtitle:
                'Gunakan tombol upload untuk mengunggah dokumen identitas atau dokumen pendukung lainnya.',
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: docs.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _DokumenCard(
        document: docs[index],
        warga: data.wargaById[docs[index].warga],
        showActions: false,
        onOpenFile: () => _openDocumentFile(docs[index]),
      ),
    );
  }

  Widget _buildVerificationDocuments(DokumenListData data) {
    final docs =
        data.documents
            .where((doc) => data.scopedWargaIds.contains(doc.warga))
            .where((doc) {
              if (_verificationStatusFilter == 'all') {
                return true;
              }
              return doc.statusVerifikasi.toLowerCase() ==
                  _verificationStatusFilter.toLowerCase();
            })
            .toList()
          ..sort(
            (a, b) => (b.created ?? DateTime(1900)).compareTo(
              a.created ?? DateTime(1900),
            ),
          );

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _buildVerificationFilterBar(),
        const SizedBox(height: 12),
        if (docs.isEmpty)
          const _EmptyStateCard(
            icon: Icons.fact_check_outlined,
            title: 'Belum ada dokumen pada filter ini',
            subtitle:
                'Antrean verifikasi akan muncul di sini sesuai wilayah akses dan status dokumen.',
          )
        else
          ...docs.map(
            (doc) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _DokumenCard(
                document: doc,
                warga: data.wargaById[doc.warga],
                showActions: true,
                onOpenFile: () => _openDocumentFile(doc),
                onVerify: doc.isPending || doc.isNeedRevision
                    ? () => _updateVerificationStatus(
                        document: doc,
                        status: AppConstants.statusVerified,
                      )
                    : null,
                onNeedRevision: doc.isPending
                    ? () => _requestReviewNoteAndSubmit(
                        document: doc,
                        status: AppConstants.statusNeedRevision,
                        title: 'Minta Revisi Dokumen',
                        submitLabel: 'Kirim Revisi',
                        noteHint:
                            'Jelaskan bagian yang perlu diperbaiki agar warga dapat mengunggah ulang dengan benar.',
                      )
                    : null,
                onReject: doc.isPending || doc.isNeedRevision
                    ? () => _requestReviewNoteAndSubmit(
                        document: doc,
                        status: AppConstants.statusRejected,
                        title: 'Tolak Dokumen',
                        submitLabel: 'Tolak',
                        noteHint:
                            'Jelaskan alasan penolakan agar warga dapat memperbaiki dokumen.',
                      )
                    : null,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildVerificationFilterBar() {
    final filters = <({String value, String label})>[
      (value: AppConstants.statusPending, label: 'Pending'),
      (value: AppConstants.statusNeedRevision, label: 'Perlu Revisi'),
      (value: AppConstants.statusVerified, label: 'Terverifikasi'),
      (value: AppConstants.statusRejected, label: 'Ditolak'),
      (value: 'all', label: 'Semua'),
    ];

    return AppSurfaceCard(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: filters.map((filter) {
          final selected = _verificationStatusFilter == filter.value;
          return ChoiceChip(
            label: Text(filter.label),
            selected: selected,
            onSelected: (_) {
              setState(() => _verificationStatusFilter = filter.value);
            },
          );
        }).toList(),
      ),
    );
  }

  Future<void> _requestReviewNoteAndSubmit({
    required DokumenModel document,
    required String status,
    required String title,
    required String submitLabel,
    required String noteHint,
  }) async {
    final noteController = TextEditingController(text: document.catatan ?? '');
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(noteHint, style: AppTheme.bodySmall),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Catatan verifikasi',
                    hintText: 'Tulis catatan singkat',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(submitLabel),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) {
      return;
    }

    await _updateVerificationStatus(
      document: document,
      status: status,
      note: noteController.text.trim(),
    );
  }

  Future<void> _updateVerificationStatus({
    required DokumenModel document,
    required String status,
    String? note,
  }) async {
    final auth = ref.read(authProvider);
    if (auth.user == null) {
      return;
    }

    try {
      await pb
          .collection(AppConstants.colDokumen)
          .update(
            document.id,
            body: {
              'status_verifikasi': status,
              'catatan': note ?? document.catatan ?? '',
              'diverifikasi_oleh': auth.user!.id,
              'tanggal_verifikasi': DateTime.now().toIso8601String(),
            },
          );

      if (!mounted) {
        return;
      }

      ErrorClassifier.showSuccessSnackBar(
        context,
        status == AppConstants.statusVerified
            ? 'Dokumen berhasil diverifikasi'
            : status == AppConstants.statusNeedRevision
            ? 'Dokumen ditandai perlu revisi'
            : 'Status dokumen berhasil diperbarui',
      );
      ref.invalidate(dokumenListProvider);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ErrorClassifier.showErrorSnackBar(context, error);
    }
  }

  Future<void> _openDocumentFile(DokumenModel document) async {
    final record = await pb
        .collection(AppConstants.colDokumen)
        .getOne(document.id);
    final url = getFileUrl(record, document.file);
    final launched = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.platformDefault,
    );

    if (!launched && mounted) {
      ErrorClassifier.showErrorSnackBar(
        context,
        Exception('File dokumen tidak dapat dibuka.'),
      );
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(dokumenListProvider);
    await ref.read(dokumenListProvider.future);
  }

  Widget _heroChip(IconData icon, String label) {
    return AppHeroBadge(
      label: label,
      foregroundColor: Colors.white,
      backgroundColor: Colors.white.withValues(alpha: 0.16),
      icon: icon,
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          gradient: selected ? AppTheme.primaryGradient : null,
          color: selected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTheme.bodySmall.copyWith(
              color: selected ? Colors.white : AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      child: Column(
        children: [
          Icon(
            icon,
            size: 54,
            color: AppTheme.textSecondary.withValues(alpha: 0.42),
          ),
          const SizedBox(height: 14),
          Text(title, style: AppTheme.heading3, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: AppTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _DokumenCard extends StatelessWidget {
  const _DokumenCard({
    required this.document,
    required this.onOpenFile,
    this.warga,
    this.showActions = false,
    this.onVerify,
    this.onNeedRevision,
    this.onReject,
  });

  final DokumenModel document;
  final WargaModel? warga;
  final bool showActions;
  final VoidCallback onOpenFile;
  final VoidCallback? onVerify;
  final VoidCallback? onNeedRevision;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    final statusColor = AppTheme.statusColor(document.statusVerifikasi);
    final wargaName = warga?.namaLengkap ?? 'Warga tidak ditemukan';
    final fileName = document.file;

    return AppSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.description_rounded, color: statusColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      document.jenis,
                      style: AppTheme.bodyLarge.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      showActions
                          ? '$wargaName - RT ${warga?.rt ?? '-'}/RW ${warga?.rw ?? '-'}'
                          : 'Status verifikasi dokumen pribadi',
                      style: AppTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _statusLabel(document.statusVerifikasi),
                  style: AppTheme.caption.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metaChip(
                Icons.schedule_rounded,
                document.created != null
                    ? Formatters.tanggalWaktu(document.created!)
                    : 'Tanggal upload tidak tersedia',
              ),
              _metaChip(Icons.attach_file_rounded, fileName),
            ],
          ),
          if ((document.catatan ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.62),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                document.catatan!.trim(),
                style: AppTheme.bodySmall.copyWith(color: AppTheme.textPrimary),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onOpenFile,
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Buka File'),
                ),
              ),
            ],
          ),
          if (showActions &&
              (onVerify != null ||
                  onNeedRevision != null ||
                  onReject != null)) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (onVerify != null)
                  SizedBox(
                    width: 160,
                    child: ElevatedButton.icon(
                      onPressed: onVerify,
                      icon: const Icon(Icons.verified_rounded),
                      label: const Text('Verifikasi'),
                    ),
                  ),
                if (onNeedRevision != null)
                  SizedBox(
                    width: 160,
                    child: OutlinedButton.icon(
                      onPressed: onNeedRevision,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.accentColor,
                        side: const BorderSide(color: AppTheme.accentColor),
                      ),
                      icon: const Icon(Icons.edit_note_rounded),
                      label: const Text('Perlu Revisi'),
                    ),
                  ),
                if (onReject != null)
                  SizedBox(
                    width: 160,
                    child: OutlinedButton.icon(
                      onPressed: onReject,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.errorColor,
                        side: const BorderSide(color: AppTheme.errorColor),
                      ),
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Tolak'),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _metaChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppTheme.textSecondary),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              style: AppTheme.caption.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'verified':
        return 'Terverifikasi';
      case 'need_revision':
        return 'Perlu Revisi';
      case 'rejected':
        return 'Ditolak';
      case 'pending':
      default:
        return 'Pending';
    }
  }
}
