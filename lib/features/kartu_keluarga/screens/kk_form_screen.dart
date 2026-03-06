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
  final _rtCtrl = TextEditingController(text: '19');
  final _rwCtrl = TextEditingController(text: '19');
  final _ocrService = KkOcrService();
  final _picker = ImagePicker();

  bool _isLoading = false;
  bool _isScanning = false;
  String? _existingScanKk;
  Uint8List? _scanBytes;
  String? _scanFilename;
  String? _selectedImagePath;
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

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final record = await pb.collection(AppConstants.colKartuKeluarga).getOne(widget.kkId!);
      if (!mounted) return;
      setState(() {
        _noKkCtrl.text = record.getStringValue('no_kk');
        _alamatCtrl.text = record.getStringValue('alamat');
        _rtCtrl.text = record.getStringValue('rt').isEmpty ? '19' : record.getStringValue('rt');
        _rwCtrl.text = record.getStringValue('rw').isEmpty ? '19' : record.getStringValue('rw');
        _existingScanKk = record.getStringValue('scan_kk');
      });
    } catch (e) {
      if (mounted) ErrorClassifier.showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImageFromDevice(ImageSource source) async {
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
    });
  }

  Future<void> _scanFromCamera() async {
    if (kIsWeb) {
      ErrorClassifier.showErrorSnackBar(context, 'Kamera tidak didukung pada mode PWA.');
      return;
    }
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
        ErrorClassifier.showErrorSnackBar(context, 'Gagal membaca file galeri.');
        return;
      }
      if (!mounted) return;
      setState(() {
        _scanBytes = file.bytes;
        _scanFilename = file.name;
        _selectedImagePath = null;
      });
      return;
    }

    await _pickImageFromDevice(ImageSource.gallery);
  }

  Future<void> _runParser() async {
    if (_scanBytes == null || (_scanFilename ?? '').isEmpty) {
      ErrorClassifier.showErrorSnackBar(context, 'Pilih gambar KK dulu dari kamera/galeri.');
      return;
    }

    setState(() => _isScanning = true);

    if (kIsWeb) {
      try {
        final rawText = await runWebOcr(_scanBytes!);
        if (!mounted) return;
        if (rawText.trim().isEmpty) {
          ErrorClassifier.showErrorSnackBar(context, 'OCR web tidak menemukan teks pada gambar.');
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
      ErrorClassifier.showErrorSnackBar(context, 'Path gambar tidak tersedia untuk parser.');
      setState(() => _isScanning = false);
      return;
    }

    try {
      final parsed = await _ocrService.parseKkDataFromImage(_selectedImagePath!);
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
      if (noKk.length == 16) {
        _noKkCtrl.text = noKk;
      }
      if (parsed.alamat.trim().isNotEmpty) {
        _alamatCtrl.text = parsed.alamat.trim();
      }
      if (parsed.rt.trim().isNotEmpty) {
        _rtCtrl.text = parsed.rt.trim();
      }
      if (parsed.rw.trim().isNotEmpty) {
        _rwCtrl.text = parsed.rw.trim();
      }
      _parsedMembers = parsed.members;
    });
  }

  void _showParserResult() {
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
                      decoration: const InputDecoration(labelText: 'Nama Lengkap'),
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
                      initialValue: AppConstants.hubunganKeluarga.contains(hubungan)
                          ? hubungan
                          : 'Anak',
                      decoration: const InputDecoration(labelText: 'Hubungan'),
                      items: AppConstants.hubunganKeluarga
                          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setLocalState(() => hubungan = value);
                      },
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: AppConstants.jenisKelamin.contains(jenisKelamin)
                          ? jenisKelamin
                          : 'Laki-laki',
                      decoration: const InputDecoration(labelText: 'Jenis Kelamin'),
                      items: AppConstants.jenisKelamin
                          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
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
    final noKk = _noKkCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (noKk.length != 16) {
      ErrorClassifier.showErrorSnackBar(context, 'Nomor KK harus hasil OCR 16 digit.');
      return false;
    }
    if (_alamatCtrl.text.trim().isEmpty) {
      ErrorClassifier.showErrorSnackBar(context, 'Alamat belum terbaca dari OCR.');
      return false;
    }
    if (_rtCtrl.text.trim().isEmpty) {
      _rtCtrl.text = '19';
    }
    if (_rwCtrl.text.trim().isEmpty) {
      _rwCtrl.text = '19';
    }
    return true;
  }

  bool _validateParsedMembers() {
    if (_parsedMembers.isEmpty) {
      ErrorClassifier.showErrorSnackBar(context, 'Anggota keluarga belum ada. Jalankan scan atau tambah manual.');
      return false;
    }

    for (var i = 0; i < _parsedMembers.length; i++) {
      final member = _parsedMembers[i];
      final nik = member.nik.replaceAll(RegExp(r'[^0-9]'), '');
      if (member.nama.trim().isEmpty) {
        ErrorClassifier.showErrorSnackBar(context, 'Nama anggota ke-${i + 1} belum diisi.');
        return false;
      }
      if (nik.length != 16) {
        ErrorClassifier.showErrorSnackBar(context, 'NIK anggota ke-${i + 1} harus 16 digit.');
        return false;
      }
    }

    return true;
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
      return await pb.collection(AppConstants.colUsers).getFirstListItem('email = "$email"');
    } catch (_) {
      return null;
    }
  }

  Future<RecordModel?> _findWargaByNik(String nik) async {
    try {
      return await pb.collection(AppConstants.colWarga).getFirstListItem('nik = "$nik"');
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
        return await pb.collection(AppConstants.colUsers).create(
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

  Future<void> _syncMembersToCollections({
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
        'no_kk': _noKkCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
        'nama_lengkap': member.nama.trim(),
        'tempat_lahir': '',
        'tanggal_lahir': null,
        'jenis_kelamin': member.jenisKelamin,
        'agama': AppConstants.daftarAgama.first,
        'status_pernikahan': AppConstants.statusPernikahan.first,
        'pekerjaan': '',
        'alamat': _alamatCtrl.text.trim(),
        'rt': _rtCtrl.text.trim(),
        'rw': _rwCtrl.text.trim(),
        'no_hp': '',
        'email': userEmail,
        'user_id': userId,
      };

      if (warga == null) {
        warga = await pb.collection(AppConstants.colWarga).create(body: wargaBody);
      } else {
        await pb.collection(AppConstants.colWarga).update(warga.id, body: {
          'user_id': userId,
          'no_kk': _noKkCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
        });
      }

      final anggotaExist = await pb.collection(AppConstants.colAnggotaKk).getList(
        page: 1,
        perPage: 1,
        filter: 'no_kk = "$kkId" && warga = "${warga.id}"',
      );

      if (anggotaExist.items.isEmpty) {
        await pb.collection(AppConstants.colAnggotaKk).create(
          body: {
            'no_kk': kkId,
            'warga': warga.id,
            'hubungan_': hubungan,
            'status': 'Aktif',
          },
        );
      } else {
        await pb.collection(AppConstants.colAnggotaKk).update(
          anggotaExist.items.first.id,
          body: {
            'hubungan_': hubungan,
          },
        );
      }
    }
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
      final existing = await pb.collection(AppConstants.colKartuKeluarga).getList(
        page: 1,
        perPage: 1,
        filter: 'no_kk = "$noKk" && user_id = "$userId"',
      );
      if (existing.items.isNotEmpty && !_isEdit) {
        if (mounted) ErrorClassifier.showErrorSnackBar(context, 'KK sudah terdaftar');
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

      final files = <http.MultipartFile>[];
      if (_scanBytes != null && (_scanFilename ?? '').isNotEmpty) {
        files.add(http.MultipartFile.fromBytes('scan_kk', _scanBytes!, filename: _scanFilename));
      }

      final kkRecord = _isEdit
          ? await pb.collection(AppConstants.colKartuKeluarga).update(
              widget.kkId!,
              body: body,
              files: files,
            )
          : await pb.collection(AppConstants.colKartuKeluarga).create(
              body: body,
              files: files,
            );

      await _syncMembersToCollections(
        kkId: kkRecord.id,
        ownerUserId: userId,
        ownerEmail: ownerEmail,
      );

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

  Widget _buildReadonlyField(String label, String value) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTheme.bodySmall),
          const SizedBox(height: 2),
          Text(
            value.isEmpty ? '-' : value,
            style: AppTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildOcrHeaderSection() {
    final noKk = _noKkCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    final formattedNoKk = noKk.length == 16 ? Formatters.formatNoKk(noKk) : _noKkCtrl.text;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hasil OCR Data KK', style: AppTheme.heading3),
            const SizedBox(height: 8),
            Text(
              'Area ini read-only, diisi dari hasil parser OCR.',
              style: AppTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            _buildReadonlyField('Nomor KK', formattedNoKk),
            _buildReadonlyField('Alamat', _alamatCtrl.text),
            Row(
              children: [
                Expanded(child: _buildReadonlyField('RT', _rtCtrl.text)),
                const SizedBox(width: 10),
                Expanded(child: _buildReadonlyField('RW', _rwCtrl.text)),
              ],
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
                separatorBuilder: (_, _) => const Divider(),
                itemBuilder: (context, index) {
                  final member = _parsedMembers[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(member.nama.isEmpty ? '(Nama belum diisi)' : member.nama),
                    subtitle: Text(
                      'NIK: ${member.nik.isEmpty ? '-' : member.nik}\n'
                      'Hubungan: ${member.hubungan} | JK: ${member.jenisKelamin}',
                    ),
                    isThreeLine: true,
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
                      ],
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
      appBar: AppBar(title: Text(_isEdit ? 'Edit KK + Scan Anggota' : 'Tambah KK + Scan Anggota')),
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
                      'Pilih gambar KK, lalu tekan tombol Scan untuk proses parser.',
                      style: AppTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (!kIsWeb)
                          ElevatedButton.icon(
                            onPressed: _isScanning || _isLoading ? null : _scanFromCamera,
                            icon: const Icon(Icons.photo_camera_outlined),
                            label: const Text('Kamera'),
                          ),
                        ElevatedButton.icon(
                          onPressed: _isScanning || _isLoading ? null : _addFromGallery,
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Tambah dari Galeri'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _isScanning || _isLoading ? null : _runParser,
                          icon: const Icon(Icons.document_scanner_outlined),
                          label: const Text('Scan'),
                        ),
                      ],
                    ),
                    if (_existingScanKk != null && (_scanFilename ?? '').isEmpty) ...[
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
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
