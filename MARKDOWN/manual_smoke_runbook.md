# Manual Smoke Runbook

Tanggal pembaruan: 2026-03-11

Dokumen ini adalah runbook smoke test manual berbasis layar untuk model SaaS
baru, data smoke lokal, dan rule akses yang sudah dipasang di PocketBase.

## 1. Tujuan

- memvalidasi flow utama dari UI Flutter
- memvalidasi role, plan, dan scope per akun smoke
- memisahkan area yang sudah siap diuji via layar dari area yang masih API-first

## 2. Prasyarat

1. migration terbaru sudah terpasang:
   - `pocketbase.exe migrate up`
2. data smoke lokal sudah ada:
   - `node scripts/pb_seed_smoke_workspace.js`
3. PocketBase lokal berjalan:
   - `pocketbase.exe serve --dev`
4. aplikasi Flutter dijalankan ke device lokal:
   - contoh: `flutter run -d windows`

## 3. Akun Smoke

Semua akun smoke memakai password yang sama:

- `SmokePass123!`

Daftar akun:

| Fungsi uji | Email | Ekspektasi akses |
| --- | --- | --- |
| Warga | `smoke.warga@local.test` | `system_role=warga`, `plan_code=free` |
| Operator RT | `smoke.rt.ketua@local.test` | `system_role=operator`, `plan_code=rt` |
| Operator RW | `smoke.rw.bendahara@local.test` | `system_role=operator`, `plan_code=rw` |
| Operator RW Pro | `smoke.rw.owner@local.test` | `system_role=operator`, `plan_code=rw_pro` |
| Ketua DKM | `smoke.dkm.ketua@local.test` | akses unit DKM sesuai yuridiksi |
| Bendahara DKM | `smoke.dkm.bendahara@local.test` | maker finance unit DKM |
| Ketua Posyandu | `smoke.posyandu.ketua@local.test` | akses unit Posyandu sesuai yuridiksi |

## 4. Coverage Saat Ini

| Area | Status | Catatan |
| --- | --- | --- |
| Login, dashboard, settings | siap diuji via UI | sudah dipakai user-facing state baru |
| Subscription checkout/status | siap diuji via UI | terhubung ke hook baru |
| Chat text/file/announcement | siap diuji via UI | scope dan badge aktif |
| Polling | backend siap, UI composer belum final | verifikasi utama saat ini via API/service |
| Voice note | backend siap, UI recorder belum final | verifikasi utama saat ini via API/service |
| Finance maker-checker | backend siap, UI finance khusus belum final | verifikasi utama saat ini via API/service |
| Iuran | UI lama tersedia | integrasi ke finance baru perlu dicek bertahap |

## 5. Skenario Per Layar

### A. Login dan Session

Layar target:

- `LoginScreen`
- `DashboardScreen`
- `SettingsScreen`

Langkah:

1. login sebagai `smoke.warga@local.test`
2. pastikan login sukses tanpa error auth
3. buka dashboard
4. buka settings
5. logout
6. ulangi untuk `smoke.rt.ketua@local.test`, `smoke.rw.bendahara@local.test`, dan `smoke.rw.owner@local.test`

Ekspektasi:

- sesi tersimpan normal
- tidak ada crash setelah `auth-refresh`
- badge status subscription terbaca sesuai akun
- akun `warga` tidak tampil seperti akun operator
- akun operator tetap masuk ke workspace yang sama

### B. Subscription Screen

Layar target:

- `SubscriptionScreen`

Langkah uji `warga`:

1. login sebagai `smoke.warga@local.test`
2. buka menu subscription
3. cek daftar paket yang muncul
4. pilih salah satu plan
5. tekan `Buat Checkout`
6. pastikan detail order dan redirect URL muncul
7. tekan `Cek Status Midtrans`

Ekspektasi:

- warga melihat plan `rt`, `rw`, `rw_pro`
- checkout bisa dibuat
- detail order memuat `order id`, `plan`, `target role`, `tagihan`, dan `redirect URL`

Langkah uji `operator rt`:

1. login sebagai `smoke.rt.ketua@local.test`
2. buka subscription
3. cek daftar paket

Ekspektasi:

- plan yang tersedia adalah `rt`, `rw`, `rw_pro`
- plan aktif terbaca sebagai `rt`

Langkah uji `operator rw`:

1. login sebagai `smoke.rw.bendahara@local.test`
2. buka subscription
3. cek daftar paket

Ekspektasi:

- plan yang tersedia adalah `rw`, `rw_pro`
- plan aktif terbaca sebagai `rw`

Langkah uji `operator rw_pro`:

1. login sebagai `smoke.rw.owner@local.test`
2. buka subscription
3. cek daftar paket

Ekspektasi:

- plan yang tersedia hanya `rw_pro`
- plan aktif terbaca sebagai `rw_pro`

### C. Chat List dan Chat Room

Layar target:

- `ChatListScreen`
- `ChatRoomScreen`

Langkah:

1. login sebagai `smoke.warga@local.test`
2. buka daftar chat
3. masuk ke percakapan RW umum
4. kirim pesan teks
5. kirim file lampiran
6. cek apakah pesan tampil di bubble setelah refresh realtime
7. logout lalu ulangi untuk `smoke.rt.ketua@local.test`, `smoke.rw.bendahara@local.test`, dan `smoke.rw.owner@local.test`

Ekspektasi:

- chat list terbuka tanpa error permission
- pesan teks dan file terkirim
- sender badge tampil konsisten dengan profil pengirim
- conversation yang tidak relevan dengan scope user tidak bocor

Catatan:

- UI chat saat ini belum menyediakan tombol final untuk create poll atau kirim
  voice note
- verifikasi `polling` dan `voice` masih memakai script/API sampai composer UI
  ditambahkan

### D. Announcement

Layar target:

- `AnnouncementScreen`

Langkah:

1. login sebagai `smoke.warga@local.test`
2. buka pengumuman
3. cek apakah pengumuman smoke tampil
4. ulangi dengan akun operator

Ekspektasi:

- announcement tampil sesuai workspace
- data tidak bocor lintas yuridiksi
- finance announcement yang sudah dipublish muncul di feed yang sesuai

### E. Iuran Screen

Layar target:

- `IuranListScreen`
- `IuranFormScreen`

Langkah:

1. login sebagai akun operator yang relevan
2. buka daftar iuran
3. buat data iuran uji jika flow UI mengizinkan
4. cek list, detail, dan status pembayaran

Ekspektasi:

- iuran lama tetap bisa dibuka
- tidak ada regression auth setelah model akses baru
- data iuran masih terikat ke yuridiksi yang benar

Catatan:

- layar iuran saat ini belum sama dengan layar finance maker-checker baru
- integrasi iuran ke `finance_transactions` perlu diuji bertahap setelah UI
  finance ditambahkan atau flow sinkronnya disambungkan penuh

## 6. Skenario API-Assisted Yang Tetap Wajib

Karena UI belum lengkap di semua area, skenario berikut tetap dijalankan lewat
script:

- `node scripts/pb_verify_smoke_workspace.js`

Ekspektasi dari script:

- `warga/free` tidak bisa create finance transaction
- `operator/rt` tidak bisa create poll
- `operator/rw` tidak bisa create poll
- `operator/rw` bisa create finance transaction sesuai rule operator
- `operator/rw_pro` bisa create poll

## 7. Exit Criteria Smoke

Smoke manual dianggap hijau jika:

- login, dashboard, settings, subscription, chat text/file, dan announcement
  berjalan tanpa blocker
- hasil `node scripts/pb_verify_smoke_workspace.js` tetap `ok: true`
- tidak ada kebocoran scope antar RT, RW, DKM, atau Posyandu
- tidak ada mismatch antara badge UI dan `system_role + plan_code` user

## 8. Known Gaps Yang Masih Wajar

- composer UI untuk `voice note` belum final
- composer UI untuk `polling` belum final
- layar finance maker-checker khusus belum final
- coverage smoke untuk area di atas masih mengandalkan API/service
