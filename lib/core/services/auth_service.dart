import 'package:pocketbase/pocketbase.dart';
import 'pocketbase_service.dart';

class AuthService {
  /// Login dengan email dan password
  Future<RecordAuth> login(String email, String password) async {
    final authData = await pb.collection('users').authWithPassword(
      email,
      password,
    );
    return authData;
  }

  /// Register user baru
  Future<RecordModel> register({
    required String email,
    required String password,
    required String passwordConfirm,
    required String name,
    String role = 'user',
  }) async {
    final record = await pb.collection('users').create(body: {
      'email': email,
      'password': password,
      'passwordConfirm': passwordConfirm,
      'name': name,
      'role': role,
    });
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
  String get currentRole =>
      pb.authStore.record?.getStringValue('role') ?? 'user';

  /// Cek apakah user adalah admin
  bool get isAdmin => currentRole == 'admin' || currentRole == 'superuser';

  /// Cek apakah user adalah superuser
  bool get isSuperuser => currentRole == 'superuser';

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
    await pb.collection('users').update(userId, body: {
      'oldPassword': oldPassword,
      'password': newPassword,
      'passwordConfirm': newPasswordConfirm,
    });
  }

  /// Refresh auth data
  Future<void> refreshAuth() async {
    await pb.collection('users').authRefresh();
  }

  /// Update role user (hanya superuser)
  Future<RecordModel> updateUserRole(String userId, String newRole) async {
    final record = await pb.collection('users').update(userId, body: {
      'role': newRole,
    });
    return record;
  }

  /// Mendapatkan semua users (admin/superuser)
  Future<List<RecordModel>> getAllUsers({
    int page = 1,
    int perPage = 50,
    String? filter,
  }) async {
    final result = await pb.collection('users').getList(
      page: page,
      perPage: perPage,
      filter: filter ?? '',
      sort: 'nama',
    );
    return result.items;
  }
}
