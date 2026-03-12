import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/notification_service.dart';
import 'router.dart';
import 'theme.dart';

class RukunWargaApp extends ConsumerStatefulWidget {
  const RukunWargaApp({super.key});

  @override
  ConsumerState<RukunWargaApp> createState() => _RukunWargaAppState();
}

class _RukunWargaAppState extends ConsumerState<RukunWargaApp> {
  @override
  void initState() {
    super.initState();
    NotificationService().launchPayload.addListener(_handleLaunchPayload);
  }

  @override
  void dispose() {
    NotificationService().launchPayload.removeListener(_handleLaunchPayload);
    super.dispose();
  }

  void _handleLaunchPayload() {
    final payload = NotificationService().launchPayload.value?.trim() ?? '';
    if (payload.isEmpty) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(routerProvider).go(payload);
      NotificationService().clearLaunchPayload();
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'RukunWarga',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      routerConfig: router,
    );
  }
}
