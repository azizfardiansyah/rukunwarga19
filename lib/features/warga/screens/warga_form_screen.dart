// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../core/services/pocketbase_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/error_classifier.dart';
import '../../../core/utils/formatters.dart';

class WargaFormScreen extends ConsumerStatefulWidget {
  final String? wargaId;
  final String? initialNoKk;
  const WargaFormScreen({super.key, this.wargaId, this.initialNoKk});

  @override
  ConsumerState<WargaFormScreen> createState() => _WargaFormScreenState();
}

class _WargaFormScreenState extends ConsumerState<WargaFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nikCtrl = TextEditingController();
  final _noKkCtrl = TextEditingController();
  final _namaCtrl = TextEditingController();
  final _tempatLahirCtrl = TextEditingController();
  final _alamatCtrl = TextEditingController();
  final _rtCtrl = TextEditingController(text: '19');
  final _rwCtrl = TextEditingController(text: '19');
  final _noHpCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _pekerjaanCtrl = TextEditingController();
  DateTime? _tanggalLahir;
  String _jenisKelamin = 'Laki-laki';
  String _agama = 'Islam';
  String _statusPernikahan = 'Belum Menikah';
  String _hubungan = 'Anak'; // default
  bool _isLoading = false;
  bool _isEdit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if ((widget.initialNoKk ?? '').isNotEmpty) {
      _noKkCtrl.text = widget.initialNoKk!;
      return;
    }
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['no_kk'] != null) {
      _noKkCtrl.text = args['no_kk'].toString();
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.wargaId != null) {
      _isEdit = true;
      _loadData();
    }
  }

  Future<void> _loadData() async {
    try {
      final record =
          await pb.collection(AppConstants.colWarga).getOne(widget.wargaId!);
      setState(() {
        _nikCtrl.text = record.getStringValue('nik');
        _namaCtrl.text = record.getStringValue('nama_lengkap');
        _tempatLahirCtrl.text = record.getStringValue('tempat_lahir');
        _tanggalLahir =
            DateTime.tryParse(record.getStringValue('tanggal_lahir'));
        _jenisKelamin = record.getStringValue('jenis_kelamin');
        _agama = record.getStringValue('agama');
        _statusPernikahan = record.getStringValue('status_pernikahan');
        _pekerjaanCtrl.text = record.getStringValue('pekerjaan');
        _alamatCtrl.text = record.getStringValue('alamat');
        _rtCtrl.text = record.getStringValue('rt');
        _rwCtrl.text = record.getStringValue('rw');
        _noHpCtrl.text = record.getStringValue('no_hp');
        _emailCtrl.text = record.getStringValue('email');
      });
    } catch (e) {
      if (mounted) ErrorClassifier.showErrorSnackBar(context, e);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final userId = pb.authStore.record?.id;
      // Hapus validasi pengecekan user_id
      final body = {
        'nik': _nikCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
        'no_kk': _noKkCtrl.text.trim(),
        'nama_lengkap': _namaCtrl.text.trim(),
        'tempat_lahir': _tempatLahirCtrl.text.trim(),
        'tanggal_lahir': _tanggalLahir?.toIso8601String(),
        'jenis_kelamin': _jenisKelamin,
        'agama': _agama,
        'status_pernikahan': _statusPernikahan,
        'pekerjaan': _pekerjaanCtrl.text.trim(),
        'alamat': _alamatCtrl.text.trim(),
        'rt': _rtCtrl.text.trim(),
        'rw': _rwCtrl.text.trim(),
        'no_hp': _noHpCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'user_id': userId,
      };

      String wargaBaruId;
      if (_isEdit) {
        await pb.collection(AppConstants.colWarga).update(widget.wargaId!, body: body);
        wargaBaruId = widget.wargaId!;
      } else {
        final wargaRecord = await pb.collection(AppConstants.colWarga).create(body: body);
        wargaBaruId = wargaRecord.id;
        // Insert ke anggota_kk
        // Cari id KK milik user
        final kkList = await pb.collection(AppConstants.colKartuKeluarga).getList(
          page: 1,
          perPage: 1,
          filter: 'no_kk = "${_noKkCtrl.text.trim()}"',
        );
        if (kkList.items.isNotEmpty) {
          final kkId = kkList.items.first.id;
          await pb.collection(AppConstants.colAnggotaKk).create(body: {
            'no_kk': kkId,
            'warga': wargaBaruId,
            'hubungan_': _hubungan,
            'status': 'Aktif',
          });
        }
      }

      if (mounted) {
        ErrorClassifier.showSuccessSnackBar(
          context,
          _isEdit ? 'Data warga berhasil diperbarui' : 'Data warga berhasil ditambahkan',
        );
        Future.microtask(() => context.go('/'));
      }
    } catch (e) {
      if (mounted) ErrorClassifier.showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nikCtrl.dispose();
    _noKkCtrl.dispose();
    _namaCtrl.dispose();
    _tempatLahirCtrl.dispose();
    _alamatCtrl.dispose();
    _rtCtrl.dispose();
    _rwCtrl.dispose();
    _noHpCtrl.dispose();
    _emailCtrl.dispose();
    _pekerjaanCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Warga' : 'Tambah Warga'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.paddingMedium),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nikCtrl,
                decoration: const InputDecoration(labelText: 'NIK'),
                keyboardType: TextInputType.number,
                maxLength: 16,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'NIK wajib diisi';
                  if (!Formatters.isValidNik(v)) return 'NIK harus 16 digit';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _namaCtrl,
                decoration: const InputDecoration(labelText: 'Nama Lengkap'),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Nama wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _tempatLahirCtrl,
                decoration: const InputDecoration(labelText: 'Tempat Lahir'),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Tanggal Lahir'),
                subtitle: Text(
                  _tanggalLahir != null
                      ? Formatters.tanggalLengkap(_tanggalLahir!)
                      : 'Belum dipilih',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _tanggalLahir ?? DateTime(2000),
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) setState(() => _tanggalLahir = date);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _jenisKelamin,
                decoration: const InputDecoration(labelText: 'Jenis Kelamin'),
                items: AppConstants.jenisKelamin
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => _jenisKelamin = v!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _agama,
                decoration: const InputDecoration(labelText: 'Agama'),
                items: AppConstants.daftarAgama
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => _agama = v!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _statusPernikahan,
                decoration:
                    const InputDecoration(labelText: 'Status Pernikahan'),
                items: AppConstants.statusPernikahan
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => _statusPernikahan = v!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _pekerjaanCtrl,
                decoration: const InputDecoration(labelText: 'Pekerjaan'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _alamatCtrl,
                decoration: const InputDecoration(labelText: 'Alamat'),
                maxLines: 2,
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
              const SizedBox(height: 12),
              TextFormField(
                controller: _noHpCtrl,
                decoration: const InputDecoration(labelText: 'No. HP'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noKkCtrl,
                decoration: const InputDecoration(labelText: 'No KK'),
                readOnly: true,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _hubungan,
                decoration: const InputDecoration(labelText: 'Hubungan dalam KK'),
                items: ['Ayah', 'Ibu', 'Anak', 'Kakak', 'Adik']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => _hubungan = v!),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _save,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(_isEdit ? 'Simpan Perubahan' : 'Tambah Warga'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


