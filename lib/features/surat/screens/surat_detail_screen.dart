// ignore_for_file: use_build_context_synchronously

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/surat_pdf_service.dart';
import '../../../core/services/pocketbase_service.dart';
import '../../../core/services/surat_service.dart';
import '../../../core/utils/error_classifier.dart';
import '../../../core/utils/formatters.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../providers/surat_providers.dart';
import '../../../shared/models/surat_model.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../../../shared/widgets/app_surface.dart';
import 'surat_list_screen.dart';

final suratDetailProvider = FutureProvider.autoDispose
    .family<SuratDetailData, String>((ref, suratId) async {
      final auth = ref.watch(authProvider);
      ref.watch(suratRefreshTickProvider);
      return ref.watch(suratServiceProvider).getDetail(auth, suratId);
    });

class SuratDetailScreen extends ConsumerStatefulWidget {
  const SuratDetailScreen({super.key, required this.suratId});

  final String suratId;

  @override
  ConsumerState<SuratDetailScreen> createState() => _SuratDetailScreenState();
}

class _SuratDetailScreenState extends ConsumerState<SuratDetailScreen> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(suratDetailProvider(widget.suratId));
    final auth = ref.watch(authProvider);
    final role = AppConstants.normalizeRole(auth.role);

    return Scaffold(
      appBar: AppBar(title: const Text('Detail Surat Pengantar')),
      body: AppPageBackground(
        child: detailAsync.when(
          data: (detail) {
            final request = detail.request;
            final statusColor = AppTheme.statusColor(request.status);
            final canEditForRevision =
                request.submittedBy == auth.user?.id && request.isNeedRevision;
            final canRtReview =
                role == AppConstants.roleAdminRt && request.isSubmitted;
            final canRtFinalize =
                role == AppConstants.roleAdminRt &&
                !request.requiresRwApproval &&
                request.isApprovedRt;
            final canRwReview =
                (AppConstants.hasRwWideAccess(role) ||
                    AppConstants.isSysadminRole(role)) &&
                request.isForwardedToRw;
            final canRwFinalize =
                (AppConstants.hasRwWideAccess(role) ||
                    AppConstants.isSysadminRole(role)) &&
                request.isApprovedRw;
            final canExportPdf =
                request.isApprovedRt ||
                request.isApprovedRw ||
                request.isCompleted;

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(suratDetailProvider(widget.suratId));
                ref.invalidate(suratListProvider);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  AppHeroPanel(
                    eyebrow: AppConstants.suratCategoryLabel(request.category),
                    icon: Icons.assignment_turned_in_outlined,
                    title: request.title,
                    subtitle: request.purpose,
                    chips: [
                      AppHeroBadge(
                        label: AppConstants.suratStatusLabel(request.status),
                        foregroundColor: Colors.white,
                        backgroundColor: statusColor.withValues(alpha: 0.22),
                        icon: Icons.circle,
                      ),
                      AppHeroBadge(
                        label: AppConstants.suratApprovalLabel(
                          request.approvalLevel,
                        ),
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.white.withValues(alpha: 0.16),
                        icon: Icons.route_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  AppSurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AppSectionHeader(
                          title: 'Ringkasan Pengajuan',
                          subtitle:
                              'Informasi utama surat dan status prosesnya.',
                        ),
                        const SizedBox(height: 10),
                        _InfoRow(label: 'Jenis Surat', value: request.title),
                        _InfoRow(
                          label: 'Status',
                          value: AppConstants.suratStatusLabel(request.status),
                        ),
                        _InfoRow(
                          label: 'Approval',
                          value: AppConstants.suratApprovalLabel(
                            request.approvalLevel,
                          ),
                        ),
                        _InfoRow(
                          label: 'Diajukan',
                          value: request.created == null
                              ? '-'
                              : Formatters.tanggalWaktu(request.created!),
                        ),
                        if ((request.applicantNote ?? '').isNotEmpty)
                          _InfoRow(
                            label: 'Catatan Pemohon',
                            value: request.applicantNote!,
                          ),
                        if ((request.reviewNoteRt ?? '').isNotEmpty)
                          _InfoRow(
                            label: 'Catatan RT',
                            value: request.reviewNoteRt!,
                          ),
                        if ((request.reviewNoteRw ?? '').isNotEmpty)
                          _InfoRow(
                            label: 'Catatan RW',
                            value: request.reviewNoteRw!,
                          ),
                      ],
                    ),
                  ),
                  if (canExportPdf) ...[
                    const SizedBox(height: 14),
                    AppSurfaceCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const AppSectionHeader(
                            title: 'Export & Cetak',
                            subtitle:
                                'Gunakan template surat untuk export PDF atau cetak langsung.',
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _isProcessing
                                      ? null
                                      : () => _handleExportPdf(detail),
                                  icon: const Icon(
                                    Icons.picture_as_pdf_outlined,
                                  ),
                                  label: const Text('Export PDF'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: _isProcessing
                                      ? null
                                      : () => _handlePrintPdf(detail),
                                  icon: const Icon(Icons.print_outlined),
                                  label: const Text('Cetak'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  AppSurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AppSectionHeader(
                          title: 'Data Pemohon',
                          subtitle:
                              'Data warga dan KK yang terhubung ke pengajuan surat.',
                        ),
                        const SizedBox(height: 10),
                        _InfoRow(
                          label: 'Nama Warga',
                          value: detail.warga?.namaLengkap ?? '-',
                        ),
                        _InfoRow(label: 'NIK', value: detail.warga?.nik ?? '-'),
                        _InfoRow(
                          label: 'No. KK',
                          value: detail.kk?.noKk ?? '-',
                        ),
                        _InfoRow(
                          label: 'Alamat',
                          value: detail.kk == null
                              ? '-'
                              : Formatters.formatAlamat(
                                  alamat: detail.kk!.alamat,
                                  rt: detail.kk!.rt,
                                  rw: detail.kk!.rw,
                                  kelurahan: detail.kk!.desaKelurahan,
                                  kecamatan: detail.kk!.kecamatan,
                                  kota: detail.kk!.kabupatenKota,
                                ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  AppSurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AppSectionHeader(
                          title: 'Data Form Surat',
                          subtitle:
                              'Detail field yang diisi pemohon sesuai jenis surat.',
                        ),
                        const SizedBox(height: 10),
                        ..._buildPayloadRows(request),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  AppSurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AppSectionHeader(
                          title: 'Lampiran dan Output',
                          subtitle:
                              'Dokumen pendukung dari warga dan file hasil surat final.',
                        ),
                        const SizedBox(height: 10),
                        if (detail.attachments.isEmpty)
                          Text(
                            'Belum ada lampiran pendukung.',
                            style: AppTheme.bodySmall,
                          )
                        else
                          ...detail.attachments.map(
                            (attachment) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _FileTile(
                                label: attachment.label.isEmpty
                                    ? attachment.file
                                    : attachment.label,
                                subtitle: 'Lampiran warga',
                                icon: Icons.attach_file_rounded,
                                onTap: () => _openFileUrl(
                                  getFileUrl(
                                    attachment.record,
                                    attachment.file,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if ((request.outputFile ?? '').isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _FileTile(
                            label: request.outputNumber?.isNotEmpty == true
                                ? request.outputNumber!
                                : 'Surat hasil',
                            subtitle: request.finalizedAt == null
                                ? 'Output surat'
                                : 'Final ${Formatters.tanggalWaktu(request.finalizedAt!)}',
                            icon: Icons.download_done_outlined,
                            onTap: () => _openFileUrl(
                              getFileUrl(request.record, request.outputFile!),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  AppSurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AppSectionHeader(
                          title: 'Timeline Proses',
                          subtitle: 'Riwayat tindakan selama surat diproses.',
                        ),
                        const SizedBox(height: 12),
                        if (detail.logs.isEmpty)
                          Text(
                            'Belum ada log proses.',
                            style: AppTheme.bodySmall,
                          )
                        else
                          ...detail.logs.map(
                            (log) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _TimelineTile(log: log),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (canEditForRevision ||
                      canRtReview ||
                      canRtFinalize ||
                      canRwReview ||
                      canRwFinalize)
                    AppSurfaceCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const AppSectionHeader(
                            title: 'Aksi',
                            subtitle:
                                'Tindakan yang tersedia sesuai role dan status surat saat ini.',
                          ),
                          const SizedBox(height: 10),
                          if (canEditForRevision)
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: () => context.push(
                                  '/surat/form?id=${request.id}',
                                ),
                                icon: const Icon(Icons.edit_note_outlined),
                                label: const Text('Edit dan Kirim Ulang'),
                              ),
                            ),
                          if (canRtReview) ...[
                            _ActionRow(
                              primaryLabel: 'Setujui RT',
                              secondaryLabel: 'Minta Revisi',
                              tertiaryLabel: 'Tolak',
                              processing: _isProcessing,
                              onPrimary: () => _handleReview(
                                title: 'Setujui Surat',
                                confirmLabel: 'Setujui',
                                onSubmit: (note) => ref
                                    .read(suratServiceProvider)
                                    .approve(
                                      auth,
                                      SuratReviewAction(
                                        requestId: request.id,
                                        note: note,
                                      ),
                                    ),
                                successMessage: request.requiresRwApproval
                                    ? 'Surat disetujui RT dan diteruskan ke RW.'
                                    : 'Surat disetujui RT.',
                              ),
                              onSecondary: () => _handleReview(
                                title: 'Minta Revisi',
                                confirmLabel: 'Kirim Revisi',
                                onSubmit: (note) => ref
                                    .read(suratServiceProvider)
                                    .requestRevision(
                                      auth,
                                      SuratReviewAction(
                                        requestId: request.id,
                                        note: note,
                                      ),
                                    ),
                                successMessage:
                                    'Permintaan revisi berhasil dikirim.',
                              ),
                              onTertiary: () => _handleReview(
                                title: 'Tolak Surat',
                                confirmLabel: 'Tolak',
                                onSubmit: (note) => ref
                                    .read(suratServiceProvider)
                                    .reject(
                                      auth,
                                      SuratReviewAction(
                                        requestId: request.id,
                                        note: note,
                                      ),
                                    ),
                                successMessage: 'Pengajuan surat ditolak.',
                              ),
                            ),
                          ],
                          if (canRwReview) ...[
                            _ActionRow(
                              primaryLabel: 'Setujui RW',
                              secondaryLabel: 'Minta Revisi',
                              tertiaryLabel: 'Tolak',
                              processing: _isProcessing,
                              onPrimary: () => _handleReview(
                                title: 'Setujui Surat di RW',
                                confirmLabel: 'Setujui',
                                onSubmit: (note) => ref
                                    .read(suratServiceProvider)
                                    .approve(
                                      auth,
                                      SuratReviewAction(
                                        requestId: request.id,
                                        note: note,
                                      ),
                                    ),
                                successMessage: 'Surat disetujui RW.',
                              ),
                              onSecondary: () => _handleReview(
                                title: 'Minta Revisi dari RW',
                                confirmLabel: 'Kirim Revisi',
                                onSubmit: (note) => ref
                                    .read(suratServiceProvider)
                                    .requestRevision(
                                      auth,
                                      SuratReviewAction(
                                        requestId: request.id,
                                        note: note,
                                      ),
                                    ),
                                successMessage:
                                    'Permintaan revisi RW berhasil dikirim.',
                              ),
                              onTertiary: () => _handleReview(
                                title: 'Tolak Surat di RW',
                                confirmLabel: 'Tolak',
                                onSubmit: (note) => ref
                                    .read(suratServiceProvider)
                                    .reject(
                                      auth,
                                      SuratReviewAction(
                                        requestId: request.id,
                                        note: note,
                                      ),
                                    ),
                                successMessage: 'Pengajuan surat ditolak.',
                              ),
                            ),
                          ],
                          if (canRtFinalize || canRwFinalize) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _isProcessing
                                    ? null
                                    : () => _handleFinalize(auth, request),
                                icon: const Icon(Icons.upload_file_outlined),
                                label: const Text('Finalisasi Surat'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
          loading: () => const _SuratDetailSkeleton(),
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
                    onPressed: () =>
                        ref.invalidate(suratDetailProvider(widget.suratId)),
                    child: const Text('Coba Lagi'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildPayloadRows(SuratModel request) {
    final config = AppConstants.suratTypeOption(request.jenisSurat);
    final widgets = <Widget>[
      _InfoRow(label: 'Keperluan', value: request.purpose),
    ];

    for (final field in config.fields) {
      final value = request.requestPayload[field.key]?.toString().trim() ?? '-';
      widgets.add(
        _InfoRow(label: field.label, value: value.isEmpty ? '-' : value),
      );
    }
    return widgets;
  }

  Future<void> _openFileUrl(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) {
      ErrorClassifier.showErrorSnackBar(
        context,
        StateError('Link file tidak valid.'),
      );
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ErrorClassifier.showErrorSnackBar(
        context,
        StateError('File tidak dapat dibuka.'),
      );
    }
  }

  Future<void> _handleExportPdf(SuratDetailData detail) async {
    setState(() => _isProcessing = true);
    try {
      await ref.read(suratPdfServiceProvider).sharePdf(detail);
    } catch (error) {
      ErrorClassifier.showErrorSnackBar(context, error);
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handlePrintPdf(SuratDetailData detail) async {
    setState(() => _isProcessing = true);
    try {
      await ref.read(suratPdfServiceProvider).printPdf(detail);
    } catch (error) {
      ErrorClassifier.showErrorSnackBar(context, error);
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handleReview({
    required String title,
    required String confirmLabel,
    required Future<void> Function(String note) onSubmit,
    required String successMessage,
  }) async {
    final noteCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: noteCtrl,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Catatan',
            helperText:
                'Opsional, tetapi disarankan untuk memperjelas keputusan.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );

    if (result != true) {
      noteCtrl.dispose();
      return;
    }

    setState(() => _isProcessing = true);
    try {
      await onSubmit(noteCtrl.text.trim());
      ref.invalidate(suratDetailProvider(widget.suratId));
      ref.invalidate(suratListProvider);
      ErrorClassifier.showSuccessSnackBar(context, successMessage);
    } catch (error) {
      ErrorClassifier.showErrorSnackBar(context, error);
    } finally {
      noteCtrl.dispose();
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handleFinalize(AuthState auth, SuratModel request) async {
    final outputNumberCtrl = TextEditingController(
      text: request.outputNumber ?? '',
    );
    PlatformFile? pickedFile;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 24,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
          ),
          child: AppTheme.glassContainer(
            borderRadius: 20,
            padding: const EdgeInsets.all(20),
            child: StatefulBuilder(
              builder: (context, setModalState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Finalisasi Surat', style: AppTheme.heading3),
                    const SizedBox(height: 12),
                    TextField(
                      controller: outputNumberCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nomor Surat',
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles(
                          allowMultiple: false,
                          withData: true,
                        );
                        if (result == null || result.files.isEmpty) {
                          return;
                        }
                        setModalState(() {
                          pickedFile = result.files.first;
                        });
                      },
                      icon: const Icon(Icons.attach_file_rounded),
                      label: Text(
                        pickedFile == null
                            ? 'Pilih File Surat'
                            : pickedFile!.name,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                Navigator.of(sheetContext).pop(false),
                            child: const Text('Batal'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              if (outputNumberCtrl.text.trim().isEmpty ||
                                  pickedFile == null) {
                                return;
                              }
                              Navigator.of(sheetContext).pop(true);
                            },
                            child: const Text('Simpan Final'),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );

    if (confirmed != true || pickedFile == null) {
      outputNumberCtrl.dispose();
      return;
    }

    setState(() => _isProcessing = true);
    try {
      await ref
          .read(suratServiceProvider)
          .finalize(
            auth,
            SuratFinalizePayload(
              requestId: request.id,
              outputNumber: outputNumberCtrl.text.trim(),
              file: pickedFile!,
            ),
          );
      ref.invalidate(suratDetailProvider(widget.suratId));
      ref.invalidate(suratListProvider);
      ErrorClassifier.showSuccessSnackBar(
        context,
        'Surat berhasil difinalisasi.',
      );
    } catch (error) {
      ErrorClassifier.showErrorSnackBar(context, error);
    } finally {
      outputNumberCtrl.dispose();
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTheme.bodySmall),
          const SizedBox(height: 4),
          Text(value, style: AppTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _FileTile extends StatelessWidget {
  const _FileTile({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.extraLightGray,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.dividerColor),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primaryColor),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTheme.bodyMedium),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTheme.caption),
                ],
              ),
            ),
            const Icon(Icons.open_in_new_rounded, size: 18),
          ],
        ),
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({required this.log});

  final SuratLogModel log;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 12,
          height: 12,
          margin: const EdgeInsets.only(top: 4),
          decoration: const BoxDecoration(
            color: AppTheme.primaryColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                log.description,
                style: AppTheme.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                log.created == null
                    ? log.action
                    : '${log.action} • ${Formatters.tanggalWaktu(log.created!)}',
                style: AppTheme.caption,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.tertiaryLabel,
    required this.processing,
    required this.onPrimary,
    required this.onSecondary,
    required this.onTertiary,
  });

  final String primaryLabel;
  final String secondaryLabel;
  final String tertiaryLabel;
  final bool processing;
  final VoidCallback onPrimary;
  final VoidCallback onSecondary;
  final VoidCallback onTertiary;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: processing ? null : onPrimary,
            child: Text(primaryLabel),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: processing ? null : onSecondary,
                child: Text(secondaryLabel),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: processing ? null : onTertiary,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.errorColor,
                ),
                child: Text(tertiaryLabel),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SuratDetailSkeleton extends StatelessWidget {
  const _SuratDetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      children: [
        // Hero panel skeleton
        const AppSkeleton(height: 160, borderRadius: 16),
        const SizedBox(height: 10),
        // Summary card
        AppSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppSkeleton(width: 140, height: 18),
              const SizedBox(height: 6),
              const AppSkeleton(width: 200, height: 14),
              const SizedBox(height: 14),
              ...List.generate(
                5,
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
        const SizedBox(height: 14),
        // Data pemohon card
        AppSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppSkeleton(width: 120, height: 18),
              const SizedBox(height: 6),
              const AppSkeleton(width: 180, height: 14),
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
        const SizedBox(height: 14),
        // Timeline card
        AppSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppSkeleton(width: 130, height: 18),
              const SizedBox(height: 14),
              ...List.generate(
                3,
                (_) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      AppSkeleton(width: 24, height: 24, borderRadius: 12),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppSkeleton(height: 14),
                            SizedBox(height: 6),
                            AppSkeleton(width: 120, height: 12),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

