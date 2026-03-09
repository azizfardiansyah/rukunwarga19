// Hapus import riverpod yang tidak perlu
// ignore_for_file: dead_code

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart'
    show StateNotifier, StateNotifierProvider;
import 'package:pocketbase/pocketbase.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/auth_service.dart';

// Auth Service provider
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

// Auth state
enum AuthStatus { initial, authenticated, unauthenticated, loading }

class AuthState {
  final AuthStatus status;
  final RecordModel? user;
  final String? error;
  final String role;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.error,
    this.role = AppConstants.roleUser,
  });

  AuthState copyWith({
    AuthStatus? status,
    RecordModel? user,
    String? error,
    String? role,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: error,
      role: role ?? this.role,
    );
  }

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isAdmin => AppConstants.isAdminRole(role);
  bool get isSysadmin => AppConstants.isSysadminRole(role);
  bool get requiresSubscription => AppConstants.requiresSubscription(role);
  String get subscriptionPlan =>
      user?.getStringValue('subscription_plan') ?? '';
  String get subscriptionStatus => AppConstants.normalizeSubscriptionStatus(
    user?.getStringValue('subscription_status') ?? '',
  );
  DateTime? get subscriptionStartedAt =>
      DateTime.tryParse(user?.getStringValue('subscription_started') ?? '');
  DateTime? get subscriptionExpiredAt =>
      DateTime.tryParse(user?.getStringValue('subscription_expired') ?? '');
  String get effectiveSubscriptionStatus =>
      AppConstants.effectiveSubscriptionStatus(
        role: role,
        subscriptionStatus: subscriptionStatus,
        subscriptionExpired: user?.getStringValue('subscription_expired'),
      );
  bool get hasActiveSubscription => AppConstants.hasActiveSubscription(
    role: role,
    subscriptionStatus: subscriptionStatus,
    subscriptionExpired: user?.getStringValue('subscription_expired'),
  );
}

// Pastikan extends StateNotifier<AuthState>
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;

  AuthNotifier(this._authService) : super(const AuthState());

  void _syncAuthState() {
    if (_authService.isLoggedIn) {
      final user = _authService.currentUser;
      state = AuthState(
        status: AuthStatus.authenticated,
        user: user,
        role: _authService.currentRole,
      );
    } else {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final authData = await _authService.login(email, password);
      state = AuthState(
        status: AuthStatus.authenticated,
        user: authData.record,
        role: AppConstants.normalizeRole(
          authData.record.getStringValue('role'),
        ),
      );
    } catch (e) {
      state = AuthState(
        status: AuthStatus.unauthenticated,
        error: e.toString(),
      );
      rethrow;
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String passwordConfirm,
    required String name,
    String role = AppConstants.roleUser,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      await _authService.register(
        email: email,
        password: password,
        passwordConfirm: passwordConfirm,
        name: name,
        role: role,
      );
      // Auto login setelah register
      await login(email, password);
    } catch (e) {
      state = AuthState(
        status: AuthStatus.unauthenticated,
        error: e.toString(),
      );
      rethrow;
    }
  }

  void logout() {
    _authService.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> refreshAuth() async {
    try {
      await _authService.refreshAuth();
      _syncAuthState();
    } catch (_) {
      logout();
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthNotifier(authService);
});

// Provider tambahan untuk kemudahan akses
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isAuthenticated;
});

final currentUserRoleProvider = Provider<String>((ref) {
  return ref.watch(authProvider).role;
});

final isAdminProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isAdmin;
});

final isSuperuserProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isSysadmin;
});

final requiresSubscriptionProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).requiresSubscription;
});

final hasActiveSubscriptionProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).hasActiveSubscription;
});
