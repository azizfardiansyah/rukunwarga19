import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/chat_service.dart';
import '../../../core/services/pocketbase_service.dart';
import '../../../core/utils/error_classifier.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/chat_model.dart';
import '../../../shared/widgets/app_surface.dart';
import '../providers/chat_providers.dart';

class AnnouncementDetailScreen extends ConsumerStatefulWidget {
  const AnnouncementDetailScreen({super.key, required this.announcementId});

  final String announcementId;

  @override
  ConsumerState<AnnouncementDetailScreen> createState() =>
      _AnnouncementDetailScreenState();
}

class _AnnouncementDetailScreenState
    extends ConsumerState<AnnouncementDetailScreen> {
  Future<void> Function()? _unsubscribeAnnouncements;
  Future<void> Function()? _unsubscribeViews;
  Timer? _refreshDebounce;

  AnnouncementDetailRequest get _request => AnnouncementDetailRequest(
    announcementId: widget.announcementId,
  );

  @override
  void initState() {
    super.initState();
    _bindRealtime();
  }

  Future<void> _bindRealtime() async {
    await _disposeRealtime();
    _unsubscribeAnnouncements = await pb
        .collection(AppConstants.colAnnouncements)
        .subscribe(widget.announcementId, (_) => _scheduleRefresh());
    try {
      _unsubscribeViews = await pb
          .collection(AppConstants.colAnnouncementViews)
          .subscribe('*', (event) {
            final record = event.record;
            if (record == null ||
                record.getStringValue('announcement') != widget.announcementId) {
              return;
            }
            _scheduleRefresh();
          }, filter: 'announcement = "${widget.announcementId}"');
    } catch (_) {
      _unsubscribeViews = null;
    }
  }

  void _scheduleRefresh() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 220), () {
      if (mounted) {
        ref.invalidate(announcementDetailProvider(_request));
        ref.invalidate(announcementStatsProvider(widget.announcementId));
        ref.invalidate(chatAnnouncementsProvider);
      }
    });
  }

  Future<void> _disposeRealtime() async {
    await _unsubscribeAnnouncements?.call();
    await _unsubscribeViews?.call();
    _unsubscribeAnnouncements = null;
    _unsubscribeViews = null;
  }

  @override
  void dispose() {
    _refreshDebounce?.cancel();
    _disposeRealtime();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final announcementAsync = ref.watch(announcementDetailProvider(_request));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Pengumuman'),
        actions: [
          announcementAsync.maybeWhen(
            data: (item) => IconButton(
              tooltip: 'Bagikan',
              onPressed: () => _shareAnnouncement(item),
              icon: const Icon(Icons.share_outlined),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
          announcementAsync.maybeWhen(
            data: (item) => _buildMoreMenu(item),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: AppPageBackground(
        child: announcementAsync.when(
          data: _buildContent,
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
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () =>
                        ref.invalidate(announcementDetailProvider(_request)),
                    child: const Text('Coba Lagi'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMoreMenu(AnnouncementModel item) {
    if (!item.canEdit && !item.canDelete && !item.canViewStats) {
      return const SizedBox.shrink();
    }

    return PopupMenuButton<String>(
      onSelected: (value) async {
        try {
          if (value == 'edit') {
            await context.push(
              Routes.announcementEdit.replaceFirst(':id', item.id),
            );
            if (mounted) {
              _scheduleRefresh();
            }
            return;
          }
          if (value == 'stats') {
            await context.push(
              Routes.announcementStats.replaceFirst(':id', item.id),
            );
            return;
          }
          if (value == 'delete') {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Hapus pengumuman'),
                content: Text(
                  'Yakin hapus "${item.title}"? Tindakan ini tidak bisa dibatalkan.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Batal'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('Hapus'),
                  ),
                ],
              ),
            );
            if (confirmed != true) {
              return;
            }
            await ref.read(chatServiceProvider).deleteAnnouncement(item.id);
            if (mounted) {
              ErrorClassifier.showSuccessSnackBar(
                context,
                'Pengumuman dihapus.',
              );
              context.pop();
            }
          }
        } catch (error) {
          if (mounted) {
            ErrorClassifier.showErrorSnackBar(context, error);
          }
        }
      },
      itemBuilder: (context) => [
        if (item.canEdit)
          const PopupMenuItem(value: 'edit', child: Text('Edit')),
        if (item.canViewStats)
          const PopupMenuItem(
            value: 'stats',
            child: Text('Lihat statistik'),
          ),
        if (item.canDelete)
          const PopupMenuItem(value: 'delete', child: Text('Hapus')),
      ],
    );
  }

  Widget _buildContent(AnnouncementModel item) {
    final isImage = _isImageAttachment(item.attachmentName);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(announcementDetailProvider(_request));
        await ref.read(announcementDetailProvider(_request).future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          AppSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MetaPill(label: item.targetLabel, color: AppTheme.primaryColor),
                    _MetaPill(
                      label: item.isDraft ? 'Draft' : 'Published',
                      color: item.isDraft
                          ? AppTheme.warningColor
                          : AppTheme.secondaryColor,
                    ),
                    _MetaPill(
                      label: '${item.viewCount} dibaca',
                      color: AppTheme.textSecondary,
                      icon: Icons.visibility_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(item.title, style: AppTheme.heading2),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.authorName,
                        style: AppTheme.bodySmall.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      item.publishedAt != null
                          ? Formatters.tanggalWaktu(item.publishedAt!)
                          : item.createdAt != null
                          ? Formatters.tanggalWaktu(item.createdAt!)
                          : '-',
                      style: AppTheme.caption,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (isImage && (item.attachmentUrl ?? '').isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.network(
                        item.attachmentUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          color: AppTheme.extraLightGray,
                          alignment: Alignment.center,
                          child: const Icon(Icons.broken_image_outlined),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  item.content,
                  style: AppTheme.bodyMedium.copyWith(height: 1.55),
                ),
                if (item.hasAttachment) ...[
                  const SizedBox(height: 18),
                  _AttachmentCard(
                    fileName: item.attachmentName ?? 'Lampiran',
                    isImage: isImage,
                    onOpen: () => _openAttachment(item),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (item.canViewStats)
            AppSurfaceCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Statistik baca',
                          style: AppTheme.bodyMedium.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item.viewCount} warga sudah membuka pengumuman ini.',
                          style: AppTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: () => context.push(
                      Routes.announcementStats.replaceFirst(':id', item.id),
                    ),
                    child: const Text('Lihat'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _shareAnnouncement(AnnouncementModel item) async {
    final buffer = StringBuffer()
      ..writeln(item.title)
      ..writeln()
      ..writeln(item.content);
    if ((item.attachmentUrl ?? '').trim().isNotEmpty) {
      buffer
        ..writeln()
        ..writeln(item.attachmentUrl!.trim());
    }
    await SharePlus.instance.share(
      ShareParams(text: buffer.toString().trim()),
    );
  }

  Future<void> _openAttachment(AnnouncementModel item) async {
    final url = (item.attachmentUrl ?? '').trim();
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

  bool _isImageAttachment(String? fileName) {
    final lower = (fileName ?? '').trim().toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp');
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
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

class _AttachmentCard extends StatelessWidget {
  const _AttachmentCard({
    required this.fileName,
    required this.onOpen,
    required this.isImage,
  });

  final String fileName;
  final VoidCallback onOpen;
  final bool isImage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.extraLightGray,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primaryColor, AppTheme.accentColor],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isImage ? Icons.image_rounded : Icons.picture_as_pdf_rounded,
              color: Colors.white,
            ),
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
          const SizedBox(width: 8),
          FilledButton.tonal(onPressed: onOpen, child: const Text('Buka')),
        ],
      ),
    );
  }
}

