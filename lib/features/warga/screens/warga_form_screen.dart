// ignore_for_file: use_build_context_synchronously

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/pocketbase_service.dart';
import '../../../core/utils/error_classifier.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../../../shared/widgets/app_surface.dart';

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
  final _rtCtrl = TextEditingController();
  final _rwCtrl = TextEditingController();
  final _noHpCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _pekerjaanCtrl = TextEditingController();
  final _pendidikanCtrl = TextEditingController();
  final _golonganDarahCtrl = TextEditingController();

  DateTime? _tanggalLahir;
  String _jenisKelamin = 'Laki-laki';
  String _agama = 'Islam';
  String _statusPernikahan = 'Belum Menikah';
  String _hubungan = 'Anak';
  String _linkedUserId = '';
  String? _anggotaKkId;

  bool _isEdit = false;
  bool _isLoading = false;
  bool _didInitKkContext = false;

  RecordModel? _wargaRecord;
  RecordModel? _userRecord;
  String? _existingFotoKtp;
  String? _existingFotoWarga;
  String? _existingAvatar;
  Uint8List? _fotoKtpBytes;
  String? _fotoKtpFilename;
  Uint8List? _fotoWargaBytes;
  String? _fotoWargaFilename;

  @override
  void initState() {
    super.initState();
    if (widget.wargaId != null) {
      _isEdit = true;
      _loadData();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isEdit || _didInitKkContext) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    final noKkFromArgs = args is Map && args['no_kk'] != null
        ? args['no_kk'].toString()
        : '';
    final noKkId = (widget.initialNoKk ?? '').trim().isNotEmpty
        ? widget.initialNoKk!.trim()
        : noKkFromArgs;
    if (noKkId.isNotEmpty) {
      _noKkCtrl.text = noKkId;
      _prefillFromKk(noKkId);
    }
    _didInitKkContext = true;
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
    _pendidikanCtrl.dispose();
    _golonganDarahCtrl.dispose();
    super.dispose();
  }

  Future<void> _prefillFromKk(String kkId) async {
    try {
      final kkRecord = await pb
          .collection(AppConstants.colKartuKeluarga)
          .getOne(kkId);
      if (!mounted || _isEdit) return;
      setState(() {
        if (_alamatCtrl.text.trim().isEmpty) {
          _alamatCtrl.text = kkRecord.getStringValue('alamat');
        }
        if (_rtCtrl.text.trim().isEmpty) {
          _rtCtrl.text = kkRecord.getStringValue('rt');
        }
        if (_rwCtrl.text.trim().isEmpty) {
          _rwCtrl.text = kkRecord.getStringValue('rw');
        }
      });
    } catch (_) {}
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final record = await pb
          .collection(AppConstants.colWarga)
          .getOne(widget.wargaId!);
      final auth = ref.read(authProvider);
      final ownerUserId = record.getStringValue('user_id');
      if (!auth.isAdmin &&
          auth.user?.id != null &&
          ownerUserId.isNotEmpty &&
          ownerUserId != auth.user!.id) {
        throw Exception('Anda tidak memiliki akses untuk mengubah data ini.');
      }

      final anggotaResult = await pb
          .collection(AppConstants.colAnggotaKk)
          .getList(page: 1, perPage: 1, filter: 'warga = "${widget.wargaId!}"');

      RecordModel? userRecord;
      if (ownerUserId.isNotEmpty) {
        try {
          userRecord = await pb
              .collection(AppConstants.colUsers)
              .getOne(ownerUserId);
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _wargaRecord = record;
        _userRecord = userRecord;
        _linkedUserId = ownerUserId;
        _noKkCtrl.text = record.getStringValue('no_kk');
        _nikCtrl.text = record.getStringValue('nik');
        _namaCtrl.text = record.getStringValue('nama_lengkap');
        _tempatLahirCtrl.text = record.getStringValue('tempat_lahir');
        _tanggalLahir = DateTime.tryParse(
          record.getStringValue('tanggal_lahir'),
        );
        _jenisKelamin = record.getStringValue('jenis_kelamin').isEmpty
            ? 'Laki-laki'
            : record.getStringValue('jenis_kelamin');
        _agama = record.getStringValue('agama').isEmpty
            ? 'Islam'
            : record.getStringValue('agama');
        _statusPernikahan = record.getStringValue('status_pernikahan').isEmpty
            ? 'Belum Menikah'
            : record.getStringValue('status_pernikahan');
        _alamatCtrl.text = record.getStringValue('alamat');
        _rtCtrl.text = record.getStringValue('rt');
        _rwCtrl.text = record.getStringValue('rw');
        _noHpCtrl.text = record.data['no_hp']?.toString() ?? '';
        _emailCtrl.text = record.getStringValue('email');
        _pekerjaanCtrl.text = record.getStringValue('pekerjaan');
        _pendidikanCtrl.text = record.getStringValue('pendidikan');
        _golonganDarahCtrl.text = record.getStringValue('golongan_darah');
        _existingFotoKtp = record.getStringValue('foto_ktp');
        _existingFotoWarga = record.getStringValue('foto_warga');
        _existingAvatar = userRecord?.getStringValue('avatar');
        if (anggotaResult.items.isNotEmpty) {
          _anggotaKkId = anggotaResult.items.first.id;
          _hubungan = anggotaResult.items.first.getStringValue('hubungan');
        }
      });
    } catch (e) {
      if (mounted) ErrorClassifier.showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage(bool isKtp) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null || file.bytes!.isEmpty) {
      AppToast.error(context, 'Gagal membaca file gambar.');
      return;
    }
    setState(() {
      if (isKtp) {
        _fotoKtpBytes = file.bytes;
        _fotoKtpFilename = file.name;
      } else {
        _fotoWargaBytes = file.bytes;
        _fotoWargaFilename = file.name;
      }
    });
  }

  Future<void> _createAnggotaKk({
    required String kkId,
    required String wargaId,
    required String hubungan,
  }) async {
    await pb
        .collection(AppConstants.colAnggotaKk)
        .create(
          body: {
            'no_kk': kkId,
            'warga': wargaId,
            'hubungan': hubungan,
            'status': 'Aktif',
          },
        );
  }

  Future<String?> _syncAvatar(String userId) async {
    if (_fotoWargaBytes == null ||
        (_fotoWargaFilename ?? '').isEmpty ||
        userId.isEmpty) {
      return null;
    }
    try {
      await pb
          .collection(AppConstants.colUsers)
          .update(
            userId,
            body: {'name': _namaCtrl.text.trim()},
            files: [
              http.MultipartFile.fromBytes(
                'avatar',
                _fotoWargaBytes!,
                filename: _fotoWargaFilename,
              ),
            ],
          );
      if (ref.read(authProvider).user?.id == userId) {
        await ref.read(authProvider.notifier).refreshAuth();
      }
      return null;
    } catch (e) {
      debugPrint('[WARGA FORM] Avatar sync gagal: $e');
      return 'Foto warga tersimpan, tetapi avatar user belum berhasil disinkronkan.';
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      AppToast.warning(context, 'Periksa kembali data yang diisi.');
      return;
    }
    if (_noKkCtrl.text.trim().isEmpty) {
      AppToast.warning(context, 'Pilih KK dulu sebelum menyimpan.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final authState = ref.read(authProvider);
      final authUserId = authState.user?.id ?? '';
      final rt = int.tryParse(_rtCtrl.text.trim());
      final rw = int.tryParse(_rwCtrl.text.trim());
      final noHpRaw = _noHpCtrl.text.trim();
      final noHp = noHpRaw.isEmpty ? null : int.tryParse(noHpRaw);
      if (rt == null || rw == null || rt == 0 || rw == 0) {
        throw Exception('RT/RW harus berupa angka dan tidak boleh 0.');
      }
      if (noHpRaw.isNotEmpty && noHp == null) {
        throw Exception('No. HP harus berupa angka.');
      }

      final linkedUserId = _linkedUserId.trim().isNotEmpty
          ? _linkedUserId.trim()
          : (!authState.isAdmin ? authUserId : '');
      final body = <String, dynamic>{
        'nik': _nikCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
        'no_kk': _noKkCtrl.text.trim(),
        'nama_lengkap': _namaCtrl.text.trim(),
        'tempat_lahir': _tempatLahirCtrl.text.trim(),
        'tanggal_lahir': _tanggalLahir?.toIso8601String(),
        'jenis_kelamin': _jenisKelamin,
        'agama': _agama,
        'status_pernikahan': _statusPernikahan,
        'pekerjaan': _pekerjaanCtrl.text.trim(),
        'pendidikan': _pendidikanCtrl.text.trim(),
        'golongan_darah': _golonganDarahCtrl.text.trim(),
        'alamat': _alamatCtrl.text.trim(),
        'rt': rt,
        'rw': rw,
        'no_hp': noHp,
        'email': _emailCtrl.text.trim(),
      };
      if (linkedUserId.isNotEmpty) body['user_id'] = linkedUserId;

      final files = <http.MultipartFile>[];
      if (_fotoKtpBytes != null && (_fotoKtpFilename ?? '').isNotEmpty) {
        files.add(
          http.MultipartFile.fromBytes(
            'foto_ktp',
            _fotoKtpBytes!,
            filename: _fotoKtpFilename,
          ),
        );
      }
      if (_fotoWargaBytes != null && (_fotoWargaFilename ?? '').isNotEmpty) {
        files.add(
          http.MultipartFile.fromBytes(
            'foto_warga',
            _fotoWargaBytes!,
            filename: _fotoWargaFilename,
          ),
        );
      }

      final wargaRecord = _isEdit
          ? await pb
                .collection(AppConstants.colWarga)
                .update(widget.wargaId!, body: body, files: files)
          : await pb
                .collection(AppConstants.colWarga)
                .create(body: body, files: files);

      if (_isEdit) {
        if ((_anggotaKkId ?? '').isNotEmpty) {
          await pb
              .collection(AppConstants.colAnggotaKk)
              .update(
                _anggotaKkId!,
                body: {'no_kk': _noKkCtrl.text.trim(), 'hubungan': _hubungan},
              );
        }
      } else {
        await _createAnggotaKk(
          kkId: _noKkCtrl.text.trim(),
          wargaId: wargaRecord.id,
          hubungan: _hubungan,
        );
      }

      final avatarSyncMessage = await _syncAvatar(
        wargaRecord.getStringValue('user_id'),
      );

      if (mounted) {
        AppToast.success(
          context,
          avatarSyncMessage ??
              (_isEdit
                  ? 'Data warga berhasil diperbarui'
                  : 'Data warga berhasil ditambahkan'),
        );
        if (context.canPop()) {
          context.pop(true);
        } else {
          context.go(Routes.warga);
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, ErrorClassifier.classify(e).message);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localTheme = Theme.of(context);
    final isDark = AppTheme.isDark(context);
    final formTheme = localTheme.copyWith(
      inputDecorationTheme: localTheme.inputDecorationTheme.copyWith(
        fillColor: isDark
            ? AppTheme.darkSurfaceRaised
            : AppTheme.cardColorFor(context),
        labelStyle: AppTheme.bodySmall.copyWith(
          color: AppTheme.secondaryTextFor(context),
        ),
        floatingLabelStyle: AppTheme.bodySmall.copyWith(
          color: isDark ? AppTheme.primaryLight : AppTheme.primaryColor,
          fontWeight: FontWeight.w700,
        ),
        prefixIconColor: AppTheme.secondaryTextFor(context),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Warga' : 'Tambah Warga')),
      body: AppPageBackground(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: _isEdit && _wargaRecord == null && _isLoading
            ? const _WargaFormSkeleton()
            : Theme(
          data: formTheme,
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _hero(context),
                  const SizedBox(height: 16),
                  _section(
                    context: context,
                    title: 'Identitas Warga',
                    icon: Icons.badge_rounded,
                    child: Column(
                      children: [
                        _field(
                          _nikCtrl,
                          'NIK',
                          Icons.credit_card_rounded,
                          keyboardType: TextInputType.number,
                          maxLength: 16,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'NIK wajib diisi';
                            }
                            if (!Formatters.isValidNik(value)) {
                              return 'NIK harus 16 digit';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        _field(
                          _namaCtrl,
                          'Nama Lengkap',
                          Icons.person_outline_rounded,
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Nama wajib diisi'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _field(
                                _tempatLahirCtrl,
                                'Tempat Lahir',
                                Icons.location_city_rounded,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: _dateCard()),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _drop(
                                'Jenis Kelamin',
                                Icons.wc_rounded,
                                _jenisKelamin,
                                AppConstants.jenisKelamin,
                                (value) =>
                                    setState(() => _jenisKelamin = value!),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _drop(
                                'Hubungan KK',
                                Icons.family_restroom_rounded,
                                _hubungan,
                                AppConstants.hubunganKeluarga,
                                (value) => setState(() => _hubungan = value!),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _drop(
                                'Agama',
                                Icons.auto_awesome_rounded,
                                _agama,
                                AppConstants.daftarAgama,
                                (value) => setState(() => _agama = value!),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _drop(
                                'Status Pernikahan',
                                Icons.favorite_border_rounded,
                                _statusPernikahan,
                                AppConstants.statusPernikahan,
                                (value) =>
                                    setState(() => _statusPernikahan = value!),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _field(
                                _pendidikanCtrl,
                                'Pendidikan',
                                Icons.school_rounded,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _field(
                                _golonganDarahCtrl,
                                'Golongan Darah',
                                Icons.water_drop_rounded,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _field(
                          _pekerjaanCtrl,
                          'Pekerjaan',
                          Icons.work_outline_rounded,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _section(
                    context: context,
                    title: 'Alamat & Kontak',
                    icon: Icons.home_rounded,
                    child: Column(
                      children: [
                        _field(
                          _alamatCtrl,
                          'Alamat',
                          Icons.pin_drop_outlined,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _field(
                                _rtCtrl,
                                'RT',
                                Icons.tag_rounded,
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  final number = int.tryParse(
                                    (value ?? '').trim(),
                                  );
                                  return number == null || number == 0
                                      ? 'RT tidak valid'
                                      : null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _field(
                                _rwCtrl,
                                'RW',
                                Icons.tag_rounded,
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  final number = int.tryParse(
                                    (value ?? '').trim(),
                                  );
                                  return number == null || number == 0
                                      ? 'RW tidak valid'
                                      : null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _field(
                                _noHpCtrl,
                                'No. HP',
                                Icons.phone_rounded,
                                keyboardType: TextInputType.phone,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _field(
                                _emailCtrl,
                                'Email',
                                Icons.mail_outline_rounded,
                                keyboardType: TextInputType.emailAddress,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _field(
                          _noKkCtrl,
                          'ID Kartu Keluarga',
                          Icons.credit_card_rounded,
                          readOnly: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _section(
                    context: context,
                    title: 'Dokumen & Foto',
                    icon: Icons.photo_library_rounded,
                    child: Column(
                      children: [
                        _noteBox(),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _uploadCard(
                                title: 'Foto Warga',
                                subtitle: 'Sinkron ke avatar user',
                                imageMemory: _fotoWargaBytes,
                                imageUrl: _fotoWargaBytes == null
                                    ? _wargaPhotoUrl()
                                    : null,
                                icon: Icons.person_rounded,
                                onPick: () => _pickImage(false),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _uploadCard(
                                title: 'Foto KTP',
                                subtitle: 'Lampiran identitas',
                                imageMemory: _fotoKtpBytes,
                                imageUrl: _fotoKtpBytes == null
                                    ? _ktpPhotoUrl()
                                    : null,
                                icon: Icons.badge_outlined,
                                onPick: () => _pickImage(true),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _isLoading ? null : _save,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    icon: _isLoading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            _isEdit
                                ? Icons.save_rounded
                                : Icons.person_add_alt_1_rounded,
                          ),
                    label: Text(
                      _isLoading
                          ? 'Menyimpan...'
                          : _isEdit
                              ? 'Simpan Perubahan'
                              : 'Tambah Warga',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _hero(BuildContext context) => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          AppTheme.primaryColor.withValues(alpha: 0.95),
          AppTheme.primaryLight.withValues(alpha: 0.92),
          AppTheme.secondaryColor.withValues(alpha: 0.86),
        ],
      ),
      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      border: Border.all(
        color: Colors.white.withValues(
          alpha: AppTheme.isDark(context) ? 0.08 : 0.18,
        ),
      ),
    ),
    child: Container(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.account_box_rounded,
              size: 30,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEdit ? 'Perbarui Data Warga' : 'Tambah Data Warga',
                  style: AppTheme.heading2.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  'Form tambah dan edit warga sekarang memakai field yang sama agar lebih konsisten.',
                  style: AppTheme.bodySmall.copyWith(
                    color: Colors.white.withValues(alpha: 0.84),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _section({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Widget child,
  }) => AppSurfaceCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 18, color: AppTheme.primaryColor),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: AppTheme.heading3.copyWith(
                color: AppTheme.primaryTextFor(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        child,
      ],
    ),
  );

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    int? maxLength,
    int maxLines = 1,
    bool readOnly = false,
    String? Function(String?)? validator,
  }) => TextFormField(
    controller: controller,
    style: AppTheme.bodyMedium.copyWith(
      color: AppTheme.primaryTextFor(context),
    ),
    keyboardType: keyboardType,
    maxLength: maxLength,
    maxLines: maxLines,
    readOnly: readOnly,
    validator: validator,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      counterText: '',
    ),
  );

  Widget _drop(
    String label,
    IconData icon,
    String value,
    List<String> items,
    void Function(String?) onChanged,
  ) => DropdownButtonFormField<String>(
    initialValue: items.contains(value) ? value : items.first,
    isExpanded: true,
    menuMaxHeight: 320,
    onChanged: onChanged,
    decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
    style: AppTheme.bodyMedium.copyWith(
      color: AppTheme.primaryTextFor(context),
    ),
    selectedItemBuilder: (context) => items
        .map(
          (item) => Align(
            alignment: Alignment.centerLeft,
            child: Text(
              item,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.primaryTextFor(context),
              ),
            ),
          ),
        )
        .toList(),
    items: items
        .map(
          (item) => DropdownMenuItem(
            value: item,
            child: Text(item, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        )
        .toList(),
  );

  Widget _dateCard() => InkWell(
    onTap: () async {
      final date = await showDatePicker(
        context: context,
        initialDate: _tanggalLahir ?? DateTime(2000),
        firstDate: DateTime(1900),
        lastDate: DateTime.now(),
      );
      if (date != null) setState(() => _tanggalLahir = date);
    },
    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
    child: InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Tanggal Lahir',
        prefixIcon: Icon(Icons.calendar_today_rounded),
      ),
      child: Text(
        _tanggalLahir == null
            ? 'Pilih tanggal'
            : Formatters.tanggalLengkap(_tanggalLahir!),
        style: AppTheme.bodyMedium.copyWith(
          color: _tanggalLahir == null
              ? AppTheme.secondaryTextFor(context)
              : AppTheme.primaryTextFor(context),
        ),
      ),
    ),
  );

  Widget _noteBox() {
    final avatarUrl = _avatarUrl();
    final noteColor = AppTheme.isDark(context)
        ? AppTheme.darkSurfaceRaised.withValues(alpha: 0.92)
        : AppTheme.secondaryColor.withValues(alpha: 0.08);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: noteColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorderColorFor(context)),
      ),
      child: Row(
        children: [
          avatarUrl == null
              ? _avatarPlaceholder()
              : ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    avatarUrl,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _avatarPlaceholder(),
                  ),
                ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Foto warga yang baru akan otomatis mengisi avatar user bila warga ini sudah terhubung ke akun.',
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.primaryTextFor(context),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarPlaceholder() => Container(
    width: 48,
    height: 48,
    decoration: BoxDecoration(
      color: AppTheme.primaryColor.withValues(
        alpha: AppTheme.isDark(context) ? 0.18 : 0.10,
      ),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Icon(
      Icons.account_circle_rounded,
      color: AppTheme.primaryColor.withValues(
        alpha: AppTheme.isDark(context) ? 0.95 : 1,
      ),
    ),
  );

  Widget _uploadCard({
    required String title,
    required String subtitle,
    required Uint8List? imageMemory,
    required String? imageUrl,
    required IconData icon,
    required VoidCallback onPick,
  }) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppTheme.cardColorFor(context),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppTheme.cardBorderColorFor(context)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(subtitle, style: AppTheme.caption),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AspectRatio(
            aspectRatio: 1,
            child: imageMemory != null
                ? Image.memory(imageMemory, fit: BoxFit.cover)
                : (imageUrl ?? '').isNotEmpty
                ? Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _imageFallback(icon),
                  )
                : _imageFallback(icon),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onPick,
            icon: const Icon(Icons.upload_rounded),
            label: const Text('Pilih Gambar'),
          ),
        ),
      ],
    ),
  );

  Widget _imageFallback(IconData icon) => Container(
    color: AppTheme.isDark(context)
        ? AppTheme.darkSurfaceRaised
        : AppTheme.backgroundColor,
    child: Icon(
      icon,
      size: 42,
      color: AppTheme.secondaryTextFor(context).withValues(alpha: 0.55),
    ),
  );

  String? _wargaPhotoUrl() =>
      _wargaRecord == null || (_existingFotoWarga ?? '').isEmpty
      ? null
      : getFileUrl(_wargaRecord!, _existingFotoWarga!);
  String? _ktpPhotoUrl() =>
      _wargaRecord == null || (_existingFotoKtp ?? '').isEmpty
      ? null
      : getFileUrl(_wargaRecord!, _existingFotoKtp!);
  String? _avatarUrl() {
    if (_userRecord == null || (_existingAvatar ?? '').isEmpty) return null;
    return getFileUrl(_userRecord!, _existingAvatar!);
  }
}

// ═══════════════════════════════════════════════════════════════════
// SKELETON LOADER — untuk mode edit saat loading data
// ═══════════════════════════════════════════════════════════════════

class _WargaFormSkeleton extends StatelessWidget {
  const _WargaFormSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hero section skeleton
          const AppSkeleton(height: 110, borderRadius: 16),
          const SizedBox(height: 16),
          // Identitas section skeleton
          AppSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    AppSkeleton(width: 34, height: 34, borderRadius: 12),
                    SizedBox(width: 10),
                    AppSkeleton(width: 100, height: 18),
                  ],
                ),
                const SizedBox(height: 16),
                // Field rows
                ...List.generate(
                  4,
                  (_) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: AppSkeleton(
                      height: 50,
                      borderRadius: AppTheme.radiusMedium,
                    ),
                  ),
                ),
                // Two-column fields
                Row(
                  children: const [
                    Expanded(
                      child: AppSkeleton(height: 50, borderRadius: 12),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: AppSkeleton(height: 50, borderRadius: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Alamat section skeleton
          AppSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    AppSkeleton(width: 34, height: 34, borderRadius: 12),
                    SizedBox(width: 10),
                    AppSkeleton(width: 120, height: 18),
                  ],
                ),
                const SizedBox(height: 16),
                ...List.generate(
                  3,
                  (_) => const Padding(
                    padding: EdgeInsets.only(bottom: 14),
                    child: AppSkeleton(height: 50, borderRadius: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Dokumen section skeleton
          AppSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    AppSkeleton(width: 34, height: 34, borderRadius: 12),
                    SizedBox(width: 10),
                    AppSkeleton(width: 110, height: 18),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: const [
                    Expanded(
                      child: AppSkeleton(height: 140, borderRadius: 16),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: AppSkeleton(height: 140, borderRadius: 16),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          // Save button skeleton
          const AppSkeleton(height: 48, borderRadius: 12),
        ],
      ),
    );
  }
}
