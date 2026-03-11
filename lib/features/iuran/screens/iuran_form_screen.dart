import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/iuran_service.dart';
import '../../../core/utils/error_classifier.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/iuran_model.dart';
import '../../../shared/widgets/app_surface.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/iuran_providers.dart';

class IuranFormScreen extends ConsumerStatefulWidget {
  const IuranFormScreen({super.key});

  @override
  ConsumerState<IuranFormScreen> createState() => _IuranFormScreenState();
}

class _IuranFormScreenState extends ConsumerState<IuranFormScreen>
    with SingleTickerProviderStateMixin {
  final _periodFormKey = GlobalKey<FormState>();
  final _typeFormKey = GlobalKey<FormState>();

  final _periodTitleCtrl = TextEditingController();
  final _periodDescriptionCtrl = TextEditingController();
  final _periodAmountCtrl = TextEditingController();
  final _typeLabelCtrl = TextEditingController();
  final _typeDescriptionCtrl = TextEditingController();
  final _typeAmountCtrl = TextEditingController();

  final Map<String, TextEditingController> _overrideControllers = {};

  DateTime? _dueDate;
  String _periodFrequency = AppConstants.iuranFrequencyBulanan;
  String _typeFrequency = AppConstants.iuranFrequencyBulanan;
  String? _selectedTypeId;
  bool _targetAllScope = true;
  bool _typeActive = true;
  bool _submittingPeriod = false;
  bool _submittingType = false;
  final Set<String> _selectedTargetIds = <String>{};

  @override
  void dispose() {
    _periodTitleCtrl.dispose();
    _periodDescriptionCtrl.dispose();
    _periodAmountCtrl.dispose();
    _typeLabelCtrl.dispose();
    _typeDescriptionCtrl.dispose();
    _typeAmountCtrl.dispose();
    for (final controller in _overrideControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    if (!auth.isOperator && !auth.isSysadmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Kelola Iuran')),
        body: const AppPageBackground(
          child: AppEmptyState(
            icon: Icons.lock_outline_rounded,
            title: 'Akses ditolak',
            message: 'Hanya admin yang dapat membuat dan mengelola iuran.',
          ),
        ),
      );
    }

    final optionsAsync = ref.watch(iuranFormOptionsProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Kelola Iuran'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Periode'),
              Tab(text: 'Jenis Iuran'),
            ],
          ),
        ),
        body: AppPageBackground(
          child: optionsAsync.when(
            data: (options) => TabBarView(
              children: [
                _buildPeriodTab(context, auth, options),
                _buildTypeTab(context, auth),
              ],
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
                      onPressed: () => ref.invalidate(iuranFormOptionsProvider),
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodTab(
    BuildContext context,
    AuthState auth,
    IuranFormOptions options,
  ) {
    if (_selectedTypeId == null && options.types.isNotEmpty) {
      final firstType = options.types.first;
      _selectedTypeId = firstType.id;
      _periodFrequency = firstType.defaultFrequency;
      if (_periodAmountCtrl.text.trim().isEmpty &&
          firstType.defaultAmount > 0) {
        _setCurrencyText(_periodAmountCtrl, firstType.defaultAmount);
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Form(
        key: _periodFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppHeroPanel(
              eyebrow: 'Periode Iuran',
              icon: Icons.calendar_month_rounded,
              title: 'Generate tagihan per KK',
              subtitle:
                  'Buat satu periode, pilih target KK, lalu sistem akan membuat tagihan penuh sesuai nominal yang Anda tetapkan.',
            ),
            const SizedBox(height: 16),
            AppSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppSectionHeader(
                    title: 'Detail Periode',
                    subtitle:
                        'Nominal bisa diubah per periode dan dapat dioverride untuk KK tertentu.',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _periodTitleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nama Periode',
                      hintText: 'Contoh: Iuran Kebersihan April 2026',
                    ),
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? 'Nama periode wajib diisi'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey('period-type-$_selectedTypeId'),
                    initialValue: _selectedTypeId,
                    decoration: const InputDecoration(labelText: 'Jenis Iuran'),
                    items: options.types
                        .map(
                          (type) => DropdownMenuItem(
                            value: type.id,
                            child: Text(type.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      IuranTypeModel? selected;
                      for (final type in options.types) {
                        if (type.id == value) {
                          selected = type;
                          break;
                        }
                      }
                      setState(() {
                        _selectedTypeId = value;
                        if (selected != null) {
                          _periodFrequency = selected.defaultFrequency;
                          final currentAmount = _parseCurrencyText(
                            _periodAmountCtrl.text,
                          );
                          if (currentAmount == null || currentAmount == 0) {
                            _setCurrencyText(
                              _periodAmountCtrl,
                              selected.defaultAmount,
                            );
                          }
                        }
                      });
                    },
                    validator: (value) =>
                        value == null ? 'Pilih jenis iuran' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          key: ValueKey('period-frequency-$_periodFrequency'),
                          initialValue: _periodFrequency,
                          decoration: const InputDecoration(
                            labelText: 'Frekuensi',
                          ),
                          items: AppConstants.iuranFrequencies
                              .map(
                                (frequency) => DropdownMenuItem(
                                  value: frequency,
                                  child: Text(
                                    AppConstants.iuranFrequencyLabel(frequency),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) => setState(
                            () => _periodFrequency =
                                value ?? AppConstants.iuranFrequencyBulanan,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _periodAmountCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Nominal Default',
                            hintText: 'Rp 20.000',
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: const [_RupiahInputFormatter()],
                          validator: (value) {
                            final amount = _parseCurrencyText(value);
                            if (amount == null || amount <= 0) {
                              return 'Nominal wajib diisi';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: _pickDueDate,
                    borderRadius: BorderRadius.circular(14),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Jatuh Tempo',
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.event_rounded, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _dueDate == null
                                  ? 'Pilih tanggal jatuh tempo'
                                  : Formatters.tanggalPendek(_dueDate!),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _periodDescriptionCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Catatan Periode',
                      hintText:
                          'Opsional, misalnya periode pembayaran atau info tambahan',
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppSectionHeader(
                    title: 'Target Tagihan',
                    subtitle:
                        'Pilih semua KK dalam scope admin, atau tentukan KK tertentu dengan override nominal.',
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('Semua Scope')),
                      ButtonSegment(value: false, label: Text('KK Tertentu')),
                    ],
                    selected: {_targetAllScope},
                    onSelectionChanged: (selection) =>
                        setState(() => _targetAllScope = selection.first),
                  ),
                  const SizedBox(height: 16),
                  if (_targetAllScope)
                    Text(
                      'Semua ${options.targets.length} KK yang berada dalam scope akses Anda akan dibuatkan tagihan.',
                      style: AppTheme.bodySmall,
                    )
                  else
                    _buildTargetSelector(options.targets),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submittingPeriod
                    ? null
                    : () => _submitPeriod(auth, options),
                child: _submittingPeriod
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Generate Tagihan Iuran'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetSelector(List<IuranKkOption> targets) {
    if (targets.isEmpty) {
      return Text(
        'Tidak ada data KK dalam scope Anda.',
        style: AppTheme.bodySmall.copyWith(color: AppTheme.errorColor),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 320),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: targets.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final option = targets[index];
          final selected = _selectedTargetIds.contains(option.kk.id);
          final overrideCtrl = _overrideControllers.putIfAbsent(
            option.kk.id,
            TextEditingController.new,
          );
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? AppTheme.primaryColor.withValues(alpha: 0.24)
                    : AppTheme.dividerColor,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CheckboxListTile(
                  value: selected,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(option.label, style: AppTheme.bodyMedium),
                  subtitle: Text(
                    'RT ${option.kk.rt} / RW ${option.kk.rw}',
                    style: AppTheme.caption,
                  ),
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _selectedTargetIds.add(option.kk.id);
                      } else {
                        _selectedTargetIds.remove(option.kk.id);
                        overrideCtrl.clear();
                      }
                    });
                  },
                ),
                if (selected)
                  TextField(
                    controller: overrideCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: const [_RupiahInputFormatter()],
                    decoration: const InputDecoration(
                      labelText: 'Override nominal',
                      hintText: 'Rp 20.000',
                      helperText:
                          'Kosongkan jika mengikuti nominal default periode.',
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTypeTab(BuildContext context, AuthState auth) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Form(
        key: _typeFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppHeroPanel(
              eyebrow: 'Jenis Iuran',
              icon: Icons.category_outlined,
              title: 'Kelola master jenis iuran',
              subtitle:
                  'Tambahkan jenis iuran yang akan dipakai di periode berikutnya, misalnya kebersihan, keamanan, atau kegiatan warga.',
            ),
            const SizedBox(height: 16),
            AppSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppSectionHeader(
                    title: 'Tambah Jenis Iuran',
                    subtitle:
                        'Nominal default ini hanya sebagai saran. Saat membuat periode, admin tetap bisa mengganti nominal.',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _typeLabelCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nama Jenis Iuran',
                      hintText: 'Contoh: Iuran Kebersihan',
                    ),
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? 'Nama jenis wajib diisi'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          key: ValueKey('type-frequency-$_typeFrequency'),
                          initialValue: _typeFrequency,
                          decoration: const InputDecoration(
                            labelText: 'Frekuensi Default',
                          ),
                          items: AppConstants.iuranFrequencies
                              .map(
                                (frequency) => DropdownMenuItem(
                                  value: frequency,
                                  child: Text(
                                    AppConstants.iuranFrequencyLabel(frequency),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) => setState(
                            () => _typeFrequency =
                                value ?? AppConstants.iuranFrequencyBulanan,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _typeAmountCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Nominal Default',
                            hintText: 'Rp 20.000',
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: const [_RupiahInputFormatter()],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _typeDescriptionCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Deskripsi',
                      hintText:
                          'Opsional, misalnya untuk keamanan malam atau kas sosial',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: _typeActive,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Aktifkan jenis iuran ini'),
                    subtitle: const Text(
                      'Jenis aktif langsung bisa dipakai saat membuat periode.',
                    ),
                    onChanged: (value) => setState(() => _typeActive = value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submittingType ? null : () => _submitType(auth),
                child: _submittingType
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Simpan Jenis Iuran'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _submitPeriod(AuthState auth, IuranFormOptions options) async {
    if (!_periodFormKey.currentState!.validate()) {
      return;
    }
    if (_selectedTypeId == null) {
      ErrorClassifier.showErrorSnackBar(
        context,
        Exception('Pilih jenis iuran terlebih dahulu.'),
      );
      return;
    }
    if (_dueDate == null) {
      ErrorClassifier.showErrorSnackBar(
        context,
        Exception('Tanggal jatuh tempo wajib dipilih.'),
      );
      return;
    }
    if (!_targetAllScope && _selectedTargetIds.isEmpty) {
      ErrorClassifier.showErrorSnackBar(
        context,
        Exception('Pilih minimal satu KK target.'),
      );
      return;
    }

    final targets = _selectedTargetIds.map((kkId) {
      final overrideAmount = _parseCurrencyText(
        _overrideControllers[kkId]?.text.trim(),
      );
      return IuranPeriodTarget(kkId: kkId, overrideAmount: overrideAmount);
    }).toList();

    setState(() => _submittingPeriod = true);
    try {
      await ref
          .read(iuranServiceProvider)
          .createPeriod(
            auth,
            IuranPeriodSubmitPayload(
              typeId: _selectedTypeId!,
              title: _periodTitleCtrl.text.trim(),
              frequency: _periodFrequency,
              defaultAmount: _parseCurrencyText(_periodAmountCtrl.text) ?? 0,
              dueDate: _dueDate!,
              targetAllScope: _targetAllScope,
              description: _periodDescriptionCtrl.text.trim(),
              targets: targets,
            ),
          );
      if (!mounted) return;
      ref.read(iuranRefreshTickProvider.notifier).bump();
      ErrorClassifier.showSuccessSnackBar(
        context,
        'Periode iuran berhasil dibuat dan tagihan sudah digenerate.',
      );
      context.pop();
    } catch (error) {
      if (mounted) {
        ErrorClassifier.showErrorSnackBar(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _submittingPeriod = false);
      }
    }
  }

  Future<void> _submitType(AuthState auth) async {
    if (!_typeFormKey.currentState!.validate()) {
      return;
    }
    setState(() => _submittingType = true);
    try {
      await ref
          .read(iuranServiceProvider)
          .createType(
            auth,
            IuranTypeSubmitPayload(
              label: _typeLabelCtrl.text.trim(),
              description: _typeDescriptionCtrl.text.trim(),
              defaultAmount: _parseCurrencyText(_typeAmountCtrl.text) ?? 0,
              defaultFrequency: _typeFrequency,
              isActive: _typeActive,
            ),
          );
      if (!mounted) return;
      ref.invalidate(iuranFormOptionsProvider);
      _typeLabelCtrl.clear();
      _typeDescriptionCtrl.clear();
      _typeAmountCtrl.clear();
      setState(() => _typeActive = true);
      ErrorClassifier.showSuccessSnackBar(
        context,
        'Jenis iuran berhasil ditambahkan.',
      );
    } catch (error) {
      if (mounted) {
        ErrorClassifier.showErrorSnackBar(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _submittingType = false);
      }
    }
  }

  int? _parseCurrencyText(String? raw) {
    final parsed = Formatters.parseRupiah(raw);
    return parsed?.toInt();
  }

  void _setCurrencyText(TextEditingController controller, int amount) {
    controller.value = TextEditingValue(
      text: Formatters.rupiah(amount),
      selection: TextSelection.collapsed(
        offset: Formatters.rupiah(amount).length,
      ),
    );
  }
}

class _RupiahInputFormatter extends TextInputFormatter {
  const _RupiahInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(text: '');
    }

    final amount = int.tryParse(digits) ?? 0;
    final formatted = Formatters.rupiah(amount);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
