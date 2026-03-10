import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/chat_service.dart';
import '../../../core/services/pocketbase_service.dart';
import '../../../core/utils/error_classifier.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/chat_model.dart';
import '../../../shared/widgets/floating_action_pill.dart';

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

    return Scaffold(
      appBar: AppBar(title: const Text('Pengumuman')),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: announcementAsync.asData?.value.canCreate == true
          ? FloatingActionPill(
              onTap: () => _showCreateDialog(context, ref),
              icon: Icons.add_comment_rounded,
              label: 'Buat Pengumuman',
              gradientColors: const [Color(0xFFFF8F00), Color(0xFFFFB74D)],
            )
          : null,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF4F8FF), Color(0xFFF9FCFF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: announcementAsync.when(
          data: (data) {
            if (data.items.isEmpty) {
              return Center(
                child: AppTheme.glassContainer(
                  opacity: 0.72,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.campaign_outlined,
                        size: 40,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(height: 10),
                      Text('Belum ada pengumuman', style: AppTheme.heading3),
                      const SizedBox(height: 6),
                      Text(
                        'Pengumuman RT/RW resmi akan tampil di sini.',
                        style: AppTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(announcementListProvider),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
                itemCount: data.items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final ann = data.items[index];
                  return _AnnouncementCard(item: ann);
                },
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                ErrorClassifier.classify(error).message,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    String targetType = 'rw';
    final rtCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: const Text('Buat Pengumuman'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: 'Judul'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: contentCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Isi'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: targetType,
                    decoration: const InputDecoration(labelText: 'Target'),
                    items: const [
                      DropdownMenuItem(value: 'rw', child: Text('Seluruh RW')),
                      DropdownMenuItem(value: 'rt', child: Text('RT Tertentu')),
                    ],
                    onChanged: (value) {
                      setDialogState(() => targetType = value ?? 'rw');
                    },
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
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: () async {
                  try {
                    final service = ref.read(chatServiceProvider);
                    await service.createAnnouncement(
                      title: titleCtrl.text.trim(),
                      content: contentCtrl.text.trim(),
                      targetType: targetType,
                      targetRt: int.tryParse(rtCtrl.text.trim()),
                    );
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    }
                    ref.invalidate(announcementListProvider);
                  } catch (error) {
                    if (dialogContext.mounted) {
                      ErrorClassifier.showErrorSnackBar(dialogContext, error);
                    }
                  }
                },
                child: const Text('Kirim'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({required this.item});

  final AnnouncementModel item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  item.targetLabel,
                  style: AppTheme.caption.copyWith(
                    color: AppTheme.accentColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                item.createdAt != null
                    ? Formatters.tanggalRelatif(item.createdAt!)
                    : '',
                style: AppTheme.caption,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(item.title, style: AppTheme.heading3),
          const SizedBox(height: 4),
          Text(item.content, style: AppTheme.bodyMedium),
          const SizedBox(height: 8),
          Text(
            'Oleh ${item.authorName}',
            style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}
