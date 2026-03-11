import 'package:pocketbase/pocketbase.dart';
import '../constants/app_constants.dart';
import 'pocketbase_service.dart';

class AuthService {
  /// Login dengan email dan password
  Future<RecordAuth> login(String email, String password) async {
    final authData = await pb
        .collection('users')
        .authWithPassword(email, password);
    return authData;
  }

  /// Register user baru
  Future<RecordModel> register({
    required String email,
    required String password,
    required String passwordConfirm,
    required String name,
    String role = AppConstants.roleWarga,
  }) async {
    final normalizedRole = AppConstants.normalizeRole(role);
    final effectiveRole =
        AppConstants.isSysadminRole(currentRole) &&
            AppConstants.assignableRoles.contains(normalizedRole)
        ? normalizedRole
        : AppConstants.roleWarga;

    final record = await pb
        .collection('users')
        .create(
          body: {
            'email': email,
            'password': password,
            'passwordConfirm': passwordConfirm,
            'name': name,
            ..._accessFieldsForRole(effectiveRole),
          },
        );
    return record;
  }

  /// Logout
  void logout() {
    pb.authStore.clear();
  }

  /// Cek apakah sudah login
  bool get isLoggedIn => pb.authStore.isValid;

  /// Mendapatkan data user saat ini
  RecordModel? get currentUser => pb.authStore.record;

  /// Mendapatkan role user saat ini
  String get currentRole => AppConstants.effectiveLegacyRole(
    role: pb.authStore.record?.getStringValue('role'),
    systemRole: pb.authStore.record?.getStringValue('system_role'),
    planCode: pb.authStore.record?.getStringValue('plan_code'),
    subscriptionPlan: pb.authStore.record?.getStringValue('subscription_plan'),
  );

  /// Mendapatkan system role user saat ini
  String get currentSystemRole => AppConstants.effectiveSystemRole(
    role: pb.authStore.record?.getStringValue('role'),
    systemRole: pb.authStore.record?.getStringValue('system_role'),
  );

  /// Mendapatkan plan code user saat ini
  String get currentPlanCode => AppConstants.effectivePlanCode(
    role: pb.authStore.record?.getStringValue('role'),
    planCode: pb.authStore.record?.getStringValue('plan_code'),
    subscriptionPlan: pb.authStore.record?.getStringValue('subscription_plan'),
  );

  /// Cek apakah user adalah admin
  bool get isAdmin => AppConstants.isAdminRole(currentRole);

  /// Cek apakah user adalah sysadmin
  bool get isSysadmin => AppConstants.isSysadminRole(currentRole);

  /// Update profil user
  Future<RecordModel> updateProfile({
    String? nama,
    String? email,
    String? noHp,
  }) async {
    final userId = pb.authStore.record!.id;
    final body = <String, dynamic>{};
    if (nama != null) body['nama'] = nama;
    if (email != null) body['email'] = email;
    if (noHp != null) body['no_hp'] = noHp;

    final record = await pb.collection('users').update(userId, body: body);
    return record;
  }

  /// Ganti password
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
    required String newPasswordConfirm,
  }) async {
    final userId = pb.authStore.record!.id;
    await pb
        .collection('users')
        .update(
          userId,
          body: {
            'oldPassword': oldPassword,
            'password': newPassword,
            'passwordConfirm': newPasswordConfirm,
          },
        );
  }

  /// Refresh auth data
  Future<void> refreshAuth() async {
    await pb.collection('users').authRefresh();
  }

  /// Update role user (hanya sysadmin)
  Future<RecordModel> updateUserRole(String userId, String newRole) async {
    final normalizedRole = AppConstants.normalizeRole(newRole);

    if (!AppConstants.assignableRoles.contains(normalizedRole)) {
      throw ArgumentError('Role tidak valid: $newRole');
    }

    final record = await pb
        .collection('users')
        .update(userId, body: _accessFieldsForRole(normalizedRole));
    return record;
  }

  /// Mendapatkan semua users (admin/sysadmin)
  Future<List<RecordModel>> getAllUsers({
    int page = 1,
    int perPage = 50,
    String? filter,
  }) async {
    final result = await pb
        .collection('users')
        .getList(
          page: page,
          perPage: perPage,
          filter: filter ?? '',
          sort: 'nama',
        );
    return result.items;
  }

  Map<String, dynamic> _accessFieldsForRole(String role) {
    final normalizedRole = AppConstants.normalizeRole(role);
    final systemRole = AppConstants.systemRoleFromRole(normalizedRole);
    final planCode = AppConstants.planCodeFromRole(normalizedRole);
    final subscriptionPlan = AppConstants.subscriptionPlanForRole(
      normalizedRole,
    );

    return {
      'role': normalizedRole,
      'system_role': systemRole,
      'plan_code': planCode,
      'subscription_plan': subscriptionPlan ?? '',
      'subscription_status': AppConstants.subscriptionStatusInactive,
      'subscription_started': null,
      'subscription_expired': null,
    };
  }
}
