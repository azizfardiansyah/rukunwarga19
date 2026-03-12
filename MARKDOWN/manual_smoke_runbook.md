# Manual Smoke Runbook

Tanggal pembaruan: 2026-03-12

Dokumen ini adalah runbook runtime untuk batch fitur yang statusnya dirujuk di
`MARKDOWN/testing_matrix.md`.

Jika ada konflik antara `MARKDOWN/README.md` dan `MARKDOWN/testing_matrix.md`,
pakai `MARKDOWN/testing_matrix.md` sebagai sumber kerja utama untuk smoke test
harian.

## 1. Tujuan

Runbook ini dipakai untuk memastikan flow runtime berikut benar-benar jalan:

- gate akses dashboard, organisasi, dan keuangan
- pengumuman scoped sesuai yuridiksi
- iuran list, formatter nominal, verifikasi pembayaran, dan ledger finance
- publish kas dari iuran
- finance maker-checker
- composer polling
- composer voice note
- chat advanced: reaction, edit, pin duration, receipt, presence, search,
  media-link browser, dan mention grup

## 2. Preflight

- PocketBase lokal aktif di `http://127.0.0.1:8090`
- data smoke sudah disiapkan dengan `node scripts/pb_seed_smoke_workspace.js`
- smoke API opsional bisa diverifikasi dengan
  `node scripts/pb_verify_smoke_workspace.js`
- Flutter app sudah terhubung ke backend lokal yang sama
- `flutter analyze` pada 2026-03-12: `No issues found!`

## 3. Akun Uji Minimum

Password default smoke user: `SmokePass123!`

| Peran uji | Email |
| --- | --- |
| warga + free | `smoke.warga@local.test` |
| operator + rt | `smoke.rt.ketua@local.test` |
| operator + rw | `smoke.rw.bendahara@local.test` |
| operator + rw_pro | `smoke.rw.owner@local.test` |

## 4. Urutan Smoke Test

### A. Dashboard dan navigasi utama

- login sebagai `operator + rt`
- pastikan dashboard terbuka tanpa error
- pastikan menu `Keuangan` bisa dibuka
- cek pengumuman, iuran, dan surat tetap bisa dibuka

- login sebagai `operator + rw` atau `operator + rw_pro`
- pastikan menu `Organisasi` bisa dibuka
- pastikan menu `Keuangan` bisa dibuka

### B. Pengumuman scoped

- login sebagai `operator + rt`
- buat pengumuman untuk RT yuridiksi sendiri
- pastikan submit berhasil
- pastikan tidak ada opsi valid untuk mengirim ke RT lain
- bila target RT dimanipulasi manual, backend harus menolak

### C. Iuran list dan formatter

- buka daftar tagihan iuran
- pastikan kartu tagihan menampilkan:
  - judul tagihan
  - no. KK
  - nama kepala keluarga
  - nominal
  - jatuh tempo
  - periode
- buka form periode iuran
- pastikan field `Nominal Default` tampil dengan format `Rp 20.000`
- pilih jenis iuran yang punya nominal default
- pastikan field periode ikut terisi dengan formatter Rupiah

### D. Iuran payment ke ledger finance

- login sebagai warga
- upload bukti transfer untuk tagihan yang belum lunas
- login sebagai admin scope terkait
- verifikasi pembayaran transfer
- pastikan terbentuk `finance_transactions`
- pastikan:
  - `source_module = iuran`
  - `source_reference = payment.id`
  - status publish belum langsung `published`

- masih di admin scope terkait
- catat pembayaran cash iuran
- pastikan terbentuk `finance_transactions`
- pastikan aturan `source_module` dan `source_reference` sama-sama benar

### E. Publish kas dari iuran

- cari tagihan lunas yang sudah punya ledger finance
- pastikan aksi `Publish Kas` muncul
- publish hanya boleh berhasil bila transaksi finance sudah `approved`
- setelah publish berhasil:
  - pengumuman kas muncul pada yuridiksi yang benar
  - publish kedua kali ditolak

### F. Finance maker-checker

- login sebagai pembuat transaksi yang punya capability submit finance
- buka `FinanceListScreen`
- buat transaksi draft dari `FinanceFormScreen`
- pastikan `Simpan Draft` berhasil
- lanjut `Simpan & Submit`
- pastikan hasil status:
  - `cash in` -> `approved`
  - `transfer in` -> `submitted`
  - `out` -> `submitted`

- buka `FinanceDetailScreen`
- pastikan draft bisa di-submit dari detail
- login sebagai checker yang sesuai
- pastikan checker tidak bisa approve transaksi miliknya sendiri
- approve atau reject transaksi `submitted`
- untuk transaksi `approved`, jalankan publish dan pastikan tidak ada error UI

### G. Polling

- login sebagai `operator + rw_pro`
- buka chat room yang sesuai
- buat polling baru
- tambahkan opsi
- kirim polling
- lakukan vote
- pastikan hasil vote tampil dan tersimpan

- login sebagai `operator + rt`
- pastikan create polling ditolak bila plan bukan `rw_pro`

- login sebagai `operator + rw`
- pastikan create polling ditolak bila plan bukan `rw_pro`

### H. Voice note

- login sebagai `operator + rw_pro`
- buka chat room
- rekam atau pilih audio
- kirim voice note
- pastikan bubble voice note muncul dan file audio bisa diputar

### I. Chat advanced

- login sebagai `operator + rw` lalu buka `Chat > Grup`
- masuk ke satu room grup aktif
- kirim pesan teks biasa
- pastikan status bubble sendiri berubah dari `Terkirim` sampai `Dibaca`
  saat room dibuka akun lain
- long press pesan sendiri lalu beri reaction emoji
- long press lagi lalu edit isi pesan
- pin pesan dengan durasi `24 jam`, `7 hari`, lalu `30 hari`
- pastikan banner pinned muncul di atas room chat
- ketik `@` di composer grup
- pastikan suggestion mention muncul lalu pilih salah satu anggota
- kirim pesan mention dan pastikan mention tampil di bubble
- aktifkan pencarian room lalu cari isi pesan tertentu
- pastikan daftar pesan terfilter sesuai kata kunci
- buka tombol `Media, Dokumen, dan Link` di app bar room
- pastikan tab `Media`, `Dokumen`, dan `Link` memuat item sesuai isi room
- buka room yang sama dari akun lain
- pastikan subtitle header menunjukkan `Online`, `sedang mengetik...`, atau
  `Terakhir dilihat ...` sesuai kondisi runtime
- kembali ke daftar chat
- pastikan tab `Pengumuman` tidak muncul lagi di menu chat

## 5. Sign-off Checklist

Centang semua item ini sebelum batch dianggap lolos:

- [ ] menu `Organisasi` bisa dibuka dari dashboard
- [ ] menu `Keuangan` bisa dibuka dari dashboard
- [ ] `operator + rt` hanya bisa membuat pengumuman pada RT yuridiksinya sendiri
- [ ] kartu tagihan iuran menampilkan nama kepala keluarga
- [ ] field nominal default periode iuran memakai formatter Rupiah Indonesia
- [ ] verifikasi transfer iuran membuat ledger finance otomatis
- [ ] catat cash iuran membuat ledger finance otomatis
- [ ] publish kas dari tagihan iuran yang valid berjalan normal
- [ ] composer polling bisa create dan vote
- [ ] composer voice note bisa kirim audio file
- [ ] reaction, edit, pin duration, receipt, presence, search, media-link, dan mention grup berjalan normal
- [ ] tab `Pengumuman` sudah hilang dari menu chat
- [ ] finance list, form, dan detail berjalan tanpa error UI
- [ ] `flutter analyze` tetap bersih

## 6. Catatan Audit

Area yang masih perlu cleanup migrasi legacy role setelah smoke test batch ini:

- service dan UI surat masih memakai `auth.role` untuk cabang approval RT/RW
- modul subscription dan role request masih memakai role legacy sebagai kontrak
- sebagian rule PocketBase masih menyisakan fallback `@request.auth.role`
