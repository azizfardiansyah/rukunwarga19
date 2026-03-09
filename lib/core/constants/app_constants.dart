class AppConstants {
  AppConstants._();

  // === APP INFO ===
  static const String appName = 'RukunWarga';
  static const String appFullName = 'Sistem Manajemen Rukun Warga';
  static const String appVersion = '1.0.0';

  // === ROLES ===
  static const String roleWarga = 'warga';
  @Deprecated('Use roleWarga instead.')
  static const String roleUser = roleWarga;
  static const String roleAdminRt = 'admin_rt';
  static const String roleAdminRw = 'admin_rw';
  static const String roleAdminRwPro = 'admin_rw_pro';
  static const String roleSysadmin = 'sysadmin';

  // Legacy roles kept for backward compatibility during migration.
  static const String legacyRoleUser = 'user';
  static const String legacyRoleAdmin = 'admin';
  static const String legacyRoleSuperuser = 'superuser';

  // === COLLECTION NAMES ===
  static const String colUsers = 'users';
  static const String colWarga = 'warga';
  static const String colKartuKeluarga = 'kartu_keluarga';
  static const String colAnggotaKk = 'anggota_kk';
  static const String colDokumen = 'dokumen';
  static const String colSurat = 'surat';
  static const String colJenisIuran = 'jenis_iuran';
  static const String colIuran = 'iuran';
  static const String colConversations = 'conversations';
  static const String colConversationMembers = 'conversation_members';
  static const String colMessages = 'messages';
  static const String colMessageReads = 'message_reads';
  static const String colAnnouncements = 'announcements';
  static const String colSubscriptionPlans = 'subscription_plans';
  static const String colSubscriptionTransactions = 'subscription_transactions';
  static const String colRoleRequests = 'role_requests';

  // === STATUS DOKUMEN ===
  static const String statusPending = 'pending';
  static const String statusVerified = 'verified';
  static const String statusRejected = 'rejected';

  // === STATUS SURAT ===
  static const String suratPending = 'pending';
  static const String suratApproved = 'approved';
  static const String suratRejected = 'rejected';

  // === JENIS SURAT ===
  static const List<String> jenisSurat = [
    'Surat Pengantar RT',
    'Surat Pengantar RW',
    'Surat Keterangan Domisili',
    'Surat Keterangan Tidak Mampu',
    'Surat Keterangan Usaha',
    'Surat Keterangan Belum Menikah',
    'Surat Keterangan Kematian',
    'Surat Keterangan Pindah',
    'Lainnya',
  ];

  // === STATUS IURAN ===
  static const String iuranLunas = 'lunas';
  static const String iuranBelumBayar = 'belum_bayar';
  static const String iuranTertunggak = 'tertunggak';

  // === PERIODE IURAN ===
  static const String periodeBulanan = 'bulanan';
  static const String periodeTahunan = 'tahunan';
  static const String periodeInsidental = 'insidental';

  // === SUBSCRIPTION ===
  static const String subscriptionPlanAdminRtMonthly = 'admin_rt_monthly';
  static const String subscriptionPlanAdminRwMonthly = 'admin_rw_monthly';
  static const String subscriptionPlanAdminRwProMonthly =
      'admin_rw_pro_monthly';
  static const String subscriptionStatusActive = 'active';
  static const String subscriptionStatusExpired = 'expired';
  static const String subscriptionStatusInactive = 'inactive';

  static const List<String> requestableRoles = [
    roleAdminRt,
    roleAdminRw,
    roleAdminRwPro,
  ];
  static const List<String> payableAdminRoles = [
    roleAdminRt,
    roleAdminRw,
    roleAdminRwPro,
  ];

  static const String roleRequestPending = 'pending';
  static const String roleRequestApproved = 'approved';
  static const String roleRequestRejected = 'rejected';

  static const List<String> assignableRoles = [
    roleWarga,
    roleAdminRt,
    roleAdminRw,
    roleAdminRwPro,
    roleSysadmin,
  ];

  static const List<String> publicRegistrationRoles = [roleWarga];

  static String normalizeRole(String role) {
    switch (role.trim().toLowerCase()) {
      case legacyRoleAdmin:
        return roleAdminRw;
      case legacyRoleSuperuser:
        return roleSysadmin;
      case legacyRoleUser:
      case roleWarga:
        return roleWarga;
      case roleAdminRt:
      case roleAdminRw:
      case roleAdminRwPro:
      case roleSysadmin:
        return role.trim().toLowerCase();
      default:
        return roleWarga;
    }
  }

  static bool isAdminRole(String role) {
    final normalizedRole = normalizeRole(role);
    return normalizedRole == roleAdminRt ||
        normalizedRole == roleAdminRw ||
        normalizedRole == roleAdminRwPro ||
        normalizedRole == roleSysadmin;
  }

  static bool isSysadminRole(String role) {
    return normalizeRole(role) == roleSysadmin;
  }

  static bool hasRwWideAccess(String role) {
    final normalizedRole = normalizeRole(role);
    return normalizedRole == roleAdminRw ||
        normalizedRole == roleAdminRwPro ||
        normalizedRole == roleSysadmin;
  }

  static bool requiresSubscription(String role) {
    final normalizedRole = normalizeRole(role);
    return normalizedRole == roleAdminRt ||
        normalizedRole == roleAdminRw ||
        normalizedRole == roleAdminRwPro;
  }

  static bool canSelfSubscribe(String role) {
    final normalizedRole = normalizeRole(role);
    return normalizedRole == roleWarga ||
        normalizedRole == roleAdminRt ||
        normalizedRole == roleAdminRw ||
        normalizedRole == roleAdminRwPro;
  }

  static bool canRequestUnsubscribe(String role) {
    return requiresSubscription(role);
  }

  static int roleRank(String role) {
    switch (normalizeRole(role)) {
      case roleAdminRt:
        return 1;
      case roleAdminRw:
        return 2;
      case roleAdminRwPro:
        return 3;
      case roleSysadmin:
        return 99;
      case roleWarga:
      default:
        return 0;
    }
  }

  static bool canPurchaseRole({
    required String currentRole,
    required String targetRole,
  }) {
    final normalizedCurrent = normalizeRole(currentRole);
    final normalizedTarget = normalizeRole(targetRole);

    if (!payableAdminRoles.contains(normalizedTarget)) {
      return false;
    }

    if (normalizedCurrent == roleSysadmin) {
      return false;
    }

    if (normalizedCurrent == roleWarga) {
      return true;
    }

    return roleRank(normalizedTarget) >= roleRank(normalizedCurrent);
  }

  static String? subscriptionPlanForRole(String role) {
    switch (normalizeRole(role)) {
      case roleAdminRt:
        return subscriptionPlanAdminRtMonthly;
      case roleAdminRw:
        return subscriptionPlanAdminRwMonthly;
      case roleAdminRwPro:
        return subscriptionPlanAdminRwProMonthly;
      default:
        return null;
    }
  }

  static String subscriptionPlanLabel(String planCode) {
    switch (planCode.trim().toLowerCase()) {
      case subscriptionPlanAdminRtMonthly:
        return 'Paket Admin RT';
      case subscriptionPlanAdminRwMonthly:
        return 'Paket Admin RW';
      case subscriptionPlanAdminRwProMonthly:
        return 'Paket Admin RW Pro';
      default:
        return 'Subscription';
    }
  }

  static String normalizeSubscriptionStatus(String status) {
    switch (status.trim().toLowerCase()) {
      case subscriptionStatusActive:
        return subscriptionStatusActive;
      case subscriptionStatusExpired:
        return subscriptionStatusExpired;
      case subscriptionStatusInactive:
      default:
        return subscriptionStatusInactive;
    }
  }

  static String effectiveSubscriptionStatus({
    required String role,
    required String subscriptionStatus,
    String? subscriptionExpired,
    DateTime? now,
  }) {
    if (!requiresSubscription(role)) {
      return subscriptionStatusActive;
    }

    final normalizedStatus = normalizeSubscriptionStatus(subscriptionStatus);
    if (normalizedStatus != subscriptionStatusActive) {
      return normalizedStatus;
    }

    final expiry = DateTime.tryParse(subscriptionExpired ?? '');
    final currentTime = now ?? DateTime.now();
    if (expiry == null || !expiry.isAfter(currentTime)) {
      return subscriptionStatusExpired;
    }

    return subscriptionStatusActive;
  }

  static bool hasActiveSubscription({
    required String role,
    required String subscriptionStatus,
    String? subscriptionExpired,
    DateTime? now,
  }) {
    if (!requiresSubscription(role)) {
      return true;
    }

    return effectiveSubscriptionStatus(
          role: role,
          subscriptionStatus: subscriptionStatus,
          subscriptionExpired: subscriptionExpired,
          now: now,
        ) ==
        subscriptionStatusActive;
  }

  static String subscriptionStatusLabel(String status) {
    switch (normalizeSubscriptionStatus(status)) {
      case subscriptionStatusActive:
        return 'Aktif';
      case subscriptionStatusExpired:
        return 'Expired';
      case subscriptionStatusInactive:
      default:
        return 'Belum Aktif';
    }
  }

  static String roleLabel(String role) {
    switch (normalizeRole(role)) {
      case roleAdminRt:
        return 'Admin RT';
      case roleAdminRw:
        return 'Admin RW';
      case roleAdminRwPro:
        return 'Admin RW Pro';
      case roleSysadmin:
        return 'Sysadmin';
      case roleWarga:
      default:
        return 'Warga';
    }
  }

  // === JENIS DOKUMEN ===
  static const List<String> jenisDokumen = [
    'KTP',
    'Kartu Keluarga',
    'Akta Kelahiran',
    'Akta Kematian',
    'Akta Nikah',
    'Ijazah',
    'BPJS',
    'Lainnya',
  ];

  // === AGAMA (sesuai PocketBase select field warga.agama) ===
  static const List<String> daftarAgama = [
    'Islam',
    'Kristen',
    'Budha',
    'Khatolik',
  ];

  // === STATUS PERNIKAHAN (sesuai PocketBase select field warga.status_pernikahan) ===
  static const List<String> statusPernikahan = [
    'Menikah',
    'Belum Menikah',
    'Cerai Hidup',
    'Cerai Mati',
  ];

  // === JENIS KELAMIN ===
  static const List<String> jenisKelamin = ['Laki-laki', 'Perempuan'];

  // === HUBUNGAN KELUARGA (sesuai PocketBase select field anggota_kk.hubungan) ===
  static const List<String> hubunganKeluarga = ['Ayah', 'Ibu', 'Anak'];

  // === CONVERSATION TYPES ===
  static const String convPrivate = 'private';
  static const String convGroupRt = 'group_rt';
  static const String convGroupRw = 'group_rw';

  // === UPLOAD LIMITS ===
  static const int maxFileSize = 5 * 1024 * 1024; // 5MB
  static const List<String> allowedImageExt = ['jpg', 'jpeg', 'png'];
  static const List<String> allowedDocExt = ['jpg', 'jpeg', 'png', 'pdf'];
}
