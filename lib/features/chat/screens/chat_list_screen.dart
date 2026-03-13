import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/chat_service.dart';
import '../../../core/utils/error_classifier.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/chat_model.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../../../shared/widgets/app_surface.dart';
import '../../../shared/widgets/current_user_avatar.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/chat_providers.dart';

enum _ChatSection { inbox, groups }

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  final _searchCtrl = TextEditingController();
  _ChatSection _section = _ChatSection.inbox;
  bool _showArchived = false;
  String get _searchQuery => _searchCtrl.text.trim().toLowerCase();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final bootstrapAsync = ref.watch(chatBootstrapProvider);
    final bootstrapData =
        bootstrapAsync.maybeWhen(data: (value) => value, orElse: () => null) ??
        ref.read(chatServiceProvider).getCachedBootstrap();
    final showBootstrap = bootstrapData != null;
    final archiveCount = switch (_section) {
      _ChatSection.inbox =>
        bootstrapData?.inbox.where((item) => item.isArchived).length,
      _ChatSection.groups =>
        bootstrapData?.groups.where((item) => item.isArchived).length,
    };

    return Scaffold(
      body: AppPageBackground(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          children: [
            _buildHero(
              authName:
                  auth.user?.getStringValue('name').trim().isNotEmpty == true
                  ? auth.user!.getStringValue('name').trim()
                  : 'Pengguna',
              roleLabel: AppConstants.roleLabel(auth.role),
              areaLabel: bootstrapData?.area.scopeLabel ?? '',
              data: bootstrapData,
            ),
            const SizedBox(height: 12),
            AppSearchBar(
              hintText: switch (_section) {
                _ChatSection.inbox => 'Cari nama, isi chat, atau percakapan...',
                _ChatSection.groups => 'Cari grup, isi chat, atau RT/RW...',
              },
              value: _searchCtrl.text,
              onChanged: (value) {
                _searchCtrl.text = value;
                setState(() {});
              },
              controller: _searchCtrl,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildSectionSelector(data: bootstrapData)),
                const SizedBox(width: 10),
                _ArchiveToggleButton(
                  active: _showArchived,
                  count: archiveCount,
                  onTap: () => setState(() => _showArchived = !_showArchived),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: showBootstrap
                  ? RefreshIndicator(
                      onRefresh: _refresh,
                      child: switch (_section) {
                        _ChatSection.inbox => _buildConversationList(
                          items: bootstrapData.inbox,
                          emptyTitle: 'Belum ada inbox layanan',
                          emptySubtitle:
                              'Inbox akan muncul otomatis saat warga butuh bantuan atau saat Anda membuka chat layanan.',
                          emptyIcon: Icons.mark_chat_unread_outlined,
                        ),
                        _ChatSection.groups => _buildConversationList(
                          items: bootstrapData.groups,
                          emptyTitle: 'Belum ada grup wilayah',
                          emptySubtitle:
                              'Grup RT atau RW akan muncul sesuai role dan cakupan wilayah akun Anda.',
                          emptyIcon: Icons.groups_2_outlined,
                        ),
                      },
                    )
                  : bootstrapAsync.when(
                      data: (data) => RefreshIndicator(
                        onRefresh: _refresh,
                        child: switch (_section) {
                          _ChatSection.inbox => _buildConversationList(
                            items: data.inbox,
                            emptyTitle: 'Belum ada inbox layanan',
                            emptySubtitle:
                                'Inbox akan muncul otomatis saat warga butuh bantuan atau saat Anda membuka chat layanan.',
                            emptyIcon: Icons.mark_chat_unread_outlined,
                          ),
                          _ChatSection.groups => _buildConversationList(
                            items: data.groups,
                            emptyTitle: 'Belum ada grup wilayah',
                            emptySubtitle:
                                'Grup RT atau RW akan muncul sesuai role dan cakupan wilayah akun Anda.',
                            emptyIcon: Icons.groups_2_outlined,
                          ),
                        },
                      ),
                      loading: () =>
                          const _ChatListSkeleton(),
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

  Widget _buildHero({
    required String authName,
    required String roleLabel,
    required String areaLabel,
    required ChatBootstrapData? data,
  }) {
    final title = switch (_section) {
      _ChatSection.inbox => 'Percakapan warga',
      _ChatSection.groups => 'Koordinasi grup wilayah',
    };

    final subtitle = areaLabel.isEmpty ? authName : '$authName / $areaLabel';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        gradient: AppTheme.headerGradientFor(context),
        borderRadius: const BorderRadius.all(Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: AppTheme.isDark(context) ? 0.18 : 0.12,
            ),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CurrentUserAvatar(
                size: 42,
                showRing: true,
                ringColor: Colors.white24,
                backgroundColor: Colors.white24,
                textColor: Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTheme.bodyLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTheme.caption.copyWith(
                        color: Colors.white.withValues(alpha: 0.76),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              AppBadge(
                label: roleLabel,
                type: AppBadgeType.info,
                size: AppBadgeSize.small,
                style: AppBadgeStyle.solid,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _HeroSummaryTile(
                    icon: Icons.inbox_rounded,
                    label: 'Inbox',
                    value: '${data?.inbox.length ?? 0}',
                  ),
                ),
                const _HeroSummaryDivider(),
                Expanded(
                  child: _HeroSummaryTile(
                    icon: Icons.groups_rounded,
                    label: 'Grup',
                    value: '${data?.groups.length ?? 0}',
                  ),
                ),
                const _HeroSummaryDivider(),
                Expanded(
                  child: _HeroSummaryTile(
                    icon: Icons.mark_chat_unread_rounded,
                    label: 'Unread',
                    value: '${data?.totalUnreadCount ?? 0}',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionSelector({ChatBootstrapData? data}) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.cardColorFor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.cardBorderColorFor(context)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.secondaryColor.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _SectionPill(
              label: 'Inbox',
              selected: _section == _ChatSection.inbox,
              onTap: () => setState(() => _section = _ChatSection.inbox),
            ),
          ),
          Expanded(
            child: _SectionPill(
              label: 'Grup',
              selected: _section == _ChatSection.groups,
              onTap: () => setState(() => _section = _ChatSection.groups),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationList({
    required List<ConversationModel> items,
    required String emptyTitle,
    required String emptySubtitle,
    required IconData emptyIcon,
  }) {
    final filtered = items
        .where((item) => _showArchived ? item.isArchived : !item.isArchived)
        .where(_matchesConversationSearch)
        .toList(growable: false);
    final hasPinned = filtered.any((item) => item.isPinned);

    if (filtered.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 64),
          AppEmptyState(
            icon: emptyIcon,
            title: _showArchived
                ? 'Belum ada chat yang diarsipkan'
                : emptyTitle,
            message: _showArchived
                ? 'Chat yang Anda arsipkan akan muncul di sini.'
                : emptySubtitle,
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: filtered.length,
      padding: const EdgeInsets.only(bottom: 8),
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final conversation = filtered[index];
        final showPinnedHeader =
            conversation.isPinned &&
            (index == 0 || !filtered[index - 1].isPinned);
        final showOtherHeader =
            !conversation.isPinned &&
            hasPinned &&
            index > 0 &&
            filtered[index - 1].isPinned;
        final metaLabel = _conversationMetaLabel(conversation);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showPinnedHeader)
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 4, 4, 2),
                child: _ConversationSectionLabel(
                  icon: Icons.push_pin_rounded,
                  label: 'Dipin',
                ),
              ),
            if (showOtherHeader)
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 4, 4, 2),
                child: _ConversationSectionLabel(
                  icon: Icons.schedule_rounded,
                  label: 'Percakapan lain',
                ),
              ),
            Slidable(
              key: ValueKey(conversation.id),
              startActionPane: ActionPane(
                motion: const DrawerMotion(),
                extentRatio: 0.46,
                children: [
                  SlidableAction(
                    onPressed: (_) => _handleConversationAction(
                      conversation: conversation,
                      action: 'unread',
                    ),
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    icon: conversation.unreadCount > 0
                        ? Icons.mark_chat_read_rounded
                        : Icons.mark_chat_unread_rounded,
                    label: conversation.unreadCount > 0 ? 'Baca' : 'Unread',
                  ),
                  SlidableAction(
                    onPressed: (_) => _handleConversationAction(
                      conversation: conversation,
                      action: 'pin',
                    ),
                    backgroundColor: AppTheme.accentColor,
                    foregroundColor: Colors.white,
                    icon: conversation.isPinned
                        ? Icons.push_pin_rounded
                        : Icons.push_pin_outlined,
                    label: conversation.isPinned ? 'Lepas Pin' : 'Pin Chat',
                  ),
                ],
              ),
              endActionPane: ActionPane(
                motion: const DrawerMotion(),
                extentRatio: 0.68,
                children: [
                  SlidableAction(
                    onPressed: (_) => _showConversationMore(conversation),
                    backgroundColor: AppTheme.secondaryColor,
                    foregroundColor: Colors.white,
                    icon: Icons.more_horiz_rounded,
                    label: 'More',
                  ),
                  SlidableAction(
                    onPressed: (_) => _handleConversationAction(
                      conversation: conversation,
                      action: 'mute',
                    ),
                    backgroundColor: AppTheme.textSecondary,
                    foregroundColor: Colors.white,
                    icon: conversation.isMuted
                        ? Icons.notifications_active_rounded
                        : Icons.notifications_off_rounded,
                    label: conversation.isMuted ? 'Unmute' : 'Mute',
                  ),
                  SlidableAction(
                    onPressed: (_) => _handleConversationAction(
                      conversation: conversation,
                      action: 'archive',
                    ),
                    backgroundColor: AppTheme.secondaryColor,
                    foregroundColor: Colors.white,
                    icon: conversation.isArchived
                        ? Icons.unarchive_outlined
                        : Icons.archive_outlined,
                    label: conversation.isArchived ? 'Unarsip' : 'Arsip',
                  ),
                ],
              ),
              child: InkWell(
                onTap: () async {
                  await context.push(
                    Routes.chatRoom.replaceFirst(':id', conversation.id),
                  );
                  if (mounted) {
                    await _refresh();
                  }
                },
                borderRadius: BorderRadius.circular(24),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColorFor(context),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: conversation.unreadCount > 0
                          ? AppTheme.primaryColor.withValues(alpha: 0.18)
                          : AppTheme.cardBorderColorFor(context),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.secondaryColor.withValues(alpha: 0.045),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      _ConversationLeadingAvatar(conversation: conversation),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    conversation.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTheme.bodyMedium.copyWith(
                                      fontSize: 13.5,
                                      fontWeight: conversation.unreadCount > 0
                                          ? FontWeight.w800
                                          : FontWeight.w700,
                                      height: 1.2,
                                    ),
                                  ),
                                ),
                                if (conversation.unreadCount > 0)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: AppTheme.primaryColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _conversationPreview(conversation),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.caption.copyWith(
                                fontSize: 11,
                                color: conversation.unreadCount > 0
                                    ? AppTheme.textPrimary
                                    : AppTheme.textSecondary,
                                fontWeight: conversation.unreadCount > 0
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 5,
                              runSpacing: 5,
                              children: [
                                if (metaLabel.isNotEmpty)
                                  _ConversationMetaChip(label: metaLabel),
                                if (conversation.isMuted)
                                  const _ConversationMetaChip(
                                    icon: Icons.notifications_off_rounded,
                                    label: 'Mute',
                                  ),
                                if (conversation.isPinned)
                                  _ConversationMetaChip(
                                    icon: Icons.push_pin_rounded,
                                    label: 'Dipin',
                                    foregroundColor: AppTheme.accentColor,
                                    backgroundColor: AppTheme.accentColor
                                        .withValues(alpha: 0.10),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            conversation.lastMessageAt != null
                                ? Formatters.waktuRingkas(
                                    conversation.lastMessageAt!,
                                  )
                                : '',
                            style: AppTheme.caption.copyWith(
                              fontSize: 11,
                              color: conversation.unreadCount > 0
                                  ? AppTheme.primaryColor
                                  : AppTheme.textSecondary,
                              fontWeight: conversation.unreadCount > 0
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (conversation.unreadCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                conversation.unreadCount > 99
                                    ? '99+'
                                    : '${conversation.unreadCount}',
                                style: AppTheme.caption.copyWith(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            )
                          else
                            Icon(
                              conversation.isPinned
                                  ? Icons.push_pin_rounded
                                  : Icons.chevron_right_rounded,
                              size: 16,
                              color: conversation.isPinned
                                  ? AppTheme.accentColor
                                  : AppTheme.textTertiary,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleConversationAction({
    required ConversationModel conversation,
    required String action,
  }) async {
    final service = ref.read(chatServiceProvider);
    try {
      switch (action) {
        case 'pin':
          await service.setConversationPreference(
            conversationId: conversation.id,
            isPinned: !conversation.isPinned,
          );
          break;
        case 'unread':
          if (conversation.unreadCount > 0) {
            await service.markConversationRead(conversation.id);
          } else {
            await service.markConversationUnread(conversation.id);
          }
          break;
        case 'mute':
          await service.setConversationPreference(
            conversationId: conversation.id,
            isMuted: !conversation.isMuted,
          );
          break;
        case 'archive':
          await service.setConversationPreference(
            conversationId: conversation.id,
            isArchived: !conversation.isArchived,
          );
          break;
      }
      await _refresh();
    } catch (error) {
      if (mounted) {
        ErrorClassifier.showErrorSnackBar(context, error);
      }
    }
  }

  Future<void> _showConversationMore(ConversationModel conversation) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: Wrap(
            children: [
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  conversation.isPinned
                      ? Icons.push_pin_rounded
                      : Icons.push_pin_outlined,
                ),
                title: Text(conversation.isPinned ? 'Lepas pin' : 'Pin chat'),
                onTap: () {
                  Navigator.pop(context);
                  _handleConversationAction(
                    conversation: conversation,
                    action: 'pin',
                  );
                },
              ),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  conversation.isMuted
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_off_rounded,
                ),
                title: Text(
                  conversation.isMuted ? 'Aktifkan notifikasi' : 'Mute chat',
                ),
                onTap: () {
                  Navigator.pop(context);
                  _handleConversationAction(
                    conversation: conversation,
                    action: 'mute',
                  );
                },
              ),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  conversation.isArchived
                      ? Icons.unarchive_outlined
                      : Icons.archive_outlined,
                ),
                title: Text(
                  conversation.isArchived
                      ? 'Keluarkan dari arsip'
                      : 'Arsipkan chat',
                ),
                onTap: () {
                  Navigator.pop(context);
                  _handleConversationAction(
                    conversation: conversation,
                    action: 'archive',
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _matchesConversationSearch(ConversationModel item) {
    if (_searchQuery.isEmpty) {
      return true;
    }
    final haystack = [
      item.name,
      item.subtitle,
      item.lastMessage ?? '',
      'rt ${item.rt}',
      'rw ${item.rw}',
    ].join(' ').toLowerCase();
    return haystack.contains(_searchQuery);
  }

  String _conversationPreview(ConversationModel conversation) {
    final lastMessage = (conversation.lastMessage ?? '').trim();
    if (lastMessage.isNotEmpty) {
      return lastMessage;
    }
    if (conversation.isPrivate) {
      return 'Mulai percakapan dengan ${conversation.name}.';
    }
    return conversation.subtitle;
  }

  String _conversationMetaLabel(ConversationModel conversation) {
    final badgeLabel = (conversation.badgeLabel ?? '').trim();
    if (badgeLabel.isNotEmpty &&
        badgeLabel.toLowerCase() !=
            AppConstants.roleLabel(AppConstants.roleWarga).toLowerCase()) {
      return badgeLabel;
    }
    if (conversation.isPrivate) {
      return '';
    }
    if (conversation.isGroupRt) {
      return 'Grup RT ${conversation.rt.toString().padLeft(2, '0')}';
    }
    return 'Grup RW ${conversation.rw.toString().padLeft(2, '0')}';
  }

  Future<void> _refresh() async {
    ref.read(chatServiceProvider).invalidateBootstrapCache();
    ref.invalidate(chatBootstrapProvider);
    await ref.read(chatBootstrapProvider.future);
  }
}

class _SectionPill extends StatelessWidget {
  const _SectionPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTheme.bodyMedium.copyWith(
            fontSize: 12.5,
            color: selected ? Colors.white : AppTheme.textSecondary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _HeroSummaryTile extends StatelessWidget {
  const _HeroSummaryTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.92)),
        const SizedBox(height: 8),
        Text(
          value,
          style: AppTheme.bodyLarge.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTheme.caption.copyWith(
            color: Colors.white.withValues(alpha: 0.72),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _HeroSummaryDivider extends StatelessWidget {
  const _HeroSummaryDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: Colors.white.withValues(alpha: 0.12),
    );
  }
}

class _ArchiveToggleButton extends StatelessWidget {
  const _ArchiveToggleButton({
    required this.active,
    required this.count,
    required this.onTap,
  });

  final bool active;
  final int? count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = count != null && count! > 0 ? 'Arsip $count' : 'Arsip';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: active
              ? AppTheme.secondaryColor
              : AppTheme.cardColorFor(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: active
                ? AppTheme.secondaryColor
                : AppTheme.cardBorderColorFor(context),
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.secondaryColor.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              active ? Icons.unarchive_outlined : Icons.archive_outlined,
              size: 18,
              color: active ? Colors.white : AppTheme.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              active ? 'Aktif' : label,
              style: AppTheme.bodySmall.copyWith(
                fontSize: 12,
                color: active ? Colors.white : AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationSectionLabel extends StatelessWidget {
  const _ConversationSectionLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppTheme.textSecondary),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTheme.caption.copyWith(
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ConversationMetaChip extends StatelessWidget {
  const _ConversationMetaChip({
    required this.label,
    this.icon,
    this.foregroundColor = AppTheme.textSecondary,
    this.backgroundColor = AppTheme.extraLightGray,
  });

  final String label;
  final IconData? icon;
  final Color foregroundColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: foregroundColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppTheme.caption.copyWith(
              fontSize: 10,
              color: foregroundColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationLeadingAvatar extends StatelessWidget {
  const _ConversationLeadingAvatar({required this.conversation});

  final ConversationModel conversation;

  @override
  Widget build(BuildContext context) {
    final hasAvatar = (conversation.avatarUrl ?? '').trim().isNotEmpty;
    if (conversation.isPrivate || hasAvatar) {
      return _AvatarCircle(
        imageUrl: conversation.avatarUrl,
        label: conversation.name,
        size: 44,
      );
    }

    return Container(
      width: 44,
      height: 44,
        decoration: BoxDecoration(
          gradient: conversation.isGroupRt
              ? const LinearGradient(
                  colors: [AppTheme.secondaryColor, AppTheme.primaryColor],
                )
              : const LinearGradient(
                  colors: [AppTheme.accentColor, AppTheme.primaryLight],
                ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppTheme.secondaryColor.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(
        conversation.isGroupRt ? Icons.groups_rounded : Icons.hub_rounded,
        color: Colors.white,
        size: 20,
      ),
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({
    required this.imageUrl,
    required this.label,
    this.size = 36,
  });

  final String? imageUrl;
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final safeLabel = label.trim().isEmpty ? '?' : label.trim();
    final normalizedUrl = (imageUrl ?? '').trim();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.14),
          width: 1.5,
        ),
      ),
      child: ClipOval(
        child: normalizedUrl.isNotEmpty
            ? Image.network(
                normalizedUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _AvatarFallback(
                  label: safeLabel,
                  size: size,
                  textColor: AppTheme.primaryColor,
                  backgroundColor: AppTheme.primaryColor.withValues(
                    alpha: 0.12,
                  ),
                ),
              )
            : _AvatarFallback(
                label: safeLabel,
                size: size,
                textColor: AppTheme.primaryColor,
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
              ),
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({
    required this.label,
    required this.size,
    required this.textColor,
    required this.backgroundColor,
  });

  final String label;
  final double size;
  final Color textColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: backgroundColor,
      alignment: Alignment.center,
      child: Text(
        Formatters.inisial(label),
        style: AppTheme.bodyMedium.copyWith(
          color: textColor,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ChatListSkeleton extends StatelessWidget {
  const _ChatListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 6,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, _) => const AppSurfaceCard(
        padding: EdgeInsets.all(14),
        child: Row(
          children: [
            AppSkeleton(width: 50, height: 50, borderRadius: 14),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: AppSkeleton(height: 16)),
                      SizedBox(width: 8),
                      AppSkeleton(width: 40, height: 12),
                    ],
                  ),
                  SizedBox(height: 8),
                  AppSkeleton(height: 14),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
