import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import '../../../app/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/pocketbase_service.dart';
import '../../../core/utils/area_access.dart';
import '../../../core/utils/error_classifier.dart';
import '../../../shared/widgets/app_surface.dart';
import '../../auth/providers/auth_provider.dart';

class DokumenUploadScreen extends ConsumerStatefulWidget {
  const DokumenUploadScreen({super.key});

  @override
  ConsumerState<DokumenUploadScreen> createState() =>
      _DokumenUploadScreenState();
}

class _DokumenUploadScreenState extends ConsumerState<DokumenUploadScreen> {
  String _jenis = AppConstants.jenisDokumen.first;
  PlatformFile? _selectedFile;
  bool _isLoading = false;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: AppConstants.allowedDocExt,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _selectedFile = result.files.first);
    }
  }

  Future<void> _upload() async {
    if (_selectedFile == null) {
      ErrorClassifier.showErrorSnackBar(
        context,
        Exception('Pilih file terlebih dahulu'),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final auth = ref.read(authProvider);
      final access = await resolveAreaAccessContext(auth);
      final wargaId = access.wargaId ?? '';

      if (wargaId.isEmpty) {
        throw Exception(
          'Data warga akun ini belum terhubung. Lengkapi data warga terlebih dahulu.',
        );
      }

      final file = http.MultipartFile.fromBytes(
        'file',
        _selectedFile!.bytes!,
        filename: _selectedFile!.name,
      );

      await pb
          .collection(AppConstants.colDokumen)
          .create(
            body: {
              'jenis': _jenis,
              'status_verifikasi': AppConstants.statusPending,
              'warga': wargaId,
            },
            files: [file],
          );

      if (mounted) {
        ErrorClassifier.showSuccessSnackBar(
          context,
          'Dokumen berhasil diupload',
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) ErrorClassifier.showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload Dokumen')),
      body: AppPageBackground(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _jenis,
              decoration: const InputDecoration(labelText: 'Jenis Dokumen'),
              items: AppConstants.jenisDokumen
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => _jenis = v!),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.attach_file),
              label: Text(_selectedFile?.name ?? 'Pilih File'),
            ),
            if (_selectedFile != null) ...[
              const SizedBox(height: 8),
              Text(
                'Ukuran: ${(_selectedFile!.size / 1024).toStringAsFixed(1)} KB',
                style: AppTheme.bodySmall,
              ),
            ],
            const Spacer(),
            ElevatedButton(
              onPressed: _isLoading ? null : _upload,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Upload'),
            ),
          ],
        ),
      ),
    );
  }
}
