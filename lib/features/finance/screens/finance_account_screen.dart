// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/services/finance_service.dart';
import '../../../core/utils/error_classifier.dart';
import '../../../shared/models/finance_model.dart';
import '../../../shared/widgets/app_surface.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/finance_providers.dart';
import '../widgets/finance_widgets.dart';

class FinanceAccountScreen extends ConsumerStatefulWidget {
  const FinanceAccountScreen({super.key});

  @override
  ConsumerState<FinanceAccountScreen> createState() =>
      _FinanceAccountScreenState();
}

class _FinanceAccountScreenState extends ConsumerState<FinanceAccountScreen> {
  String _statusFilter = 'all';
  String _unitFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    if (!auth.isOperator && !auth.isSysadmin) {
      return const FinanceAccessDenied(
        title: 'Akses akun kas tidak tersedia',
        message:
            'Screen ini hanya tersedia untuk operator atau sysadmin yang mengelola keuangan unit.',
      );
    }

    final dataAsync = ref.watch(financeAccountManagementProvider);
    return FinanceScreenShell(
      title: 'Kelola Akun Kas',
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: () => ref.read(financeRefreshTickProvider.notifier).bump(),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      floatingActionButton:
          dataAsync.asData?.value.manageableUnits.isNotEmpty == true
          ? FloatingActionButton.extended(
              onPressed: () =>
                  _openAccountDialog(context, ref, dataAsync.asData!.value),
              icon: const Icon(Icons.add),
              label: const Text('Tambah Akun'),
            )
          : null,
      child: dataAsync.when(
        data: (data) {
          final canOpen =
              data.profile.member.isSysadmin || data.manageableUnits.isNotEmpty;
          if (!canOpen) {
            return const FinanceAccessDenied(
              title: 'Tidak ada unit yang bisa dikelola',
              message:
                  'Tambahkan hak submit keuangan pada jabatan unit agar akun kas bisa diatur dari aplikasi.',
            );
          }

          final accounts =
              data.manageableAccounts
                  .where((account) {
                    final statusMatch =
                        _statusFilter == 'all' ||
                        (_statusFilter == 'active' && account.isActive) ||
                        (_statusFilter == 'inactive' && !account.isActive);
                    final unitMatch =
                        _unitFilter == 'all' ||
                        account.orgUnitId == _unitFilter;
                    return statusMatch && unitMatch;
                  })
                  .toList(growable: false)
                ..sort((left, right) {
                  if (left.isActive != right.isActive) {
                    return left.isActive ? -1 : 1;
                  }
                  return left.label.toLowerCase().compareTo(
                    right.label.toLowerCase(),
                  );
                });

          return RefreshIndicator(
            onRefresh: () async {
              ref.read(financeRefreshTickProvider.notifier).bump();
              await ref.read(financeAccountManagementProvider.future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
              children: [
                _FinanceAccountHero(data: data),
                const SizedBox(height: 12),
                FinanceSectionCard(
                  title: 'Panduan setup',
                  subtitle:
                      'Akun kas dipakai saat transaksi manual disubmit dan saat iuran terverifikasi masuk ke ledger.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _GuideLine(
                        icon: Icons.account_balance_wallet_outlined,
                        text:
                            'Buat minimal satu akun per unit yang mengelola transaksi.',
                      ),
                      _GuideLine(
                        icon: Icons.payments_outlined,
                        text:
                            'Pilih tipe bank untuk transfer dan cash untuk pembayaran tunai.',
                      ),
                      _GuideLine(
                        icon: Icons.rule_folder_outlined,
                        text:
                            'Saat iuran gagal diverifikasi karena akun belum ada, tambahkan akun unit di sini lalu ulangi verifikasi.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                FinanceSectionCard(
                  title: 'Filter akun',
                  subtitle:
                      'Saring akun kas berdasarkan unit dan status aktif.',
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _unitFilter,
                        decoration: const InputDecoration(labelText: 'Unit'),
                        items: [
                          const DropdownMenuItem(
                            value: 'all',
                            child: Text('Semua unit'),
                          ),
                          ...data.manageableUnits.map(
                            (unit) => DropdownMenuItem(
                              value: unit.id,
                              child: Text(unit.name),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() => _unitFilter = value ?? 'all');
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _statusFilter,
                        decoration: const InputDecoration(labelText: 'Status'),
                        items: const [
                          DropdownMenuItem(
                            value: 'all',
                            child: Text('Semua status'),
                          ),
                          DropdownMenuItem(
                            value: 'active',
                            child: Text('Aktif'),
                          ),
                          DropdownMenuItem(
                            value: 'inactive',
                            child: Text('Nonaktif'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() => _statusFilter = value ?? 'all');
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (accounts.isEmpty)
                  const FinanceSectionCard(
                    title: 'Daftar akun kas',
                    child: FinanceEmptyState(
                      icon: Icons.account_balance_outlined,
                      title: 'Belum ada akun kas',
                      message:
                          'Tambahkan akun kas per unit supaya transaksi dan verifikasi iuran bisa diposting ke ledger.',
                    ),
                  )
                else
                  FinanceSectionCard(
                    title: 'Daftar akun kas',
                    subtitle:
                        'Edit label, pindahkan unit, atau nonaktifkan akun yang sudah tidak dipakai.',
                    child: Column(
                      children: accounts
                          .map(
                            (account) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _FinanceAccountTile(
                                account: account,
                                unitName:
                                    data
                                        .unitById(account.orgUnitId ?? '')
                                        ?.name ??
                                    'Unit belum dikenali',
                                onEdit: () => _openAccountDialog(
                                  context,
                                  ref,
                                  data,
                                  account,
                                ),
                                onToggleActive: () =>
                                    _toggleAccountActive(context, ref, account),
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ),
              ],
            ),
          );
        },
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.paddingLarge),
            child: Text(
              'Gagal memuat akun kas.\n${error.toString()}',
              textAlign: TextAlign.center,
              style: AppTheme.bodySmall,
            ),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Future<void> _toggleAccountActive(
    BuildContext context,
    WidgetRef ref,
    FinanceAccountModel account,
  ) async {
    final targetState = !account.isActive;
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              targetState ? 'Aktifkan akun kas' : 'Nonaktifkan akun kas',
            ),
            content: Text(
              targetState
                  ? 'Akun ${account.label} akan diaktifkan kembali.'
                  : 'Akun ${account.label} akan disembunyikan dari pilihan transaksi aktif.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(targetState ? 'Aktifkan' : 'Nonaktifkan'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !context.mounted) {
      return;
    }

    try {
      await ref
          .read(financeServiceProvider)
          .setAccountActive(accountId: account.id, isActive: targetState);
      ref.read(financeRefreshTickProvider.notifier).bump();
      if (!context.mounted) {
        return;
      }
      ErrorClassifier.showSuccessSnackBar(
        context,
        targetState
            ? 'Akun kas berhasil diaktifkan.'
            : 'Akun kas berhasil dinonaktifkan.',
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ErrorClassifier.showErrorSnackBar(context, error);
    }
  }

  Future<void> _openAccountDialog(
    BuildContext context,
    WidgetRef ref,
    FinanceAccountManagementData data, [
    FinanceAccountModel? existing,
  ]) async {
    final codeCtrl = TextEditingController(text: existing?.code ?? '');
    final labelCtrl = TextEditingController(text: existing?.label ?? '');
    String selectedUnitId =
        existing?.orgUnitId ??
        (data.manageableUnits.isNotEmpty ? data.manageableUnits.first.id : '');
    String type = existing?.type ?? 'cash';
    bool isActive = existing?.isActive ?? true;
    bool isSaving = false;

    final saved =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => StatefulBuilder(
            builder: (context, setState) => AlertDialog(
              title: Text(
                existing == null ? 'Tambah Akun Kas' : 'Edit Akun Kas',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: selectedUnitId.isEmpty
                          ? null
                          : selectedUnitId,
                      decoration: const InputDecoration(labelText: 'Unit'),
                      items: data.manageableUnits
                          .map(
                            (unit) => DropdownMenuItem(
                              value: unit.id,
                              child: Text(unit.name),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: isSaving
                          ? null
                          : (value) {
                              setState(() => selectedUnitId = value ?? '');
                            },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: codeCtrl,
                      enabled: !isSaving,
                      decoration: const InputDecoration(
                        labelText: 'Kode akun',
                        hintText: 'Contoh: kas_rt01 atau bank_rw19',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: labelCtrl,
                      enabled: !isSaving,
                      decoration: const InputDecoration(
                        labelText: 'Label akun',
                        hintText: 'Contoh: Kas RT 01/19',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: type,
                      decoration: const InputDecoration(labelText: 'Tipe akun'),
                      items: const [
                        DropdownMenuItem(value: 'cash', child: Text('Cash')),
                        DropdownMenuItem(
                          value: 'bank',
                          child: Text('Bank / Transfer'),
                        ),
                      ],
                      onChanged: isSaving
                          ? null
                          : (value) {
                              setState(() => type = value ?? 'cash');
                            },
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: isActive,
                      title: const Text('Akun aktif'),
                      subtitle: const Text(
                        'Akun nonaktif tidak tampil di transaksi atau verifikasi iuran.',
                      ),
                      onChanged: isSaving
                          ? null
                          : (value) {
                              setState(() => isActive = value);
                            },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.pop(dialogContext, false),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (selectedUnitId.trim().isEmpty) {
                            ErrorClassifier.showErrorSnackBar(
                              dialogContext,
                              Exception('Pilih unit akun kas terlebih dahulu.'),
                            );
                            return;
                          }
                          if (codeCtrl.text.trim().isEmpty ||
                              labelCtrl.text.trim().isEmpty) {
                            ErrorClassifier.showErrorSnackBar(
                              dialogContext,
                              Exception('Kode dan label akun kas wajib diisi.'),
                            );
                            return;
                          }

                          setState(() => isSaving = true);
                          try {
                            if (existing == null) {
                              await ref
                                  .read(financeServiceProvider)
                                  .createAccount(
                                    orgUnitId: selectedUnitId,
                                    code: codeCtrl.text,
                                    label: labelCtrl.text,
                                    type: type,
                                    isActive: isActive,
                                  );
                            } else {
                              await ref
                                  .read(financeServiceProvider)
                                  .updateAccount(
                                    accountId: existing.id,
                                    orgUnitId: selectedUnitId,
                                    code: codeCtrl.text,
                                    label: labelCtrl.text,
                                    type: type,
                                    isActive: isActive,
                                  );
                            }
                            if (!dialogContext.mounted) {
                              return;
                            }
                            Navigator.pop(dialogContext, true);
                          } catch (error) {
                            if (!dialogContext.mounted) {
                              return;
                            }
                            setState(() => isSaving = false);
                            ErrorClassifier.showErrorSnackBar(
                              dialogContext,
                              error,
                            );
                          }
                        },
                  child: Text(
                    isSaving
                        ? 'Menyimpan...'
                        : existing == null
                        ? 'Simpan Akun'
                        : 'Perbarui Akun',
                  ),
                ),
              ],
            ),
          ),
        ) ??
        false;

    codeCtrl.dispose();
    labelCtrl.dispose();

    if (!saved || !context.mounted) {
      return;
    }
    ref.read(financeRefreshTickProvider.notifier).bump();
    ErrorClassifier.showSuccessSnackBar(
      context,
      existing == null
          ? 'Akun kas berhasil ditambahkan.'
          : 'Akun kas berhasil diperbarui.',
    );
  }
}

class _FinanceAccountHero extends StatelessWidget {
  const _FinanceAccountHero({required this.data});

  final FinanceAccountManagementData data;

  @override
  Widget build(BuildContext context) {
    final activeCount = data.manageableAccounts
        .where((item) => item.isActive)
        .length;
    final inactiveCount = data.manageableAccounts.length - activeCount;
    final bankCount = data.manageableAccounts
        .where((item) => item.type == 'bank')
        .length;
    final cashCount = data.manageableAccounts
        .where((item) => item.type == 'cash')
        .length;

    return AppHeroPanel(
      eyebrow: 'Setup',
      icon: Icons.account_balance_rounded,
      title: 'Akun Kas Per Unit',
      subtitle:
          'Sumber rekening dan kas yang dipakai transaksi manual serta posting otomatis dari iuran.',
      chips: [
        AppHeroBadge(
          icon: Icons.check_circle_outline_rounded,
          label: 'Aktif $activeCount',
          foregroundColor: AppTheme.successColor,
          backgroundColor: AppTheme.successColor.withValues(alpha: 0.08),
        ),
        AppHeroBadge(
          icon: Icons.payments_outlined,
          label: 'Cash $cashCount',
          foregroundColor: AppTheme.primaryColor,
          backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.08),
        ),
        AppHeroBadge(
          icon: Icons.account_balance_outlined,
          label: 'Bank $bankCount',
          foregroundColor: AppTheme.accentColor,
          backgroundColor: AppTheme.accentColor.withValues(alpha: 0.08),
        ),
        if (inactiveCount > 0)
          AppHeroBadge(
            icon: Icons.pause_circle_outline_rounded,
            label: 'Nonaktif $inactiveCount',
            foregroundColor: AppTheme.warningColor,
            backgroundColor: AppTheme.warningColor.withValues(alpha: 0.08),
          ),
      ],
    );
  }
}

class _FinanceAccountTile extends StatelessWidget {
  const _FinanceAccountTile({
    required this.account,
    required this.unitName,
    required this.onEdit,
    required this.onToggleActive,
  });

  final FinanceAccountModel account;
  final String unitName;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;

  @override
  Widget build(BuildContext context) {
    final tone = account.type == 'bank'
        ? AppTheme.accentColor
        : AppTheme.primaryColor;
    return Opacity(
      opacity: account.isActive ? 1 : 0.72,
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: AppTheme.cardDecoration(),
          padding: const EdgeInsets.all(AppTheme.paddingMedium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: tone.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      account.type == 'bank'
                          ? Icons.account_balance_outlined
                          : Icons.account_balance_wallet_outlined,
                      color: tone,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          account.label,
                          style: AppTheme.bodyMedium.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$unitName • ${account.code}',
                          style: AppTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        onEdit();
                      } else if (value == 'toggle') {
                        onToggleActive();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Edit akun'),
                      ),
                      PopupMenuItem(
                        value: 'toggle',
                        child: Text(
                          account.isActive
                              ? 'Nonaktifkan akun'
                              : 'Aktifkan akun',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FinanceBadge(
                    label: account.type == 'bank' ? 'BANK' : 'CASH',
                    color: tone,
                  ),
                  FinanceBadge(
                    label: account.isActive ? 'AKTIF' : 'NONAKTIF',
                    color: account.isActive
                        ? AppTheme.successColor
                        : AppTheme.warningColor,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuideLine extends StatelessWidget {
  const _GuideLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
