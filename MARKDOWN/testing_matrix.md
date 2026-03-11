# Testing Matrix

Tanggal pembaruan: 2026-03-11

Dokumen ini adalah checklist pengujian aktual untuk kondisi runtime terbaru.
Fokusnya sekarang:

- model akses `system_role + plan_code + jabatan + scope`
- organisasi dan membership
- pengumuman scoped
- iuran operasional
- finance maker-checker UI
- composer polling dan voice note
- fallback legacy role lama di area yang belum dimigrasikan

## 0. Status Coverage Saat Ini

Referensi runbook layar:

- `MARKDOWN/README.md`

Status implementasi per area:

- auth, settings, subscription, dashboard, announcement, organization, dan finance: siap diuji via UI
- iuran list dan iuran form: siap diuji via UI
- polling dan voice note: backend dan composer UI aktif
- iuran ke ledger finance otomatis: aktif
- publish pengumuman kas dari iuran: aktif
- smoke API lokal untuk akses workspace dan finance: sudah hijau

## 1. Test Role Subscription

### A. `warga + free`

- login berhasil
- tidak melihat menu admin
- hanya melihat data diri sendiri dan KK sendiri
- tidak bisa membuat pengumuman
- bisa melihat pengumuman sesuai yuridiksi
- bisa melihat tagihan iuran milik KK sendiri
- tidak bisa membuat transaksi finance
- tidak bisa membuat polling atau voice note

### B. `operator + rt`

- login berhasil dan scope hanya RT sendiri
- hanya melihat warga dan KK di RT sendiri
- menu `Keuangan` muncul jika akun operator aktif
- bisa membuat pengumuman, tetapi hanya untuk RT sesuai yuridiksi akun
- tidak bisa membuat pengumuman ke RW penuh
- tidak bisa mengirim pengumuman ke RT lain lewat manipulasi input
- bendahara RT bisa membuat draft dan submit transaksi unit RT
- ketua atau wakil RT bisa approve transaksi RT
- tidak bisa membuat polling atau voice note jika plan bukan `rw_pro`

### C. `operator + rw`

- login berhasil dan scope RW sendiri
- bisa melihat data lintas RT dalam RW sendiri
- bisa membuat pengumuman RW sesuai yuridiksi
- bisa membuat pengumuman RT di dalam RW sendiri
- bisa membuka layar organisasi
- bisa membuka layar finance
- bisa membuat custom group basic
- tidak bisa voice note atau polling jika plan bukan `rw_pro`

### D. `operator + rw_pro`

- semua hak `operator + rw` tetap jalan
- bisa voice note
- bisa polling
- bisa publish finance announcement setelah transaksi approved
- bisa custom group advanced

### E. `sysadmin`

- bisa audit lintas workspace
- bisa melihat semua transaksi dan approval
- bisa membuat pengumuman lintas scope sesuai tool admin
- tidak ikut flow checkout biasa

## 2. Test Organisasi

- menu `Organisasi` tampil di dashboard untuk `rw`, `rw_pro`, dan `sysadmin`
- overview workspace menampilkan nama workspace, owner, seat aktif, unit, dan pengurus
- layar unit bisa list, tambah, edit, dan archive unit jika punya hak
- layar membership bisa assign jabatan, ubah masa bakti, set primary, dan nonaktifkan membership jika punya hak
- user tanpa capability `can_manage_workspace`, `can_manage_unit`, atau `can_manage_membership` tidak melihat tombol edit terkait

## 3. Test Pengumuman dan Scope

- warga hanya bisa membaca pengumuman sesuai RT atau RW yuridiksinya
- `operator + rt` hanya bisa membuat pengumuman untuk RT sendiri
- input target RT manual tidak boleh bisa mengirim ke RT lain
- `operator + rw` bisa membuat pengumuman RW sendiri
- `operator + rw` bisa membuat pengumuman RT di dalam RW yang sama
- pengumuman finance yang dipublish manual hanya terlihat pada yuridiksi transaksi

## 4. Test Iuran

### List dan detail tagihan

- daftar tagihan tampil sesuai scope akses
- detail kartu tagihan menampilkan:
  - judul tagihan
  - no. KK
  - nama kepala keluarga
  - nominal
  - jatuh tempo
  - periode

### Form periode iuran

- field `Nominal Default` memakai formatter Rupiah Indonesia
- contoh tampilan input: `Rp 20.000`
- validasi tetap membaca nilai numerik dengan benar saat submit
- saat pilih jenis iuran yang punya nominal default, field periode ikut terisi format Rupiah
- override nominal per KK juga mengikuti formatter Rupiah

### Verifikasi pembayaran

- warga bisa upload bukti transfer
- admin scope terkait bisa verifikasi atau tolak pembayaran
- pembayaran cash tetap bisa dicatat dari admin
- verifikasi transfer membuat `finance_transactions` otomatis
- pencatatan cash membuat `finance_transactions` otomatis
- `source_module` harus `iuran`
- `source_reference` harus mengarah ke `payment.id`
- transaksi finance hasil iuran belum langsung `published`

### Publish kas dari iuran

- tagihan lunas yang sudah punya ledger menampilkan aksi `Publish Kas`
- publish hanya berhasil jika transaksi finance sudah `approved`
- pengumuman yang terbit mengikuti yuridiksi tagihan atau unitnya
- publish kedua kali harus ditolak

## 5. Test Finance Maker-Checker

### List

- menu `Keuangan` tampil untuk operator dan sysadmin
- list finance bisa filter unit, arah, approval, dan publish status
- transaksi draft, submitted, approved, rejected, dan published tampil dengan label benar

### Form

- bendahara atau jabatan submit finance bisa simpan draft
- draft bisa di-edit ulang oleh maker
- `Simpan & Submit` mengubah status:
  - `cash in` -> `approved`
  - `transfer in` -> `submitted`
  - `out` -> `submitted`

### Detail

- draft bisa di-submit dari detail screen
- draft hanya bisa di-edit oleh maker atau sysadmin
- checker tidak bisa approve transaksi yang dia buat sendiri
- approve dan reject hanya tersedia untuk transaksi `submitted`
- publish hanya tersedia untuk transaksi `approved` dan belum dipublish

## 6. Test Per Jabatan

### `bendahara_*`

- bisa membuat draft transaksi
- bisa submit transaksi
- tidak bisa approve transaksi miliknya sendiri

### `ketua_*` dan `wakil_*`

- bisa approve transaksi unit yang sesuai
- bisa reject transaksi unit yang sesuai
- bisa publish pengumuman kas jika capability dan plan mendukung

### `ketua_dkm`, `wakil_ketua_dkm`, `admin_dkm`

- hanya bisa kelola data dan jadwal DKM sesuai unitnya
- tidak bisa mengelola unit DKM lain tanpa membership

## 7. Test Legacy Mapping

- user lama `admin_rt` terbaca sebagai `operator + rt`
- user lama `admin_rw` terbaca sebagai `operator + rw`
- user lama `admin_rw_pro` terbaca sebagai `operator + rw_pro`
- login lama tidak putus selama fallback legacy masih aktif

## 8. Area yang Masih Pending

- migrasi penuh seluruh repo dari legacy `users.role`
- modul subscription dan role request ke model `system_role + plan_code` penuh

## 9. Exit Criteria Batch Hari Ini

Batch perubahan hari ini dianggap lolos jika:

- menu `Organisasi` dan `Keuangan` bisa dibuka dari dashboard
- `operator + rt` hanya bisa membuat pengumuman pada RT yuridiksinya sendiri
- kartu tagihan iuran menampilkan nama kepala keluarga
- field nominal default periode iuran memakai formatter Rupiah Indonesia
- verifikasi transfer iuran membuat ledger finance otomatis
- catat cash iuran membuat ledger finance otomatis
- publish kas dari tagihan iuran yang valid berjalan normal
- composer polling bisa create dan vote
- composer voice note bisa kirim audio file
- finance list, form, dan detail berjalan tanpa error UI
- `flutter analyze` tetap bersih
