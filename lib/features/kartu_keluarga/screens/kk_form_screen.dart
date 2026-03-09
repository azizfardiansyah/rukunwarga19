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
import '../../../core/utils/area_access.dart';
import '../../../core/utils/error_classifier.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/models/kartu_keluarga_model.dart';
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
  static const double _mainActionButtonWidth = 220;

  final _noKkCtrl = TextEditingController();
  final _kepalaNamaCtrl = TextEditingController();
  final _alamatCtrl = TextEditingController();
  final _rtCtrl = TextEditingController();
  final _rwCtrl = TextEditingController();
  final _kelurahanCtrl = TextEditingController();
  final _kecamatanCtrl = TextEditingController();
  final _kabupatenKotaCtrl = TextEditingController();
  final _provinsiCtrl = TextEditingController();
  final _kelurahanFocusNode = FocusNode();
  final _kecamatanFocusNode = FocusNode();
  final _kabupatenKotaFocusNode = FocusNode();
  final _provinsiFocusNode = FocusNode();
  final _ocrService = KkOcrService();
  final _picker = ImagePicker();

  bool _isLoading = false;
  bool _isScanning = false;
  String? _existingScanKk;
  Uint8List? _scanBytes;
  String? _scanFilename;
  String? _selectedImagePath;
  List<ParsedKkMember> _parsedMembers = [];
  List<String> _kelurahanSuggestions = const [];
  List<String> _kecamatanSuggestions = const [];
  List<String> _kabupatenKotaSuggestions = const [];
  List<String> _provinsiSuggestions = const [];

  bool get _isEdit => widget.kkId != null;

  @override
  void initState() {
    super.initState();
    for (final node in [
      _kelurahanFocusNode,
      _kecamatanFocusNode,
      _kabupatenKotaFocusNode,
      _provinsiFocusNode,
    ]) {
      node.addListener(_refreshSuggestionState);
    }
    _loadAreaSuggestions();
    if (_isEdit) {
      _loadData();
    }
  }

  @override
  void dispose() {
    _noKkCtrl.dispose();
    _kepalaNamaCtrl.dispose();
    _alamatCtrl.dispose();
    _rtCtrl.dispose();
    _rwCtrl.dispose();
    _kelurahanCtrl.dispose();
    _kecamatanCtrl.dispose();
    _kabupatenKotaCtrl.dispose();
    _provinsiCtrl.dispose();
    _kelurahanFocusNode.dispose();
    _kecamatanFocusNode.dispose();
    _kabupatenKotaFocusNode.dispose();
    _provinsiFocusNode.dispose();
    super.dispose();
  }

  void _refreshSuggestionState() {
    if (mounted) {
      setState(() {});
    }
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
        _kelurahanCtrl.text = record.getStringValue('desa_kelurahan').isNotEmpty
            ? record.getStringValue('desa_kelurahan')
            : record.getStringValue('kelurahan');
        _kecamatanCtrl.text = record.getStringValue('kecamatan');
        _kabupatenKotaCtrl.text =
            record.getStringValue('kabupaten_kota').isNotEmpty
            ? record.getStringValue('kabupaten_kota')
            : record.getStringValue('kota');
        _provinsiCtrl.text = record.getStringValue('provinsi');
        _existingScanKk = record.getStringValue('scan_kk');
      });
    } catch (e) {
      if (mounted) ErrorClassifier.showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAreaSuggestions() async {
    final auth = ref.read(authProvider);
    if (auth.user == null) {
      return;
    }

    try {
      final access = await resolveAreaAccessContext(auth);
      final records = await pb
          .collection(AppConstants.colKartuKeluarga)
          .getFullList(
            sort: '-updated',
            filter: buildKkScopeFilter(auth, context: access),
            fields:
                'id,desa_kelurahan,kelurahan,kecamatan,kabupaten_kota,kota,provinsi',
          );
      final kkList = records.map(KartuKeluargaModel.fromRecord).toList();
      if (!mounted) {
        return;
      }

      setState(() {
        _kelurahanSuggestions = _uniqueSuggestions(
          kkList.map((item) => item.desaKelurahan),
        );
        _kecamatanSuggestions = _uniqueSuggestions(
          kkList.map((item) => item.kecamatan),
        );
        _kabupatenKotaSuggestions = _uniqueSuggestions(
          kkList.map((item) => item.kabupatenKota),
        );
        _provinsiSuggestions = _uniqueSuggestions(
          kkList.map((item) => item.provinsi),
        );
      });
    } catch (_) {}
  }

  List<String> _uniqueSuggestions(Iterable<String?> values) {
    final seen = <String, String>{};

    for (final value in values) {
      final normalized = value?.trim() ?? '';
      if (normalized.isEmpty) {
        continue;
      }
      seen.putIfAbsent(normalized.toLowerCase(), () => normalized);
    }

    final result = seen.values.toList();
    result.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return result;
  }

  List<String> _matchingSuggestions(String query, List<String> source) {
    final keyword = query.trim().toLowerCase();
    if (keyword.length < 2) {
      return const [];
    }

    final startsWith = <String>[];
    final contains = <String>[];

    for (final option in source) {
      final normalized = option.toLowerCase();
      if (normalized == keyword) {
        continue;
      }
      if (normalized.startsWith(keyword)) {
        startsWith.add(option);
      } else if (normalized.contains(keyword)) {
        contains.add(option);
      }
    }

    return [...startsWith, ...contains].take(6).toList();
  }

  void _applySuggestion(TextEditingController controller, String value) {
    controller
      ..text = value
      ..selection = TextSelection.collapsed(offset: value.length);
    setState(() {});
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
      });
      return;
    }

    await _pickImageFromDevice(ImageSource.gallery);
  }

  Future<void> _pickKkFile() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pilih Sumber Gambar',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ambil foto KK dari kamera atau pilih dari galeri',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _imageSourceCard(
                        icon: Icons.photo_library_rounded,
                        label: 'Galeri',
                        color: const Color(0xFF7C3AED),
                        onTap: () =>
                            Navigator.pop(sheetContext, ImageSource.gallery),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _imageSourceCard(
                        icon: Icons.camera_alt_rounded,
                        label: 'Kamera',
                        color: const Color(0xFF0EA5E9),
                        onTap: () =>
                            Navigator.pop(sheetContext, ImageSource.camera),
                      ),
                    ),
                  ],
                ),
              ],
            ),
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

  Widget _imageSourceCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
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
      _kepalaNamaCtrl.text = parsed.namaKepalaKeluarga.trim().isNotEmpty
          ? parsed.namaKepalaKeluarga.trim()
          : _deriveKepalaKeluargaNama(parsed.members);
      _kelurahanCtrl.text = parsed.kelurahan.trim();
      _kecamatanCtrl.text = parsed.kecamatan.trim();
      _kabupatenKotaCtrl.text = parsed.kabupatenKota.trim();
      _provinsiCtrl.text = parsed.provinsi.trim();
      _parsedMembers = parsed.members;
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

  String get _kepalaNama => _kepalaNamaCtrl.text.trim();

  bool get _isNoKkValid =>
      _noKkCtrl.text.replaceAll(RegExp(r'[^0-9]'), '').length == 16;
  bool get _isKepalaNamaValid => _kepalaNama.isNotEmpty;
  bool get _isAlamatValid => _alamatCtrl.text.trim().isNotEmpty;
  bool get _isRtValid =>
      RegExp(r'^(?!0+$)[0-9]{1,3}$').hasMatch(_rtCtrl.text.trim());
  bool get _isRwValid =>
      RegExp(r'^(?!0+$)[0-9]{1,3}$').hasMatch(_rwCtrl.text.trim());
  bool get _isKelurahanValid => _kelurahanCtrl.text.trim().isNotEmpty;
  bool get _isKecamatanValid => _kecamatanCtrl.text.trim().isNotEmpty;
  bool get _isKabupatenKotaValid => _kabupatenKotaCtrl.text.trim().isNotEmpty;
  bool get _isProvinsiValid => _provinsiCtrl.text.trim().isNotEmpty;

  List<String> _getHeaderIssues() {
    final issues = <String>[];
    if (!_isNoKkValid) {
      issues.add('Nomor KK belum valid (harus 16 digit).');
    }
    if (!_isKepalaNamaValid) {
      issues.add('Nama kepala keluarga belum diisi.');
    }
    if (!_isAlamatValid) {
      issues.add('Alamat belum diisi.');
    }
    if (!_isRtValid) {
      issues.add('RT belum valid.');
    }
    if (!_isRwValid) {
      issues.add('RW belum valid.');
    }
    if (!_isKelurahanValid) {
      issues.add('Desa/Kelurahan belum diisi.');
    }
    if (!_isKecamatanValid) {
      issues.add('Kecamatan belum diisi.');
    }
    if (!_isKabupatenKotaValid) {
      issues.add('Kabupaten/Kota belum diisi.');
    }
    if (!_isProvinsiValid) {
      issues.add('Provinsi belum diisi.');
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
          hubungan: AppConstants.hubunganKeluarga.first,
          jenisKelamin: 'Laki-laki',
        ),
      ];
    });
  }

  bool _validateHeaderFromParser() {
    final issues = _getHeaderIssues();
    if (issues.isNotEmpty) {
      ErrorClassifier.showErrorSnackBar(context, issues.first);
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
      if (member.hubungan.trim().isEmpty ||
          !AppConstants.hubunganKeluarga.contains(member.hubungan.trim())) {
        ErrorClassifier.showErrorSnackBar(
          context,
          'Hubungan anggota ke-${i + 1} wajib dipilih (Ayah/Ibu/Anak).',
        );
        return false;
      }
      if (member.jenisKelamin.trim().isEmpty ||
          !AppConstants.jenisKelamin.contains(member.jenisKelamin.trim())) {
        ErrorClassifier.showErrorSnackBar(
          context,
          'Jenis kelamin anggota ke-${i + 1} belum lengkap.',
        );
        return false;
      }
      if (member.tempatLahir.trim().isEmpty) {
        ErrorClassifier.showErrorSnackBar(
          context,
          'Tempat lahir anggota ke-${i + 1} belum diisi.',
        );
        return false;
      }
      if (member.tanggalLahir.trim().isEmpty ||
          _normalizeTanggalLahirToIso(member.tanggalLahir) == null) {
        ErrorClassifier.showErrorSnackBar(
          context,
          'Tanggal lahir anggota ke-${i + 1} belum lengkap atau tidak valid.',
        );
        return false;
      }
      if (member.agama.trim().isEmpty) {
        ErrorClassifier.showErrorSnackBar(
          context,
          'Agama anggota ke-${i + 1} belum diisi.',
        );
        return false;
      }
      if (member.pendidikan.trim().isEmpty) {
        ErrorClassifier.showErrorSnackBar(
          context,
          'Pendidikan anggota ke-${i + 1} belum diisi.',
        );
        return false;
      }
      if (member.jenisPekerjaan.trim().isEmpty) {
        ErrorClassifier.showErrorSnackBar(
          context,
          'Jenis pekerjaan anggota ke-${i + 1} belum diisi.',
        );
        return false;
      }
      if (member.golonganDarah.trim().isEmpty) {
        ErrorClassifier.showErrorSnackBar(
          context,
          'Golongan darah anggota ke-${i + 1} belum diisi.',
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
    if (upper.contains('KATOLIK') ||
        upper.contains('KATHOLIK') ||
        upper.contains('KHATOLIK')) {
      return 'Khatolik';
    }
    if (upper.contains('BUDHA') || upper.contains('BUDDHA')) return 'Budha';
    if (upper.contains('HINDU')) return 'Islam'; // Fallback, not in DB
    if (upper.contains('KONGHUCU') || upper.contains('KONGHUCHU')) {
      return 'Islam'; // Fallback, not in DB
    }
    return AppConstants.daftarAgama.first;
  }

  /// Maps any hubungan value (from OCR or user input) to the PocketBase
  /// select values: Ayah, Ibu, Anak.
  String _mapHubunganForStorage(String input) {
    final upper = input.trim().toUpperCase();
    if (upper.contains('AYAH') ||
        upper.contains('KEPALA KELUARGA') ||
        upper.contains('SUAMI')) {
      return 'Ayah';
    }
    if (upper.contains('IBU') || upper.contains('ISTRI')) return 'Ibu';
    if (upper.contains('ANAK') ||
        upper.contains('MENANTU') ||
        upper.contains('CUCU')) {
      return 'Anak';
    }
    // If already one of the valid values, return as-is
    if (AppConstants.hubunganKeluarga.contains(input.trim())) {
      return input.trim();
    }
    return 'Anak'; // Default fallback
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
            'hubungan': _mapHubunganForStorage(hubungan),
            'status': 'Aktif',
          },
        );
  }

  Future<void> _updateAnggotaKkHubungan({
    required String anggotaId,
    required String hubungan,
  }) async {
    await pb
        .collection(AppConstants.colAnggotaKk)
        .update(
          anggotaId,
          body: {'hubungan': _mapHubunganForStorage(hubungan)},
        );
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
                'role': AppConstants.roleWarga,
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
      final hubungan = member.hubungan.trim();

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
        'status_pernikahan': 'Belum Menikah',
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

  Future<void> _showMemberDetail(int index) async {
    final member = _parsedMembers[index];
    final namaCtrl = TextEditingController(text: member.nama);
    final nikCtrl = TextEditingController(text: member.nik);
    final tempatLahirCtrl = TextEditingController(text: member.tempatLahir);
    final tanggalLahirCtrl = TextEditingController(text: member.tanggalLahir);
    final pendidikanCtrl = TextEditingController(text: member.pendidikan);
    final pekerjaanCtrl = TextEditingController(text: member.jenisPekerjaan);
    final golonganDarahCtrl = TextEditingController(text: member.golonganDarah);

    var jenisKelamin = member.jenisKelamin.trim().toLowerCase() == 'perempuan'
        ? 'Perempuan'
        : 'Laki-laki';

    var hubungan = _mapHubunganForStorage(
      member.hubungan.isNotEmpty ? member.hubungan : '',
    );
    if (!AppConstants.hubunganKeluarga.contains(hubungan)) {
      hubungan = AppConstants.hubunganKeluarga.first;
    }

    var agama = _mapAgamaForStorage(
      member.agama.isNotEmpty ? member.agama : '',
    );
    if (!AppConstants.daftarAgama.contains(agama)) {
      agama = AppConstants.daftarAgama.first;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        var isEditing = false;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Widget buildField({
              required String label,
              required TextEditingController controller,
              TextInputType keyboardType = TextInputType.text,
              String? hintText,
              IconData? prefixIcon,
            }) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: TextField(
                  controller: controller,
                  enabled: isEditing,
                  keyboardType: keyboardType,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    labelText: label,
                    hintText: hintText,
                    prefixIcon: prefixIcon != null
                        ? Icon(
                            prefixIcon,
                            size: 20,
                            color: AppTheme.primaryColor,
                          )
                        : null,
                    filled: true,
                    fillColor: isEditing
                        ? Colors.white
                        : const Color(0xFFF5F7FA),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.dividerColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.dividerColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppTheme.primaryColor,
                        width: 1.5,
                      ),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppTheme.dividerColor.withValues(alpha: 0.5),
                      ),
                    ),
                    labelStyle: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }

            Widget buildDropdown({
              required String label,
              required String value,
              required List<String> items,
              required ValueChanged<String?> onChanged,
              IconData? prefixIcon,
            }) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: label,
                    prefixIcon: prefixIcon != null
                        ? Icon(
                            prefixIcon,
                            size: 20,
                            color: AppTheme.primaryColor,
                          )
                        : null,
                    filled: true,
                    fillColor: isEditing
                        ? Colors.white
                        : const Color(0xFFF5F7FA),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.dividerColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.dividerColor),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppTheme.dividerColor.withValues(alpha: 0.5),
                      ),
                    ),
                    labelStyle: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: value,
                      isExpanded: true,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textPrimary,
                      ),
                      items: items
                          .map(
                            (v) => DropdownMenuItem(value: v, child: Text(v)),
                          )
                          .toList(),
                      onChanged: isEditing ? onChanged : null,
                    ),
                  ),
                ),
              );
            }

            Future<void> saveMember() async {
              final nama = namaCtrl.text.trim();
              final nik = nikCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
              if (nama.isEmpty) {
                ErrorClassifier.showErrorSnackBar(
                  sheetContext,
                  'Nama anggota wajib diisi.',
                );
                return;
              }
              if (nik.length != 16) {
                ErrorClassifier.showErrorSnackBar(
                  sheetContext,
                  'NIK anggota harus 16 digit.',
                );
                return;
              }
              if (hubungan.isEmpty) {
                ErrorClassifier.showErrorSnackBar(
                  sheetContext,
                  'Hubungan wajib dipilih.',
                );
                return;
              }

              final updatedMember = member.copyWith(
                nama: nama,
                nik: nik,
                hubungan: hubungan,
                jenisKelamin: jenisKelamin,
                tempatLahir: tempatLahirCtrl.text.trim(),
                tanggalLahir: tanggalLahirCtrl.text.trim(),
                agama: agama,
                pendidikan: pendidikanCtrl.text.trim(),
                jenisPekerjaan: pekerjaanCtrl.text.trim(),
                golonganDarah: golonganDarahCtrl.text.trim(),
              );
              setState(() {
                final updated = [..._parsedMembers];
                updated[index] = updatedMember;
                _parsedMembers = updated;
              });
              if (mounted) {
                ErrorClassifier.showSuccessSnackBar(
                  this.context,
                  'Detail anggota diperbarui.',
                );
              }
              if (sheetContext.mounted) Navigator.pop(sheetContext);
            }

            void cancelEdit() {
              if (!isEditing) {
                if (sheetContext.mounted) Navigator.pop(sheetContext);
                return;
              }
              namaCtrl.text = member.nama;
              nikCtrl.text = member.nik;
              tempatLahirCtrl.text = member.tempatLahir;
              tanggalLahirCtrl.text = member.tanggalLahir;
              pendidikanCtrl.text = member.pendidikan;
              pekerjaanCtrl.text = member.jenisPekerjaan;
              golonganDarahCtrl.text = member.golonganDarah;
              jenisKelamin =
                  member.jenisKelamin.trim().toLowerCase() == 'perempuan'
                  ? 'Perempuan'
                  : 'Laki-laki';
              hubungan = _mapHubunganForStorage(
                member.hubungan.isNotEmpty ? member.hubungan : '',
              );
              agama = _mapAgamaForStorage(
                member.agama.isNotEmpty ? member.agama : '',
              );
              setSheetState(() => isEditing = false);
            }

            final isMale = jenisKelamin == 'Laki-laki';
            final avatarColor = isMale
                ? const Color(0xFF3B82F6)
                : const Color(0xFFEC4899);
            final avatarBg = avatarColor.withValues(alpha: 0.1);

            return SafeArea(
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(sheetContext).size.height * 0.88,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            avatarColor.withValues(alpha: 0.08),
                            Colors.white,
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: avatarBg,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              isMale ? Icons.man_rounded : Icons.woman_rounded,
                              color: avatarColor,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  member.nama.isNotEmpty
                                      ? member.nama
                                      : 'Anggota ${index + 1}',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$hubungan - $jenisKelamin',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isEditing)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.accentColor.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.edit_rounded,
                                    size: 12,
                                    color: AppTheme.accentColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Edit',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.accentColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Scrollable form
                    Flexible(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          0,
                          20,
                          20 + MediaQuery.of(sheetContext).viewInsets.bottom,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            buildField(
                              label: 'Nama Lengkap',
                              controller: namaCtrl,
                              prefixIcon: Icons.badge_rounded,
                            ),
                            buildField(
                              label: 'NIK (16 digit)',
                              controller: nikCtrl,
                              keyboardType: TextInputType.number,
                              prefixIcon: Icons.credit_card_rounded,
                              hintText: '3273xxxxxxxxxxxx',
                            ),
                            buildDropdown(
                              label: 'Hubungan',
                              value: hubungan,
                              items: AppConstants.hubunganKeluarga,
                              prefixIcon: Icons.family_restroom_rounded,
                              onChanged: (v) {
                                if (v == null) return;
                                setSheetState(() => hubungan = v);
                              },
                            ),
                            buildDropdown(
                              label: 'Jenis Kelamin',
                              value: jenisKelamin,
                              items: const ['Laki-laki', 'Perempuan'],
                              prefixIcon: Icons.wc_rounded,
                              onChanged: (v) {
                                if (v == null) return;
                                setSheetState(() => jenisKelamin = v);
                              },
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: buildField(
                                    label: 'Tempat Lahir',
                                    controller: tempatLahirCtrl,
                                    prefixIcon: Icons.location_city_rounded,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: buildField(
                                    label: 'Tgl Lahir',
                                    controller: tanggalLahirCtrl,
                                    hintText: 'DD-MM-YYYY',
                                    prefixIcon: Icons.calendar_today_rounded,
                                  ),
                                ),
                              ],
                            ),
                            buildDropdown(
                              label: 'Agama',
                              value: agama,
                              items: AppConstants.daftarAgama,
                              prefixIcon: Icons.auto_awesome_rounded,
                              onChanged: (v) {
                                if (v == null) return;
                                setSheetState(() => agama = v);
                              },
                            ),
                            buildField(
                              label: 'Pendidikan',
                              controller: pendidikanCtrl,
                              prefixIcon: Icons.school_rounded,
                            ),
                            buildField(
                              label: 'Jenis Pekerjaan',
                              controller: pekerjaanCtrl,
                              prefixIcon: Icons.work_rounded,
                            ),
                            buildField(
                              label: 'Golongan Darah',
                              controller: golonganDarahCtrl,
                              prefixIcon: Icons.bloodtype_rounded,
                            ),
                            const SizedBox(height: 8),
                            // Action buttons
                            Row(
                              children: [
                                if (!isEditing)
                                  Expanded(
                                    child: _buildSheetButton(
                                      icon: Icons.edit_rounded,
                                      label: 'Edit',
                                      color: AppTheme.primaryColor,
                                      onPressed: () =>
                                          setSheetState(() => isEditing = true),
                                    ),
                                  ),
                                if (isEditing) ...[
                                  Expanded(
                                    child: _buildSheetButton(
                                      icon: Icons.save_rounded,
                                      label: 'Simpan',
                                      color: AppTheme.successColor,
                                      filled: true,
                                      onPressed: saveMember,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _buildSheetButton(
                                      icon: Icons.close_rounded,
                                      label: 'Batal',
                                      color: AppTheme.textSecondary,
                                      onPressed: cancelEdit,
                                    ),
                                  ),
                                ],
                                if (!isEditing) ...[
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _buildSheetButton(
                                      icon: Icons.close_rounded,
                                      label: 'Tutup',
                                      color: AppTheme.textSecondary,
                                      onPressed: () {
                                        if (sheetContext.mounted) {
                                          Navigator.pop(sheetContext);
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSheetButton({
    required IconData icon,
    required String label,
    required Color color,
    bool filled = false,
    required VoidCallback onPressed,
  }) {
    if (filled) {
      return ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      );
    }
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: color.withValues(alpha: 0.4)),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }

  Widget _memberChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F8),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: AppTheme.textSecondary),
          const SizedBox(width: 3),
          Text(
            text,
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
        ],
      ),
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
        'desa_kelurahan': _kelurahanCtrl.text.trim(),
        'kecamatan': _kecamatanCtrl.text.trim(),
        'kabupaten_kota': _kabupatenKotaCtrl.text.trim(),
        'provinsi': _provinsiCtrl.text.trim(),
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

  Widget _buildEditableHeaderField({
    required String label,
    required TextEditingController controller,
    required bool isValid,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    List<String> suggestions = const [],
    FocusNode? focusNode,
  }) {
    final color = isValid ? AppTheme.successColor : AppTheme.errorColor;
    final matches = (focusNode?.hasFocus ?? false)
        ? _matchingSuggestions(controller.text, suggestions)
        : const <String>[];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: keyboardType,
            maxLines: maxLines,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: label,
              hintText: suggestions.isEmpty ? null : 'Ketik minimal 2 huruf',
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
              suffixIcon: Icon(
                isValid ? Icons.check_circle_rounded : Icons.error_rounded,
                size: 18,
                color: color,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                borderSide: BorderSide(color: color.withValues(alpha: 0.28)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                borderSide: BorderSide(color: color.withValues(alpha: 0.28)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                borderSide: BorderSide(color: color, width: 1.3),
              ),
            ),
          ),
          if (matches.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: matches
                    .map(
                      (option) => ActionChip(
                        onPressed: () => _applySuggestion(controller, option),
                        backgroundColor: AppTheme.primaryColor.withValues(
                          alpha: 0.08,
                        ),
                        side: BorderSide(
                          color: AppTheme.primaryColor.withValues(alpha: 0.12),
                        ),
                        labelStyle: AppTheme.caption.copyWith(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                        avatar: const Icon(
                          Icons.north_west_rounded,
                          size: 14,
                          color: AppTheme.primaryColor,
                        ),
                        label: Text(option),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildOcrHeaderSection() {
    final headerIssues = _getHeaderIssues();
    return Container(
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Compact header with gradient
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              gradient: AppTheme.headerGradient,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(AppTheme.radiusLarge),
                topRight: Radius.circular(AppTheme.radiusLarge),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.document_scanner_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hasil Scan Kartu Keluarga',
                        style: AppTheme.bodyMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Bisa dikoreksi manual sebelum disimpan',
                        style: AppTheme.caption.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: Nama KK + No KK
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildEditableHeaderField(
                        label: 'Nama Kepala Keluarga',
                        controller: _kepalaNamaCtrl,
                        isValid: _isKepalaNamaValid,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: _buildEditableHeaderField(
                        label: 'Nomor KK',
                        controller: _noKkCtrl,
                        isValid: _isNoKkValid,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                // Row 2: Alamat
                _buildEditableHeaderField(
                  label: 'Alamat',
                  controller: _alamatCtrl,
                  isValid: _isAlamatValid,
                  maxLines: 2,
                ),
                // Row 3: RT, RW, Kelurahan, Kecamatan
                Row(
                  children: [
                    Expanded(
                      child: _buildEditableHeaderField(
                        label: 'RT',
                        controller: _rtCtrl,
                        isValid: _isRtValid,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildEditableHeaderField(
                        label: 'RW',
                        controller: _rwCtrl,
                        isValid: _isRwValid,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: _buildEditableHeaderField(
                        label: 'Desa/Kelurahan',
                        controller: _kelurahanCtrl,
                        isValid: _isKelurahanValid,
                        focusNode: _kelurahanFocusNode,
                        suggestions: _kelurahanSuggestions,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: _buildEditableHeaderField(
                        label: 'Kecamatan',
                        controller: _kecamatanCtrl,
                        isValid: _isKecamatanValid,
                        focusNode: _kecamatanFocusNode,
                        suggestions: _kecamatanSuggestions,
                      ),
                    ),
                  ],
                ),
                // Row 4: Kabupaten + Provinsi
                Row(
                  children: [
                    Expanded(
                      child: _buildEditableHeaderField(
                        label: 'Kabupaten/Kota',
                        controller: _kabupatenKotaCtrl,
                        isValid: _isKabupatenKotaValid,
                        focusNode: _kabupatenKotaFocusNode,
                        suggestions: _kabupatenKotaSuggestions,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildEditableHeaderField(
                        label: 'Provinsi',
                        controller: _provinsiCtrl,
                        isValid: _isProvinsiValid,
                        focusNode: _provinsiFocusNode,
                        suggestions: _provinsiSuggestions,
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 8),
                  child: Text(
                    'Ketik minimal 2 huruf pada field wilayah untuk melihat saran. Anda tetap bisa mengetik manual.',
                    style: AppTheme.caption.copyWith(
                      color: AppTheme.primaryColor.withValues(alpha: 0.88),
                    ),
                  ),
                ),
                if (headerIssues.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.warningColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      border: Border.all(
                        color: AppTheme.warningColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.orange.shade700,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Data belum lengkap',
                                style: AppTheme.bodySmall.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange.shade800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              ...headerIssues.map(
                                (issue) => Text(
                                  '- $issue',
                                  style: AppTheme.caption.copyWith(
                                    color: Colors.orange.shade700,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 18,
                        color: Colors.blue.shade700,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Header hasil scan divalidasi otomatis saat tombol Simpan KK + Anggota ditekan.',
                          style: AppTheme.caption.copyWith(
                            color: Colors.blue.shade700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableOcrHeaderSection() {
    final headerIssues = _getHeaderIssues();

    return Container(
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              gradient: AppTheme.headerGradient,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(AppTheme.radiusLarge),
                topRight: Radius.circular(AppTheme.radiusLarge),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.document_scanner_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hasil Scan Kartu Keluarga',
                        style: AppTheme.bodyMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Bisa dikoreksi manual sebelum disimpan',
                        style: AppTheme.caption.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildEditableHeaderField(
                        label: 'Nama Kepala Keluarga',
                        controller: _kepalaNamaCtrl,
                        isValid: _isKepalaNamaValid,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: _buildEditableHeaderField(
                        label: 'Nomor KK',
                        controller: _noKkCtrl,
                        isValid: _isNoKkValid,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                _buildEditableHeaderField(
                  label: 'Alamat',
                  controller: _alamatCtrl,
                  isValid: _isAlamatValid,
                  maxLines: 2,
                ),
                Row(
                  children: [
                    Expanded(
                      child: _buildEditableHeaderField(
                        label: 'RT',
                        controller: _rtCtrl,
                        isValid: _isRtValid,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildEditableHeaderField(
                        label: 'RW',
                        controller: _rwCtrl,
                        isValid: _isRwValid,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: _buildEditableHeaderField(
                        label: 'Desa/Kelurahan',
                        controller: _kelurahanCtrl,
                        isValid: _isKelurahanValid,
                        focusNode: _kelurahanFocusNode,
                        suggestions: _kelurahanSuggestions,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: _buildEditableHeaderField(
                        label: 'Kecamatan',
                        controller: _kecamatanCtrl,
                        isValid: _isKecamatanValid,
                        focusNode: _kecamatanFocusNode,
                        suggestions: _kecamatanSuggestions,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: _buildEditableHeaderField(
                        label: 'Kabupaten/Kota',
                        controller: _kabupatenKotaCtrl,
                        isValid: _isKabupatenKotaValid,
                        focusNode: _kabupatenKotaFocusNode,
                        suggestions: _kabupatenKotaSuggestions,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildEditableHeaderField(
                        label: 'Provinsi',
                        controller: _provinsiCtrl,
                        isValid: _isProvinsiValid,
                        focusNode: _provinsiFocusNode,
                        suggestions: _provinsiSuggestions,
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 8),
                  child: Text(
                    'Ketik minimal 2 huruf pada field wilayah untuk melihat saran. Anda tetap bisa mengetik manual.',
                    style: AppTheme.caption.copyWith(
                      color: AppTheme.primaryColor.withValues(alpha: 0.88),
                    ),
                  ),
                ),
                if (headerIssues.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.warningColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      border: Border.all(
                        color: AppTheme.warningColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.orange.shade700,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Data belum lengkap',
                                style: AppTheme.bodySmall.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange.shade800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              ...headerIssues.map(
                                (issue) => Text(
                                  '- $issue',
                                  style: AppTheme.caption.copyWith(
                                    color: Colors.orange.shade700,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParsedMembersSection() {
    return Container(
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.secondaryColor.withValues(alpha: 0.9),
                  AppTheme.secondaryColor,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppTheme.radiusLarge),
                topRight: Radius.circular(AppTheme.radiusLarge),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.people_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Anggota Keluarga',
                        style: AppTheme.bodyMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _parsedMembers.isEmpty
                            ? 'Belum ada anggota terdeteksi'
                            : '${_parsedMembers.length} anggota terdeteksi',
                        style: AppTheme.caption.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_parsedMembers.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusXLarge,
                      ),
                    ),
                    child: Text(
                      '${_parsedMembers.length}',
                      style: AppTheme.bodySmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_parsedMembers.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundColor,
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusMedium,
                      ),
                      border: Border.all(
                        color: AppTheme.dividerColor,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.person_search_rounded,
                          size: 48,
                          color: AppTheme.textSecondary.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Belum ada anggota terdeteksi',
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Scan KK atau tambah manual',
                          style: AppTheme.caption,
                        ),
                      ],
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _parsedMembers.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final member = _parsedMembers[index];
                      final hasName = member.nama.isNotEmpty;
                      final hasNik = member.nik.isNotEmpty;
                      final hasHubungan = member.hubungan.isNotEmpty;
                      final isComplete = hasName && hasNik && hasHubungan;
                      final isMale = member.jenisKelamin != 'Perempuan';
                      final genderColor = isMale
                          ? const Color(0xFF3B82F6)
                          : const Color(0xFFEC4899);

                      return InkWell(
                        onTap: () => _showMemberDetail(index),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isComplete
                                  ? AppTheme.successColor.withValues(
                                      alpha: 0.25,
                                    )
                                  : AppTheme.warningColor.withValues(
                                      alpha: 0.35,
                                    ),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Avatar
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      genderColor.withValues(alpha: 0.15),
                                      genderColor.withValues(alpha: 0.08),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: genderColor,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            hasName
                                                ? member.nama
                                                : '(Nama belum diisi)',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: hasName
                                                  ? AppTheme.textPrimary
                                                  : AppTheme.textSecondary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (hasHubungan)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppTheme.secondaryColor
                                                  .withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              member.hubungan,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: AppTheme.secondaryColor,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    // NIK row
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.credit_card_rounded,
                                          size: 13,
                                          color: hasNik
                                              ? AppTheme.textSecondary
                                              : AppTheme.errorColor,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          hasNik
                                              ? member.nik
                                              : 'NIK belum diisi',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: hasNik
                                                ? AppTheme.textSecondary
                                                : AppTheme.errorColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                    // Extra detail chips
                                    if (member.tempatLahir.isNotEmpty ||
                                        member.tanggalLahir.isNotEmpty ||
                                        member.agama.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: [
                                          if (member.jenisKelamin.isNotEmpty)
                                            _memberChip(
                                              Icons.wc_rounded,
                                              member.jenisKelamin,
                                            ),
                                          if (member.tempatLahir.isNotEmpty)
                                            _memberChip(
                                              Icons.location_city_rounded,
                                              member.tempatLahir,
                                            ),
                                          if (member.tanggalLahir.isNotEmpty)
                                            _memberChip(
                                              Icons.calendar_today_rounded,
                                              member.tanggalLahir,
                                            ),
                                          if (member.agama.isNotEmpty)
                                            _memberChip(
                                              Icons.auto_awesome_rounded,
                                              member.agama,
                                            ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              // Action buttons
                              Column(
                                children: [
                                  InkWell(
                                    onTap: () => _showMemberDetail(index),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Padding(
                                      padding: const EdgeInsets.all(6),
                                      child: Icon(
                                        Icons.edit_rounded,
                                        color: AppTheme.primaryColor,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  InkWell(
                                    onTap: () {
                                      setState(() {
                                        _parsedMembers = [..._parsedMembers]
                                          ..removeAt(index);
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(8),
                                    child: Padding(
                                      padding: const EdgeInsets.all(6),
                                      child: Icon(
                                        Icons.delete_outline_rounded,
                                        color: AppTheme.errorColor.withValues(
                                          alpha: 0.7,
                                        ),
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 14),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: _mainActionButtonWidth,
                      child: OutlinedButton.icon(
                        onPressed: _addManualMember,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusMedium,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.person_add_alt_1_rounded),
                        label: const Text('Tambah Manual'),
                      ),
                    ),
                    SizedBox(
                      width: _mainActionButtonWidth,
                      child: OutlinedButton.icon(
                        onPressed: _isScanning ? null : _runParser,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusMedium,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.document_scanner_rounded),
                        label: const Text('Scan Ulang'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Kartu Keluarga' : 'Tambah Kartu Keluarga'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildEditableOcrHeaderSection(),
            const SizedBox(height: 16),
            // Upload Section
            Container(
              decoration: AppTheme.cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppTheme.paddingMedium),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.accentColor.withValues(alpha: 0.85),
                          AppTheme.accentColor,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(AppTheme.radiusLarge),
                        topRight: Radius.circular(AppTheme.radiusLarge),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusSmall,
                            ),
                          ),
                          child: const Icon(
                            Icons.upload_file_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Upload Scan KK',
                                style: AppTheme.heading3.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Pilih gambar lalu tekan Scan',
                                style: AppTheme.caption.copyWith(
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppTheme.paddingMedium),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            SizedBox(
                              width: _mainActionButtonWidth,
                              child: ElevatedButton.icon(
                                onPressed: _isScanning || _isLoading
                                    ? null
                                    : _pickKkFile,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusMedium,
                                    ),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.add_photo_alternate_rounded,
                                ),
                                label: Text(
                                  _scanBytes != null
                                      ? 'Ganti Gambar'
                                      : 'Pilih Gambar',
                                ),
                              ),
                            ),
                            SizedBox(
                              width: _mainActionButtonWidth,
                              child: ElevatedButton.icon(
                                onPressed: _isScanning || _isLoading
                                    ? null
                                    : _runParser,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.secondaryColor,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusMedium,
                                    ),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.document_scanner_rounded,
                                ),
                                label: const Text('Scan'),
                              ),
                            ),
                          ],
                        ),
                        if (_existingScanKk != null &&
                            (_scanFilename ?? '').isEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(
                                alpha: 0.06,
                              ),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusSmall,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.image_rounded,
                                  size: 18,
                                  color: AppTheme.primaryColor,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Tersimpan: $_existingScanKk',
                                    style: AppTheme.caption.copyWith(
                                      color: AppTheme.primaryColor,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if ((_scanFilename ?? '').isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.successColor.withValues(
                                alpha: 0.06,
                              ),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusSmall,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle_rounded,
                                  size: 18,
                                  color: AppTheme.successColor,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Dipilih: $_scanFilename',
                                    style: AppTheme.caption.copyWith(
                                      color: AppTheme.successColor,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (_isScanning) ...[
                          const SizedBox(height: 16),
                          Center(
                            child: Column(
                              children: [
                                const SizedBox(
                                  height: 28,
                                  width: 28,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Proses Scan sedang berjalan, harap tunggu beberapa saat..',
                                  style: AppTheme.caption.copyWith(
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildParsedMembersSection(),
            const SizedBox(height: 24),
            // Save & Cancel buttons
            Center(
              child: SizedBox(
                width: _mainActionButtonWidth,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: _isLoading || _isScanning
                        ? null
                        : AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    boxShadow: _isLoading || _isScanning
                        ? null
                        : [
                            BoxShadow(
                              color: AppTheme.primaryColor.withValues(
                                alpha: 0.3,
                              ),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading || _isScanning ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusMedium,
                        ),
                      ),
                      disabledBackgroundColor: AppTheme.dividerColor,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.save_rounded, size: 20),
                              SizedBox(width: 8),
                              Text('Simpan KK + Anggota'),
                            ],
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: SizedBox(
                width: _mainActionButtonWidth,
                child: OutlinedButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          ref.invalidate(hasKartuKeluargaProvider);
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) context.go(Routes.dashboard);
                          });
                        },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusMedium,
                      ),
                    ),
                  ),
                  child: const Text('Batal'),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
