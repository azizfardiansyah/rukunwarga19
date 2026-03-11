// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/services/finance_service.dart';
import '../../../core/services/pocketbase_service.dart';
import '../../../core/utils/error_classifier.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/finance_model.dart';
import '../providers/finance_providers.dart';
import '../widgets/finance_widgets.dart';

class FinanceDetailScreen extends ConsumerWidget {
  const FinanceDetailScreen({super.key, required this.transactionId});

  final String transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(financeDetailProvider(transactionId));
    return detailAsync.when(
      data: (detail) {
        final profile = detail.overview.profile;
        final transaction = detail.transaction;
        final canEditDraft =
            transaction.approvalStatus == 'draft' &&
            (profile.member.isSysadmin ||
                transaction.makerMemberId == profile.member.id) &&
            profile.canSubmitFinanceForUnit(transaction.orgUnitId);
        final canSubmitDraft = canEditDraft;
        final canApprove =
            transaction.isSubmitted &&
            profile.canApproveFinanceForUnit(transaction.orgUnitId) &&
            (profile.member.isSysadmin ||
                transaction.makerMemberId != profile.member.id);
        final canPublish =
            transaction.isApproved &&
            !transaction.isPublished &&
            profile.canPublishFinanceByPlan &&
            profile.canPublishFinanceForUnit(transaction.orgUnitId);

        return FinanceScreenShell(
          title: 'Detail Transaksi',
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: () =>
                  ref.read(financeRefreshTickProvider.notifier).bump(),
              icon: const Icon(Icons.refresh_rounded),
            ),
            if (canEditDraft)
              IconButton(
                tooltip: 'Edit Draft',
                onPressed: () =>
                    context.push('${Routes.financeForm}?id=${transaction.id}'),
                icon: const Icon(Icons.edit_outlined),
              ),
          ],
          child: RefreshIndicator(
            onRefresh: () async {
              ref.read(financeRefreshTickProvider.notifier).bump();
              await ref.read(financeDetailProvider(transactionId).future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppTheme.paddingMedium,
                AppTheme.paddingMedium,
                AppTheme.paddingMedium,
                AppTheme.paddingLarge,
              ),
              children: [
                _DetailHero(detail: detail),
                const SizedBox(height: 16),
                FinanceSectionCard(
                  title: 'Informasi transaksi',
                  subtitle:
                      'Ringkasan ledger, unit, maker, metode, dan timestamp transaksi.',
                  child: Column(
                    children: [
                      _InfoRow(
                        label: 'Unit',
                        value: detail.orgUnit?.name ?? transaction.orgUnitId,
                      ),
                      _InfoRow(
                        label: 'Akun kas',
                        value: detail.account?.label ?? transaction.accountId,
                      ),
                      _InfoRow(label: 'Kategori', value: transaction.category),
                      _InfoRow(
                        label: 'Metode',
                        value: transaction.paymentMethod,
                      ),
                      _InfoRow(
                        label: 'Maker',
                        value:
                            transaction.makerJabatanSnapshot ??
                            transaction.makerMemberId,
                      ),
                      _InfoRow(
                        label: 'Sumber',
                        value: transaction.sourceModule,
                      ),
                      _InfoRow(
                        label: 'Dibuat',
                        value: _dateLabel(transaction.created),
                      ),
                      _InfoRow(
                        label: 'Submitted',
                        value: _dateLabel(transaction.submittedAt),
                      ),
                      _InfoRow(
                        label: 'Approved',
                        value: _dateLabel(transaction.approvedAt),
                      ),
                      _InfoRow(
                        label: 'Published',
                        value: _dateLabel(transaction.publishedAt),
                      ),
                    ],
                  ),
                ),
                if ((transaction.description ?? '').isNotEmpty) ...[
                  const SizedBox(height: 16),
                  FinanceSectionCard(
                    title: 'Deskripsi',
                    child: Text(
                      transaction.description!,
                      style: AppTheme.bodyMedium,
                    ),
                  ),
                ],
                if ((transaction.proofFile ?? '').isNotEmpty) ...[
                  const SizedBox(height: 16),
                  FinanceSectionCard(
                    title: 'Bukti transaksi',
                    subtitle: 'Lampiran bukti yang tersimpan di ledger.',
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            transaction.proofFile!,
                            style: AppTheme.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: () => _openProof(context, transaction),
                          icon: const Icon(Icons.open_in_new_rounded),
                          label: const Text('Buka'),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                FinanceSectionCard(
                  title: 'Approval trail',
                  subtitle:
                      'Catatan checker yang masuk setelah transaksi disubmit.',
                  child: detail.approvals.isEmpty
                      ? FinanceEmptyState(
                          icon: transaction.requiresTwoWayVerification
                              ? Icons.fact_check_outlined
                              : Icons.check_circle_outline_rounded,
                          title: transaction.requiresTwoWayVerification
                              ? 'Belum ada approval'
                              : 'Checker tidak diperlukan',
                          message: transaction.requiresTwoWayVerification
                              ? 'Submit draft ini lebih dulu agar checker bisa memberi keputusan.'
                              : 'Transaksi cash in dapat langsung approved saat submit.',
                        )
                      : Column(
                          children: detail.approvals
                              .map(
                                (approval) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _ApprovalTile(approval: approval),
                                ),
                              )
                              .toList(growable: false),
                        ),
                ),
                if (canEditDraft ||
                    canSubmitDraft ||
                    canApprove ||
                    canPublish) ...[
                  const SizedBox(height: 16),
                  FinanceSectionCard(
                    title: 'Tindakan',
                    subtitle:
                        'Aksi tersedia mengikuti plan, jabatan, dan scope unit transaksi ini.',
                    child: Column(
                      children: [
                        if (canSubmitDraft)
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () => _submitDraft(context, ref),
                              icon: const Icon(Icons.send_rounded),
                              label: const Text('Submit Draft'),
                            ),
                          ),
                        if (canEditDraft) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => context.push(
                                '${Routes.financeForm}?id=${transaction.id}',
                              ),
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('Edit Draft'),
                            ),
                          ),
                        ],
                        if (canApprove) ...[
                          if (canSubmitDraft || canEditDraft)
                            const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () =>
                                      _decide(context, ref, approve: true),
                                  icon: const Icon(Icons.check_rounded),
                                  label: const Text('Approve'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      _decide(context, ref, approve: false),
                                  icon: const Icon(Icons.close_rounded),
                                  label: const Text('Reject'),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (canPublish) ...[
                          if (canSubmitDraft || canEditDraft || canApprove)
                            const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () => _publish(context, ref, detail),
                              icon: const Icon(Icons.campaign_rounded),
                              label: const Text('Publish Pengumuman Kas'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
      loading: () => const FinanceScreenShell(
        title: 'Detail Transaksi',
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => FinanceScreenShell(
        title: 'Detail Transaksi',
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.paddingLarge),
            child: Text(
              'Gagal memuat detail transaksi.\n${error.toString()}',
              textAlign: TextAlign.center,
              style: AppTheme.bodySmall,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitDraft(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(financeServiceProvider)
          .submitTransaction(transactionId: transactionId);
      ref.read(financeRefreshTickProvider.notifier).bump();
      if (!context.mounted) {
        return;
      }
      ErrorClassifier.showSuccessSnackBar(
        context,
        'Draft berhasil disubmit ke alur maker-checker.',
      );
    } catch (error) {
      if (context.mounted) {
        ErrorClassifier.showErrorSnackBar(context, error);
      }
    }
  }

  Future<void> _decide(
    BuildContext context,
    WidgetRef ref, {
    required bool approve,
  }) async {
    final noteCtrl = TextEditingController();
    final proceed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(approve ? 'Approve Transaksi' : 'Reject Transaksi'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  approve
                      ? 'Tambahkan catatan checker jika diperlukan.'
                      : 'Jelaskan alasan penolakan agar maker bisa memperbaiki draft.',
                  style: AppTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: approve ? 'Catatan approve' : 'Alasan reject',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(approve ? 'Approve' : 'Reject'),
              ),
            ],
          ),
        ) ??
        false;
    if (!proceed) {
      return;
    }

    try {
      if (approve) {
        await ref
            .read(financeServiceProvider)
            .approveTransaction(
              transactionId: transactionId,
              note: noteCtrl.text.trim(),
            );
      } else {
        await ref
            .read(financeServiceProvider)
            .rejectTransaction(
              transactionId: transactionId,
              note: noteCtrl.text.trim(),
            );
      }
      ref.read(financeRefreshTickProvider.notifier).bump();
      if (!context.mounted) {
        return;
      }
      ErrorClassifier.showSuccessSnackBar(
        context,
        approve
            ? 'Transaksi berhasil di-approve.'
            : 'Transaksi berhasil direject.',
      );
    } catch (error) {
      if (context.mounted) {
        ErrorClassifier.showErrorSnackBar(context, error);
      }
    }
  }

  Future<void> _publish(
    BuildContext context,
    WidgetRef ref,
    FinanceDetailData detail,
  ) async {
    final transaction = detail.transaction;
    final unitName = detail.orgUnit?.name ?? 'Unit';
    final titleCtrl = TextEditingController(
      text: '${transaction.isIncoming ? 'Pemasukan' : 'Pengeluaran'} $unitName',
    );
    final contentCtrl = TextEditingController(
      text:
          '${transaction.title} sebesar ${Formatters.rupiah(transaction.amount)} telah selesai diverifikasi dan dipublikasikan.',
    );

    final proceed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Publish Pengumuman Kas'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Judul pengumuman',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: contentCtrl,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Isi pengumuman',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Publish'),
              ),
            ],
          ),
        ) ??
        false;
    if (!proceed) {
      return;
    }

    try {
      await ref
          .read(financeServiceProvider)
          .publishTransaction(
            transactionId: transactionId,
            announcementTitle: titleCtrl.text.trim(),
            announcementContent: contentCtrl.text.trim(),
          );
      ref.read(financeRefreshTickProvider.notifier).bump();
      if (!context.mounted) {
        return;
      }
      ErrorClassifier.showSuccessSnackBar(
        context,
        'Pengumuman kas berhasil dipublikasikan.',
      );
    } catch (error) {
      if (context.mounted) {
        ErrorClassifier.showErrorSnackBar(context, error);
      }
    }
  }

  Future<void> _openProof(
    BuildContext context,
    FinanceTransactionModel transaction,
  ) async {
    final fileName = transaction.proofFile;
    if (fileName == null || fileName.isEmpty) {
      return;
    }
    final uri = Uri.parse(
      pb.files.getUrl(transaction.record, fileName).toString(),
    );
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ErrorClassifier.showErrorSnackBar(
        context,
        Exception('File bukti tidak dapat dibuka.'),
      );
    }
  }

  String _dateLabel(DateTime? value) {
    if (value == null) {
      return '-';
    }
    return Formatters.tanggalWaktu(value);
  }
}

class _DetailHero extends StatelessWidget {
  const _DetailHero({required this.detail});

  final FinanceDetailData detail;

  @override
  Widget build(BuildContext context) {
    final transaction = detail.transaction;
    final amountColor = transaction.isIncoming
        ? AppTheme.successColor
        : AppTheme.errorColor;
    return Container(
      padding: const EdgeInsets.all(AppTheme.paddingLarge),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            amountColor.withValues(alpha: 0.92),
            amountColor.withValues(alpha: 0.68),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            transaction.title,
            style: AppTheme.heading2.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            Formatters.rupiah(transaction.amount),
            style: AppTheme.heading1.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FinanceBadge(
                label: financeDirectionLabel(transaction.direction),
                color: Colors.white,
              ),
              FinanceBadge(
                label: financeApprovalStatusLabel(transaction.approvalStatus),
                color: Colors.white,
              ),
              FinanceBadge(
                label: financePublishStatusLabel(transaction.publishStatus),
                color: Colors.white,
              ),
              if ((detail.orgUnit?.name ?? '').isNotEmpty)
                FinanceBadge(label: detail.orgUnit!.name, color: Colors.white),
            ],
          ),
        ],
      ),
    );
  }
}

class _ApprovalTile extends StatelessWidget {
  const _ApprovalTile({required this.approval});

  final FinanceApprovalModel approval;

  @override
  Widget build(BuildContext context) {
    final tone = approval.decision == 'approved'
        ? AppTheme.successColor
        : AppTheme.errorColor;
    return Container(
      decoration: AppTheme.cardDecoration(),
      padding: const EdgeInsets.all(AppTheme.paddingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FinanceBadge(
                label: financeApprovalStatusLabel(approval.decision),
                color: tone,
              ),
              const Spacer(),
              Text(
                approval.created == null
                    ? '-'
                    : Formatters.tanggalRelatif(approval.created!),
                style: AppTheme.caption,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            approval.checkerJabatanSnapshot ?? approval.checkerMemberId,
            style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w700),
          ),
          if ((approval.note ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(approval.note!, style: AppTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: AppTheme.bodySmall)),
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
