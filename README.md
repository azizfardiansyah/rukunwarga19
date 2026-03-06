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

### Hak Akses Data KK
* **Admin (pengurus RT/RW):** Hanya bisa display semua data KK dan anggota KK.
* **Kepala Keluarga:** Bisa mengedit data anggota warga yang terdaftar dalam KK miliknya (validasi: hanya KK sendiri).
* **Anggota KK:** Hanya bisa mengedit data warga miliknya sendiri.

## Validasi & Flow Data Warga, KK, dan Anggota KK
- Field user_id pada data warga selalu terisi sesuai user yang login (otomatis saat simpan).
- Validasi: user_id tidak lagi unik, sehingga user dapat membuat lebih dari satu data warga (misal untuk anggota keluarga lain).
- Setelah data warga berhasil ditambah atau diupdate, aplikasi otomatis redirect ke dashboard.
- Jika warga ditambah dari detail KK, field no_kk di warga form otomatis terisi dari argument route (no_kk KK yang sedang dibuka).
- Setelah warga berhasil dibuat, aplikasi otomatis menambah record anggota_kk (relasi warga ke KK, dengan hubungan dipilih dari dropdown di form warga).
- Dropdown hubungan (misal: kepala keluarga, istri, anak, dll) muncul di form warga jika akses dari KK detail.
- Daftar anggota keluarga di detail KK diambil dari collection anggota_kk, menampilkan nama dari warga yang terkait.
- Tombol "Tambah Anggota KK" di detail KK akan membuka form warga dengan no_kk terisi.
- Routing: setelah data warga atau KK berhasil dibuat/diupdate, redirect ke dashboard (context.go('/'), dengan Future.microtask untuk reliability).

### Hak Akses & Edit
- Admin (pengurus RT/RW): hanya bisa display semua data KK dan anggota KK.
- Kepala Keluarga: bisa mengedit data anggota warga yang terdaftar dalam KK miliknya (validasi: hanya KK sendiri).
- Anggota KK: hanya bisa mengedit data warga miliknya sendiri.

### PocketBase Collections & Rules
- Collection anggota_kk: relasi antara KK dan warga, dengan field hubungan.
- Collection warga: user_id selalu terisi, tidak perlu unik.
- Collection kartu_keluarga: satu user bisa punya satu atau lebih KK, kepala_keluarga direlasikan ke warga.
- Pastikan rules di PocketBase sesuai dengan flow dan hak akses di atas.

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

### Implementasi CRUD Warga, Kartu Keluarga, dan Anggota KK

#### Alur & Validasi
- **Warga:**
  - Form warga otomatis mengisi `user_id` sesuai user yang login.
  - Jika form warga dibuka dari detail KK, field `no_kk` otomatis terisi dari argumen route.
  - Setelah warga berhasil dibuat, record anggota_kk otomatis ditambah (no_kk, warga, hubungan, status).
  - Validasi: user_id selalu terisi, user bisa membuat lebih dari satu warga (user_id tidak unik).
  - Routing: setelah save/update warga, redirect ke dashboard menggunakan `context.go('/')` dengan `Future.microtask` untuk keandalan.
- **Kartu Keluarga (KK):**
  - Form KK mengisi user_id kepala keluarga.
  - Setelah save/update KK, redirect ke dashboard.
  - Di detail KK, tombol "Tambah Anggota KK" membuka form warga dengan no_kk terisi.
  - List anggota keluarga di detail KK menampilkan nama dari warga via relasi anggota_kk.
- **Anggota KK:**
  - Record anggota_kk dibuat otomatis setelah warga ditambah dari KK.
  - Dropdown hubungan (ayah, ibu, anak, dll) tersedia di form warga.

#### Routing & Auto-fill
- Routing setelah save/update selalu menggunakan `context.go('/')` (Future.microtask).
- Field no_kk di form warga auto-filled dari route argument jika dibuka dari KK detail.
- Tombol "Tambah Anggota KK" di detail KK membuka form warga dengan no_kk pre-filled.

#### Hak Akses
- **Admin:** Hanya display semua data KK dan anggota KK.
- **Kepala Keluarga:** Edit anggota warga dalam KK miliknya.
- **Anggota KK:** Edit data warga miliknya sendiri.

#### Dokumentasi & Error Handling
- Semua flow, validasi, dan akses didokumentasikan di README.
- Error handling dan routing diperbaiki agar konsisten.

---

## Update Alur & Validasi (MVP Scan KK)

### Alur Onboarding User Baru
- Setelah register berhasil, user otomatis masuk ke collection `users` (auth collection PocketBase).
- User baru dianggap sebagai **kepala keluarga** untuk proses input KK pertama.
- Saat login pertama, jika belum punya data KK (`kartu_keluarga`), app mengarahkan user ke form KK.

### Alur Input KK dengan Scan
- Menu: `Kartu Keluarga` -> `Tambah KK + Scan Anggota`.
- APK (Android/iOS): user bisa ambil foto dari kamera atau tambah dari galeri, lalu OCR mem-parsing daftar anggota keluarga.
- PWA (Web): user tambah gambar KK dari galeri/file picker, lalu tekan tombol **Scan** untuk OCR native browser (Tesseract.js) dan parser data KK.
- Hasil parser tampil dalam list draft anggota.
- Jika ada data kurang/keliru, user bisa `Edit` setiap anggota sebelum simpan.
- Jika parser belum menangkap semua anggota, user bisa `Tambah Manual`.

### Validasi Sebelum Simpan KK
- Nomor KK wajib 16 digit.
- Alamat wajib diisi.
- Setiap anggota wajib memiliki:
  - `nama_lengkap`
  - `nik` 16 digit
  - `hubungan` dalam keluarga
- Save diblok jika ada anggota yang belum valid.

### Sinkron Data Saat Save
- Simpan/Update `kartu_keluarga` lebih dulu (termasuk file `scan_kk` jika ada).
- Untuk setiap anggota hasil parser:
  - Buat/cek data `warga` berdasarkan `nik`.
  - Buat relasi `anggota_kk` (`no_kk` relasi ke ID KK, `warga`, `hubungan_`, `status`).
  - Kepala keluarga dihubungkan ke user yang sedang login.

### Auto-Create User untuk Anggota KK
- Untuk anggota selain kepala keluarga, sistem membuat akun baru di collection `users` secara otomatis.
- Format email default: `nama_depan@gmail.com`.
  - Contoh: `Asep Arno` -> `asep@gmail.com`.
- Password default: `12345678`.
- Jika email bentrok, sistem menambahkan suffix angka agar tetap unik.

### Aturan Akses Data Setelah Onboarding
- Jika user sudah terdaftar dan sudah punya KK, menu KK menampilkan data miliknya dan bisa lanjut CRUD.
- Menu `Warga` menampilkan data warga sesuai user login.
- Admin/superuser tetap dapat melihat data lintas user.
