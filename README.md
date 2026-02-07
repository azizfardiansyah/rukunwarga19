# rukunwarga19

## Tech Stack
* **Frontend:** Flutter (Android, iOS, Web)
* **Backend:** PocketBase (auth, database, file storage, REST API)
* **State Management:** Riverpod
* **Routing:** GoRouter
* **PocketBase SDK:** pocketbase dart package (CRUD langsung dari kode Flutter)
* **Local Notification:** flutter_local_notifications
## Arsitektur
Flutter app langsung CRUD ke PocketBase menggunakan PocketBase Dart SDK (`pocketbase` package). PocketBase berjalan sebagai single binary server yang menangani:
* Authentication & authorization (role-based)
* Database (SQLite built-in)
* File storage (upload KTP, KK, dokumen)
* Real-time subscriptions
## Struktur Role/User
1. **User Biasa (warga)** — Lihat data sendiri, upload dokumen sendiri, ajukan surat
2. **Admin (pengurus RT/RW)** — Kelola data warga, verifikasi dokumen, buat laporan, kelola iuran
3. **Superuser** — Semua akses admin + kelola user & role, konfigurasi sistem, hapus data
## Fitur Utama
### 1. Autentikasi & Otorisasi
* Login/register dengan email & password
* Role-based access control (user, admin, superuser)
* Session management
### 2. Data Warga
* CRUD data warga: nama lengkap, NIK, tempat/tanggal lahir, jenis kelamin, agama, status pernikahan, pekerjaan, alamat lengkap (RT/RW), nomor HP, email
* Pencarian & filter warga
* Riwayat perubahan data
### 3. Kartu Keluarga (KK)
* CRUD data KK: nomor KK, kepala keluarga, anggota keluarga, alamat
* Relasi antar anggota keluarga
* Upload scan dokumen KK
### 4. KTP
* Data KTP terhubung dengan data warga
* Upload scan KTP (depan & belakang)
* Status verifikasi dokumen
### 5. Upload & Manajemen Dokumen
* Upload scan dokumen (KTP, KK, akta, dll.)
* Preview dokumen
* Status verifikasi (pending, verified, rejected)
* Kategori dokumen
### 6. Surat Pengantar
* Ajukan surat pengantar (warga)
* Template surat: pengantar RT/RW, domisili, keterangan tidak mampu, dll.
* Approval workflow (warga ajukan → admin review → approved/rejected)
* Cetak/download surat (PDF)
* Riwayat surat
### 7. Iuran Warga
* Kelola jenis iuran (bulanan, tahunan, insidental)
* Catat pembayaran per warga
* Status pembayaran (lunas, belum bayar, tertunggak)
* Laporan iuran per periode
### 8. Laporan & Dashboard
* Dashboard statistik: jumlah warga, jumlah KK, demografi
* Laporan iuran
* Laporan dokumen
* Export laporan (PDF/Excel)
## Struktur Folder Flutter
```warp-runnable-command
lib/
├── main.dart
├── app/
│   ├── app.dart
│   ├── router.dart
│   └── theme.dart              # Mengelola semua tema (colors, text styles, component themes)
├── core/
│   ├── constants/
│   ├── services/
│   │   ├── pocketbase_service.dart
│   │   ├── auth_service.dart
│   │   └── notification_service.dart  # Local notifications
│   └── utils/
│       ├── formatters.dart      # Format tanggal, currency (Rupiah), NIK, no HP, dll.
│       └── error_classifier.dart # Klasifikasi & handling error (network, auth, validation, dll.)
├── features/
│   ├── auth/
│   │   ├── models/
│   │   ├── providers/
│   │   └── screens/
│   ├── dashboard/
│   ├── warga/
│   ├── kartu_keluarga/
│   ├── ktp/
│   ├── dokumen/
│   ├── surat/
│   ├── iuran/
│   ├── notifikasi/
│   ├── chat/
│   └── settings/
└── shared/
    ├── models/
    ├── widgets/
    └── providers/
```
### 9. Notifikasi Lokal
* Notifikasi status surat (diajukan, disetujui, ditolak)
* Pengingat iuran yang belum dibayar / jatuh tempo
* Notifikasi verifikasi dokumen
* Notifikasi dari admin ke warga
### 10. Chat & Komunikasi
**Chat Pribadi (warga ↔ pengurus)**
* Kirim teks & gambar
* Status pesan (terkirim, dibaca)
* Riwayat percakapan
**Grup Chat**
* Grup per RT (otomatis berdasarkan data RT warga)
* Grup 1 RW (seluruh warga RW 19)
* Admin bisa setting/kelola grup
* Kirim teks & gambar
**Broadcast/Pengumuman**
* Admin kirim pengumuman ke semua warga atau per RT
* Read-only (satu arah)
* Riwayat pengumuman
* Notifikasi lokal saat ada pesan/pengumuman baru
## PocketBase Collections
1. **users** — Auth collection (email, password, role, nama)
2. **warga** — Data warga (NIK, nama, ttl, alamat, dll.)
3. **kartu_keluarga** — Data KK (no_kk, kepala_keluarga → warga)
4. **anggota_kk** — Relasi anggota KK (kk → kartu_keluarga, warga → warga, hubungan)
5. **dokumen** — Upload dokumen (warga → warga, jenis, file, status_verifikasi)
6. **surat** — Surat pengantar (warga → warga, jenis, status, catatan)
7. **jenis_iuran** — Master jenis iuran (nama, nominal, periode)
8. **iuran** — Pembayaran iuran (warga → warga, jenis → jenis_iuran, tanggal, jumlah, status)
9. **conversations** — Data percakapan (type: private/group_rt/group_rw, nama, target_rt)
10. **conversation_members** — Anggota percakapan (conversation → conversations, user → users)
11. **messages** — Pesan chat (conversation → conversations, sender → users, text, image, created)
12. **message_reads** — Status baca pesan (message → messages, user → users, read_at)
13. **announcements** — Pengumuman (author → users, judul, isi, target: all/rt_tertentu)
## Tahapan Implementasi
### Fase 1: Setup & Fondasi
* Inisialisasi project Flutter
* Setup PocketBase (collections, rules, migrations)
* Implementasi auth (login, register, role management)
* Setup routing & theme
### Fase 2: Data Warga & Keluarga
* CRUD data warga
* CRUD kartu keluarga & anggota
* Upload & preview dokumen (KTP, KK)
### Fase 3: Surat & Iuran
* Sistem surat pengantar dengan workflow
* Manajemen iuran warga
### Fase 4: Chat & Komunikasi
* Chat pribadi (warga ↔ pengurus)
* Grup chat (per RT & 1 RW)
* Broadcast pengumuman
* Real-time via PocketBase subscriptions
### Fase 5: Dashboard & Laporan
* Dashboard statistik
* Laporan & export
### Fase 6: Polish
* Responsive design (mobile & web)
* Error handling & validasi
* Testing
