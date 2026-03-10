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
import '../../../shared/widgets/floating_action_pill.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/chat_providers.dart';

enum _ChatSection { inbox, groups, announcements }

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

  void _triggerRefresh({bool includeAnnouncements = false}) {
    ref.read(chatRefreshTickProvider.notifier).bump();
    if (includeAnnouncements || _section == _ChatSection.announcements) {
      ref.invalidate(chatAnnouncementsProvider);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final bootstrapAsync = ref.watch(chatBootstrapProvider);
    final announcementsAsync = ref.watch(chatAnnouncementsProvider);
    final bootstrapData = bootstrapAsync.asData?.value;
    final announcementsData = announcementsAsync.asData?.value;
    final showBootstrap = bootstrapData != null;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Chat'),
        actions: [
          IconButton(
            tooltip: _showArchived ? 'Tampilkan aktif' : 'Tampilkan arsip',
            onPressed: () => setState(() => _showArchived = !_showArchived),
            icon: Icon(
              _showArchived
                  ? Icons.unarchive_outlined
                  : Icons.archive_outlined,
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton:
          _section == _ChatSection.announcements &&
              announcementsData?.canCreate == true
          ? FloatingActionPill(
              onTap: () => context.push(Routes.announcements),
              icon: Icons.campaign_rounded,
              label: 'Kelola Pengumuman',
              gradientColors: const [AppTheme.accentColor, Color(0xFFE0B56C)],
            )
          : null,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFF2F7F5),
              Colors.white.withValues(alpha: 0.98),
              const Color(0xFFF7FBF9),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
                const SizedBox(height: 8),
                _buildSearchField(),
                const SizedBox(height: 8),
                _buildSectionSelector(),
                const SizedBox(height: 8),
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
                            _ChatSection.announcements =>
                              _buildAnnouncementPreview(announcementsAsync),
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
                        _ChatSection.announcements =>
                          _buildAnnouncementPreview(announcementsAsync),
                      },
                          ),
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (error, _) => Center(
                            child: AppTheme.glassContainer(
                              opacity: 0.76,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    ErrorClassifier.classify(error).message,
                                    style: AppTheme.bodyMedium,
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 10),
                                  ElevatedButton(
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
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: switch (_section) {
            _ChatSection.inbox => 'Cari nama, isi chat, atau percakapan...',
            _ChatSection.groups => 'Cari grup, isi chat, atau RT/RW...',
            _ChatSection.announcements => 'Cari judul, isi, atau pembuat...',
          },
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _searchCtrl.text.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() {});
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
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
      _ChatSection.inbox => 'Inbox layanan warga dan pengurus',
      _ChatSection.groups => 'Forum RT dan koordinasi RW',
      _ChatSection.announcements => 'Pengumuman resmi wilayah Anda',
    };
    final subtitle = switch (_section) {
      _ChatSection.inbox =>
        'Gunakan inbox untuk percakapan bantuan administrasi, dokumen, surat, dan layanan.',
      _ChatSection.groups =>
        'Grup dipakai untuk koordinasi operasional sesuai cakupan RT dan RW akun Anda.',
      _ChatSection.announcements =>
        'Pengumuman dipisahkan dari chat harian agar informasi penting tetap rapi dan mudah dicari.',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        gradient: AppTheme.headerGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
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
          const SizedBox(height: 10),
          Text(
            authName,
            style: AppTheme.heading2.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (areaLabel.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              areaLabel,
              style: AppTheme.bodySmall.copyWith(
                color: Colors.white.withValues(alpha: 0.86),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(title, style: AppTheme.heading2.copyWith(color: Colors.white)),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: AppTheme.bodyMedium.copyWith(
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _StatChip(
                icon: Icons.mark_chat_read_rounded,
                label: 'Inbox',
                value: '${data?.inbox.length ?? 0}',
                unreadCount: data?.inboxUnreadCount ?? 0,
              ),
              const SizedBox(width: 8),
              _StatChip(
                icon: Icons.groups_rounded,
                label: 'Grup',
                value: '${data?.groups.length ?? 0}',
                unreadCount: data?.groupUnreadCount ?? 0,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerColor),
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
          Expanded(
            child: _SectionPill(
              label: 'Pengumuman',
              selected: _section == _ChatSection.announcements,
              onTap: () => setState(
                () => _section = _ChatSection.announcements,
              ),
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

    if (filtered.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 48),
          Center(
            child: AppTheme.glassContainer(
              opacity: 0.72,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(emptyIcon, size: 44, color: AppTheme.textSecondary),
                  const SizedBox(height: 12),
                  Text(
                    _showArchived ? 'Belum ada chat yang diarsipkan' : emptyTitle,
                    style: AppTheme.heading3,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _showArchived
                        ? 'Chat yang Anda arsipkan akan muncul di sini.'
                        : emptySubtitle,
                    style: AppTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
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
        final scopeLabel = conversation.isPrivate
            ? 'Percakapan layanan'
            : conversation.isGroupRt
                ? 'RT ${conversation.rt.toString().padLeft(2, '0')} / RW ${conversation.rw.toString().padLeft(2, '0')}'
                : 'RW ${conversation.rw.toString().padLeft(2, '0')}';

        return Slidable(
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
                label: conversation.isPinned ? 'Unpin' : 'Pin',
              ),
            ],
          ),
          endActionPane: ActionPane(
            motion: const DrawerMotion(),
            extentRatio: 0.68,
            children: [
              SlidableAction(
                onPressed: (_) => _showConversationMore(conversation),
                backgroundColor: const Color(0xFF54616B),
                foregroundColor: Colors.white,
                icon: Icons.more_horiz_rounded,
                label: 'More',
              ),
              SlidableAction(
                onPressed: (_) => _handleConversationAction(
                  conversation: conversation,
                  action: 'mute',
                ),
                backgroundColor: const Color(0xFF5E6B66),
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
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.dividerColor),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.04),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                    gradient: conversation.isPrivate
                        ? const LinearGradient(
                            colors: [AppTheme.primaryColor, AppTheme.primaryLight],
                          )
                        : conversation.isGroupRt
                            ? const LinearGradient(
                                colors: [Color(0xFF2E5F55), AppTheme.primaryColor],
                              )
                            : const LinearGradient(
                                colors: [AppTheme.accentColor, Color(0xFFE2B96D)],
                              ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      conversation.isPrivate
                          ? Icons.support_agent_rounded
                          : conversation.isGroupRt
                              ? Icons.groups_rounded
                              : Icons.hub_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
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
                                style: AppTheme.bodyLarge.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              conversation.lastMessageAt != null
                                  ? Formatters.waktuRingkas(conversation.lastMessageAt!)
                                  : '',
                              style: AppTheme.caption.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Expanded(child: Text(scopeLabel, style: AppTheme.caption)),
                            if (conversation.isPinned)
                              const Icon(
                                Icons.push_pin_rounded,
                                size: 14,
                                color: AppTheme.accentColor,
                              ),
                            if (conversation.isMuted) ...[
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.notifications_off_rounded,
                                size: 14,
                                color: AppTheme.textSecondary,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                (conversation.lastMessage ?? '').trim().isNotEmpty
                                    ? conversation.lastMessage!.trim()
                                    : conversation.subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTheme.bodyMedium.copyWith(
                                  color: AppTheme.textSecondary,
                                  height: 1.3,
                                ),
                              ),
                            ),
                            if (conversation.unreadCount > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  gradient: AppTheme.primaryGradient,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  conversation.unreadCount > 99
                                      ? '99+'
                                      : '${conversation.unreadCount}',
                                  style: AppTheme.caption.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnnouncementPreview(
    AsyncValue<ChatAnnouncementsData> announcementsAsync,
  ) {
    final data = announcementsAsync.asData?.value;
    if (data != null) {
      final items = data.items.where(_matchesAnnouncementSearch).toList(growable: false);
      if (items.isEmpty) {
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 48),
            Center(
              child: AppTheme.glassContainer(
                opacity: 0.72,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.campaign_outlined,
                      size: 44,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(height: 12),
                    Text('Tidak ada hasil pengumuman', style: AppTheme.heading3),
                    const SizedBox(height: 6),
                    Text(
                      _searchQuery.isEmpty
                          ? 'Pengumuman resmi RT/RW akan muncul di sini.'
                          : 'Ubah kata kunci pencarian untuk melihat hasil lain.',
                      style: AppTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }

      return ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: items.length,
        padding: const EdgeInsets.only(bottom: 10),
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final item = items[index];
          return Container(
            padding: const EdgeInsets.all(12),
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                          ? Formatters.waktuRingkas(item.createdAt!)
                          : '',
                      style: AppTheme.caption,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(item.title, style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  item.content,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.bodyMedium.copyWith(height: 1.35),
                ),
                const SizedBox(height: 8),
                Text(
                  'Oleh ${item.authorName}',
                  style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
                ),
              ],
            ),
          );
        },
      );
    }

    return announcementsAsync.when(
      data: (data) {
        if (data.items.isEmpty) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const SizedBox(height: 48),
              Center(
                child: AppTheme.glassContainer(
                  opacity: 0.72,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.campaign_outlined,
                        size: 44,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(height: 12),
                      Text('Belum ada pengumuman', style: AppTheme.heading3),
                      const SizedBox(height: 6),
                      Text(
                        'Pengumuman resmi RT/RW akan muncul di sini.',
                        style: AppTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        return const SizedBox.shrink();
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) =>
          Center(child: Text(ErrorClassifier.classify(error).message)),
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

  bool _matchesAnnouncementSearch(AnnouncementModel item) {
    if (_searchQuery.isEmpty) {
      return true;
    }
    final haystack = [
      item.title,
      item.content,
      item.authorName,
      item.targetLabel,
    ].join(' ').toLowerCase();
    return haystack.contains(_searchQuery);
  }

  Future<void> _refresh() async {
    _triggerRefresh(includeAnnouncements: true);
    await Future<void>.delayed(const Duration(milliseconds: 250));
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
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: selected ? AppTheme.primaryGradient : null,
          color: selected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTheme.bodyMedium.copyWith(
            color: selected ? Colors.white : AppTheme.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    this.unreadCount = 0,
  });

  final IconData icon;
  final String label;
  final String value;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            '$label $value',
            style: AppTheme.caption.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (unreadCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.24),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                unreadCount > 99 ? '99+' : '$unreadCount',
                style: AppTheme.caption.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
