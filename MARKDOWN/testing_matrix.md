# Testing Matrix

Tanggal pembaruan: 2026-03-11

Dokumen ini adalah checklist pengujian untuk model baru:

- `system_role + plan_code + jabatan + scope`
- chat scope baru
- finance maker-checker
- billing seat-based

## 0. Status Coverage

Referensi runbook manual per layar:

- lihat `MARKDOWN/manual_smoke_runbook.md`

Status saat ini:

- auth, settings, subscription, chat text/file, dan announcement: siap diuji via UI
- polling dan voice note: backend sudah aktif, UI composer belum final
- finance maker-checker: backend sudah aktif, UI finance khusus belum final
- smoke API lokal: sudah hijau lewat `node scripts/pb_verify_smoke_workspace.js`

## 1. Test Per Role Subscription

### A. `warga + free`

- login berhasil dan tidak melihat menu admin
- hanya melihat data diri sendiri dan KK sendiri
- tidak bisa membuat broadcast
- tidak bisa membuat custom group
- bisa membuka chat basic yang relevan
- tidak bisa kirim voice note
- tidak bisa membuat polling
- bisa melihat pengumuman sesuai yuridiksi

### B. `operator + rt`

- login berhasil dan scope hanya RT sendiri
- bisa lihat dan kelola data warga RT sendiri
- tidak bisa melihat data RT lain
- bisa broadcast RT sendiri
- bisa kelola agenda dasar RT
- tidak bisa membuat custom group jika policy final tetap `rw` ke atas
- bendahara RT bisa input transaksi
- ketua atau wakil RT bisa approve transaksi
- tidak bisa membuat polling atau voice note jika fitur hanya `rw_pro`

### C. `operator + rw`

- login berhasil dan scope RW sendiri
- bisa lihat data lintas RT dalam RW
- bisa broadcast RW sesuai yuridiksi
- bisa buat custom group basic
- bisa kelola agenda komunitas dasar
- bendahara RW bisa input transaksi
- ketua atau wakil RW bisa approve transaksi
- tidak bisa voice note atau polling jika fitur khusus `rw_pro`

### D. `operator + rw_pro`

- login berhasil dan scope RW sendiri
- semua hak `rw` tetap jalan
- bisa buat custom group advanced
- bisa kirim voice note
- bisa buat polling dan vote
- bisa publish finance announcement setelah approval
- bisa export advanced

### E. `sysadmin`

- bisa audit lintas workspace
- bisa lihat semua transaksi dan approval
- bisa broadcast sistem
- bisa membuka semua data untuk supervisi
- tidak ikut alur checkout subscription biasa

## 2. Test Per Jabatan

### `bendahara_*`

- bisa membuat draft transaksi kas
- bisa submit transaksi untuk approval
- tidak bisa approve transaksi miliknya sendiri jika rule strict aktif

### `ketua_*` dan `wakil_*`

- bisa approve atau reject transaksi
- tidak bisa mengubah nominal setelah submit tanpa jejak audit

### `admin_dkm`, `ketua_dkm`, `wakil_ketua_dkm`

- bisa kelola jadwal khotib dan tarawih pada unit DKM yang sesuai
- tidak bisa mengubah unit DKM lain

### `panitia_agustus`

- bisa kelola agenda Agustus jika scope unit dan plan mengizinkan

### `koordinator_ronda`

- bisa kelola jadwal ronda jika scope dan plan mengizinkan

## 3. Test Transaksi Subscription

- warga checkout plan `rt` berhasil
- warga checkout plan `rw` berhasil
- operator `rt` upgrade ke `rw` berhasil
- operator `rw` upgrade ke `rw_pro` berhasil
- sysadmin ditolak saat mencoba checkout
- transaksi pending tidak mengubah akses
- transaksi paid mengaktifkan seat membership yang benar
- unsubscribe hanya menurunkan seat membership yang benar
- user yang punya banyak workspace tidak merusak seat workspace lain
- ownership pindah ke akun aktif tertinggi berikutnya saat owner expired

## 4. Test Transaksi Chat

### Basic chat

- kirim text berhasil
- kirim file berhasil
- unread counter bergerak sesuai scope
- badge user tampil benar

### Voice note

- operator `rw_pro` bisa upload voice
- operator `rt` ditolak jika fitur tidak aktif
- warga ditolak jika fitur tidak aktif
- playback voice bisa dibuka oleh anggota conversation yang sah

### Polling

- operator `rw_pro` bisa membuat polling
- anggota conversation bisa vote sesuai rule
- vote ganda ditolak jika `allow_multiple_choice = false`
- hasil mentah polling hanya terlihat sesuai scope

### Broadcast

- broadcast RT hanya masuk ke RT terkait
- broadcast RW hanya masuk ke RW terkait
- broadcast sysadmin tidak bocor ke workspace yang tidak ditargetkan

### Developer support

- user bisa masuk kanal support sesuai rule
- user tidak bisa melihat ticket atau conversation user lain tanpa hak

## 5. Test Transaksi Keuangan

### Kas keluar

- bendahara membuat draft transaksi `out`
- bendahara submit transaksi
- ketua/wakil approve
- status berubah ke `approved`
- publish manual membuat pengumuman sesuai yuridiksi
- transaksi reject tidak bisa dipublish

### Kas masuk manual

- bendahara input transaksi `in`
- checker verifikasi
- publish manual opsional

### Kas masuk dari iuran transfer

- warga upload bukti transfer
- admin verifikasi payment
- sistem atau admin membuat transaksi finance `in`
- publish manual sesuai yuridiksi

### Cash masuk

- admin catat cash masuk
- status verified langsung
- transaksi tetap tercatat di ledger

## 6. Test Scope dan Kebocoran Data

- anggota DKM tidak bisa lihat data warga di luar unitnya hanya karena punya jabatan DKM
- anggota Posyandu tidak bisa lihat unit lain
- operator RT tidak bisa lihat RW lain
- operator RW tidak bisa lihat workspace lain
- sysadmin bisa audit tanpa mengubah data operasional secara tidak sengaja

## 7. Test Migrasi Legacy

- user lama `admin_rt` terbaca sebagai `operator + rt`
- user lama `admin_rw` terbaca sebagai `operator + rw`
- user lama `admin_rw_pro` terbaca sebagai `operator + rw_pro`
- fallback legacy tidak memecahkan login lama
- setelah backfill membership, akses baru dan akses lama menghasilkan scope yang sama

## 8. Exit Criteria

Semua dianggap OK jika:

- role subscription baru jalan tanpa bocor scope
- transaction flow finance lengkap dari draft sampai publish berjalan
- chat scope baru tidak menabrak chat lama
- migration legacy tidak memutus akun lama
- billing seat-based aktif per workspace member
- testing matrix di atas lolos tanpa blocker P0 atau P1
