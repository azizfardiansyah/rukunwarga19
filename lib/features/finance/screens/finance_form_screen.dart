// ignore_for_file: use_build_context_synchronously

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/services/finance_service.dart';
import '../../../core/utils/error_classifier.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/finance_model.dart';
import '../providers/finance_providers.dart';
import '../widgets/finance_widgets.dart';

class FinanceFormScreen extends ConsumerStatefulWidget {
  const FinanceFormScreen({super.key, this.transactionId});

  final String? transactionId;

  @override
  ConsumerState<FinanceFormScreen> createState() => _FinanceFormScreenState();
}

class _FinanceFormScreenState extends ConsumerState<FinanceFormScreen> {
  final _categoryCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();

  String? _selectedUnitId;
  String? _selectedAccountId;
  String _direction = 'in';
  String _paymentMethod = 'cash';
  PlatformFile? _pickedProof;
  String? _seededTransactionId;
  String? _existingProofName;
  bool _isSaving = false;

  @override
  void dispose() {
    _categoryCtrl.dispose();
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final transactionId = widget.transactionId;
    if ((transactionId ?? '').isNotEmpty) {
      final detailAsync = ref.watch(financeDetailProvider(transactionId!));
      return detailAsync.when(
        data: (detail) {
          final transaction = detail.transaction;
          if (transaction.approvalStatus != 'draft') {
            return const FinanceScreenShell(
              title: 'Edit Draft',
              child: FinanceEmptyState(
                icon: Icons.lock_clock_outlined,
                title: 'Draft tidak bisa diedit',
                message:
                    'Hanya transaksi dengan status draft yang bisa dibuka di form ini.',
              ),
            );
          }
          _seedForm(detail.overview, transaction: transaction);
          return _buildForm(context, detail.overview, transaction: transaction);
        },
        loading: () => const FinanceScreenShell(
          title: 'Edit Draft',
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => FinanceScreenShell(
          title: 'Edit Draft',
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.paddingLarge),
              child: Text(
                'Gagal memuat draft.\n${error.toString()}',
                textAlign: TextAlign.center,
                style: AppTheme.bodySmall,
              ),
            ),
          ),
        ),
      );
    }

    final overviewAsync = ref.watch(financeOverviewProvider);
    return overviewAsync.when(
      data: (overview) {
        _seedForm(overview);
        return _buildForm(context, overview);
      },
      loading: () => const FinanceScreenShell(
        title: 'Buat Transaksi',
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => FinanceScreenShell(
        title: 'Buat Transaksi',
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.paddingLarge),
            child: Text(
              'Gagal memuat data form.\n${error.toString()}',
              textAlign: TextAlign.center,
              style: AppTheme.bodySmall,
            ),
          ),
        ),
      ),
    );
  }

  void _seedForm(
    FinanceOverviewData overview, {
    FinanceTransactionModel? transaction,
  }) {
    final seedKey = transaction?.id ?? 'new';
    if (_seededTransactionId == seedKey) {
      return;
    }

    final initialUnitId =
        transaction?.orgUnitId ??
        (overview.creatableUnits.isNotEmpty
            ? overview.creatableUnits.first.id
            : null);
    final accounts = initialUnitId == null
        ? const <FinanceAccountModel>[]
        : overview.accountsForUnit(initialUnitId);
    final initialAccountId =
        transaction?.accountId ??
        (accounts.isNotEmpty ? accounts.first.id : null);

    _selectedUnitId = initialUnitId;
    _selectedAccountId = initialAccountId;
    _direction = transaction?.direction ?? 'in';
    _paymentMethod = transaction?.paymentMethod ?? 'cash';
    _categoryCtrl.text = transaction?.category ?? '';
    _titleCtrl.text = transaction?.title ?? '';
    _descriptionCtrl.text = transaction?.description ?? '';
    _amountCtrl.text = transaction?.amount.toString() ?? '';
    _existingProofName = transaction?.proofFile;
    _pickedProof = null;
    _seededTransactionId = seedKey;
  }

  Widget _buildForm(
    BuildContext context,
    FinanceOverviewData overview, {
    FinanceTransactionModel? transaction,
  }) {
    final isEditing = transaction != null;
    final creatableUnits = overview.creatableUnits;
    final selectedUnitId = _selectedUnitId;
    final selectedAccounts = selectedUnitId == null
        ? const <FinanceAccountModel>[]
        : overview.accountsForUnit(selectedUnitId);
    if (_selectedAccountId != null &&
        !selectedAccounts.any((item) => item.id == _selectedAccountId)) {
      _selectedAccountId = selectedAccounts.isNotEmpty
          ? selectedAccounts.first.id
          : null;
    }

    final canEdit = isEditing
        ? overview.profile.member.isSysadmin ||
              (transaction.makerMemberId == overview.profile.member.id &&
                  overview.profile.canSubmitFinanceForUnit(
                    transaction.orgUnitId,
                  ))
        : true;

    if (!isEditing && creatableUnits.isEmpty) {
      return const FinanceAccessDenied(
        title: 'Tidak ada unit yang bisa dikelola',
        message:
            'Akun ini tidak memiliki unit dengan hak submit keuangan. Tambahkan jabatan bendahara atau hak submit terlebih dahulu.',
      );
    }

    if (!canEdit) {
      return const FinanceAccessDenied(
        title: 'Draft ini tidak bisa diedit',
        message:
            'Hanya maker atau sysadmin yang bisa mengedit draft transaksi.',
      );
    }

    return FinanceScreenShell(
      title: isEditing ? 'Edit Draft' : 'Buat Transaksi',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
        children: [
          FinanceSectionCard(
            title: isEditing
                ? 'Perbarui draft transaksi'
                : 'Draft transaksi baru',
            subtitle:
                'Simpan draft dulu jika data belum lengkap, atau submit langsung untuk masuk ke flow maker-checker.',
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _selectedUnitId,
                  decoration: const InputDecoration(labelText: 'Unit'),
                  items: creatableUnits
                      .map(
                        (unit) => DropdownMenuItem(
                          value: unit.id,
                          child: Text(unit.name),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: _isSaving
                      ? null
                      : (value) {
                          final nextAccounts = value == null
                              ? const <FinanceAccountModel>[]
                              : overview.accountsForUnit(value);
                          setState(() {
                            _selectedUnitId = value;
                            _selectedAccountId = nextAccounts.isNotEmpty
                                ? nextAccounts.first.id
                                : null;
                          });
                        },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedAccountId,
                  decoration: const InputDecoration(labelText: 'Akun kas'),
                  items: selectedAccounts
                      .map(
                        (account) => DropdownMenuItem(
                          value: account.id,
                          child: Text('${account.label} (${account.code})'),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: _isSaving
                      ? null
                      : (value) {
                          setState(() => _selectedAccountId = value);
                        },
                ),
                if (selectedUnitId != null && selectedAccounts.isEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Belum ada akun kas aktif untuk unit ini. Buka menu Kelola Akun Kas untuk menambahkan akun unit terlebih dahulu.',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.errorColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _isSaving
                          ? null
                          : () => context.push(Routes.financeAccounts),
                      icon: const Icon(
                        Icons.account_balance_outlined,
                        size: 18,
                      ),
                      label: const Text('Kelola Akun Kas'),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _direction,
                        decoration: const InputDecoration(labelText: 'Arah'),
                        items: const [
                          DropdownMenuItem(
                            value: 'in',
                            child: Text('Pemasukan'),
                          ),
                          DropdownMenuItem(
                            value: 'out',
                            child: Text('Pengeluaran'),
                          ),
                        ],
                        onChanged: _isSaving
                            ? null
                            : (value) {
                                setState(() => _direction = value ?? 'in');
                              },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _paymentMethod,
                        decoration: const InputDecoration(
                          labelText: 'Metode bayar',
                        ),
                        items: const [
                          DropdownMenuItem(value: 'cash', child: Text('Cash')),
                          DropdownMenuItem(
                            value: 'transfer',
                            child: Text('Transfer'),
                          ),
                        ],
                        onChanged: _isSaving
                            ? null
                            : (value) {
                                setState(
                                  () => _paymentMethod = value ?? 'cash',
                                );
                              },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _categoryCtrl,
                  enabled: !_isSaving,
                  decoration: const InputDecoration(
                    labelText: 'Kategori',
                    hintText: 'Contoh: Kas Operasional, Donasi, Konsumsi',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _titleCtrl,
                  enabled: !_isSaving,
                  decoration: const InputDecoration(
                    labelText: 'Judul transaksi',
                    hintText: 'Contoh: Pembelian sound system',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amountCtrl,
                  enabled: !_isSaving,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Nominal',
                    hintText: 'Contoh: 250000',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionCtrl,
                  enabled: !_isSaving,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Deskripsi',
                    hintText: 'Opsional. Tambahkan rincian transaksi.',
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _isSaving ? null : _pickProof,
                        icon: const Icon(Icons.attach_file_rounded),
                        label: Text(
                          _pickedProof?.name ?? 'Lampirkan bukti transaksi',
                        ),
                      ),
                      if ((_existingProofName ?? '').isNotEmpty &&
                          _pickedProof == null)
                        FinanceBadge(
                          label: 'File lama: $_existingProofName',
                          color: AppTheme.secondaryColor,
                        ),
                    ],
                  ),
                ),
                if (_pickedProof != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${_pickedProof!.name} • ${Formatters.fileSize(_pickedProof!.size)}',
                      style: AppTheme.bodySmall,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          FinanceSectionCard(
            title: 'Ringkasan flow',
            subtitle: _requiresChecker
                ? 'Transaksi ini akan masuk status submitted dan menunggu checker.'
                : 'Transaksi ini akan langsung approved saat di-submit.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(
                  label: 'Saat disubmit',
                  value: _requiresChecker
                      ? 'Status menjadi submitted'
                      : 'Status menjadi approved',
                ),
                _InfoRow(
                  label: 'Publish',
                  value: 'Pengumuman kas tetap dipicu manual setelah approved.',
                ),
                _InfoRow(
                  label: 'Scope',
                  value: 'Pengumuman mengikuti yuridiksi unit transaksi.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSaving ? null : () => _save(false),
                  child: Text(isEditing ? 'Update Draft' : 'Simpan Draft'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _isSaving ? null : () => _save(true),
                  child: Text(
                    _isSaving
                        ? 'Menyimpan...'
                        : isEditing
                        ? 'Update & Submit'
                        : 'Simpan & Submit',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool get _requiresChecker =>
      _direction == 'out' ||
      (_direction == 'in' && _paymentMethod == 'transfer');

  Future<void> _pickProof() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
    );
    if (result == null || result.files.isEmpty) {
      return;
    }
    setState(() => _pickedProof = result.files.single);
  }

  Future<void> _save(bool submitAfterSave) async {
    final unitId = _selectedUnitId;
    final accountId = _selectedAccountId;
    final amount = int.tryParse(
      _amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
    );
    if ((unitId ?? '').isEmpty) {
      ErrorClassifier.showErrorSnackBar(
        context,
        Exception('Pilih unit transaksi terlebih dahulu.'),
      );
      return;
    }
    if ((accountId ?? '').isEmpty) {
      ErrorClassifier.showErrorSnackBar(
        context,
        Exception('Pilih akun kas terlebih dahulu.'),
      );
      return;
    }
    if (_categoryCtrl.text.trim().isEmpty || _titleCtrl.text.trim().isEmpty) {
      ErrorClassifier.showErrorSnackBar(
        context,
        Exception('Kategori dan judul transaksi wajib diisi.'),
      );
      return;
    }
    if (amount == null || amount <= 0) {
      ErrorClassifier.showErrorSnackBar(
        context,
        Exception('Nominal transaksi harus lebih besar dari 0.'),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      var transaction = await ref
          .read(financeServiceProvider)
          .saveDraftTransaction(
            transactionId: widget.transactionId,
            orgUnitId: unitId!,
            accountId: accountId!,
            direction: _direction,
            category: _categoryCtrl.text.trim(),
            title: _titleCtrl.text.trim(),
            amount: amount,
            paymentMethod: _paymentMethod,
            description: _descriptionCtrl.text.trim(),
            proofFile: _pickedProof,
          );
      if (submitAfterSave) {
        transaction = await ref
            .read(financeServiceProvider)
            .submitTransaction(transactionId: transaction.id);
      }

      ref.read(financeRefreshTickProvider.notifier).bump();
      if (!mounted) {
        return;
      }
      ErrorClassifier.showSuccessSnackBar(
        context,
        submitAfterSave
            ? 'Transaksi berhasil disimpan dan disubmit.'
            : 'Draft transaksi berhasil disimpan.',
      );
      context.pushReplacement(
        Routes.financeDetail.replaceFirst(':id', transaction.id),
      );
    } catch (error) {
      if (mounted) {
        ErrorClassifier.showErrorSnackBar(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: AppTheme.bodySmall)),
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
