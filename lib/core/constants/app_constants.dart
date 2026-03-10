enum SuratFieldInputKind { text, textarea, number, date }

class SuratFieldOption {
  const SuratFieldOption({
    required this.key,
    required this.label,
    required this.inputKind,
    this.required = false,
    this.hint = '',
  });

  final String key;
  final String label;
  final SuratFieldInputKind inputKind;
  final bool required;
  final String hint;
}

class SuratTypeOption {
  const SuratTypeOption({
    required this.code,
    required this.label,
    required this.category,
    required this.approvalLevel,
    required this.description,
    required this.fields,
  });

  final String code;
  final String label;
  final String category;
  final String approvalLevel;
  final String description;
  final List<SuratFieldOption> fields;
}

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
  static const String colSuratAttachments = 'surat_attachments';
  static const String colSuratLogs = 'surat_logs';
  static const String colSuratTemplates = 'surat_templates';
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
  static const String statusNeedRevision = 'need_revision';
  static const String statusRejected = 'rejected';

  // === STATUS SURAT ===
  static const String suratDraft = 'draft';
  static const String suratSubmitted = 'submitted';
  static const String suratNeedRevision = 'need_revision';
  static const String suratApprovedRt = 'approved_rt';
  static const String suratForwardedToRw = 'forwarded_to_rw';
  static const String suratApprovedRw = 'approved_rw';
  static const String suratCompleted = 'completed';
  static const String suratRejected = 'rejected';
  @Deprecated('Use suratSubmitted instead.')
  static const String suratPending = suratSubmitted;
  @Deprecated('Use suratCompleted instead.')
  static const String suratApproved = suratCompleted;

  static const String suratApprovalRt = 'rt';
  static const String suratApprovalRw = 'rw';

  static const String suratCategoryKependudukan = 'kependudukan';
  static const String suratCategoryKeluarga = 'keluarga';
  static const String suratCategorySosial = 'sosial';
  static const String suratCategoryUsaha = 'usaha';
  static const String suratCategoryKematian = 'kematian';
  static const String suratCategoryLingkungan = 'lingkungan';

  // === JENIS SURAT ===
  static const String suratDomisili = 'domisili';
  static const String suratPengantarKtp = 'pengantar_ktp';
  static const String suratPengantarKia = 'pengantar_kia';
  static const String suratPengantarSkck = 'pengantar_skck';
  static const String suratPindahKeluar = 'pengantar_pindah_keluar';
  static const String suratPindahDatang = 'pengantar_pindah_datang';
  static const String suratKelahiran = 'pengantar_kelahiran';
  static const String suratTambahAnggotaKk = 'pengantar_tambah_anggota_kk';
  static const String suratPerubahanKk = 'pengantar_perubahan_kk';
  static const String suratPecahKk = 'pengantar_pecah_kk';
  static const String suratGabungKk = 'pengantar_gabung_kk';
  static const String suratNikah = 'pengantar_nikah';
  static const String suratSktmPendidikan = 'sktm_pendidikan';
  static const String suratSktmKesehatan = 'sktm_kesehatan';
  static const String suratSktmUmum = 'sktm_umum';
  static const String suratKeteranganUsaha = 'keterangan_usaha';
  static const String suratDomisiliUsaha = 'domisili_usaha';
  static const String suratKematian = 'pengantar_kematian';
  static const String suratKematianLingkungan =
      'keterangan_kematian_lingkungan';
  static const String suratPemakaman = 'pengantar_pemakaman';
  static const String suratAhliWaris = 'pengantar_ahli_waris';
  static const String suratDomisiliSementara = 'domisili_sementara';
  static const String suratKeteranganTinggal = 'keterangan_tinggal_lingkungan';
  static const String suratBelumMenikah = 'keterangan_belum_menikah';
  static const String suratJandaDuda = 'keterangan_janda_duda';

  static const List<SuratTypeOption> jenisSurat = [
    SuratTypeOption(
      code: suratDomisili,
      label: 'Surat Keterangan Domisili',
      category: suratCategoryKependudukan,
      approvalLevel: suratApprovalRw,
      description: 'Dipakai untuk kebutuhan administrasi umum dan instansi.',
      fields: [
        SuratFieldOption(
          key: 'alamat_domisili',
          label: 'Alamat Domisili',
          inputKind: SuratFieldInputKind.textarea,
          required: true,
        ),
        SuratFieldOption(
          key: 'lama_tinggal',
          label: 'Lama Tinggal',
          inputKind: SuratFieldInputKind.text,
          required: true,
        ),
      ],
    ),
    SuratTypeOption(
      code: suratPengantarKtp,
      label: 'Surat Pengantar KTP',
      category: suratCategoryKependudukan,
      approvalLevel: suratApprovalRw,
      description: 'Untuk perekaman atau pembaruan KTP.',
      fields: [
        SuratFieldOption(
          key: 'keperluan',
          label: 'Keperluan',
          inputKind: SuratFieldInputKind.textarea,
          required: true,
        ),
      ],
    ),
    SuratTypeOption(
      code: suratPengantarKia,
      label: 'Surat Pengantar KIA',
      category: suratCategoryKependudukan,
      approvalLevel: suratApprovalRw,
      description: 'Untuk administrasi Kartu Identitas Anak.',
      fields: [
        SuratFieldOption(
          key: 'keperluan',
          label: 'Keperluan',
          inputKind: SuratFieldInputKind.textarea,
          required: true,
        ),
      ],
    ),
    SuratTypeOption(
      code: suratPengantarSkck,
      label: 'Surat Pengantar SKCK',
      category: suratCategoryKependudukan,
      approvalLevel: suratApprovalRw,
      description: 'Untuk pengurusan SKCK ke kepolisian.',
      fields: [
        SuratFieldOption(
          key: 'keperluan_skck',
          label: 'Keperluan SKCK',
          inputKind: SuratFieldInputKind.textarea,
          required: true,
        ),
        SuratFieldOption(
          key: 'institusi_tujuan',
          label: 'Instansi Tujuan',
          inputKind: SuratFieldInputKind.text,
        ),
      ],
    ),
    SuratTypeOption(
      code: suratPindahKeluar,
      label: 'Surat Pengantar Pindah Keluar',
      category: suratCategoryKependudukan,
      approvalLevel: suratApprovalRw,
      description: 'Untuk administrasi pindah keluar wilayah.',
      fields: [
        SuratFieldOption(
          key: 'alamat_tujuan',
          label: 'Alamat Tujuan',
          inputKind: SuratFieldInputKind.textarea,
          required: true,
        ),
        SuratFieldOption(
          key: 'jumlah_pengikut',
          label: 'Jumlah Pengikut',
          inputKind: SuratFieldInputKind.number,
        ),
        SuratFieldOption(
          key: 'alasan_pindah',
          label: 'Alasan Pindah',
          inputKind: SuratFieldInputKind.textarea,
          required: true,
        ),
      ],
    ),
    SuratTypeOption(
      code: suratPindahDatang,
      label: 'Surat Pengantar Pindah Datang',
      category: suratCategoryKependudukan,
      approvalLevel: suratApprovalRw,
      description: 'Untuk administrasi pindah datang ke wilayah.',
      fields: [
        SuratFieldOption(
          key: 'alamat_asal',
          label: 'Alamat Asal',
          inputKind: SuratFieldInputKind.textarea,
          required: true,
        ),
        SuratFieldOption(
          key: 'jumlah_pengikut',
          label: 'Jumlah Pengikut',
          inputKind: SuratFieldInputKind.number,
        ),
      ],
    ),
    SuratTypeOption(
      code: suratKelahiran,
      label: 'Surat Pengantar Kelahiran',
      category: suratCategoryKeluarga,
      approvalLevel: suratApprovalRw,
      description: 'Untuk pengurusan kelahiran dan pembaruan KK.',
      fields: [
        SuratFieldOption(
          key: 'nama_bayi',
          label: 'Nama Bayi',
          inputKind: SuratFieldInputKind.text,
          required: true,
        ),
        SuratFieldOption(
          key: 'tanggal_lahir_bayi',
          label: 'Tanggal Lahir Bayi',
          inputKind: SuratFieldInputKind.date,
          required: true,
        ),
        SuratFieldOption(
          key: 'tempat_lahir_bayi',
          label: 'Tempat Lahir Bayi',
          inputKind: SuratFieldInputKind.text,
          required: true,
        ),
        SuratFieldOption(
          key: 'nama_ayah',
          label: 'Nama Ayah',
          inputKind: SuratFieldInputKind.text,
          required: true,
        ),
        SuratFieldOption(
          key: 'nama_ibu',
          label: 'Nama Ibu',
          inputKind: SuratFieldInputKind.text,
          required: true,
        ),
      ],
    ),
    SuratTypeOption(
      code: suratTambahAnggotaKk,
      label: 'Surat Pengantar Tambah Anggota KK',
      category: suratCategoryKeluarga,
      approvalLevel: suratApprovalRw,
      description: 'Untuk penambahan anggota keluarga ke KK.',
      fields: [
        SuratFieldOption(
          key: 'nama_anggota_baru',
          label: 'Nama Anggota Baru',
          inputKind: SuratFieldInputKind.text,
          required: true,
        ),
        SuratFieldOption(
          key: 'hubungan_keluarga',
          label: 'Hubungan Keluarga',
          inputKind: SuratFieldInputKind.text,
          required: true,
        ),
      ],
    ),
    SuratTypeOption(
      code: suratPerubahanKk,
      label: 'Surat Pengantar Perubahan KK',
      category: suratCategoryKeluarga,
      approvalLevel: suratApprovalRw,
      description: 'Untuk perubahan data dalam KK.',
      fields: [
        SuratFieldOption(
          key: 'alasan_perubahan',
          label: 'Alasan Perubahan',
          inputKind: SuratFieldInputKind.textarea,
          required: true,
        ),
      ],
    ),
    SuratTypeOption(
      code: suratPecahKk,
      label: 'Surat Pengantar Pecah KK',
      category: suratCategoryKeluarga,
      approvalLevel: suratApprovalRw,
      description: 'Untuk pemisahan anggota ke KK baru.',
      fields: [
        SuratFieldOption(
          key: 'kk_asal',
          label: 'Nomor KK Asal',
          inputKind: SuratFieldInputKind.text,
          required: true,
        ),
        SuratFieldOption(
          key: 'alasan',
          label: 'Alasan',
          inputKind: SuratFieldInputKind.textarea,
          required: true,
        ),
      ],
    ),
    SuratTypeOption(
      code: suratGabungKk,
      label: 'Surat Pengantar Gabung KK',
      category: suratCategoryKeluarga,
      approvalLevel: suratApprovalRw,
      description: 'Untuk penggabungan ke KK tertentu.',
      fields: [
        SuratFieldOption(
          key: 'kk_tujuan',
          label: 'Nomor KK Tujuan',
          inputKind: SuratFieldInputKind.text,
          required: true,
        ),
        SuratFieldOption(
          key: 'alasan',
          label: 'Alasan',
          inputKind: SuratFieldInputKind.textarea,
          required: true,
        ),
      ],
    ),
    SuratTypeOption(
      code: suratNikah,
      label: 'Surat Pengantar Nikah',
      category: suratCategoryKeluarga,
      approvalLevel: suratApprovalRw,
      description: 'Untuk administrasi nikah ke KUA atau instansi terkait.',
      fields: [
        SuratFieldOption(
          key: 'nama_pasangan',
          label: 'Nama Pasangan',
          inputKind: SuratFieldInputKind.text,
          required: true,
        ),
        SuratFieldOption(
          key: 'tanggal_rencana_nikah',
          label: 'Tanggal Rencana Nikah',
          inputKind: SuratFieldInputKind.date,
          required: true,
        ),
        SuratFieldOption(
          key: 'lokasi_kua_atau_tempat',
          label: 'Lokasi KUA / Tempat',
          inputKind: SuratFieldInputKind.text,
          required: true,
        ),
      ],
    ),
    SuratTypeOption(
      code: suratSktmPendidikan,
      label: 'SKTM Pendidikan',
      category: suratCategorySosial,
      approvalLevel: suratApprovalRw,
      description: 'Untuk kebutuhan beasiswa atau bantuan sekolah.',
      fields: [
        SuratFieldOption(
          key: 'institusi_tujuan',
          label: 'Institusi Tujuan',
          inputKind: SuratFieldInputKind.text,
          required: true,
        ),
        SuratFieldOption(
          key: 'alasan_permohonan',
          label: 'Alasan Permohonan',
          inputKind: SuratFieldInputKind.textarea,
          required: true,
        ),
      ],
    ),
    SuratTypeOption(
      code: suratSktmKesehatan,
      label: 'SKTM Kesehatan',
      category: suratCategorySosial,
      approvalLevel: suratApprovalRw,
      description: 'Untuk pengurusan bantuan atau keringanan kesehatan.',
      fields: [
        SuratFieldOption(
          key: 'institusi_tujuan',
          label: 'Institusi Tujuan',
          inputKind: SuratFieldInputKind.text,
          required: true,
        ),
        SuratFieldOption(
          key: 'alasan_permohonan',
          label: 'Alasan Permohonan',
          inputKind: SuratFieldInputKind.textarea,
          required: true,
        ),
      ],
    ),
    SuratTypeOption(
      code: suratSktmUmum,
      label: 'SKTM Umum',
      category: suratCategorySosial,
      approvalLevel: suratApprovalRw,
      description: 'Untuk kebutuhan bantuan sosial atau administrasi umum.',
      fields: [
        SuratFieldOption(
          key: 'institusi_tujuan',
          label: 'Institusi Tujuan',
          inputKind: SuratFieldInputKind.text,
        ),
        SuratFieldOption(
          key: 'alasan_permohonan',
          label: 'Alasan Permohonan',
          inputKind: SuratFieldInputKind.textarea,
          required: true,
        ),
      ],
    ),
    SuratTypeOption(
      code: suratKeteranganUsaha,
      label: 'Surat Keterangan Usaha',
      category: suratCategoryUsaha,
      approvalLevel: suratApprovalRw,
      description: 'Untuk kebutuhan administrasi usaha atau UMKM.',
      fields: [
        SuratFieldOption(
          key: 'nama_usaha',
          label: 'Nama Usaha',
          inputKind: SuratFieldInputKind.text,
          required: true,
        ),
        SuratFieldOption(
          key: 'jenis_usaha',
          label: 'Jenis Usaha',
          inputKind: SuratFieldInputKind.text,
          required: true,
        ),
        SuratFieldOption(
          key: 'alamat_usaha',
          label: 'Alamat Usaha',
          inputKind: SuratFieldInputKind.textarea,
          required: true,
        ),
        SuratFieldOption(
          key: 'lama_usaha',
          label: 'Lama Usaha',
          inputKind: SuratFieldInputKind.text,
        ),
      ],
    ),
    SuratTypeOption(
      code: suratDomisiliUsaha,
      label: 'Surat Domisili Usaha',
      category: suratCategoryUsaha,
      approvalLevel: suratApprovalRw,
      description: 'Untuk administrasi domisili usaha.',
      fields: [
        SuratFieldOption(
          key: 'nama_usaha',
          label: 'Nama Usaha',
          inputKind: SuratFieldInputKind.text,
          required: true,
        ),
        SuratFieldOption(
          key: 'alamat_usaha',
          label: 'Alamat Usaha',
          inputKind: SuratFieldInputKind.textarea,
          required: true,
        ),
      ],
    ),
    SuratTypeOption(
      code: suratKematian,
      label: 'Surat Pengantar Kematian',
      category: suratCategoryKematian,
      approvalLevel: suratApprovalRw,
      description: 'Untuk administrasi kematian dan pengurusan lanjut.',
      fields: [
        SuratFieldOption(
          key: 'nama_almarhum',
          label: 'Nama Almarhum',
          inputKind: SuratFieldInputKind.text,
          required: true,
        ),
        SuratFieldOption(
          key: 'tanggal_meninggal',
          label: 'Tanggal Meninggal',
          inputKind: SuratFieldInputKind.date,
          required: true,
        ),
        SuratFieldOption(
          key: 'tempat_meninggal',
          label: 'Tempat Meninggal',
          inputKind: SuratFieldInputKind.text,
          required: true,
        ),
        SuratFieldOption(
          key: 'sebab_meninggal',
          label: 'Sebab Meninggal',
          inputKind: SuratFieldInputKind.textarea,
        ),
      ],
    ),
    SuratTypeOption(
      code: suratKematianLingkungan,
      label: 'Keterangan Kematian Lingkungan',
      category: suratCategoryKematian,
      approvalLevel: suratApprovalRt,
      description: 'Keterangan lingkungan atas peristiwa kematian.',
      fields: [
        SuratFieldOption(
          key: 'nama_almarhum',
          label: 'Nama Almarhum',
          inputKind: SuratFieldInputKind.text,
          required: true,
        ),
        SuratFieldOption(
          key: 'tanggal_meninggal',
          label: 'Tanggal Meninggal',
          inputKind: SuratFieldInputKind.date,
          required: true,
        ),
        SuratFieldOption(
          key: 'hubungan_pelapor',
          label: 'Hubungan Pelapor',
          inputKind: SuratFieldInputKind.text,
        ),
      ],
    ),
    SuratTypeOption(
      code: suratPemakaman,
      label: 'Surat Pengantar Pemakaman',
      category: suratCategoryKematian,
      approvalLevel: suratApprovalRt,
      description: 'Untuk kebutuhan lingkungan terkait pemakaman.',
      fields: [
        SuratFieldOption(
          key: 'nama_almarhum',
          label: 'Nama Almarhum',
          inputKind: SuratFieldInputKind.text,
          required: true,
        ),
        SuratFieldOption(
          key: 'lokasi_pemakaman',
          label: 'Lokasi Pemakaman',
          inputKind: SuratFieldInputKind.text,
          required: true,
        ),
        SuratFieldOption(
          key: 'jadwal_pemakaman',
          label: 'Jadwal Pemakaman',
          inputKind: SuratFieldInputKind.date,
          required: true,
        ),
      ],
    ),
    SuratTypeOption(
      code: suratAhliWaris,
      label: 'Surat Pengantar Ahli Waris',
      category: suratCategoryKematian,
      approvalLevel: suratApprovalRw,
      description: 'Pengantar awal untuk proses ahli waris.',
      fields: [
        SuratFieldOption(
          key: 'nama_almarhum',
          label: 'Nama Almarhum',
          inputKind: SuratFieldInputKind.text,
          required: true,
        ),
        SuratFieldOption(
          key: 'daftar_ahli_waris',
          label: 'Daftar Ahli Waris',
          inputKind: SuratFieldInputKind.textarea,
          required: true,
        ),
      ],
    ),
    SuratTypeOption(
      code: suratDomisiliSementara,
      label: 'Surat Domisili Sementara',
      category: suratCategoryLingkungan,
      approvalLevel: suratApprovalRt,
      description: 'Untuk kebutuhan tinggal sementara di lingkungan.',
      fields: [
        SuratFieldOption(
          key: 'alamat_domisili',
          label: 'Alamat Domisili',
          inputKind: SuratFieldInputKind.textarea,
          required: true,
        ),
      ],
    ),
    SuratTypeOption(
      code: suratKeteranganTinggal,
      label: 'Keterangan Tinggal Lingkungan',
      category: suratCategoryLingkungan,
      approvalLevel: suratApprovalRt,
      description: 'Keterangan tinggal di lingkungan setempat.',
      fields: [
        SuratFieldOption(
          key: 'alamat_domisili',
          label: 'Alamat Tinggal',
          inputKind: SuratFieldInputKind.textarea,
          required: true,
        ),
      ],
    ),
    SuratTypeOption(
      code: suratBelumMenikah,
      label: 'Surat Keterangan Belum Menikah',
      category: suratCategoryLingkungan,
      approvalLevel: suratApprovalRt,
      description: 'Keterangan belum menikah dari lingkungan.',
      fields: [],
    ),
    SuratTypeOption(
      code: suratJandaDuda,
      label: 'Surat Keterangan Janda / Duda',
      category: suratCategoryLingkungan,
      approvalLevel: suratApprovalRt,
      description: 'Keterangan status janda atau duda.',
      fields: [],
    ),
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

  static String suratStatusLabel(String status) {
    switch (status.trim().toLowerCase()) {
      case suratDraft:
        return 'Draft';
      case suratSubmitted:
        return 'Diajukan';
      case suratNeedRevision:
        return 'Perlu Revisi';
      case suratApprovedRt:
        return 'Disetujui RT';
      case suratForwardedToRw:
        return 'Diteruskan ke RW';
      case suratApprovedRw:
        return 'Disetujui RW';
      case suratCompleted:
        return 'Selesai';
      case suratRejected:
        return 'Ditolak';
      default:
        return status;
    }
  }

  static String suratCategoryLabel(String category) {
    switch (category) {
      case suratCategoryKependudukan:
        return 'Kependudukan';
      case suratCategoryKeluarga:
        return 'Keluarga';
      case suratCategorySosial:
        return 'Sosial';
      case suratCategoryUsaha:
        return 'Usaha';
      case suratCategoryKematian:
        return 'Kematian';
      case suratCategoryLingkungan:
        return 'Lingkungan';
      default:
        return category;
    }
  }

  static String suratApprovalLabel(String approvalLevel) {
    switch (approvalLevel) {
      case suratApprovalRt:
        return 'RT';
      case suratApprovalRw:
        return 'RT + RW';
      default:
        return approvalLevel;
    }
  }

  static SuratTypeOption suratTypeOption(String code) {
    return jenisSurat.firstWhere(
      (item) => item.code == code,
      orElse: () => jenisSurat.first,
    );
  }

  static String suratTypeLabel(String code) {
    for (final item in jenisSurat) {
      if (item.code == code) {
        return item.label;
      }
    }
    return code;
  }

  static bool suratNeedsRwApproval(String code) {
    return suratTypeOption(code).approvalLevel == suratApprovalRw;
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

  // === GOLONGAN DARAH ===
  static const List<String> daftarGolonganDarah = ['A', 'B', 'AB', 'O', '-'];

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
