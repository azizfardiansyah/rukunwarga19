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
import '../features/chat/screens/chat_list_screen.dart';
import '../features/chat/screens/chat_room_screen.dart';
import '../features/chat/screens/announcement_screen.dart';
import '../features/notifikasi/screens/notifikasi_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../shared/widgets/main_scaffold.dart';
import '../core/services/pocketbase_service.dart';
import '../core/constants/app_constants.dart';

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
  static const String chat = '/chat';
  static const String chatRoom = '/chat/:id';
  static const String announcements = '/pengumuman';
  static const String notifikasi = '/notifikasi';
  static const String settings = '/settings';
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: Routes.dashboard,
    redirect: (context, state) {
      final isLoggedIn = authState.isAuthenticated;
      final isAuthRoute = state.matchedLocation == Routes.login ||
          state.matchedLocation == Routes.register;

      if (!isLoggedIn && !isAuthRoute) {
        return Routes.login;
      }
      if (isLoggedIn && isAuthRoute) {
        return Routes.dashboard;
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
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => MainScaffold(child: child),
        routes: [
          GoRoute(
            path: Routes.dashboard,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: DashboardScreen(),
            ),
          ),
          GoRoute(
            path: Routes.warga,
            builder: (context, state) {
              // Cek data warga user, jika kosong redirect ke form
              return _WargaEntryPoint();
            },
          ),
          GoRoute(
            path: Routes.chat,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ChatListScreen(),
            ),
          ),
          GoRoute(
            path: Routes.settings,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SettingsScreen(),
            ),
          ),
        ],
      ),

      // Detail & form routes (full screen, tanpa bottom nav)
      GoRoute(
        path: Routes.wargaForm,
        builder: (context, state) {
          final wargaId = state.uri.queryParameters['id'];
          return WargaFormScreen(wargaId: wargaId);
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
    ],
  );
});

// Tambahkan widget entry point untuk menu Data Warga
class _WargaEntryPoint extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    return FutureBuilder(
      future: pb.collection(AppConstants.colWarga).getList(
        page: 1,
        perPage: 1,
        filter: 'user_id = "${auth.user?.id ?? ''}"',
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Scaffold(body: Center(child: Text('Gagal cek data warga')));
        }
        final items = snapshot.data?.items ?? [];
        if (items.isEmpty) {
          // Redirect ke form jika data warga tidak ada
          Future.microtask(() => context.go(Routes.wargaForm));
          return const SizedBox.shrink();
        }
        // Sudah ada data, tampilkan list
        return WargaListScreen();
      },
    );
  }
}
