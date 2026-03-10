import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/pocketbase_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/error_classifier.dart';
import '../../../shared/widgets/app_surface.dart';

class SuratFormScreen extends ConsumerStatefulWidget {
  final String? suratId;
  const SuratFormScreen({super.key, this.suratId});

  @override
  ConsumerState<SuratFormScreen> createState() => _SuratFormScreenState();
}

class _SuratFormScreenState extends ConsumerState<SuratFormScreen> {
  final _formKey = GlobalKey<FormState>();
  String _jenis = AppConstants.jenisSurat.first;
  final _keperluanCtrl = TextEditingController();
  final _catatanCtrl = TextEditingController();
  bool _isLoading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await pb.collection(AppConstants.colSurat).create(body: {
        'jenis': _jenis,
        'keperluan': _keperluanCtrl.text.trim(),
        'catatan': _catatanCtrl.text.trim(),
        'status': AppConstants.suratPending,
        'warga': pb.authStore.record?.id ?? '',
      });
      if (mounted) {
        ErrorClassifier.showSuccessSnackBar(context, 'Surat berhasil diajukan');
        context.pop();
      }
    } catch (e) {
      if (mounted) ErrorClassifier.showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _keperluanCtrl.dispose();
    _catatanCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajukan Surat Pengantar')),
      body: AppPageBackground(
        child: SingleChildScrollView(
          child: AppSurfaceCard(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AppSectionHeader(
                    title: 'Form Pengajuan Surat',
                    subtitle: 'Lengkapi jenis surat dan keperluan pengajuan.',
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _jenis,
                    decoration: const InputDecoration(labelText: 'Jenis Surat'),
                    items: AppConstants.jenisSurat
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) => setState(() => _jenis = v!),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _keperluanCtrl,
                    decoration: const InputDecoration(labelText: 'Keperluan'),
                    maxLines: 3,
                    validator: (v) => v == null || v.isEmpty ? 'Keperluan wajib diisi' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _catatanCtrl,
                    decoration: const InputDecoration(labelText: 'Catatan (opsional)'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Ajukan Surat'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
