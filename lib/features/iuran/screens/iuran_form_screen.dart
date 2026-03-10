import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/pocketbase_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/error_classifier.dart';
import '../../../shared/widgets/app_surface.dart';

class IuranFormScreen extends ConsumerStatefulWidget {
  const IuranFormScreen({super.key});

  @override
  ConsumerState<IuranFormScreen> createState() => _IuranFormScreenState();
}

class _IuranFormScreenState extends ConsumerState<IuranFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _jumlahCtrl = TextEditingController();
  final _keteranganCtrl = TextEditingController();
  bool _isLoading = false;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await pb.collection(AppConstants.colIuran).create(body: {
        'jumlah': int.tryParse(_jumlahCtrl.text) ?? 0,
        'status': AppConstants.iuranLunas,
        'tanggal_bayar': DateTime.now().toIso8601String(),
        'keterangan': _keteranganCtrl.text.trim(),
        'dicatat_oleh': pb.authStore.record?.id ?? '',
      });
      if (mounted) {
        ErrorClassifier.showSuccessSnackBar(context, 'Iuran berhasil dicatat');
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
    _jumlahCtrl.dispose();
    _keteranganCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Catat Iuran')),
      body: AppPageBackground(
        child: SingleChildScrollView(
          child: AppSurfaceCard(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AppSectionHeader(
                    title: 'Catat Pembayaran Iuran',
                    subtitle: 'Masukkan nominal dan keterangan pencatatan.',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _jumlahCtrl,
                    decoration: const InputDecoration(labelText: 'Jumlah (Rp)', prefixText: 'Rp '),
                    keyboardType: TextInputType.number,
                    validator: (v) => v == null || v.isEmpty ? 'Jumlah wajib diisi' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _keteranganCtrl,
                    decoration: const InputDecoration(labelText: 'Keterangan'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _isLoading ? null : _save,
                    child: _isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Simpan'),
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
