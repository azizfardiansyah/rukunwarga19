import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/pocketbase_service.dart';
import '../../core/utils/area_access.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/chat/providers/chat_providers.dart';
import '../../features/surat/providers/surat_providers.dart';
import '../../shared/models/surat_model.dart';

class MainScaffold extends ConsumerStatefulWidget {
  const MainScaffold({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  Future<void> Function()? _unsubscribeConversations;
  Future<void> Function()? _unsubscribeMessages;
  Future<void> Function()? _unsubscribeMembers;
  Future<void> Function()? _unsubscribeAnnouncements;
  Future<void> Function()? _unsubscribeSurat;
  Future<void> Function()? _unsubscribeSuratLogs;
  Timer? _refreshDebounce;
  final Set<String> _seenSuratLogIds = <String>{};

  @override
  void initState() {
    super.initState();
    _bindRealtime();
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
        .subscribe('*', (_) => _scheduleRefresh());
    _unsubscribeSurat = await pb
        .collection(AppConstants.colSurat)
        .subscribe('*', (_) => _scheduleRefresh());
    _unsubscribeSuratLogs = await pb
        .collection(AppConstants.colSuratLogs)
        .subscribe('*', (event) => _handleSuratLogEvent(event));
  }

  void _scheduleRefresh() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) {
        return;
      }
      ref.read(chatRefreshTickProvider.notifier).bump();
      ref.read(suratRefreshTickProvider.notifier).bump();
    });
  }

  Future<void> _handleSuratLogEvent(dynamic event) async {
    _scheduleRefresh();

    final action = '${event.action ?? ''}'.toLowerCase();
    final record = event.record;
    if (action != 'create' || record == null) {
      return;
    }

    final log = SuratLogModel.fromRecord(record);
    if (_seenSuratLogIds.contains(log.id)) {
      return;
    }
    _seenSuratLogIds.add(log.id);

    final auth = ref.read(authProvider);
    if (auth.user == null || log.actorId == auth.user!.id) {
      return;
    }

    try {
      final suratRecord = await pb
          .collection(AppConstants.colSurat)
          .getOne(log.requestId);
      final surat = SuratModel.fromRecord(suratRecord);
      final access = await resolveAreaAccessContext(auth);
      if (!canAccessSuratRecord(auth, surat, context: access)) {
        return;
      }

      await NotificationService().showSuratNotification(
        title: surat.title,
        body: log.description,
        payload: '/surat/${surat.id}',
      );
    } catch (_) {}
  }

  Future<void> _disposeRealtime() async {
    await _unsubscribeConversations?.call();
    await _unsubscribeMessages?.call();
    await _unsubscribeMembers?.call();
    await _unsubscribeAnnouncements?.call();
    await _unsubscribeSurat?.call();
    await _unsubscribeSuratLogs?.call();
    _unsubscribeConversations = null;
    _unsubscribeMessages = null;
    _unsubscribeMembers = null;
    _unsubscribeAnnouncements = null;
    _unsubscribeSurat = null;
    _unsubscribeSuratLogs = null;
  }

  int _getSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location == Routes.dashboard || location == Routes.warga) return 0;
    if (location == Routes.chat) return 1;
    if (location == Routes.settings) return 2;
    return 0;
  }

  @override
  void dispose() {
    _refreshDebounce?.cancel();
    _disposeRealtime();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _getSelectedIndex(context);
    final unreadCount = ref.watch(chatUnreadCountProvider);

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(
              color: AppTheme.dividerColor.withValues(alpha: 0.5),
              width: 0.5,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: NavigationBar(
            selectedIndex: selectedIndex,
            backgroundColor: Colors.transparent,
            elevation: 0,
            height: 68,
            onDestinationSelected: (index) {
              switch (index) {
                case 0:
                  context.go(Routes.dashboard);
                  break;
                case 1:
                  context.go(Routes.chat);
                  break;
                case 2:
                  context.go(Routes.settings);
                  break;
              }
            },
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.space_dashboard_outlined),
                selectedIcon: Icon(Icons.space_dashboard),
                label: 'Dashboard',
              ),
              NavigationDestination(
                icon: unreadCount > 0
                    ? Badge(
                        label: Text(unreadCount > 99 ? '99+' : '$unreadCount'),
                        child: const Icon(Icons.chat_bubble_outline_rounded),
                      )
                    : const Icon(Icons.chat_bubble_outline_rounded),
                selectedIcon: unreadCount > 0
                    ? Badge(
                        label: Text(unreadCount > 99 ? '99+' : '$unreadCount'),
                        child: const Icon(Icons.chat_bubble_rounded),
                      )
                    : const Icon(Icons.chat_bubble_rounded),
                label: 'Chat',
              ),
              const NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings_rounded),
                label: 'Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
