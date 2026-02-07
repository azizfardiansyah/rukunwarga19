class AppConstants {
  AppConstants._();

  // === APP INFO ===
  static const String appName = 'RW 19';
  static const String appFullName = 'Sistem Manajemen Rukun Warga 19';
  static const String appVersion = '1.0.0';

  // === ROLES ===
  static const String roleUser = 'user';
  static const String roleAdmin = 'admin';
  static const String roleSuperuser = 'superuser';

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

  // === AGAMA ===
  static const List<String> daftarAgama = [
    'Islam',
    'Kristen',
    'Katolik',
    'Hindu',
    'Buddha',
    'Konghucu',
  ];

  // === STATUS PERNIKAHAN ===
  static const List<String> statusPernikahan = [
    'Belum Menikah',
    'Menikah',
    'Cerai Hidup',
    'Cerai Mati',
  ];

  // === JENIS KELAMIN ===
  static const List<String> jenisKelamin = [
    'Laki-laki',
    'Perempuan',
  ];

  // === HUBUNGAN KELUARGA ===
  static const List<String> hubunganKeluarga = [
    'Kepala Keluarga',
    'Istri',
    'Anak',
    'Menantu',
    'Cucu',
    'Orang Tua',
    'Mertua',
    'Famili Lain',
    'Pembantu',
    'Lainnya',
  ];

  // === CONVERSATION TYPES ===
  static const String convPrivate = 'private';
  static const String convGroupRt = 'group_rt';
  static const String convGroupRw = 'group_rw';

  // === UPLOAD LIMITS ===
  static const int maxFileSize = 5 * 1024 * 1024; // 5MB
  static const List<String> allowedImageExt = ['jpg', 'jpeg', 'png'];
  static const List<String> allowedDocExt = ['jpg', 'jpeg', 'png', 'pdf'];
}
