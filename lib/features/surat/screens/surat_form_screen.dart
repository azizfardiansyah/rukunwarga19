// ignore_for_file: use_build_context_synchronously

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/pocketbase_service.dart';
import '../../../core/services/surat_service.dart';
import '../../../core/utils/error_classifier.dart';
import '../../../core/utils/formatters.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/models/surat_model.dart';
import '../../../shared/widgets/app_surface.dart';
import 'surat_list_screen.dart';

class SuratFormScreen extends ConsumerStatefulWidget {
  const SuratFormScreen({super.key, this.suratId});

  final String? suratId;

  @override
  ConsumerState<SuratFormScreen> createState() => _SuratFormScreenState();
}

class _SuratFormScreenState extends ConsumerState<SuratFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _purposeCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final Map<String, TextEditingController> _fieldControllers = {};

  String _selectedType = AppConstants.jenisSurat.first.code;
  bool _isLoading = false;
  bool _isLoadingExisting = false;
  bool _didLoadExisting = false;
  List<PlatformFile> _pickedAttachments = [];
  List<SuratAttachmentModel> _existingAttachments = [];

  @override
  void initState() {
    super.initState();
    _ensureControllersForType(_selectedType);
    if ((widget.suratId ?? '').isNotEmpty) {
      _loadExisting();
    }
  }

  @override
  void dispose() {
    _purposeCtrl.dispose();
    _notesCtrl.dispose();
    for (final controller in _fieldControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadExisting() async {
    if (_didLoadExisting || (widget.suratId ?? '').isEmpty) {
      return;
    }

    setState(() => _isLoadingExisting = true);
    try {
      final auth = ref.read(authProvider);
      final detail = await ref
          .read(suratServiceProvider)
          .getDetail(auth, widget.suratId!);
      final request = detail.request;

      _selectedType = request.jenisSurat;
      _ensureControllersForType(_selectedType);
      _purposeCtrl.text = request.purpose;
      _notesCtrl.text = request.applicantNote ?? '';

      for (final field in AppConstants.suratTypeOption(_selectedType).fields) {
        _fieldControllers[field.key]?.text =
            request.requestPayload[field.key]?.toString() ?? '';
      }

      _existingAttachments = detail.attachments;
      _didLoadExisting = true;
    } catch (error) {
      ErrorClassifier.showErrorSnackBar(context, error);
      context.pop();
    } finally {
      if (mounted) {
        setState(() => _isLoadingExisting = false);
      }
    }
  }

  void _ensureControllersForType(String typeCode) {
    final config = AppConstants.suratTypeOption(typeCode);
    for (final field in config.fields) {
      _fieldControllers.putIfAbsent(field.key, TextEditingController.new);
    }
  }

  Future<void> _pickDate(String key) async {
    final current = Formatters.parseTanggalInput(_fieldControllers[key]?.text);
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _fieldControllers[key]?.text = Formatters.tanggalInput(picked);
    });
  }

  Future<void> _pickAttachments() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return;
    }

    final validFiles = <PlatformFile>[];
    for (final file in result.files) {
      if (file.bytes == null || file.bytes!.isEmpty) {
        continue;
      }
      validFiles.add(file);
    }

    if (validFiles.isEmpty) {
      ErrorClassifier.showErrorSnackBar(
        context,
        StateError('Lampiran tidak dapat dibaca.'),
      );
      return;
    }

    setState(() {
      _pickedAttachments = [..._pickedAttachments, ...validFiles];
    });
  }

  Future<void> _openExistingAttachment(SuratAttachmentModel attachment) async {
    final fileName = attachment.file.trim();
    if (fileName.isEmpty) {
      ErrorClassifier.showErrorSnackBar(
        context,
        StateError('File lampiran tidak tersedia.'),
      );
      return;
    }

    final uri = Uri.tryParse(getFileUrl(attachment.record, fileName));
    if (uri == null) {
      ErrorClassifier.showErrorSnackBar(
        context,
        StateError('URL lampiran tidak valid.'),
      );
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ErrorClassifier.showErrorSnackBar(
        context,
        StateError('Lampiran tidak dapat dibuka.'),
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final dynamicValues = <String, String>{};
    final config = AppConstants.suratTypeOption(_selectedType);
    for (final field in config.fields) {
      dynamicValues[field.key] =
          _fieldControllers[field.key]?.text.trim() ?? '';
    }

    setState(() => _isLoading = true);
    try {
      final auth = ref.read(authProvider);
      final requestId = await ref
          .read(suratServiceProvider)
          .submitRequest(
            auth,
            SuratSubmitPayload(
              typeCode: _selectedType,
              purpose: _purposeCtrl.text.trim(),
              notes: _notesCtrl.text.trim(),
              dynamicValues: dynamicValues,
              requestId: widget.suratId,
              attachments: _pickedAttachments,
            ),
          );

      ref.invalidate(suratListProvider);
      ErrorClassifier.showSuccessSnackBar(
        context,
        widget.suratId == null
            ? 'Pengajuan surat berhasil dikirim.'
            : 'Pengajuan surat berhasil diperbarui.',
      );
      context.go('/surat/$requestId');
    } catch (error) {
      ErrorClassifier.showErrorSnackBar(context, error);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = AppConstants.suratTypeOption(_selectedType);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.suratId == null
              ? 'Ajukan Surat Pengantar'
              : 'Edit Pengajuan Surat Pengantar',
        ),
      ),
      body: AppPageBackground(
        child: _isLoadingExisting
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  children: [
                    AppHeroPanel(
                      eyebrow: AppConstants.suratCategoryLabel(config.category),
                      icon: Icons.assignment_outlined,
                      title: config.label,
                      subtitle: config.description,
                      chips: [
                        AppHeroBadge(
                          label: AppConstants.suratApprovalLabel(
                            config.approvalLevel,
                          ),
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.white.withValues(alpha: 0.16),
                          icon: Icons.route_outlined,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    AppSurfaceCard(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const AppSectionHeader(
                              title: 'Form Pengajuan Surat Pengantar',
                              subtitle:
                                  'Lengkapi data surat dan lampiran pendukung sesuai kebutuhan.',
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              initialValue: _selectedType,
                              decoration: const InputDecoration(
                                labelText: 'Jenis Surat',
                              ),
                              items: AppConstants.jenisSurat
                                  .map(
                                    (item) => DropdownMenuItem<String>(
                                      value: item.code,
                                      child: Text(item.label),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value == null) {
                                  return;
                                }
                                setState(() {
                                  _selectedType = value;
                                  _ensureControllersForType(value);
                                });
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _purposeCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Keperluan / Tujuan Surat',
                                helperText:
                                    'Tuliskan kebutuhan penggunaan surat secara ringkas.',
                              ),
                              minLines: 2,
                              maxLines: 3,
                              validator: (value) {
                                if ((value ?? '').trim().isEmpty) {
                                  return 'Keperluan surat wajib diisi.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            ..._buildDynamicFields(config),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _notesCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Catatan Pemohon',
                                helperText:
                                    'Opsional. Gunakan untuk menambahkan konteks tambahan kepada pengurus.',
                              ),
                              minLines: 2,
                              maxLines: 3,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppSurfaceCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppSectionHeader(
                            title: 'Lampiran',
                            subtitle:
                                'Tambahkan dokumen pendukung jika diperlukan untuk verifikasi.',
                            action: OutlinedButton.icon(
                              onPressed: _pickAttachments,
                              icon: const Icon(Icons.attach_file_rounded),
                              label: const Text('Pilih Lampiran'),
                            ),
                          ),
                          if (_existingAttachments.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Text(
                              'Lampiran sebelumnya',
                              style: AppTheme.bodySmall,
                            ),
                            const SizedBox(height: 8),
                            ..._existingAttachments.map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _AttachmentTile(
                                  label: item.label.isEmpty
                                      ? item.file
                                      : item.label,
                                  icon: Icons.description_outlined,
                                  onTap: () => _openExistingAttachment(item),
                                ),
                              ),
                            ),
                          ],
                          if (_pickedAttachments.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Text('Lampiran baru', style: AppTheme.bodySmall),
                            const SizedBox(height: 8),
                            ...List.generate(_pickedAttachments.length, (
                              index,
                            ) {
                              final file = _pickedAttachments[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _AttachmentTile(
                                  label: file.name,
                                  icon: Icons.upload_file_outlined,
                                  onRemove: () {
                                    setState(() {
                                      _pickedAttachments = _pickedAttachments
                                          .where((item) => item != file)
                                          .toList();
                                    });
                                  },
                                ),
                              );
                            }),
                          ],
                          if (_existingAttachments.isEmpty &&
                              _pickedAttachments.isEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              'Belum ada lampiran. Anda tetap bisa mengirim pengajuan tanpa lampiran jika jenis surat tidak mewajibkannya.',
                              style: AppTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isLoading ? null : () => context.pop(),
                            child: const Text('Batal'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: _isLoading ? null : _submit,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    widget.suratId == null
                                        ? 'Kirim Pengajuan'
                                        : 'Kirim Ulang Surat',
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  List<Widget> _buildDynamicFields(SuratTypeOption config) {
    final widgets = <Widget>[];
    for (final field in config.fields) {
      final controller = _fieldControllers[field.key]!;
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _DynamicFieldInput(
            option: field,
            controller: controller,
            onPickDate: field.inputKind == SuratFieldInputKind.date
                ? () => _pickDate(field.key)
                : null,
          ),
        ),
      );
    }
    return widgets;
  }
}

class _DynamicFieldInput extends StatelessWidget {
  const _DynamicFieldInput({
    required this.option,
    required this.controller,
    this.onPickDate,
  });

  final SuratFieldOption option;
  final TextEditingController controller;
  final VoidCallback? onPickDate;

  @override
  Widget build(BuildContext context) {
    final isDate = option.inputKind == SuratFieldInputKind.date;
    final isArea = option.inputKind == SuratFieldInputKind.textarea;
    final isNumber = option.inputKind == SuratFieldInputKind.number;

    return TextFormField(
      controller: controller,
      readOnly: isDate,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      minLines: isArea ? 2 : 1,
      maxLines: isArea ? 3 : 1,
      onTap: onPickDate,
      decoration: InputDecoration(
        labelText: option.label,
        helperText: option.hint.isEmpty ? null : option.hint,
        suffixIcon: isDate ? const Icon(Icons.calendar_today_outlined) : null,
      ),
      validator: (value) {
        if (!option.required) {
          return null;
        }
        if ((value ?? '').trim().isEmpty) {
          return '${option.label} wajib diisi.';
        }
        return null;
      },
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({
    required this.label,
    required this.icon,
    this.onTap,
    this.onRemove,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

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
              child: Text(
                label,
                style: AppTheme.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onRemove != null)
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded),
              )
            else if (onTap != null)
              const Icon(Icons.open_in_new_rounded, size: 18),
          ],
        ),
      ),
    );
  }
}

