import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme.dart';
import '../../../core/services/chat_service.dart';
import '../../../core/utils/area_access.dart';
import '../../../core/utils/error_classifier.dart';
import '../../../shared/models/chat_model.dart';
import '../../../shared/widgets/app_surface.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/chat_providers.dart';

class AnnouncementFormScreen extends ConsumerStatefulWidget {
  const AnnouncementFormScreen({super.key, this.announcementId});

  final String? announcementId;

  @override
  ConsumerState<AnnouncementFormScreen> createState() =>
      _AnnouncementFormScreenState();
}

class _AnnouncementFormScreenState
    extends ConsumerState<AnnouncementFormScreen> {
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _contentCtrl = TextEditingController();
  final TextEditingController _rtCtrl = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _publishNow = true;
  bool _removeExistingAttachment = false;
  String _targetType = 'rw';
  PlatformFile? _selectedAttachment;
  AnnouncementModel? _existing;
  AreaAccessContext? _area;
  Object? _loadError;

  bool get _isEditing => (widget.announcementId ?? '').trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _titleCtrl.addListener(_handleFieldChanged);
    _contentCtrl.addListener(_handleFieldChanged);
    _rtCtrl.addListener(_handleFieldChanged);
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    try {
      final auth = ref.read(authProvider);
      final area = await resolveAreaAccessContext(auth);
      AnnouncementModel? existing;
      if (_isEditing) {
        existing = await ref.read(chatServiceProvider).getAnnouncementDetail(
          widget.announcementId!,
          markAsViewed: false,
        );
        _titleCtrl.text = existing.title;
        _contentCtrl.text = existing.content;
        _targetType = existing.targetType == 'all' ? 'rw' : existing.targetType;
        if (_targetType == 'rt' && existing.rt > 0) {
          _rtCtrl.text = '${existing.rt}';
        }
        _publishNow = existing.isPublished;
      }
      if (mounted) {
        setState(() {
          _existing = existing;
          _area = area;
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loadError = error;
          _isLoading = false;
        });
      }
    }
  }

  void _handleFieldChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _titleCtrl.removeListener(_handleFieldChanged);
    _contentCtrl.removeListener(_handleFieldChanged);
    _rtCtrl.removeListener(_handleFieldChanged);
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _rtCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Pengumuman' : 'Buat Pengumuman'),
      ),
      body: AppPageBackground(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
            ? Center(
                child: AppSurfaceCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        ErrorClassifier.classify(_loadError).message,
                        style: AppTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () {
                          setState(() {
                            _loadError = null;
                            _isLoading = true;
                          });
                          _loadInitial();
                        },
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                ),
              )
            : _buildForm(auth),
      ),
    );
  }

  Widget _buildForm(AuthState auth) {
    final area = _area!;
    final isRtScopedOperator =
        auth.isOperator && !auth.isSysadmin && !auth.hasRwWideAccess;
    final rtLabel = area.rt == null || area.rt == 0
        ? 'RT Saya'
        : 'RT ${area.rt.toString().padLeft(2, '0')}';
    final rwLabel = area.rw == null || area.rw == 0
        ? 'RW Saya'
        : 'RW ${area.rw.toString().padLeft(2, '0')}';

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        children: [
          AppSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEditing
                      ? 'Perbarui informasi resmi untuk warga.'
                      : 'Tulis pengumuman resmi yang ringkas dan mudah dipahami warga.',
                  style: AppTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                _FormSection(
                  label: 'Judul',
                  helper: '${_titleCtrl.text.trim().length}/100',
                  child: TextField(
                    controller: _titleCtrl,
                    maxLength: 100,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Contoh: Kerja bakti Minggu pagi',
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _FormSection(
                  label: 'Isi pengumuman',
                  helper: '${_contentCtrl.text.trim().length}/1000',
                  child: TextField(
                    controller: _contentCtrl,
                    minLines: 6,
                    maxLines: 10,
                    maxLength: 1000,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText:
                          'Tuliskan waktu, lokasi, instruksi, dan informasi penting lainnya.',
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _FormSection(
                  label: 'Target pengumuman',
                  helper: isRtScopedOperator
                      ? 'Admin RT hanya bisa kirim ke RT sendiri atau seluruh RW.'
                      : 'Pilih seluruh RW atau warga RT tertentu.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: Text(rtLabel),
                            selected: _targetType == 'rt',
                            onSelected: (_) => setState(() => _targetType = 'rt'),
                          ),
                          ChoiceChip(
                            label: Text('Seluruh $rwLabel'),
                            selected: _targetType == 'rw',
                            onSelected: (_) => setState(() => _targetType = 'rw'),
                          ),
                        ],
                      ),
                      if (_targetType == 'rt' && !isRtScopedOperator) ...[
                        const SizedBox(height: 10),
                        TextField(
                          controller: _rtCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Nomor RT',
                            hintText: 'Contoh: 1',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _FormSection(
                  label: 'Lampiran',
                  helper: 'Format JPG, PNG, atau PDF. Maksimal 5 MB.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: _pickAttachment,
                            icon: const Icon(Icons.attach_file_rounded),
                            label: Text(
                              _selectedAttachment == null
                                  ? 'Pilih lampiran'
                                  : 'Ganti lampiran',
                            ),
                          ),
                          if (_selectedAttachment != null)
                            TextButton.icon(
                              onPressed: () =>
                                  setState(() => _selectedAttachment = null),
                              icon: const Icon(Icons.delete_outline_rounded),
                              label: const Text('Hapus pilihan'),
                            ),
                        ],
                      ),
                      if (_selectedAttachment != null) ...[
                        const SizedBox(height: 12),
                        _DraftAttachmentTile(fileName: _selectedAttachment!.name),
                      ],
                      if (_existing?.hasAttachment == true &&
                          !_removeExistingAttachment &&
                          _selectedAttachment == null) ...[
                        const SizedBox(height: 12),
                        _ExistingAttachmentTile(
                          fileName: _existing!.attachmentName ?? 'Lampiran',
                          onOpen: _openExistingAttachment,
                          onRemove: () =>
                              setState(() => _removeExistingAttachment = true),
                        ),
                      ],
                      if (_removeExistingAttachment &&
                          _selectedAttachment == null) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Lampiran lama akan dihapus saat disimpan.',
                          style: AppTheme.caption.copyWith(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _FormSection(
                  label: 'Status publikasi',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Publish sekarang'),
                            selected: _publishNow,
                            onSelected: (_) => setState(() => _publishNow = true),
                          ),
                          ChoiceChip(
                            label: const Text('Simpan draft'),
                            selected: !_publishNow,
                            onSelected: (_) =>
                                setState(() => _publishNow = false),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _publishNow
                            ? 'Pengumuman langsung tampil ke warga target.'
                            : 'Pengumuman disimpan dulu dan belum dipublikasikan.',
                        style: AppTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSubmitting ? null : () => context.pop(),
                  child: const Text('Batal'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.tonal(
                  onPressed: _isSubmitting ? null : _showPreview,
                  child: const Text('Preview'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isSubmitting ? null : () => _submit(auth),
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          _publishNow
                              ? Icons.publish_rounded
                              : Icons.save_outlined,
                        ),
                  label: Text(_isSubmitting ? 'Menyimpan...' : 'Simpan'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickAttachment() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: true,
      );
      if (!mounted || result == null || result.files.isEmpty) {
        return;
      }
      setState(() {
        _selectedAttachment = result.files.single;
        _removeExistingAttachment = false;
      });
    } catch (error) {
      if (mounted) {
        ErrorClassifier.showErrorSnackBar(context, error);
      }
    }
  }

  Future<void> _submit(AuthState auth) async {
    if (_isSubmitting) {
      return;
    }
    final area = _area!;
    setState(() => _isSubmitting = true);
    try {
      final service = ref.read(chatServiceProvider);
      final isRtScopedOperator =
          auth.isOperator && !auth.isSysadmin && !auth.hasRwWideAccess;
      final targetRt = _targetType == 'rt'
          ? (isRtScopedOperator ? area.rt : int.tryParse(_rtCtrl.text.trim()))
          : null;

      if (_isEditing) {
        await service.updateAnnouncement(
          announcementId: widget.announcementId!,
          title: _titleCtrl.text.trim(),
          content: _contentCtrl.text.trim(),
          targetType: _targetType,
          targetRt: targetRt,
          targetRw: area.rw,
          attachment: _selectedAttachment,
          publishNow: _publishNow,
          removeAttachment: _removeExistingAttachment,
        );
      } else {
        await service.createAnnouncement(
          title: _titleCtrl.text.trim(),
          content: _contentCtrl.text.trim(),
          targetType: _targetType,
          targetRt: targetRt,
          targetRw: area.rw,
          attachment: _selectedAttachment,
          publishNow: _publishNow,
        );
      }

      ref.invalidate(chatAnnouncementsProvider);
      if (_isEditing) {
        ref.invalidate(
          announcementDetailProvider(
            AnnouncementDetailRequest(
              announcementId: widget.announcementId!,
              markAsViewed: false,
            ),
          ),
        );
        ref.invalidate(announcementStatsProvider(widget.announcementId!));
      }
      ref.read(announcementRefreshTickProvider.notifier).bump();

      if (mounted) {
        ErrorClassifier.showSuccessSnackBar(
          context,
          _isEditing
              ? 'Pengumuman diperbarui.'
              : (_publishNow
                    ? 'Pengumuman dipublikasikan.'
                    : 'Draft pengumuman disimpan.'),
        );
        context.pop();
      }
    } catch (error) {
      if (mounted) {
        ErrorClassifier.showErrorSnackBar(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _showPreview() async {
    final area = _area!;
    final isRtTarget = _targetType == 'rt';
    final rtNumber = _rtCtrl.text.trim();
    final targetLabel = isRtTarget
        ? 'RT ${(rtNumber.isEmpty ? (area.rt ?? 0) : int.tryParse(rtNumber) ?? 0).toString().padLeft(2, '0')} / RW ${(area.rw ?? 0).toString().padLeft(2, '0')}'
        : 'Seluruh RW ${(area.rw ?? 0).toString().padLeft(2, '0')}';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Preview Pengumuman'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _titleCtrl.text.trim().isEmpty
                    ? '(Judul belum diisi)'
                    : _titleCtrl.text.trim(),
                style: AppTheme.heading3,
              ),
              const SizedBox(height: 10),
              Text(
                targetLabel,
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _contentCtrl.text.trim().isEmpty
                    ? '(Isi belum diisi)'
                    : _contentCtrl.text.trim(),
                style: AppTheme.bodyMedium,
              ),
              if (_selectedAttachment != null ||
                  (_existing?.hasAttachment == true &&
                      !_removeExistingAttachment)) ...[
                const SizedBox(height: 14),
                Text(
                  'Lampiran: ${_selectedAttachment?.name ?? _existing?.attachmentName ?? '-'}',
                  style: AppTheme.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Text(
                _publishNow ? 'Status: Publish sekarang' : 'Status: Draft',
                style: AppTheme.caption.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Future<void> _openExistingAttachment() async {
    final url = (_existing?.attachmentUrl ?? '').trim();
    if (url.isEmpty) {
      return;
    }
    try {
      final launched = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ErrorClassifier.showErrorSnackBar(
          context,
          'Lampiran tidak dapat dibuka.',
        );
      }
    } catch (error) {
      if (mounted) {
        ErrorClassifier.showErrorSnackBar(context, error);
      }
    }
  }
}

class _FormSection extends StatelessWidget {
  const _FormSection({
    required this.label,
    required this.child,
    this.helper,
  });

  final String label;
  final String? helper;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF8F4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if ((helper ?? '').isNotEmpty)
                Text(helper!, style: AppTheme.caption),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _DraftAttachmentTile extends StatelessWidget {
  const _DraftAttachmentTile({required this.fileName});

  final String fileName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Row(
        children: [
          const Icon(Icons.attach_file_rounded),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExistingAttachmentTile extends StatelessWidget {
  const _ExistingAttachmentTile({
    required this.fileName,
    required this.onOpen,
    required this.onRemove,
  });

  final String fileName;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.attach_file_rounded),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonal(onPressed: onOpen, child: const Text('Buka')),
              TextButton(
                onPressed: onRemove,
                child: const Text('Hapus lampiran lama'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
