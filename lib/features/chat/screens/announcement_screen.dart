import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/chat_service.dart';
import '../../../core/services/pocketbase_service.dart';
import '../../../core/utils/error_classifier.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/chat_model.dart';
import '../../../shared/widgets/app_surface.dart';
import '../../../shared/widgets/floating_action_pill.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/chat_providers.dart';

enum _AnnouncementStatusFilter { all, published, draft }

enum _AnnouncementTargetFilter { all, rw, rt }

enum _AnnouncementSortOrder { newest, oldest, mostViewed }

class AnnouncementScreen extends ConsumerStatefulWidget {
  const AnnouncementScreen({super.key});

  @override
  ConsumerState<AnnouncementScreen> createState() => _AnnouncementScreenState();
}

class _AnnouncementScreenState extends ConsumerState<AnnouncementScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  ChatAnnouncementsData? _lastData;
  Future<void> Function()? _unsubscribeAnnouncements;
  Future<void> Function()? _unsubscribeViews;
  Timer? _refreshDebounce;
  _AnnouncementStatusFilter _statusFilter = _AnnouncementStatusFilter.all;
  _AnnouncementTargetFilter _targetFilter = _AnnouncementTargetFilter.all;
  _AnnouncementSortOrder _sortOrder = _AnnouncementSortOrder.newest;
  bool _mineOnly = false;

  @override
  void initState() {
    super.initState();
    _bindRealtime();
  }

  Future<void> _bindRealtime() async {
    await _disposeRealtime();
    _unsubscribeAnnouncements = await pb
        .collection(AppConstants.colAnnouncements)
        .subscribe('*', (_) => _scheduleRefresh());
    try {
      _unsubscribeViews = await pb
          .collection(AppConstants.colAnnouncementViews)
          .subscribe('*', (_) => _scheduleRefresh());
    } catch (_) {
      _unsubscribeViews = null;
    }
  }

  void _scheduleRefresh() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 220), () {
      if (mounted) {
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
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final announcementAsync = ref.watch(chatAnnouncementsProvider);
    final loaded = announcementAsync.maybeWhen(
      data: (value) {
        _lastData = value;
        return value;
      },
      orElse: () => _lastData,
    );
    final items = _filterItems(loaded?.items ?? const []);
    final canCreate = loaded?.canCreate == true;

    return Scaffold(
      appBar: AppBar(
        title: Text(canCreate ? 'Kelola Pengumuman' : 'Pengumuman'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: canCreate
          ? FloatingActionPill(
              onTap: () async {
                await context.push(Routes.announcementCreate);
                if (mounted) {
                  await _refresh();
                }
              },
              icon: Icons.campaign_rounded,
              label: 'Buat Pengumuman',
              gradientColors: const [AppTheme.primaryColor, AppTheme.accentColor],
            )
          : null,
      body: AppPageBackground(
        child: Column(
          children: [
            _AnnouncementHero(
              totalCount: loaded?.items.length ?? 0,
              publishedCount: (loaded?.items ?? const [])
                  .where((item) => item.isPublished)
                  .length,
              draftCount: (loaded?.items ?? const [])
                  .where((item) => item.isDraft)
                  .length,
              roleLabel: AppConstants.roleLabel(auth.role),
              canCreate: canCreate,
            ),
            const SizedBox(height: 12),
            AppSearchBar(
              hintText: 'Cari judul atau isi pengumuman...',
              controller: _searchCtrl,
              value: _searchCtrl.text,
              onChanged: (value) => setState(() {}),
            ),
            const SizedBox(height: 10),
            _FilterToolbar(
              canCreate: canCreate,
              mineOnly: _mineOnly,
              statusFilter: _statusFilter,
              targetFilter: _targetFilter,
              sortOrder: _sortOrder,
              onMineOnlyChanged: (value) => setState(() => _mineOnly = value),
              onStatusChanged: (value) => setState(() => _statusFilter = value),
              onTargetChanged: (value) => setState(() => _targetFilter = value),
              onSortChanged: (value) => setState(() => _sortOrder = value),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: announcementAsync.when(
                data: (_) => _buildList(items),
                loading: () => loaded != null
                    ? _buildList(items)
                    : const Center(child: CircularProgressIndicator()),
                error: (error, _) => loaded != null
                    ? _buildList(items)
                    : Center(
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
                                onPressed: _refresh,
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

  Widget _buildList(List<AnnouncementModel> items) {
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 52),
            AppEmptyState(
              icon: Icons.campaign_outlined,
              title: 'Belum ada pengumuman',
              message: 'Pengumuman RT/RW yang sesuai wilayah akan muncul di sini.',
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 96),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final item = items[index];
          return _AnnouncementCard(
            item: item,
            onTap: () async {
              await context.push(
                Routes.announcementDetail.replaceFirst(':id', item.id),
              );
              if (mounted) {
                await _refresh();
              }
            },
            onActionSelected: (action) => _handleCardAction(item, action),
          );
        },
      ),
    );
  }

  List<AnnouncementModel> _filterItems(List<AnnouncementModel> items) {
    final query = _searchCtrl.text.trim().toLowerCase();
    final filtered = items.where((item) {
      if (_mineOnly && !item.isMine) {
        return false;
      }
      if (_statusFilter == _AnnouncementStatusFilter.published &&
          !item.isPublished) {
        return false;
      }
      if (_statusFilter == _AnnouncementStatusFilter.draft && !item.isDraft) {
        return false;
      }
      if (_targetFilter == _AnnouncementTargetFilter.rw &&
          item.targetType != 'rw' &&
          item.targetType != 'all') {
        return false;
      }
      if (_targetFilter == _AnnouncementTargetFilter.rt &&
          item.targetType != 'rt') {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      final haystack = [
        item.title,
        item.content,
        item.authorName,
        item.targetLabel,
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList(growable: false);

    filtered.sort((left, right) {
      switch (_sortOrder) {
        case _AnnouncementSortOrder.oldest:
          final leftTime = left.publishedAt ?? left.createdAt ?? DateTime(1970);
          final rightTime =
              right.publishedAt ?? right.createdAt ?? DateTime(1970);
          return leftTime.compareTo(rightTime);
        case _AnnouncementSortOrder.mostViewed:
          final byView = right.viewCount.compareTo(left.viewCount);
          if (byView != 0) {
            return byView;
          }
          final leftTime = left.publishedAt ?? left.createdAt ?? DateTime(1970);
          final rightTime =
              right.publishedAt ?? right.createdAt ?? DateTime(1970);
          return rightTime.compareTo(leftTime);
        case _AnnouncementSortOrder.newest:
          final leftTime = left.publishedAt ?? left.createdAt ?? DateTime(1970);
          final rightTime =
              right.publishedAt ?? right.createdAt ?? DateTime(1970);
          return rightTime.compareTo(leftTime);
      }
    });
    return filtered;
  }

  Future<void> _handleCardAction(
    AnnouncementModel item,
    _AnnouncementCardAction action,
  ) async {
    try {
      switch (action) {
        case _AnnouncementCardAction.edit:
          await context.push(
            Routes.announcementEdit.replaceFirst(':id', item.id),
          );
          if (mounted) {
            await _refresh();
          }
          break;
        case _AnnouncementCardAction.stats:
          await context.push(
            Routes.announcementStats.replaceFirst(':id', item.id),
          );
          break;
        case _AnnouncementCardAction.delete:
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
            await _refresh();
          }
          break;
      }
    } catch (error) {
      if (mounted) {
        ErrorClassifier.showErrorSnackBar(context, error);
      }
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(chatAnnouncementsProvider);
    await ref.read(chatAnnouncementsProvider.future);
  }
}

class _AnnouncementHero extends StatelessWidget {
  const _AnnouncementHero({
    required this.totalCount,
    required this.publishedCount,
    required this.draftCount,
    required this.roleLabel,
    required this.canCreate,
  });

  final int totalCount;
  final int publishedCount;
  final int draftCount;
  final String roleLabel;
  final bool canCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: const BoxDecoration(
        gradient: AppTheme.headerGradient,
        borderRadius: BorderRadius.all(Radius.circular(26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
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
                      canCreate ? 'Pusat pengumuman warga' : 'Feed pengumuman warga',
                      style: AppTheme.bodyLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      canCreate
                          ? 'Kelola draft, publikasi, dan pantau angka baca warga per pengumuman.'
                          : 'Lihat informasi resmi RT/RW yang sesuai dengan wilayah Anda.',
                      style: AppTheme.caption.copyWith(
                        color: Colors.white.withValues(alpha: 0.76),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  roleLabel,
                  style: AppTheme.caption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroChip(icon: Icons.feed_rounded, label: '$totalCount total'),
              _HeroChip(
                icon: Icons.publish_rounded,
                label: '$publishedCount terbit',
              ),
              if (canCreate)
                _HeroChip(
                  icon: Icons.drafts_rounded,
                  label: '$draftCount draft',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.label});

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
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterToolbar extends StatelessWidget {
  const _FilterToolbar({
    required this.canCreate,
    required this.mineOnly,
    required this.statusFilter,
    required this.targetFilter,
    required this.sortOrder,
    required this.onMineOnlyChanged,
    required this.onStatusChanged,
    required this.onTargetChanged,
    required this.onSortChanged,
  });

  final bool canCreate;
  final bool mineOnly;
  final _AnnouncementStatusFilter statusFilter;
  final _AnnouncementTargetFilter targetFilter;
  final _AnnouncementSortOrder sortOrder;
  final ValueChanged<bool> onMineOnlyChanged;
  final ValueChanged<_AnnouncementStatusFilter> onStatusChanged;
  final ValueChanged<_AnnouncementTargetFilter> onTargetChanged;
  final ValueChanged<_AnnouncementSortOrder> onSortChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'Semua',
                      selected: statusFilter == _AnnouncementStatusFilter.all,
                      onTap: () =>
                          onStatusChanged(_AnnouncementStatusFilter.all),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Terbit',
                      selected:
                          statusFilter == _AnnouncementStatusFilter.published,
                      onTap: () =>
                          onStatusChanged(_AnnouncementStatusFilter.published),
                    ),
                    if (canCreate) ...[
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Draft',
                        selected:
                            statusFilter == _AnnouncementStatusFilter.draft,
                        onTap: () =>
                            onStatusChanged(_AnnouncementStatusFilter.draft),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<_AnnouncementSortOrder>(
              initialValue: sortOrder,
              onSelected: onSortChanged,
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _AnnouncementSortOrder.newest,
                  child: Text('Terbaru'),
                ),
                PopupMenuItem(
                  value: _AnnouncementSortOrder.oldest,
                  child: Text('Terlama'),
                ),
                PopupMenuItem(
                  value: _AnnouncementSortOrder.mostViewed,
                  child: Text('Paling banyak dibaca'),
                ),
              ],
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: AppTheme.cardDecoration(
                  borderRadius: AppTheme.radiusMedium,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.tune_rounded, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      _sortLabel(sortOrder),
                      style: AppTheme.bodySmall.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterChip(
                label: 'Semua target',
                selected: targetFilter == _AnnouncementTargetFilter.all,
                onTap: () => onTargetChanged(_AnnouncementTargetFilter.all),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'RW',
                selected: targetFilter == _AnnouncementTargetFilter.rw,
                onTap: () => onTargetChanged(_AnnouncementTargetFilter.rw),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'RT',
                selected: targetFilter == _AnnouncementTargetFilter.rt,
                onTap: () => onTargetChanged(_AnnouncementTargetFilter.rt),
              ),
              if (canCreate) ...[
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Milik saya'),
                  selected: mineOnly,
                  onSelected: onMineOnlyChanged,
                  selectedColor: AppTheme.primaryColor.withValues(alpha: 0.14),
                  checkmarkColor: AppTheme.primaryColor,
                  labelStyle: AppTheme.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: mineOnly
                        ? AppTheme.primaryColor
                        : AppTheme.textSecondary,
                  ),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                    side: BorderSide(color: AppTheme.dividerColor),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static String _sortLabel(_AnnouncementSortOrder value) {
    switch (value) {
      case _AnnouncementSortOrder.oldest:
        return 'Terlama';
      case _AnnouncementSortOrder.mostViewed:
        return 'Paling dibaca';
      case _AnnouncementSortOrder.newest:
        return 'Terbaru';
    }
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppTheme.primaryColor.withValues(alpha: 0.14),
      checkmarkColor: AppTheme.primaryColor,
      labelStyle: AppTheme.bodySmall.copyWith(
        fontWeight: FontWeight.w700,
        color: selected ? AppTheme.primaryColor : AppTheme.textSecondary,
      ),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(color: AppTheme.dividerColor),
      ),
    );
  }
}

enum _AnnouncementCardAction { edit, stats, delete }

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({
    required this.item,
    required this.onTap,
    required this.onActionSelected,
  });

  final AnnouncementModel item;
  final VoidCallback onTap;
  final ValueChanged<_AnnouncementCardAction> onActionSelected;

  @override
  Widget build(BuildContext context) {
    final accentColor = item.isDraft
        ? AppTheme.warningColor
        : item.targetType == 'rt'
        ? AppTheme.primaryColor
        : AppTheme.accentColor;

    return AppAccentCard(
      accentColor: accentColor,
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoPill(label: item.targetLabel, color: accentColor),
                    _InfoPill(
                      label: item.isDraft ? 'Draft' : 'Published',
                      color: item.isDraft
                          ? AppTheme.warningColor
                          : AppTheme.secondaryColor,
                    ),
                    _InfoPill(
                      label: '${item.viewCount} baca',
                      color: AppTheme.textSecondary,
                      icon: Icons.visibility_rounded,
                    ),
                    if (item.hasViewed)
                      const _InfoPill(
                        label: 'Sudah dibaca',
                        color: AppTheme.primaryColor,
                        icon: Icons.done_all_rounded,
                      ),
                  ],
                ),
              ),
              if (item.canEdit || item.canDelete || item.canViewStats)
                PopupMenuButton<_AnnouncementCardAction>(
                  onSelected: onActionSelected,
                  itemBuilder: (context) => [
                    if (item.canEdit)
                      const PopupMenuItem(
                        value: _AnnouncementCardAction.edit,
                        child: Text('Edit'),
                      ),
                    if (item.canViewStats)
                      const PopupMenuItem(
                        value: _AnnouncementCardAction.stats,
                        child: Text('Lihat statistik'),
                      ),
                    if (item.canDelete)
                      const PopupMenuItem(
                        value: _AnnouncementCardAction.delete,
                        child: Text('Hapus'),
                      ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(item.title, style: AppTheme.heading3.copyWith(fontSize: 21)),
          const SizedBox(height: 6),
          Text(
            item.content,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.bodyMedium.copyWith(height: 1.45),
          ),
          if (item.hasAttachment) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.extraLightGray,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.dividerColor),
              ),
              child: Row(
                children: [
                  const Icon(Icons.attach_file_rounded, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.attachmentName ?? 'Lampiran',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.bodySmall.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
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
                    ? Formatters.tanggalRelatif(item.publishedAt!)
                    : item.createdAt != null
                    ? Formatters.tanggalRelatif(item.createdAt!)
                    : '-',
                style: AppTheme.caption,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label, required this.color, this.icon});

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

