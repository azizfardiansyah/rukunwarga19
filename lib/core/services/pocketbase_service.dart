import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';
import '../constants/app_constants.dart';

/// URL PocketBase server - ganti sesuai environment
const String pocketBaseUrl = 'http://127.0.0.1:8090';

/// PocketBase client instance
final pb = PocketBase(pocketBaseUrl);

/// Provider untuk PocketBase client
final pocketBaseProvider = Provider<PocketBase>((ref) => pb);

/// Cek apakah user sedang login
bool get isAuthenticated => pb.authStore.isValid;

/// Mendapatkan user yang sedang login
RecordModel? get currentUser => pb.authStore.record;

/// Mendapatkan role user yang login
String get currentUserRole => AppConstants.normalizeRole(
  pb.authStore.record?.getStringValue('role') ?? AppConstants.roleWarga,
);

/// Mendapatkan token auth
String get authToken => pb.authStore.token;

/// Helper untuk mendapatkan URL file dari PocketBase
String getFileUrl(RecordModel record, String filename) {
  return pb.files.getUrl(record, filename).toString();
}

/// Logout - clear auth store
void logout() {
  pb.authStore.clear();
}
