# RukunWarga SaaS Model

Tanggal pembaruan: 2026-03-11

## Overview

RukunWarga adalah aplikasi manajemen komunitas berbasis Software as a Service
(SaaS) untuk pengelolaan data warga, kartu keluarga, dokumen, surat, iuran,
komunikasi, agenda, dan struktur organisasi di tingkat RW, RT, DKM, dan
Posyandu.

Dokumen ini adalah sumber kebenaran utama untuk:

- model SaaS
- billing
- hak akses
- struktur organisasi
- paywall fitur
- arah pengembangan chat, agenda, dan transparansi keuangan

## Prinsip Utama

- `1 workspace data = 1 RW / yuridiksi`
- beberapa akun operator pada RW yang sama masuk ke workspace data yang sama
- billing memakai model `seat-based per akun operator`
- setiap akun operator wajib punya subscription aktif sendiri
- `system_role`, `plan_code`, `jabatan`, dan `scope` dipisah
- satu user boleh tergabung di banyak workspace
- satu user boleh memegang banyak jabatan
- owner workspace mengikuti akun aktif dengan level plan tertinggi
- jika owner expired, ownership pindah otomatis ke akun aktif tertinggi berikutnya

## Konsep SaaS

Software as a Service berarti aplikasi digunakan melalui internet dengan sistem
langganan. User tidak membeli software sekali putus, tetapi membayar untuk
menggunakan layanan yang terus berjalan.

Karakteristik model ini:

- berbasis cloud
- recurring revenue
- update software otomatis
- tidak perlu server sendiri di tiap RW
- bisa dipakai banyak workspace dengan satu basis produk

## Struktur Akses Final

Model final tidak lagi memakai `admin_rt`, `admin_rw`, dan `admin_rw_pro`
sebagai role utama karena istilah itu mencampur:

- billing atau paket
- level akses
- jabatan operasional

Model final dipisah menjadi 4 layer:

### 1. `system_role`

Dipakai untuk level akses sistem paling atas.

- `warga`
- `operator`
- `sysadmin`

### 2. `plan_code`

Dipakai untuk billing dan paywall fitur.

- `free`
- `rt`
- `rw`
- `rw_pro`

### 3. `jabatan`

Dipakai untuk struktur organisasi dan approval operasional.

Contoh:

- `ketua_rt`
- `bendahara_rt`
- `ketua_rw`
- `ketua_dkm`
- `ketua_posyandu`

### 4. `scope`

Dipakai untuk batas akses data.

Contoh:

- RT mana
- RW mana
- unit mana
- yuridiksi mana

Catatan:

- `plan_code` dipakai untuk billing dan pembukaan fitur
- `jabatan` dipakai untuk struktur organisasi dan approval
- `scope` dipakai untuk batas akses data
- jangan membuat istilah gabungan seperti `ketua_rt_pro`

## Mapping Legacy ke Model Baru

Istilah lama dianggap legacy:

- `admin_rt` -> `system_role = operator` + `plan_code = rt`
- `admin_rw` -> `system_role = operator` + `plan_code = rw`
- `admin_rw_pro` -> `system_role = operator` + `plan_code = rw_pro`

Implikasi:

- istilah lama masih bisa dipakai sementara untuk migrasi
- desain baru tidak boleh lagi menambah kombinasi seperti `ketua_rt_pro`,
  `bendahara_rw_pro`, dan sejenisnya

## Siapa yang Membayar

Billing memakai model `seat-based per akun operator`.

Artinya:

- yang dibayar adalah akun operator aktif
- bukan satu RW dengan akun operator tak terbatas
- beberapa akun operator boleh bekerja pada workspace yang sama
- data workspace tetap satu
- hak memakai fitur premium dihitung per akun

Contoh:

- RW A memiliki 1 akun operator dengan `plan_code = rw`
- RW A juga memiliki 2 akun operator dengan `plan_code = rt`
- ketiga akun bekerja pada data RW yang sama
- jika ketiganya ingin memakai fitur premium, masing-masing akun harus punya
  subscription aktif sendiri

## Target Pengguna

### 1. Warga

Fungsi utama:

- melihat profil sendiri
- melihat KK sendiri
- upload dokumen
- menerima pengumuman
- chat layanan

Model:

- `system_role = warga`
- `plan_code = free`

### 2. Operator RT

Fungsi utama:

- operasional RT sesuai yuridiksi
- verifikasi dokumen
- pengelolaan iuran dan agenda RT
- broadcast RT

Model:

- `system_role = operator`
- `plan_code = rt`

### 3. Operator RW

Fungsi utama:

- operasional RW sesuai yuridiksi
- dashboard statistik
- laporan lintas RT
- pengumuman scoped RW

Model:

- `system_role = operator`
- `plan_code = rw`

### 4. Operator RW Pro

Fungsi utama:

- semua fitur plan RW
- grup custom
- agenda lanjutan
- transparansi kas
- polling
- voice note
- export lanjutan

Model:

- `system_role = operator`
- `plan_code = rw_pro`

### 5. Sysadmin

Fungsi utama:

- audit penuh
- konfigurasi sistem
- supervisi lintas workspace
- broadcast sistem bila diperlukan

## Unit Organisasi Resmi

Unit resmi di dalam workspace:

- `RW`
- `RT`
- `DKM`
- `Posyandu`

Aturan:

- satu workspace boleh punya banyak unit sejenis
- DKM dan Posyandu dianggap unit resmi, bukan sekadar custom group

## Jabatan Operasional

Jabatan dipisah dari `system_role` dan `plan_code`.

Daftar awal jabatan yang perlu disiapkan:

- `ketua_rw`
- `wakil_ketua_rw`
- `sekretaris_rw`
- `wakil_sekretaris_rw`
- `bendahara_rw`
- `wakil_bendahara_rw`
- `ketua_rt`
- `wakil_ketua_rt`
- `sekretaris_rt`
- `bendahara_rt`
- `ketua_dkm`
- `wakil_ketua_dkm`
- `sekretaris_dkm`
- `bendahara_dkm`
- `admin_dkm`
- `ketua_posyandu`
- `wakil_ketua_posyandu`
- `sekretaris_posyandu`
- `bendahara_posyandu`
- `kader_posyandu`
- `panitia_agustus`
- `koordinator_ronda`

Catatan:

- daftar ini belum final mutlak
- satu user boleh punya lebih dari satu jabatan
- jabatan wajib punya histori masa bakti

## Histori Pengurus

Histori pengurus wajib disimpan.

Minimal field yang perlu ada:

- `workspace_id`
- `unit_type`
- `unit_id`
- `user_id`
- `jabatan_code`
- `is_primary`
- `started_at`
- `ended_at`
- `status`
- `period_label` atau `masa_bakti_id`

## Model Hak Akses

Hak akses ditentukan oleh kombinasi:

- `workspace`
- `system_role`
- `plan_code`
- `jabatan`
- `yuridiksi`
- `unit`
- `status subscription aktif`

Aturan akses inti:

- operator dengan `plan_code = rw` atau `rw_pro` mengelola scope RW sesuai
  yuridiksi
- operator dengan `plan_code = rt` mengelola scope RT sesuai yuridiksi
- DKM dan Posyandu tidak otomatis melihat semua data warga
- DKM dan Posyandu hanya melihat anggota unit atau grupnya sendiri
- grup custom bisa dibuat, diubah, dan diarsipkan oleh operator dengan
  `plan_code = rw` atau `rw_pro`
- broadcast bisa dilakukan oleh akun yang subscribe, sesuai yuridiksi masing-masing

## Rule Final Jabatan vs Subscription

Prinsip final:

- `jabatan` tidak perlu subscribe
- `subscription` melekat ke akun operator atau seat
- `jabatan` dipakai untuk identitas, struktur, badge, dan fungsi operasional
- `plan_code` dipakai untuk membuka fitur SaaS
- aksi sensitif harus lolos `plan + jabatan + scope`

### 1. Aksi yang cukup `free`

Kategori ini tidak butuh akun operator berbayar.

| Aksi | Minimal status | Catatan |
| --- | --- | --- |
| tercatat di struktur organisasi | `warga + free` | nama muncul di unit resmi |
| punya badge jabatan | `warga + free` | untuk tampilan profil atau chat |
| histori masa bakti tersimpan | `warga + free` | untuk audit pengurus |
| terlihat sebagai pengurus unit | `warga + free` | hanya sebagai identitas organisasi |
| lihat informasi umum unit sendiri | `warga + free` | tanpa hak admin |

Contoh:

- `ketua_dkm` boleh tercatat sebagai pengurus walau belum subscribe
- `bendahara_posyandu` boleh muncul di struktur organisasi walau bukan operator

### 2. Aksi yang mensyaratkan `operator + plan`

Kategori ini tidak harus punya jabatan khusus, tetapi harus punya seat operator
aktif dan scope yang cocok.

| Aksi | Minimal plan | Scope |
| --- | --- | --- |
| masuk area admin | `rt` | sesuai workspace dan yuridiksi |
| lihat data warga operasional | `rt` | RT sendiri atau RW sendiri sesuai plan |
| broadcast RT | `rt` | RT sendiri |
| broadcast RW | `rw` | RW sendiri |
| buat atau arsip grup custom | `rw` | RW sendiri |
| akses dashboard dan laporan operator | `rt` atau `rw` | sesuai plan |
| kirim voice note | `rw_pro` | conversation yang sah |
| buat polling chat | `rw_pro` | conversation yang sah |
| akses export lanjutan | `rw_pro` | sesuai workspace |

Catatan:

- jika user punya plan aktif tetapi tidak punya jabatan, user tetap bisa memakai
  fitur operator umum sesuai scope
- aksi sensitif seperti approval tetap tidak boleh tanpa jabatan yang cocok

### 3. Aksi yang butuh `jabatan + plan` sekaligus

Kategori ini dipakai untuk aksi resmi, sensitif, atau yang berdampak ke
organisasi.

| Aksi | Jabatan minimal | Minimal plan | Scope |
| --- | --- | --- | --- |
| input transaksi kas | `bendahara_*` | `rt` untuk unit RT, `rw` untuk RW atau unit resmi di RW | unit atau yuridiksi terkait |
| submit transaksi kas | `bendahara_*` | sama seperti di atas | unit atau yuridiksi terkait |
| approve atau reject transaksi | `ketua_*` atau `wakil_*` | `rt` untuk unit RT, `rw` untuk RW atau unit resmi di RW | unit atau yuridiksi terkait |
| publish pengumuman kas | `ketua_*` atau `wakil_*` | `rw` atau `rw_pro` | sesuai yuridiksi data |
| kelola jadwal ronda | `koordinator_ronda`, `ketua_rt`, `wakil_ketua_rt` | `rt` | RT terkait |
| kelola acara Agustus | `panitia_agustus`, `ketua_rw`, `wakil_ketua_rw` | `rw` | RW terkait |
| kelola jadwal khotib atau tarawih | `ketua_dkm`, `wakil_ketua_dkm`, `admin_dkm` | `rw` | unit DKM terkait |
| kelola jadwal Posyandu | `ketua_posyandu`, `wakil_ketua_posyandu`, `kader_posyandu` | `rw` | unit Posyandu terkait |
| broadcast unit resmi | jabatan pengurus unit yang diberi hak | `rw` | unit terkait |

Aturan eksekusi:

- `plan` membuka fitur
- `jabatan` membuka aksi operasional
- `scope` membatasi wilayah atau unit
- jika `plan` ada tetapi `jabatan` tidak cocok, user hanya bisa lihat
- jika `jabatan` ada tetapi `plan` tidak cocok, aksi tetap ditolak

### 4. Kesimpulan Praktis

Model paling sederhana yang dipakai adalah:

- semua jabatan boleh tercatat walau masih `free`
- semua menu admin butuh `operator + plan`
- semua aksi keuangan dan jadwal resmi butuh `jabatan + plan`
- jangan pernah mencampur jabatan dan paket menjadi istilah seperti
  `ketua_rt_pro`

## Paket dan Harga

### Free / Warga

Harga:

`Rp0`

Fitur:

- profil warga
- lihat KK sendiri
- upload dokumen
- chat layanan
- pengumuman scoped

### Plan RT

Harga:

`Rp30.000 / bulan`

Fitur:

- operasional RT
- data warga sesuai RT
- verifikasi dokumen
- pengumuman RT
- laporan RT
- jadwal ronda RT

### Plan RW

Harga:

`Rp100.000 / bulan`

Fitur:

- operasional RW
- akses semua data warga dalam RW
- akses semua KK dalam RW
- dashboard statistik
- laporan iuran
- broadcast sesuai yuridiksi
- custom group basic
- agenda komunitas dasar

### Plan RW Pro

Harga:

`Rp250.000 / bulan`

Fitur tambahan:

- grup custom
- agenda lanjutan
- transparansi kas
- OCR scan KK
- parsing anggota keluarga
- laporan PDF otomatis
- arsip surat digital
- polling
- voice note
- export lanjutan

## Fitur yang Dikunci

Fitur premium dikunci berdasarkan `plan_code`, bukan jabatan.

Contoh paywall:

- `free`
  - profil warga
  - chat dasar
  - pengumuman
- `rt`
  - operasional RT
- `rw`
  - operasional RW
  - dashboard
  - laporan
- `rw_pro`
  - grup custom
  - agenda lanjutan
  - transparansi kas
  - polling
  - voice note
  - export lanjutan

## Broadcast dan Pengumuman

Aturan final:

- broadcast mengikuti yuridiksi pengirim
- tidak semua broadcast harus global satu RW
- akun subscribe boleh broadcast sesuai scope dan yuridiksi
- sysadmin bisa broadcast pada layer sistem bila diperlukan
- data iuran masuk dan keluar wajib diumumkan setelah:
  - data selesai diverifikasi
  - ada trigger manual publish
- scope pengumuman mengikuti yuridiksi data tersebut

## Agenda dan Jadwal

Aturan awal:

- `jadwal ronda` dikelola role subscribe selain warga, sesuai yuridiksi
- `acara agustus` dikelola role subscribe selain warga, sesuai yuridiksi
- `jadwal khotib / tarawih` dikelola oleh pengurus atau admin DKM dan wakilnya,
  sesuai yuridiksi ketua DKM

## Keuangan dan Transparansi

Model final:

- semua unit memakai pola `maker-checker`
- `bendahara` input data
- `ketua / wakil` approve data
- berlaku untuk `RW`, `RT`, `DKM`, dan `Posyandu`

Aturan verifikasi:

- semua `pengeluaran` wajib 2-way verification
- semua `pemasukan transfer` wajib 2-way verification
- `cash masuk` boleh langsung diverifikasi admin

Tujuan produk:

- transparansi iuran masuk
- transparansi pengeluaran
- pengumuman kas sesuai yuridiksi

## Chat dan Komunikasi

Chat tidak lagi diposisikan hanya sebagai inbox warga, tetapi sebagai pusat
komunikasi operasional yang tunduk pada `plan_code`, `jabatan`, dan `scope`.

Perubahan chat yang harus masuk scope produk:

- `badge chat jenis user`
  - tampilkan identitas pengirim seperti warga, operator RT, operator RW,
    pengurus DKM, pengurus Posyandu, sysadmin
- `voice note`
  - tambah `message_type = voice`
  - simpan file audio, durasi, dan pengirim
- `polling`
  - tambah `message_type = poll`
  - hasil mentah polling tersimpan dan dapat dilihat sesuai scope
- `broadcast dari sysadmin`
  - layer sistem lintas workspace bila diperlukan
- `broadcast dari akun subscribe`
  - sesuai yuridiksi dan role aktif
- `chat ke developer`
  - kanal support produk, bukan chat bebas antar semua user
- `group create custom`
  - support grup seperti Posyandu, panitia Agustus, DKM, dan grup operasional lain

## Value Produk

Nilai utama untuk operator RW:

- dashboard demografi
- data warga dan KK terpusat
- komunikasi scoped per yuridiksi
- transparansi kas
- pelacakan iuran
- agenda dan grup operasional

Dashboard membantu:

- laporan ke kelurahan
- data sensus wilayah
- pengelolaan bantuan sosial
- monitoring iuran

## Model Revenue

Revenue dihitung dari seat operator aktif, bukan sekadar jumlah RW.

Contoh:

- 100 workspace
- rata-rata tiap workspace punya:
  - 1 seat plan `rw`
  - 2 seat plan `rt`
- estimasi bulanan:
  - 100 x Rp100.000
  - 200 x Rp30.000
  - total Rp16.000.000 / bulan

Jika sebagian workspace upgrade ke `rw_pro`, recurring revenue akan naik dari
seat premium tambahan.

## Strategi Pertumbuhan

Pendekatan yang digunakan:

`bottom-up adoption`

Urutan adopsi:

`warga -> operator RT -> operator RW`

Strategi:

1. warga menggunakan aplikasi gratis
2. data warga dan KK terkumpul
3. operator RT mulai memakai fitur operasional
4. operator RW melihat manfaat dashboard dan laporan
5. workspace upgrade ke penggunaan operator yang lebih aktif dan seat premium

## Implikasi Teknis

Model ini berarti backend perlu menyiapkan:

- `workspace` atau `tenant`
- `workspace_members`
- `org_units`
- `jabatan_master` atau `org_positions`
- `org_memberships`
- `ownership failover`
- `chat visibility by role + unit + yuridiksi`
- `finance approval workflow`
- `manual publish announcement after verification`

## Summary Perubahan Terbaru

Perubahan penting dari model lama:

- istilah `admin_rt`, `admin_rw`, dan `admin_rw_pro` tidak lagi dipakai sebagai
  role utama
- model final dipecah menjadi `system_role + plan_code + jabatan + scope`
- `jabatan` tetap dipakai untuk operasional organisasi
- `plan_code` dipakai untuk billing dan pembukaan fitur
- `scope` dipakai untuk yuridiksi akses
- ide seperti `ketua_rt_pro` dinyatakan tidak dipakai karena mencampur jabatan
  dan paket
- semua kebutuhan chat, agenda, broadcast, dan keuangan harus mengikuti model
  baru ini

## Next Step

Urutan lanjutan yang disarankan:

1. finalkan collection model untuk workspace, unit, jabatan, dan membership
2. buat matrix hak akses per `system_role + plan_code + jabatan`
3. turunkan scope chat baru ke schema dan API
4. turunkan flow keuangan `maker-checker`
5. mapping fitur ke paket subscription
