// ignore_for_file: use_build_context_synchronously

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/pocketbase_service.dart';
import '../../../core/utils/error_classifier.dart';
import '../../../core/utils/formatters.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../dashboard/screens/dashboard_screen.dart';
import '../models/parsed_kk_member.dart';
import '../services/kk_ocr_service.dart';
import '../services/web_ocr_bridge.dart';

class KkFormScreen extends ConsumerStatefulWidget {
  final String? kkId;
  const KkFormScreen({super.key, this.kkId});

  @override
  ConsumerState<KkFormScreen> createState() => _KkFormScreenState();
}

class _KkFormScreenState extends ConsumerState<KkFormScreen> {
  final _noKkCtrl = TextEditingController();
  final _alamatCtrl = TextEditingController();
  final _rtCtrl = TextEditingController();
  final _rwCtrl = TextEditingController();
  final _ocrService = KkOcrService();
  final _picker = ImagePicker();

  bool _isLoading = false;
  bool _isScanning = false;
  bool _headerConfirmed = false;
  String? _existingScanKk;
  Uint8List? _scanBytes;
  String? _scanFilename;
  String? _selectedImagePath;
  String _namaKepalaKeluarga = '';
  String _kelurahan = '';
  String _kecamatan = '';
  String _kabupatenKota = '';
  String _provinsi = '';
  List<ParsedKkMember> _parsedMembers = [];

  bool get _isEdit => widget.kkId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _loadData();
    }
  }

  @override
  void dispose() {
    _noKkCtrl.dispose();
    _alamatCtrl.dispose();
    _rtCtrl.dispose();
    _rwCtrl.dispose();
    super.dispose();
  }

  String _recordFieldAsString(RecordModel record, String field) {
    final fromGetter = record.getStringValue(field).trim();
    if (fromGetter.isNotEmpty) return fromGetter;
    final raw = record.data[field];
    return raw?.toString().trim() ?? '';
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final record = await pb
          .collection(AppConstants.colKartuKeluarga)
          .getOne(widget.kkId!);
      if (!mounted) return;
      setState(() {
        _noKkCtrl.text = _recordFieldAsString(record, 'no_kk');
        _alamatCtrl.text = record.getStringValue('alamat');
        _rtCtrl.text = _recordFieldAsString(record, 'rt');
        _rwCtrl.text = _recordFieldAsString(record, 'rw');
        _kelurahan = record.getStringValue('desa_kelurahan').isNotEmpty
            ? record.getStringValue('desa_kelurahan')
            : record.getStringValue('kelurahan');
        _kecamatan = record.getStringValue('kecamatan');
        _kabupatenKota = record.getStringValue('kabupaten_kota').isNotEmpty
            ? record.getStringValue('kabupaten_kota')
            : record.getStringValue('kota');
        _provinsi = record.getStringValue('provinsi');
        _existingScanKk = record.getStringValue('scan_kk');
        _headerConfirmed = true;
      });
    } catch (e) {
      if (mounted) ErrorClassifier.showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImageFromDevice(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 2400,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      if (!mounted) return;

      setState(() {
        _scanBytes = bytes;
        _scanFilename = picked.path.split(RegExp(r'[\\/]')).last;
        _selectedImagePath = picked.path;
        _headerConfirmed = false;
      });
    } catch (e) {
      if (!mounted) return;
      final sourceLabel = source == ImageSource.camera ? 'kamera' : 'galeri';
      ErrorClassifier.showErrorSnackBar(
        context,
        'Gagal mengambil gambar dari $sourceLabel: $e',
      );
    }
  }

  Future<void> _scanFromCamera() async {
    await _pickImageFromDevice(ImageSource.camera);
  }

  Future<void> _addFromGallery() async {
    if (kIsWeb) {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.bytes == null || file.bytes!.isEmpty) {
        ErrorClassifier.showErrorSnackBar(
          context,
          'Gagal membaca file galeri.',
        );
        return;
      }
      if (!mounted) return;
      setState(() {
        _scanBytes = file.bytes;
        _scanFilename = file.name;
        _selectedImagePath = null;
        _headerConfirmed = false;
      });
      return;
    }

    await _pickImageFromDevice(ImageSource.gallery);
  }

  Future<void> _pickKkFile() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Galeri'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Foto'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
              ),
            ],
          ),
        );
      },
    );

    if (source == null || !mounted) return;

    if (source == ImageSource.gallery) {
      await _addFromGallery();
      return;
    }
    await _scanFromCamera();
  }

  Future<void> _runParser() async {
    if (_scanBytes == null || (_scanFilename ?? '').isEmpty) {
      ErrorClassifier.showErrorSnackBar(
        context,
        'Pilih gambar KK dulu dari kamera/galeri.',
      );
      return;
    }

    setState(() => _isScanning = true);

    if (kIsWeb) {
      try {
        final rawText = await runWebOcr(_scanBytes!);
        if (!mounted) return;
        if (rawText.trim().isEmpty) {
          ErrorClassifier.showErrorSnackBar(
            context,
            'OCR web tidak menemukan teks pada gambar.',
          );
          return;
        }

        final parsed = _ocrService.parseKkDataFromText(rawText);
        _applyParsedData(parsed);
        _showParserResult();
      } catch (e) {
        if (mounted) ErrorClassifier.showErrorSnackBar(context, e);
      } finally {
        if (mounted) setState(() => _isScanning = false);
      }
      return;
    }

    if ((_selectedImagePath ?? '').isEmpty) {
      ErrorClassifier.showErrorSnackBar(
        context,
        'Path gambar tidak tersedia untuk parser.',
      );
      setState(() => _isScanning = false);
      return;
    }

    try {
      final parsed = await _ocrService.parseKkDataFromImage(
        _selectedImagePath!,
      );
      if (!mounted) return;
      _applyParsedData(parsed);
      _showParserResult();
    } catch (e) {
      if (mounted) ErrorClassifier.showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  void _applyParsedData(ParsedKkData parsed) {
    setState(() {
      final noKk = parsed.noKk.replaceAll(RegExp(r'[^0-9]'), '');
      _noKkCtrl.text = noKk;
      _alamatCtrl.text = parsed.alamat.trim();
      _rtCtrl.text = parsed.rt.trim();
      _rwCtrl.text = parsed.rw.trim();
      _namaKepalaKeluarga = parsed.namaKepalaKeluarga.trim().isNotEmpty
          ? parsed.namaKepalaKeluarga.trim()
          : _deriveKepalaKeluargaNama(parsed.members);
      _kelurahan = parsed.kelurahan.trim();
      _kecamatan = parsed.kecamatan.trim();
      _kabupatenKota = parsed.kabupatenKota.trim();
      _provinsi = parsed.provinsi.trim();
      _parsedMembers = parsed.members;
      _headerConfirmed = false;
    });
  }

  String _deriveKepalaKeluargaNama(List<ParsedKkMember> members) {
    if (members.isEmpty) return '';
    final kepala = members.firstWhere(
      (m) => m.hubungan.toLowerCase().contains('kepala'),
      orElse: () => members.first,
    );
    return kepala.nama.trim();
  }

  String get _kepalaNama => _namaKepalaKeluarga.trim().isNotEmpty
      ? _namaKepalaKeluarga.trim()
      : _deriveKepalaKeluargaNama(_parsedMembers);

  bool get _isNoKkValid =>
      _noKkCtrl.text.replaceAll(RegExp(r'[^0-9]'), '').length == 16;
  bool get _isKepalaNamaValid => _kepalaNama.isNotEmpty;
  bool get _isAlamatValid => _alamatCtrl.text.trim().isNotEmpty;
  bool get _isRtValid =>
      RegExp(r'^(?!0+$)[0-9]{1,3}$').hasMatch(_rtCtrl.text.trim());
  bool get _isRwValid =>
      RegExp(r'^(?!0+$)[0-9]{1,3}$').hasMatch(_rwCtrl.text.trim());
  bool get _isKelurahanValid => _kelurahan.trim().isNotEmpty;
  bool get _isKecamatanValid => _kecamatan.trim().isNotEmpty;
  bool get _isKabupatenKotaValid => _kabupatenKota.trim().isNotEmpty;
  bool get _isProvinsiValid => _provinsi.trim().isNotEmpty;

  List<String> _getHeaderIssues() {
    final issues = <String>[];
    if (!_isNoKkValid) {
      issues.add('Nomor KK belum valid (harus 16 digit).');
    }
    if (!_isKepalaNamaValid) {
      issues.add('Nama kepala keluarga belum terbaca.');
    }
    if (!_isAlamatValid) {
      issues.add('Alamat belum terbaca dari OCR.');
    }
    if (!_isRtValid) {
      issues.add('RT belum valid.');
    }
    if (!_isRwValid) {
      issues.add('RW belum valid.');
    }
    if (!_isKelurahanValid) {
      issues.add('Desa/Kelurahan belum terbaca.');
    }
    if (!_isKecamatanValid) {
      issues.add('Kecamatan belum terbaca.');
    }
    if (!_isKabupatenKotaValid) {
      issues.add('Kabupaten/Kota belum terbaca.');
    }
    if (!_isProvinsiValid) {
      issues.add('Provinsi belum terbaca.');
    }

    return issues;
  }

  void _showParserResult() {
    final headerIssues = _getHeaderIssues();
    if (headerIssues.isNotEmpty) {
      ErrorClassifier.showErrorSnackBar(
        context,
        'Header OCR belum lengkap: ${headerIssues.first}',
      );
      return;
    }
    if (_parsedMembers.isEmpty) {
      ErrorClassifier.showErrorSnackBar(
        context,
        'Parser selesai, tapi anggota belum terdeteksi. Tambah manual.',
      );
      return;
    }
    ErrorClassifier.showSuccessSnackBar(
      context,
      'Parser selesai: ${_parsedMembers.length} anggota terdeteksi.',
    );
  }

  void _addManualMember() {
    setState(() {
      _parsedMembers = [
        ..._parsedMembers,
        ParsedKkMember(
          nama: '',
          nik: '',
          hubungan: _parsedMembers.isEmpty ? 'Kepala Keluarga' : 'Anak',
          jenisKelamin: 'Laki-laki',
        ),
      ];
    });
  }

  Future<void> _editMemberDialog(int index) async {
    final member = _parsedMembers[index];
    final namaCtrl = TextEditingController(text: member.nama);
    final nikCtrl = TextEditingController(text: member.nik);
    var hubungan = member.hubungan;
    var jenisKelamin = member.jenisKelamin;

    final updated = await showDialog<ParsedKkMember>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Edit Anggota ${index + 1}'),
          content: StatefulBuilder(
            builder: (context, setLocalState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: namaCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nama Lengkap',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nikCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 16,
                      decoration: const InputDecoration(labelText: 'NIK'),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue:
                          AppConstants.hubunganKeluarga.contains(hubungan)
                          ? hubungan
                          : 'Anak',
                      decoration: const InputDecoration(labelText: 'Hubungan'),
                      items: AppConstants.hubunganKeluarga
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(item),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setLocalState(() => hubungan = value);
                      },
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue:
                          AppConstants.jenisKelamin.contains(jenisKelamin)
                          ? jenisKelamin
                          : 'Laki-laki',
                      decoration: const InputDecoration(
                        labelText: 'Jenis Kelamin',
                      ),
                      items: AppConstants.jenisKelamin
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(item),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setLocalState(() => jenisKelamin = value);
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  ParsedKkMember(
                    nama: namaCtrl.text.trim(),
                    nik: nikCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
                    hubungan: hubungan,
                    jenisKelamin: jenisKelamin,
                    tempatLahir: member.tempatLahir,
                    tanggalLahir: member.tanggalLahir,
                    agama: member.agama,
                    pendidikan: member.pendidikan,
                    jenisPekerjaan: member.jenisPekerjaan,
                    golonganDarah: member.golonganDarah,
                  ),
                );
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );

    namaCtrl.dispose();
    nikCtrl.dispose();

    if (updated == null || !mounted) return;
    setState(() {
      _parsedMembers[index] = updated;
    });
  }

  bool _validateHeaderFromParser() {
    final issues = _getHeaderIssues();
    if (issues.isNotEmpty) {
      ErrorClassifier.showErrorSnackBar(context, issues.first);
      return false;
    }
    if (!_headerConfirmed) {
      ErrorClassifier.showErrorSnackBar(
        context,
        'Pastikan area header OCR yang ditandai merah sudah benar, lalu konfirmasi header.',
      );
      return false;
    }
    return true;
  }

  bool _validateParsedMembers() {
    if (_parsedMembers.isEmpty) {
      ErrorClassifier.showErrorSnackBar(
        context,
        'Anggota keluarga belum ada. Jalankan scan atau tambah manual.',
      );
      return false;
    }

    for (var i = 0; i < _parsedMembers.length; i++) {
      final member = _parsedMembers[i];
      final nik = member.nik.replaceAll(RegExp(r'[^0-9]'), '');
      if (member.nama.trim().isEmpty) {
        ErrorClassifier.showErrorSnackBar(
          context,
          'Nama anggota ke-${i + 1} belum diisi.',
        );
        return false;
      }
      if (nik.length != 16) {
        ErrorClassifier.showErrorSnackBar(
          context,
          'NIK anggota ke-${i + 1} harus 16 digit.',
        );
        return false;
      }
    }

    return true;
  }

  String? _normalizeTanggalLahirToIso(String input) {
    final raw = input.trim();
    if (raw.isEmpty) return null;

    final match = RegExp(
      r'^(\d{1,2})[-/](\d{1,2})[-/](\d{2,4})$',
    ).firstMatch(raw);
    if (match == null) return null;

    final day = int.tryParse(match.group(1) ?? '');
    final month = int.tryParse(match.group(2) ?? '');
    final yearRaw = int.tryParse(match.group(3) ?? '');
    if (day == null || month == null || yearRaw == null) return null;
    if (day < 1 || day > 31 || month < 1 || month > 12) return null;

    final year = yearRaw < 100
        ? (yearRaw <= 30 ? 2000 + yearRaw : 1900 + yearRaw)
        : yearRaw;
    final date = DateTime(year, month, day);
    return date.toIso8601String();
  }

  String _mapAgamaForStorage(String input) {
    final upper = input.trim().toUpperCase();
    if (upper.contains('ISLAM')) return 'Islam';
    if (upper.contains('KRISTEN')) return 'Kristen';
    if (upper.contains('KATOLIK') || upper.contains('KATHOLIK')) {
      return 'Katolik';
    }
    if (upper.contains('HINDU')) return 'Hindu';
    if (upper.contains('BUDDHA') || upper.contains('BUDHA')) return 'Buddha';
    if (upper.contains('KONGHUCU') || upper.contains('KONGHUCHU')) {
      return 'Konghucu';
    }
    return AppConstants.daftarAgama.first;
  }

  Future<void> _createAnggotaKk({
    required String kkId,
    required String wargaId,
    required String hubungan,
  }) async {
    try {
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
    } catch (_) {
      await pb
          .collection(AppConstants.colAnggotaKk)
          .create(
            body: {
              'no_kk': kkId,
              'warga': wargaId,
              'hubungan_': hubungan,
              'status': 'Aktif',
            },
          );
    }
  }

  Future<void> _updateAnggotaKkHubungan({
    required String anggotaId,
    required String hubungan,
  }) async {
    try {
      await pb
          .collection(AppConstants.colAnggotaKk)
          .update(anggotaId, body: {'hubungan': hubungan});
    } catch (_) {
      await pb
          .collection(AppConstants.colAnggotaKk)
          .update(anggotaId, body: {'hubungan_': hubungan});
    }
  }

  String _slugFirstName(String fullName) {
    final parts = fullName
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    final firstName = parts.isNotEmpty ? parts.first : 'user';
    final slug = firstName.replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (slug.isEmpty) return 'user';
    return slug;
  }

  Future<RecordModel?> _findUserByEmail(String email) async {
    try {
      return await pb
          .collection(AppConstants.colUsers)
          .getFirstListItem('email = "$email"');
    } catch (_) {
      return null;
    }
  }

  Future<RecordModel?> _findWargaByNik(String nik) async {
    try {
      return await pb
          .collection(AppConstants.colWarga)
          .getFirstListItem('nik = "$nik"');
    } catch (_) {
      return null;
    }
  }

  Future<RecordModel> _createUserWithUniqueEmail(String fullName) async {
    const defaultPassword = '12345678';
    final base = _slugFirstName(fullName);
    for (var suffix = 0; suffix < 50; suffix++) {
      final localPart = suffix == 0 ? base : '$base$suffix';
      final email = '$localPart@gmail.com';
      final existing = await _findUserByEmail(email);
      if (existing != null) continue;
      try {
        return await pb
            .collection(AppConstants.colUsers)
            .create(
              body: {
                'email': email,
                'password': defaultPassword,
                'passwordConfirm': defaultPassword,
                'name': fullName,
                'role': AppConstants.roleUser,
              },
            );
      } catch (_) {
        continue;
      }
    }
    throw Exception('Gagal membuat akun user otomatis untuk anggota KK.');
  }

  Future<String> _syncMembersToCollections({
    required String kkId,
    required String ownerUserId,
    required String ownerEmail,
  }) async {
    final detectedHeadIndex = _parsedMembers.indexWhere(
      (member) => member.hubungan.toLowerCase().contains('kepala'),
    );
    final noHeadDetected = detectedHeadIndex < 0;
    var headIndex = detectedHeadIndex;
    if (headIndex < 0) headIndex = 0;
    var kepalaKeluargaWargaId = '';
    final rtNumber = int.tryParse(_rtCtrl.text.trim());
    final rwNumber = int.tryParse(_rwCtrl.text.trim());
    if (rtNumber == null ||
        rwNumber == null ||
        rtNumber == 0 ||
        rwNumber == 0) {
      throw Exception('RT/RW tidak valid.');
    }

    for (var i = 0; i < _parsedMembers.length; i++) {
      final member = _parsedMembers[i];
      final nik = member.nik.replaceAll(RegExp(r'[^0-9]'), '');
      final hubungan = (i == headIndex && noHeadDetected)
          ? 'Kepala Keluarga'
          : (member.hubungan.trim().isEmpty ? 'Anak' : member.hubungan);

      RecordModel? warga = await _findWargaByNik(nik);

      String userId;
      var userEmail = '${_slugFirstName(member.nama)}@gmail.com';
      if (warga != null && warga.getStringValue('user_id').isNotEmpty) {
        userId = warga.getStringValue('user_id');
      } else if (i == headIndex) {
        userId = ownerUserId;
        userEmail = ownerEmail.isEmpty ? userEmail : ownerEmail;
      } else {
        final autoUser = await _createUserWithUniqueEmail(member.nama);
        userId = autoUser.id;
        userEmail = autoUser.getStringValue('email');
      }

      final wargaBody = {
        'nik': nik,
        'no_kk': kkId,
        'nama_lengkap': member.nama.trim(),
        'tempat_lahir': member.tempatLahir.trim(),
        'tanggal_lahir': _normalizeTanggalLahirToIso(member.tanggalLahir),
        'jenis_kelamin': member.jenisKelamin,
        'agama': _mapAgamaForStorage(member.agama),
        'status_pernikahan': AppConstants.statusPernikahan.first,
        'pekerjaan': member.jenisPekerjaan.trim(),
        'alamat': _alamatCtrl.text.trim(),
        'rt': rtNumber,
        'rw': rwNumber,
        'pendidikan': member.pendidikan.trim(),
        'golongan_darah': member.golonganDarah.trim(),
        'no_hp': null,
        'email': userEmail,
        'user_id': userId,
      };

      if (warga == null) {
        warga = await pb
            .collection(AppConstants.colWarga)
            .create(body: wargaBody);
      } else {
        await pb
            .collection(AppConstants.colWarga)
            .update(warga.id, body: {'user_id': userId, 'no_kk': kkId});
      }
      if (i == headIndex) {
        kepalaKeluargaWargaId = warga.id;
      }

      final anggotaExist = await pb
          .collection(AppConstants.colAnggotaKk)
          .getList(
            page: 1,
            perPage: 1,
            filter: 'no_kk = "$kkId" && warga = "${warga.id}"',
          );

      if (anggotaExist.items.isEmpty) {
        await _createAnggotaKk(
          kkId: kkId,
          wargaId: warga.id,
          hubungan: hubungan,
        );
      } else {
        await _updateAnggotaKkHubungan(
          anggotaId: anggotaExist.items.first.id,
          hubungan: hubungan,
        );
      }
    }
    return kepalaKeluargaWargaId;
  }

  Widget _buildMemberDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 130, child: Text(label, style: AppTheme.bodySmall)),
          const Text(': '),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: AppTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showMemberDetail(int index) async {
    final member = _parsedMembers[index];
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Detail Anggota ${index + 1}', style: AppTheme.heading3),
                  const SizedBox(height: 12),
                  _buildMemberDetailRow('Nama Lengkap', member.nama),
                  _buildMemberDetailRow('NIK', member.nik),
                  _buildMemberDetailRow('Hubungan', member.hubungan),
                  _buildMemberDetailRow('Jenis Kelamin', member.jenisKelamin),
                  _buildMemberDetailRow('Tempat Lahir', member.tempatLahir),
                  _buildMemberDetailRow('Tanggal Lahir', member.tanggalLahir),
                  _buildMemberDetailRow('Agama', member.agama),
                  _buildMemberDetailRow('Pendidikan', member.pendidikan),
                  _buildMemberDetailRow(
                    'Jenis Pekerjaan',
                    member.jenisPekerjaan,
                  ),
                  _buildMemberDetailRow('Golongan Darah', member.golonganDarah),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    if (!_validateHeaderFromParser()) return;
    if (!_validateParsedMembers()) return;

    setState(() => _isLoading = true);
    try {
      final auth = ref.read(authProvider);
      final userId = auth.user?.id;
      if (userId == null) throw Exception('User belum login');
      final ownerEmail = auth.user?.getStringValue('email') ?? '';

      final noKk = _noKkCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
      final noKkNumber = int.tryParse(noKk);
      final rtNumber = int.tryParse(_rtCtrl.text.trim());
      final rwNumber = int.tryParse(_rwCtrl.text.trim());
      if (noKkNumber == null) {
        throw Exception('Nomor KK tidak valid.');
      }
      if (rtNumber == null ||
          rwNumber == null ||
          rtNumber == 0 ||
          rwNumber == 0) {
        throw Exception('RT/RW tidak valid.');
      }
      final existing = await pb
          .collection(AppConstants.colKartuKeluarga)
          .getList(
            page: 1,
            perPage: 1,
            filter: 'no_kk = $noKkNumber && user_id = "$userId"',
          );
      if (existing.items.isNotEmpty && !_isEdit) {
        if (mounted) {
          ErrorClassifier.showErrorSnackBar(context, 'KK sudah terdaftar');
        }
        setState(() => _isLoading = false);
        return;
      }

      final body = {
        'no_kk': noKkNumber,
        'alamat': _alamatCtrl.text.trim(),
        'rt': rtNumber,
        'rw': rwNumber,
        'desa_kelurahan': _kelurahan.trim(),
        'kecamatan': _kecamatan.trim(),
        'kabupaten_kota': _kabupatenKota.trim(),
        'provinsi': _provinsi.trim(),
        'user_id': userId,
      };

      final files = <http.MultipartFile>[];
      if (_scanBytes != null && (_scanFilename ?? '').isNotEmpty) {
        files.add(
          http.MultipartFile.fromBytes(
            'scan_kk',
            _scanBytes!,
            filename: _scanFilename,
          ),
        );
      }

      final kkRecord = _isEdit
          ? await pb
                .collection(AppConstants.colKartuKeluarga)
                .update(widget.kkId!, body: body, files: files)
          : await pb
                .collection(AppConstants.colKartuKeluarga)
                .create(body: body, files: files);

      final kepalaKeluargaWargaId = await _syncMembersToCollections(
        kkId: kkRecord.id,
        ownerUserId: userId,
        ownerEmail: ownerEmail,
      );
      if (kepalaKeluargaWargaId.isNotEmpty) {
        await pb
            .collection(AppConstants.colKartuKeluarga)
            .update(
              kkRecord.id,
              body: {'kepala_keluarga': kepalaKeluargaWargaId},
            );
      }

      if (mounted) {
        ErrorClassifier.showSuccessSnackBar(
          context,
          _isEdit
              ? 'Data KK dan anggota berhasil diperbarui'
              : 'Data KK dan anggota berhasil disimpan',
        );
        ref.invalidate(hasKartuKeluargaProvider);
        ref.invalidate(hasWargaDataProvider);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.go(Routes.dashboard);
        });
      }
    } catch (e) {
      if (mounted) ErrorClassifier.showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildReadonlyField(
    String label,
    String value, {
    required bool isValid,
  }) {
    final color = isValid ? Colors.green : Colors.red;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.8)),
        borderRadius: BorderRadius.circular(10),
        color: color.withValues(alpha: 0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: AppTheme.bodySmall)),
              Icon(
                isValid ? Icons.check_circle_outline : Icons.error_outline,
                size: 16,
                color: color,
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(value.isEmpty ? '-' : value, style: AppTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildOcrHeaderSection() {
    final noKk = _noKkCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    final formattedNoKk = noKk.length == 16
        ? Formatters.formatNoKk(noKk)
        : _noKkCtrl.text;
    final kepalaNama = _kepalaNama;
    final headerIssues = _getHeaderIssues();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hasil Scan Data Kartu Keluarga', style: AppTheme.heading3),
            const SizedBox(height: 8),
            Text(
              'Pastikan area merah (No KK, alamat, dan wilayah) sudah benar sebelum simpan.',
              style: AppTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            _buildReadonlyField(
              'Nama Kepala Keluarga',
              kepalaNama,
              isValid: _isKepalaNamaValid,
            ),
            _buildReadonlyField(
              'Nomor KK',
              formattedNoKk,
              isValid: _isNoKkValid,
            ),
            _buildReadonlyField(
              'Alamat',
              _alamatCtrl.text,
              isValid: _isAlamatValid,
            ),
            Row(
              children: [
                Expanded(
                  child: _buildReadonlyField(
                    'RT',
                    _rtCtrl.text,
                    isValid: _isRtValid,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildReadonlyField(
                    'RW',
                    _rwCtrl.text,
                    isValid: _isRwValid,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: _buildReadonlyField(
                    'Desa/Kelurahan',
                    _kelurahan,
                    isValid: _isKelurahanValid,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildReadonlyField(
                    'Kecamatan',
                    _kecamatan,
                    isValid: _isKecamatanValid,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: _buildReadonlyField(
                    'Kabupaten/Kota',
                    _kabupatenKota,
                    isValid: _isKabupatenKotaValid,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildReadonlyField(
                    'Provinsi',
                    _provinsi,
                    isValid: _isProvinsiValid,
                  ),
                ),
              ],
            ),
            if (headerIssues.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Header belum valid', style: AppTheme.bodyMedium),
                    const SizedBox(height: 4),
                    ...headerIssues.map(
                      (issue) => Text('- $issue', style: AppTheme.bodySmall),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: headerIssues.isEmpty
                  ? () => setState(() {
                      _headerConfirmed = true;
                    })
                  : null,
              icon: Icon(
                _headerConfirmed
                    ? Icons.verified_outlined
                    : Icons.fact_check_outlined,
              ),
              label: const Text('Konfirmasi Data'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParsedMembersSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hasil Parser Anggota KK', style: AppTheme.heading3),
            const SizedBox(height: 8),
            Text(
              'Jika ada data kurang/keliru, edit dulu sebelum simpan.',
              style: AppTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            if (_parsedMembers.isEmpty)
              Text('Belum ada anggota terdeteksi.', style: AppTheme.bodySmall)
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _parsedMembers.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final member = _parsedMembers[index];
                  return Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
                      title: Text(
                        member.nama.isEmpty
                            ? '(Nama belum diisi)'
                            : member.nama,
                      ),
                      onTap: () => _showMemberDetail(index),
                      trailing: Wrap(
                        spacing: 0,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _editMemberDialog(index),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () {
                              setState(() {
                                final updated = [..._parsedMembers];
                                updated.removeAt(index);
                                _parsedMembers = updated;
                              });
                            },
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _addManualMember,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Tambah Manual'),
                ),
                OutlinedButton.icon(
                  onPressed: _isScanning ? null : _runParser,
                  icon: const Icon(Icons.document_scanner_outlined),
                  label: const Text('Scan Ulang'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEdit ? 'Edit KK + Scan Anggota' : 'Tambah KK + Scan Anggota',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildOcrHeaderSection(),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.paddingMedium),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Upload Scan KK', style: AppTheme.heading3),
                    const SizedBox(height: 8),
                    Text(
                      'Pilih file KK dari galeri atau foto langsung, lalu tekan tombol Scan.',
                      style: AppTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _isScanning || _isLoading
                              ? null
                              : _pickKkFile,
                          icon: const Icon(Icons.upload_file_outlined),
                          label: const Text('Tambah File KK'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _isScanning || _isLoading
                              ? null
                              : _runParser,
                          icon: const Icon(Icons.document_scanner_outlined),
                          label: const Text('Scan'),
                        ),
                      ],
                    ),
                    if (_existingScanKk != null &&
                        (_scanFilename ?? '').isEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Scan KK tersimpan: $_existingScanKk',
                        style: AppTheme.bodySmall,
                      ),
                    ],
                    if ((_scanFilename ?? '').isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'File dipilih: $_scanFilename',
                        style: AppTheme.bodySmall,
                      ),
                    ],
                    if (_isScanning) ...[
                      const SizedBox(height: 12),
                      const Center(child: CircularProgressIndicator()),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildParsedMembersSection(),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading || _isScanning ? null : _save,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Simpan KK + Anggota'),
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
    );
  }
}
