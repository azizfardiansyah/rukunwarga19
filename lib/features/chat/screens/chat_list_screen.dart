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
  _ChatSection _section = _ChatSection.inbox;
  bool _showArchived = false;
  Future<void> Function()? _unsubscribeConversations;
  Future<void> Function()? _unsubscribeMessages;
  Future<void> Function()? _unsubscribeMembers;
  Future<void> Function()? _unsubscribeAnnouncements;
  Timer? _refreshDebounce;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _bindRealtime();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _triggerRefresh(includeAnnouncements: _section == _ChatSection.announcements),
    );
  }

  Future<void> _bindRealtime() async {
    await _disposeRealtime();
    _unsubscribeConversations = await pb
        .collection(AppConstants.colConversations)
        .subscribe('*', (_) => _scheduleRefresh());
    _unsubscribeMessages = await pb
        .collection(AppConstants.colMessages)
        .subscribe('*', (_) => _scheduleRefresh());
    _unsubscribeMembers = await pb
        .collection(AppConstants.colConversationMembers)
        .subscribe('*', (_) => _scheduleRefresh());
    _unsubscribeAnnouncements = await pb
        .collection(AppConstants.colAnnouncements)
        .subscribe('*', (_) => _scheduleRefresh(includeAnnouncements: true));
  }

  void _scheduleRefresh({bool includeAnnouncements = false}) {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) {
        return;
      }
      _triggerRefresh(includeAnnouncements: includeAnnouncements);
    });
  }

  void _triggerRefresh({bool includeAnnouncements = false}) {
    ref.read(chatRefreshTickProvider.notifier).bump();
    if (includeAnnouncements || _section == _ChatSection.announcements) {
      ref.invalidate(chatAnnouncementsProvider);
    }
  }

  Future<void> _disposeRealtime() async {
    await _unsubscribeConversations?.call();
    await _unsubscribeMessages?.call();
    await _unsubscribeMembers?.call();
    await _unsubscribeAnnouncements?.call();
    _unsubscribeConversations = null;
    _unsubscribeMessages = null;
    _unsubscribeMembers = null;
    _unsubscribeAnnouncements = null;
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _refreshDebounce?.cancel();
    _disposeRealtime();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final bootstrapAsync = ref.watch(chatBootstrapProvider);
    final announcementsAsync = ref.watch(chatAnnouncementsProvider);
    final bootstrapData = bootstrapAsync.asData?.value;
    final announcementsData = announcementsAsync.asData?.value;

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
              gradientColors: const [Color(0xFFFF8F00), Color(0xFFFFA726)],
            )
          : null,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFEAF3FF), Color(0xFFF7FBFF), Color(0xFFF5FFFC)],
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
                const SizedBox(height: 10),
                _buildSectionSelector(),
                const SizedBox(height: 10),
                Expanded(
                  child: bootstrapAsync.when(
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
        gradient: const LinearGradient(
          colors: [Color(0xFF0D47A1), Color(0xFF1976D2), Color(0xFF42A5F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
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
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final conversation = filtered[index];
        final scopeLabel = conversation.isPrivate
            ? 'Percakapan layanan'
            : conversation.isGroupRt
                ? 'RT ${conversation.rt.toString().padLeft(2, '0')} / RW ${conversation.rw.toString().padLeft(2, '0')}'
                : 'RW ${conversation.rw.toString().padLeft(2, '0')}';

        return InkWell(
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
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.dividerColor),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: conversation.isPrivate
                        ? const LinearGradient(
                            colors: [Color(0xFF00897B), Color(0xFF26A69A)],
                          )
                        : conversation.isGroupRt
                            ? const LinearGradient(
                                colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                              )
                            : const LinearGradient(
                                colors: [Color(0xFFFF8F00), Color(0xFFFFB300)],
                              ),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    conversation.isPrivate
                        ? Icons.support_agent_rounded
                        : conversation.isGroupRt
                            ? Icons.groups_rounded
                            : Icons.hub_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (conversation.isPinned) ...[
                            const Icon(
                              Icons.push_pin_rounded,
                              size: 15,
                              color: Color(0xFFFF8F00),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(
                              conversation.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.bodyLarge.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          if (conversation.lastMessageAt != null)
                            Text(
                              Formatters.tanggalRelatif(
                                conversation.lastMessageAt!,
                              ),
                              style: AppTheme.caption.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Expanded(
                            child: Text(scopeLabel, style: AppTheme.caption),
                          ),
                          if (conversation.isMuted)
                            const Icon(
                              Icons.notifications_off_rounded,
                              size: 15,
                              color: AppTheme.textSecondary,
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (conversation.unreadCount > 0)
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
                              PopupMenuButton<String>(
                                tooltip: 'Aksi chat',
                                padding: EdgeInsets.zero,
                                icon: const Icon(
                                  Icons.more_horiz_rounded,
                                  color: AppTheme.textSecondary,
                                ),
                                onSelected: (value) =>
                                    _handleConversationAction(
                                  conversation: conversation,
                                  action: value,
                                ),
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: 'pin',
                                    child: Text(
                                      conversation.isPinned
                                          ? 'Lepas pin'
                                          : 'Pin chat',
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'mute',
                                    child: Text(
                                      conversation.isMuted
                                          ? 'Aktifkan notifikasi'
                                          : 'Mute chat',
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'archive',
                                    child: Text(
                                      conversation.isArchived
                                          ? 'Keluarkan dari arsip'
                                          : 'Arsipkan chat',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnnouncementPreview(
    AsyncValue<ChatAnnouncementsData> announcementsAsync,
  ) {
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

        return ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: data.items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = data.items[index];
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
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
                    style: AppTheme.caption.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          },
        );
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
