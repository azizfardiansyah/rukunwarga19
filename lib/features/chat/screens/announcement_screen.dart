import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/chat_service.dart';
import '../../../core/services/pocketbase_service.dart';
import '../../../core/utils/area_access.dart';
import '../../../core/utils/error_classifier.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/chat_model.dart';
import '../../../shared/widgets/app_surface.dart';
import '../../../shared/widgets/floating_action_pill.dart';
import '../../auth/providers/auth_provider.dart';

final announcementListProvider =
    FutureProvider.autoDispose<ChatAnnouncementsData>((ref) async {
      final service = ref.watch(chatServiceProvider);
      return service.getAnnouncements();
    });

class AnnouncementScreen extends ConsumerStatefulWidget {
  const AnnouncementScreen({super.key});

  @override
  ConsumerState<AnnouncementScreen> createState() => _AnnouncementScreenState();
}

class _AnnouncementScreenState extends ConsumerState<AnnouncementScreen> {
  Future<void> Function()? _unsubscribeAnnouncements;
  Timer? _refreshDebounce;

  @override
  void initState() {
    super.initState();
    _bindRealtime();
  }

  Future<void> _bindRealtime() async {
    _unsubscribeAnnouncements = await pb
        .collection(AppConstants.colAnnouncements)
        .subscribe('*', (_) => _scheduleRefresh());
  }

  void _scheduleRefresh() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 180), () {
      if (mounted) {
        ref.invalidate(announcementListProvider);
      }
    });
  }

  @override
  void dispose() {
    _refreshDebounce?.cancel();
    _unsubscribeAnnouncements?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final announcementAsync = ref.watch(announcementListProvider);
    final auth = ref.watch(authProvider);
    final data = announcementAsync.asData?.value;

    return Scaffold(
      appBar: AppBar(title: const Text('Pengumuman')),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: data?.canCreate == true
          ? FloatingActionPill(
              onTap: () => _showCreateSheet(context, ref),
              icon: Icons.campaign_rounded,
              label: 'Buat Pengumuman',
              gradientColors: const [AppTheme.accentColor, Color(0xFFE0B56C)],
            )
          : null,
      body: AppPageBackground(
        child: Column(
          children: [
            _AnnouncementHero(
              totalItems: data?.items.length ?? 0,
              canCreate: data?.canCreate == true,
              roleLabel: AppConstants.roleLabel(auth.role),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: announcementAsync.when(
                data: (loaded) {
                  if (loaded.items.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 40),
                        AppEmptyState(
                          icon: Icons.campaign_outlined,
                          title: 'Belum ada pengumuman',
                          message:
                              'Pengumuman resmi RT/RW, kas, dan agenda wilayah akan tampil rapi di sini.',
                          action: loaded.canCreate
                              ? FilledButton.icon(
                                  onPressed: () =>
                                      _showCreateSheet(context, ref),
                                  icon: const Icon(Icons.add_comment_rounded),
                                  label: const Text('Buat Pengumuman Pertama'),
                                )
                              : null,
                        ),
                      ],
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async =>
                        ref.invalidate(announcementListProvider),
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 90),
                      itemCount: loaded.items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = loaded.items[index];
                        return _AnnouncementFeedCard(
                          item: item,
                          onOpenAttachment: item.hasAttachment
                              ? () => _openAttachment(item)
                              : null,
                        );
                      },
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: AppSurfaceCard(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          ErrorClassifier.classify(error).message,
                          style: AppTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        FilledButton(
                          onPressed: () =>
                              ref.invalidate(announcementListProvider),
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAttachment(AnnouncementModel item) async {
    final url = (item.attachmentUrl ?? '').trim();
    if (url.isEmpty) {
      return;
    }

    try {
      final uri = Uri.parse(url);
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
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

  void _showCreateSheet(BuildContext context, WidgetRef ref) {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    final rtCtrl = TextEditingController();
    final auth = ref.read(authProvider);
    final isRtScopedOperator =
        auth.isOperator && !auth.isSysadmin && !auth.hasRwWideAccess;
    var targetType = isRtScopedOperator ? 'rt' : 'rw';
    PlatformFile? selectedAttachment;
    var isSubmitting = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> pickAttachment() async {
            try {
              final result = await FilePicker.platform.pickFiles(
                allowMultiple: false,
                withData: true,
              );
              if (result == null || result.files.isEmpty) {
                return;
              }

              setDialogState(() {
                selectedAttachment = result.files.single;
              });
            } catch (error) {
              if (dialogContext.mounted) {
                ErrorClassifier.showErrorSnackBar(dialogContext, error);
              }
            }
          }

          Future<void> submit() async {
            if (isSubmitting) {
              return;
            }

            setDialogState(() => isSubmitting = true);
            try {
              final service = ref.read(chatServiceProvider);
              final area = await resolveAreaAccessContext(auth);
              await service.createAnnouncement(
                title: titleCtrl.text.trim(),
                content: contentCtrl.text.trim(),
                targetType: targetType,
                targetRt: isRtScopedOperator
                    ? area.rt
                    : int.tryParse(rtCtrl.text.trim()),
                attachment: selectedAttachment,
              );
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
              ref.invalidate(announcementListProvider);
            } catch (error) {
              if (dialogContext.mounted) {
                ErrorClassifier.showErrorSnackBar(dialogContext, error);
              }
            } finally {
              if (dialogContext.mounted) {
                setDialogState(() => isSubmitting = false);
              }
            }
          }

          final viewInsets = MediaQuery.of(dialogContext).viewInsets;

          return SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(10, 24, 10, viewInsets.bottom + 10),
              child: Container(
                decoration: AppTheme.cardDecoration(borderRadius: 28),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  AppTheme.primaryColor,
                                  AppTheme.accentColor,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.campaign_rounded,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Buat Pengumuman',
                                  style: AppTheme.heading2.copyWith(
                                    fontSize: 24,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Tulis info resmi yang ringkas, akurat, dan mudah dipahami warga.',
                                  style: AppTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _ComposerFieldShell(
                        label: 'Judul',
                        child: TextField(
                          controller: titleCtrl,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            hintText: 'Contoh: Kerja bakti Minggu pagi',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _ComposerFieldShell(
                        label: 'Isi pengumuman',
                        helper:
                            'Boleh dikosongkan jika informasi utamanya sudah ada di lampiran.',
                        child: TextField(
                          controller: contentCtrl,
                          minLines: 4,
                          maxLines: 6,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            hintText:
                                'Tuliskan waktu, lokasi, kebutuhan, atau instruksi penting lainnya.',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _ComposerFieldShell(
                        label: 'Target distribusi',
                        child: isRtScopedOperator
                            ? const _LockedScopeNotice(
                                text:
                                    'Akun operator RT hanya bisa mengirim ke RT pada yuridiksi akunnya sendiri.',
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _TargetChoiceChip(
                                        label: 'Seluruh RW',
                                        selected: targetType == 'rw',
                                        onTap: () => setDialogState(
                                          () => targetType = 'rw',
                                        ),
                                      ),
                                      _TargetChoiceChip(
                                        label: 'RT tertentu',
                                        selected: targetType == 'rt',
                                        onTap: () => setDialogState(
                                          () => targetType = 'rt',
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (targetType == 'rt') ...[
                                    const SizedBox(height: 10),
                                    TextField(
                                      controller: rtCtrl,
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
                      _ComposerFieldShell(
                        label: 'Lampiran',
                        helper:
                            'Tambahkan PDF, gambar, atau dokumen lain hingga 10 MB.',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                FilledButton.tonalIcon(
                                  onPressed: pickAttachment,
                                  icon: const Icon(Icons.attach_file_rounded),
                                  label: Text(
                                    selectedAttachment == null
                                        ? 'Pilih lampiran'
                                        : 'Ganti lampiran',
                                  ),
                                ),
                                if (selectedAttachment != null)
                                  TextButton.icon(
                                    onPressed: () => setDialogState(
                                      () => selectedAttachment = null,
                                    ),
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                    ),
                                    label: const Text('Hapus'),
                                  ),
                              ],
                            ),
                            if (selectedAttachment != null) ...[
                              const SizedBox(height: 12),
                              _AttachmentDraftTile(file: selectedAttachment!),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isSubmitting
                                  ? null
                                  : () => Navigator.pop(dialogContext),
                              child: const Text('Batal'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: isSubmitting ? null : submit,
                              icon: isSubmitting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.send_rounded),
                              label: Text(
                                isSubmitting ? 'Mengirim...' : 'Kirim',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AnnouncementHero extends StatelessWidget {
  const _AnnouncementHero({
    required this.totalItems,
    required this.canCreate,
    required this.roleLabel,
  });

  final int totalItems;
  final bool canCreate;
  final String roleLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: const BoxDecoration(
        gradient: AppTheme.headerGradient,
        borderRadius: BorderRadius.all(Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.campaign_rounded,
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
                      'Feed pengumuman resmi',
                      style: AppTheme.bodyLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Informasi RT/RW, agenda warga, dan update penting yang sudah dipublikasikan.',
                      style: AppTheme.caption.copyWith(
                        color: Colors.white.withValues(alpha: 0.78),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  roleLabel,
                  style: AppTheme.caption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroInfoChip(
                icon: Icons.feed_rounded,
                label: '$totalItems terbit',
              ),
              _HeroInfoChip(
                icon: canCreate
                    ? Icons.edit_note_rounded
                    : Icons.visibility_rounded,
                label: canCreate ? 'Bisa publish' : 'Mode baca',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroInfoChip extends StatelessWidget {
  const _HeroInfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTheme.caption.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnnouncementFeedCard extends StatelessWidget {
  const _AnnouncementFeedCard({required this.item, this.onOpenAttachment});

  final AnnouncementModel item;
  final VoidCallback? onOpenAttachment;

  @override
  Widget build(BuildContext context) {
    final accentColor = item.targetType == 'rt'
        ? AppTheme.primaryColor
        : AppTheme.accentColor;

    return AppAccentCard(
      accentColor: accentColor,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _FeedChip(
                label: item.targetLabel,
                color: accentColor,
                background: accentColor.withValues(alpha: 0.12),
              ),
              if ((item.sourceModule ?? '').trim().isNotEmpty) ...[
                const SizedBox(width: 8),
                _FeedChip(
                  label: _sourceModuleLabel(item.sourceModule!),
                  color: AppTheme.textSecondary,
                  background: const Color(0xFFF4F1EC),
                  icon: Icons.bolt_rounded,
                ),
              ],
              const Spacer(),
              Text(
                item.createdAt != null
                    ? Formatters.waktuRingkas(item.createdAt!)
                    : '',
                style: AppTheme.caption,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(item.title, style: AppTheme.heading3.copyWith(fontSize: 20)),
          if (item.content.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              item.content,
              style: AppTheme.bodyMedium.copyWith(height: 1.45),
            ),
          ],
          if (item.hasAttachment) ...[
            const SizedBox(height: 12),
            _AnnouncementAttachmentCard(
              fileName: item.attachmentName!,
              onTap: onOpenAttachment,
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.person_rounded, size: 16, color: accentColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.authorName,
                  style: AppTheme.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              if (item.createdAt != null)
                Text(
                  Formatters.tanggalWaktu(item.createdAt!),
                  style: AppTheme.caption,
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _sourceModuleLabel(String sourceModule) {
    switch (sourceModule.trim().toLowerCase()) {
      case 'finance':
        return 'Kas';
      case 'iuran':
        return 'Iuran';
      case 'manual':
      default:
        return 'Manual';
    }
  }
}

class _FeedChip extends StatelessWidget {
  const _FeedChip({
    required this.label,
    required this.color,
    required this.background,
    this.icon,
  });

  final String label;
  final Color color;
  final Color background;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppTheme.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnnouncementAttachmentCard extends StatelessWidget {
  const _AnnouncementAttachmentCard({required this.fileName, this.onTap});

  final String fileName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final lowerName = fileName.toLowerCase();
    final icon = lowerName.endsWith('.pdf')
        ? Icons.picture_as_pdf_rounded
        : lowerName.endsWith('.jpg') ||
              lowerName.endsWith('.jpeg') ||
              lowerName.endsWith('.png') ||
              lowerName.endsWith('.webp')
        ? Icons.image_rounded
        : lowerName.endsWith('.doc') || lowerName.endsWith('.docx')
        ? Icons.description_rounded
        : lowerName.endsWith('.xls') || lowerName.endsWith('.xlsx')
        ? Icons.table_chart_rounded
        : Icons.attach_file_rounded;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F3EE),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.dividerColor),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primaryColor, AppTheme.accentColor],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lampiran tersedia',
                      style: AppTheme.caption.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      fileName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.tonal(onPressed: onTap, child: const Text('Buka')),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComposerFieldShell extends StatelessWidget {
  const _ComposerFieldShell({
    required this.label,
    required this.child,
    this.helper,
  });

  final String label;
  final Widget child;
  final String? helper;

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
          Text(
            label,
            style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w800),
          ),
          if ((helper ?? '').isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(helper!, style: AppTheme.caption),
          ],
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _TargetChoiceChip extends StatelessWidget {
  const _TargetChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
      labelStyle: AppTheme.bodySmall.copyWith(
        color: selected ? Colors.white : AppTheme.textSecondary,
        fontWeight: FontWeight.w700,
      ),
      backgroundColor: Colors.white,
      selectedColor: AppTheme.primaryColor,
      side: BorderSide(
        color: selected ? AppTheme.primaryColor : AppTheme.dividerColor,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    );
  }
}

class _LockedScopeNotice extends StatelessWidget {
  const _LockedScopeNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.verified_user_rounded,
            size: 18,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: AppTheme.bodySmall)),
        ],
      ),
    );
  }
}

class _AttachmentDraftTile extends StatelessWidget {
  const _AttachmentDraftTile({required this.file});

  final PlatformFile file;

  @override
  Widget build(BuildContext context) {
    final lowerName = file.name.toLowerCase();
    final icon = lowerName.endsWith('.pdf')
        ? Icons.picture_as_pdf_rounded
        : lowerName.endsWith('.jpg') ||
              lowerName.endsWith('.jpeg') ||
              lowerName.endsWith('.png') ||
              lowerName.endsWith('.webp')
        ? Icons.image_rounded
        : lowerName.endsWith('.doc') || lowerName.endsWith('.docx')
        ? Icons.description_rounded
        : lowerName.endsWith('.xls') || lowerName.endsWith('.xlsx')
        ? Icons.table_chart_rounded
        : Icons.attach_file_rounded;

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
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.accentColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.accentColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(Formatters.fileSize(file.size), style: AppTheme.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
