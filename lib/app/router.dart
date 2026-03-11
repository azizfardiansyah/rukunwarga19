// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/warga/screens/warga_list_screen.dart';
import '../features/warga/screens/warga_form_screen.dart';
import '../features/warga/screens/warga_detail_screen.dart';
import '../features/kartu_keluarga/screens/kk_list_screen.dart';
import '../features/kartu_keluarga/screens/kk_form_screen.dart';
import '../features/kartu_keluarga/screens/kk_detail_screen.dart';
import '../features/dokumen/screens/dokumen_list_screen.dart';
import '../features/dokumen/screens/dokumen_upload_screen.dart';
import '../features/surat/screens/surat_list_screen.dart';
import '../features/surat/screens/surat_form_screen.dart';
import '../features/surat/screens/surat_detail_screen.dart';
import '../features/iuran/screens/iuran_list_screen.dart';
import '../features/iuran/screens/iuran_form_screen.dart';
import '../features/laporan/screens/laporan_screen.dart';
import '../features/chat/screens/chat_list_screen.dart';
import '../features/chat/screens/chat_room_screen.dart';
import '../features/chat/screens/announcement_screen.dart';
import '../features/notifikasi/screens/notifikasi_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/settings/screens/role_request_screen.dart';
import '../features/settings/screens/subscription_screen.dart';
import '../features/settings/screens/user_role_management_screen.dart';
import '../features/organization/screens/organization_workspace_screen.dart';
import '../features/organization/screens/organization_unit_screen.dart';
import '../features/organization/screens/organization_membership_screen.dart';
import '../shared/widgets/main_scaffold.dart';

// Route paths
class Routes {
  static const String login = '/login';
  static const String register = '/register';
  static const String dashboard = '/';
  static const String warga = '/warga';
  static const String wargaForm = '/warga/form';
  static const String wargaDetail = '/warga/:id';
  static const String kartuKeluarga = '/kartu-keluarga';
  static const String kkForm = '/kartu-keluarga/form';
  static const String kkDetail = '/kartu-keluarga/:id';
  static const String dokumen = '/dokumen';
  static const String dokumenUpload = '/dokumen/upload';
  static const String surat = '/surat';
  static const String suratForm = '/surat/form';
  static const String suratDetail = '/surat/:id';
  static const String iuran = '/iuran';
  static const String iuranForm = '/iuran/form';
  static const String laporan = '/laporan';
  static const String chat = '/chat';
  static const String chatRoom = '/chat/:id';
  static const String announcements = '/pengumuman';
  static const String notifikasi = '/notifikasi';
  static const String settings = '/settings';
  static const String subscription = '/subscription';
  static const String roleRequests = '/settings/role-requests';
  static const String userManagement = '/settings/user-management';
  static const String organization = '/organisasi';
  static const String organizationUnits = '/organisasi/unit';
  static const String organizationMemberships = '/organisasi/membership';
}

/// A [ChangeNotifier] bridge so that [GoRouter.refreshListenable] re-evaluates
/// its redirect whenever the Riverpod auth state changes.
class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier(Ref ref) {
    // Listen to auth state changes; every emission triggers GoRouter redirect.
    ref.listen<AuthState>(authProvider, (_, _) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthChangeNotifier(ref);

  // Create keys inside the provider closure so each GoRouter instance
  // gets its own keys — prevents "Duplicate GlobalKey" on hot restart
  // or provider invalidation.
  final rootNavigatorKey = GlobalKey<NavigatorState>();
  final shellNavigatorKey = GlobalKey<NavigatorState>();

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    refreshListenable: notifier,
    initialLocation: Routes.dashboard,
    redirect: (context, state) {
      // Read (not watch) current auth state inside redirect callback.
      final authState = ref.read(authProvider);
      final isLoggedIn = authState.isAuthenticated;
      final isAuthRoute =
          state.matchedLocation == Routes.login ||
          state.matchedLocation == Routes.register;

      if (!isLoggedIn && !isAuthRoute) {
        return Routes.login;
      }
      if (isLoggedIn && isAuthRoute) {
        return Routes.dashboard;
      }
      if (isLoggedIn &&
          authState.requiresSubscription &&
          !authState.hasActiveSubscription) {
        final isAllowedWhileInactive =
            state.matchedLocation == Routes.subscription ||
            state.matchedLocation == Routes.settings ||
            state.matchedLocation == Routes.roleRequests;

        if (!isAllowedWhileInactive) {
          return Routes.subscription;
        }
      }
      return null;
    },
    routes: [
      // Auth routes (tanpa shell)
      GoRoute(
        path: Routes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: Routes.register,
        builder: (context, state) => const RegisterScreen(),
      ),

      // Main app routes (dengan bottom nav shell)
      ShellRoute(
        navigatorKey: shellNavigatorKey,
        builder: (context, state, child) => MainScaffold(child: child),
        routes: [
          GoRoute(
            path: Routes.dashboard,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: DashboardScreen()),
          ),
          GoRoute(
            path: Routes.warga,
            builder: (context, state) {
              return _WargaEntryPoint();
            },
          ),
          GoRoute(
            path: Routes.chat,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ChatListScreen()),
          ),
          GoRoute(
            path: Routes.settings,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: SettingsScreen()),
          ),
        ],
      ),

      // Detail & form routes (full screen, tanpa bottom nav)
      GoRoute(
        path: Routes.wargaForm,
        builder: (context, state) {
          final wargaId = state.uri.queryParameters['id'];
          final noKk = state.uri.queryParameters['noKk'];
          return WargaFormScreen(wargaId: wargaId, initialNoKk: noKk);
        },
      ),
      GoRoute(
        path: Routes.wargaDetail,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return WargaDetailScreen(wargaId: id);
        },
      ),
      GoRoute(
        path: Routes.kartuKeluarga,
        builder: (context, state) => const KkListScreen(),
      ),
      GoRoute(
        path: Routes.kkForm,
        builder: (context, state) {
          final kkId = state.uri.queryParameters['id'];
          return KkFormScreen(kkId: kkId);
        },
      ),
      GoRoute(
        path: Routes.kkDetail,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return KkDetailScreen(kkId: id);
        },
      ),
      GoRoute(
        path: Routes.dokumen,
        builder: (context, state) => const DokumenListScreen(),
      ),
      GoRoute(
        path: Routes.dokumenUpload,
        builder: (context, state) => const DokumenUploadScreen(),
      ),
      GoRoute(
        path: Routes.surat,
        builder: (context, state) => const SuratListScreen(),
      ),
      GoRoute(
        path: Routes.suratForm,
        builder: (context, state) {
          final suratId = state.uri.queryParameters['id'];
          return SuratFormScreen(suratId: suratId);
        },
      ),
      GoRoute(
        path: Routes.suratDetail,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return SuratDetailScreen(suratId: id);
        },
      ),
      GoRoute(
        path: Routes.iuran,
        builder: (context, state) => const IuranListScreen(),
      ),
      GoRoute(
        path: Routes.iuranForm,
        builder: (context, state) => const IuranFormScreen(),
      ),
      GoRoute(
        path: Routes.laporan,
        builder: (context, state) {
          final focus = state.uri.queryParameters['focus'];
          return LaporanScreen(initialFocus: focus);
        },
      ),
      GoRoute(
        path: Routes.chatRoom,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ChatRoomScreen(conversationId: id);
        },
      ),
      GoRoute(
        path: Routes.announcements,
        builder: (context, state) => const AnnouncementScreen(),
      ),
      GoRoute(
        path: Routes.notifikasi,
        builder: (context, state) => const NotifikasiScreen(),
      ),
      GoRoute(
        path: Routes.roleRequests,
        builder: (context, state) => const RoleRequestScreen(),
      ),
      GoRoute(
        path: Routes.subscription,
        builder: (context, state) => const SubscriptionScreen(),
      ),
      GoRoute(
        path: Routes.userManagement,
        builder: (context, state) => const UserRoleManagementScreen(),
      ),
      GoRoute(
        path: Routes.organization,
        builder: (context, state) => const OrganizationWorkspaceScreen(),
      ),
      GoRoute(
        path: Routes.organizationUnits,
        builder: (context, state) => const OrganizationUnitScreen(),
      ),
      GoRoute(
        path: Routes.organizationMemberships,
        builder: (context, state) => const OrganizationMembershipScreen(),
      ),
    ],
  );
});

// Tambahkan widget entry point untuk menu Data Warga
class _WargaEntryPoint extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return WargaListScreen();
  }
}
