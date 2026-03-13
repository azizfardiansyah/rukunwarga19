import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

import '../config/app_env.dart';
import '../constants/app_constants.dart';

/// URL PocketBase server - dibaca dari --dart-define / .env
const String pocketBaseUrl = AppEnv.pocketBaseUrl;

/// PocketBase client instance
final pb = PocketBase(pocketBaseUrl);

/// Provider untuk PocketBase client
final pocketBaseProvider = Provider<PocketBase>((ref) => pb);

/// Cek apakah user sedang login
bool get isAuthenticated => pb.authStore.isValid;

/// Mendapatkan user yang sedang login
RecordModel? get currentUser => pb.authStore.record;

/// Mendapatkan role user yang login
String get currentUserRole => AppConstants.effectiveLegacyRole(
  role: pb.authStore.record?.getStringValue('role'),
  systemRole: pb.authStore.record?.getStringValue('system_role'),
  planCode: pb.authStore.record?.getStringValue('plan_code'),
  subscriptionPlan: pb.authStore.record?.getStringValue('subscription_plan'),
);

/// Mendapatkan system role user yang login
String get currentUserSystemRole => AppConstants.effectiveSystemRole(
  role: pb.authStore.record?.getStringValue('role'),
  systemRole: pb.authStore.record?.getStringValue('system_role'),
);

/// Mendapatkan plan code user yang login
String get currentUserPlanCode => AppConstants.effectivePlanCode(
  role: pb.authStore.record?.getStringValue('role'),
  planCode: pb.authStore.record?.getStringValue('plan_code'),
  subscriptionPlan: pb.authStore.record?.getStringValue('subscription_plan'),
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
