import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/pocketbase_service.dart';
import '../../../core/utils/error_classifier.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_surface.dart';
import '../providers/chat_providers.dart';

class AnnouncementStatsScreen extends ConsumerStatefulWidget {
  const AnnouncementStatsScreen({super.key, required this.announcementId});

  final String announcementId;

  @override
  ConsumerState<AnnouncementStatsScreen> createState() =>
      _AnnouncementStatsScreenState();
}

class _AnnouncementStatsScreenState
    extends ConsumerState<AnnouncementStatsScreen> {
  Future<void> Function()? _unsubscribeAnnouncements;
  Future<void> Function()? _unsubscribeViews;
  Timer? _refreshDebounce;

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
        ref.invalidate(announcementStatsProvider(widget.announcementId));
        ref.invalidate(
          announcementDetailProvider(
            AnnouncementDetailRequest(
              announcementId: widget.announcementId,
              markAsViewed: false,
            ),
          ),
        );
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
    final statsAsync = ref.watch(announcementStatsProvider(widget.announcementId));
    final detailAsync = ref.watch(
      announcementDetailProvider(
        AnnouncementDetailRequest(
          announcementId: widget.announcementId,
          markAsViewed: false,
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Statistik Pengumuman')),
      body: AppPageBackground(
        child: statsAsync.when(
          data: (stats) => detailAsync.when(
            data: (detail) => RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(announcementStatsProvider(widget.announcementId));
                ref.invalidate(
                  announcementDetailProvider(
                    AnnouncementDetailRequest(
                      announcementId: widget.announcementId,
                      markAsViewed: false,
                    ),
                  ),
                );
                await ref.read(announcementStatsProvider(widget.announcementId).future);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  AppSurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(detail.title, style: AppTheme.heading3),
                        const SizedBox(height: 8),
                        Text(
                          detail.targetLabel,
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          detail.publishedAt != null
                              ? 'Dipublikasikan ${Formatters.tanggalWaktu(detail.publishedAt!)}'
                              : 'Belum dipublikasikan',
                          style: AppTheme.caption,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: 'Total dibaca',
                          value: '${stats.totalViews}',
                          helper: 'warga',
                          accentColor: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatCard(
                          label: 'Target warga',
                          value: '${stats.targetAudienceCount}',
                          helper: 'penerima',
                          accentColor: AppTheme.accentColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AppSurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Persentase keterbacaan',
                          style: AppTheme.bodyMedium.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            minHeight: 12,
                            value: stats.percentage,
                            backgroundColor: const Color(0xFFF2E7DE),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppTheme.primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${(stats.percentage * 100).toStringAsFixed(0)}% dari target warga sudah membaca pengumuman ini.',
                          style: AppTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppSurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rentang pembacaan',
                          style: AppTheme.bodyMedium.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _TimelineRow(
                          label: 'Pertama dibaca',
                          value: stats.firstViewedAt != null
                              ? Formatters.tanggalWaktu(stats.firstViewedAt!)
                              : 'Belum ada data',
                        ),
                        const SizedBox(height: 10),
                        _TimelineRow(
                          label: 'Terakhir dibaca',
                          value: stats.lastViewedAt != null
                              ? Formatters.tanggalWaktu(stats.lastViewedAt!)
                              : 'Belum ada data',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Text(
                ErrorClassifier.classify(error).message,
                style: AppTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
          ),
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
                        ref.invalidate(announcementStatsProvider(widget.announcementId)),
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
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.helper,
    required this.accentColor,
  });

  final String label;
  final String value;
  final String helper;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTheme.bodySmall),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTheme.heading2.copyWith(
              color: accentColor,
              fontSize: 28,
            ),
          ),
          const SizedBox(height: 4),
          Text(helper, style: AppTheme.caption),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
