// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../app/router.dart';
import '../../../core/services/pocketbase_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/error_classifier.dart';
import '../../../core/utils/formatters.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../dashboard/screens/dashboard_screen.dart';

class KkFormScreen extends ConsumerStatefulWidget {
  final String? kkId;
  const KkFormScreen({super.key, this.kkId});

  @override
  ConsumerState<KkFormScreen> createState() => _KkFormScreenState();
}

class _KkFormScreenState extends ConsumerState<KkFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _noKkCtrl = TextEditingController();
  final _alamatCtrl = TextEditingController();
  final _rtCtrl = TextEditingController(text: '19');
  final _rwCtrl = TextEditingController(text: '19');
  bool _isLoading = false;

  @override
  void dispose() {
    _noKkCtrl.dispose();
    _alamatCtrl.dispose();
    _rtCtrl.dispose();
    _rwCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final auth = ref.read(authProvider);
      final userId = auth.user?.id;
      if (userId == null) throw Exception('User belum login');
      final noKk = _noKkCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
      // Cek duplikasi KK
      final existing = await pb.collection(AppConstants.colKartuKeluarga).getList(
        page: 1,
        perPage: 1,
        filter: 'no_kk = "$noKk" && user_id = "$userId"',
      );
      if (existing.items.isNotEmpty && widget.kkId == null) {
        if (mounted) {
          ErrorClassifier.showErrorSnackBar(context, 'KK sudah terdaftar');
        }
        setState(() => _isLoading = false);
        return;
      }
      final body = {
        'no_kk': noKk,
        'alamat': _alamatCtrl.text.trim(),
        'rt': _rtCtrl.text.trim(),
        'rw': _rwCtrl.text.trim(),
        'user_id': userId,
      };
      debugPrint('[DEBUG KK FORM] body: $body');
      if (widget.kkId != null) {
        await pb.collection(AppConstants.colKartuKeluarga).update(widget.kkId!, body: body);
      } else {
        await pb.collection(AppConstants.colKartuKeluarga).create(body: body);
      }
      if (mounted) {
        ErrorClassifier.showSuccessSnackBar(context, 'Data KK berhasil disimpan');
        ref.invalidate(hasKartuKeluargaProvider);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.go(Routes.dashboard);
        });
      }
    } catch (e) {
      debugPrint('[DEBUG KK FORM ERROR] $e');
      if (mounted) ErrorClassifier.showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.kkId != null ? 'Edit KK' : 'Tambah KK')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.paddingMedium),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _noKkCtrl,
                decoration: const InputDecoration(labelText: 'Nomor KK'),
                keyboardType: TextInputType.number,
                maxLength: 16,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'No KK wajib diisi';
                  if (!Formatters.isValidNoKk(v)) return 'No KK harus 16 digit';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _alamatCtrl,
                decoration: const InputDecoration(labelText: 'Alamat'),
                maxLines: 2,
                validator: (v) => v == null || v.isEmpty ? 'Alamat wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _rtCtrl,
                      decoration: const InputDecoration(labelText: 'RT'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _rwCtrl,
                      decoration: const InputDecoration(labelText: 'RW'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _save,
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Simpan'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        ref.invalidate(hasKartuKeluargaProvider);
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) context.go(Routes.dashboard);
                        });
                      },
                child: const Text('Batal'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
