# RukunWarga

Tanggal pembaruan: 2026-03-13

Dokumen ini adalah README utama yang menggabungkan isi:

- `manual_smoke_runbook.md`
- `testing_matrix.md`

RULES.md` tetap dipisah karena dipakai sebagai aturan agent AI dan bukan
dokumen produk utama.

## 0. Ringkasan Perubahan 10-13 Maret 2026

### 2026-03-13

- `Laporan` dirombak menjadi dashboard 3 layer: alert urgent, snapshot
  operasional, dan detail drill-down, dengan CTA langsung ke modul kerja.
- route `iuran`, `dokumen`, dan `surat` sekarang menerima query parameter
  filter awal agar tombol dari dashboard bisa membuka konteks yang tepat.
- grup chat unit resmi sekarang bisa tersinkron otomatis dari `org_units`,
  mendukung avatar grup, dan anggota dikelola manual sesuai area yuridiksi.
- layar struktur organisasi diubah menjadi chart hierarkis berbentuk piramida
  dengan lead member yang lebih menonjol.

### 2026-03-12

- organisasi menambah dukungan `Karang Taruna`, `workspace_member.display_name`,
  avatar anggota workspace, dan pembacaan user untuk mapping pengurus.
- pengumuman mendapat attachment, statistik view, dan penyelarasan rule fitur
  chat scoped.
- chat menambah fondasi pin duration, presence, dan penyempurnaan alur room
  serta announcement.

### 2026-03-11

- fondasi akses SaaS direfaktor besar ke model `workspace + plan + jabatan +
  scope`, termasuk capability flag dan plan-gated collection rules.
- finance maker-checker, group, dan sumber referensi transaksi diperluas untuk
  flow operasional RW/RT.
- polish UI/UX lintas modul admin dirapikan agar surface, spacing, dan visual
  state lebih konsisten.

## 1. Ringkasan Produk

RukunWarga adalah aplikasi manajemen komunitas berbasis Flutter dan PocketBase
untuk operasional tingkat RW, RT, DKM, dan Posyandu.

Scope utama produk:

- data warga dan kartu keluarga
- dokumen dan verifikasi
- surat pengantar dan approval
- iuran per KK
- chat, pengumuman, dan broadcast
- struktur organisasi dan pengurus
- kas masuk dan keluar dengan maker-checker
- subscription operator berbasis seat

## 2. Tech Stack

- Frontend: Flutter
- Backend: PocketBase
- State management: Riverpod
- Routing: GoRouter
- Realtime: PocketBase subscription
- Payment gateway: Midtrans Snap

## 3. Arsitektur Dasar

Flutter app berkomunikasi langsung ke PocketBase. PocketBase menangani:

- auth dan session
- collection database
- file storage
- realtime subscription
- migration schema
- hook backend untuk business rule tertentu

## 4. Model SaaS Final

### Prinsip inti

- `1 workspace data = 1 RW / yuridiksi`
- beberapa operator di RW yang sama masuk ke workspace data yang sama
- billing memakai model `seat-based per akun operator`
- setiap akun operator wajib punya subscription aktif sendiri
- satu user bisa punya banyak workspace
- satu user bisa punya banyak jabatan
- owner workspace mengikuti akun aktif dengan rank plan tertinggi
- jika owner expired, ownership pindah ke akun aktif tertinggi berikutnya

### Layer akses final

#### `system_role`

- `warga`
- `operator`
- `sysadmin`

#### `plan_code`

- `free`
- `rt`
- `rw`
- `rw_pro`

#### `jabatan`

Contoh:

- `ketua_rw`
- `wakil_rw`
- `sekretaris_rw`
- `bendahara_rw`
- `ketua_rt`
- `bendahara_rt`
- `ketua_dkm`
- `wakil_ketua_dkm`
- `admin_dkm`
- `bendahara_dkm`
- `ketua_posyandu`
- `wakil_ketua_posyandu`
- `bendahara_posyandu`
- `kader_posyandu`
- `panitia_agustus`
- `koordinator_ronda`

#### `scope`

Scope menentukan batas wilayah dan unit:

- RT
- RW
- DKM
- Posyandu
- unit custom
- yuridiksi wilayah resmi

### Mapping legacy

Istilah lama tetap dipahami selama masa transisi:

- `admin_rt` -> `operator + rt`
- `admin_rw` -> `operator + rw`
- `admin_rw_pro` -> `operator + rw_pro`

Namun desain baru tidak lagi memakai istilah itu sebagai sumber akses utama.

## 5. Unit Resmi dan Organisasi

Unit resmi yang didukung:

- `RW`
- `RT`
- `DKM`
- `Posyandu`

Satu workspace bisa punya banyak unit sejenis.

Struktur pengurus harus menyimpan:

- unit
- jabatan
- user
- masa bakti mulai
- masa bakti selesai
- status aktif atau nonaktif
- primary membership

## 6. Aturan Hak Akses

Urutan evaluasi akses:

1. user login valid
2. punya `workspace_member` aktif
3. `system_role` valid
4. `plan_code` memenuhi gate fitur
5. `jabatan_master` memenuhi capability flag
6. `scope` unit dan yuridiksi cocok

### Capability flag penting di `jabatan_master`

- `can_manage_workspace`
- `can_manage_unit`
- `can_manage_membership`
- `can_submit_finance`
- `can_approve_finance`
- `can_publish_finance`
- `can_manage_schedule`
- `can_broadcast_unit`
- `can_manage_iuran`
- `can_verify_iuran_payment`

### Rule sederhana

- `jabatan` tidak perlu subscription
- `subscription` tetap melekat ke akun operator
- `plan` membuka fitur SaaS
- `jabatan` membuka aksi operasional sensitif
- `scope` membatasi yuridiksi

Contoh:

- badge dan histori pengurus boleh ada walau user masih `free`
- masuk area admin butuh `operator + plan`
- approval kas butuh `jabatan + plan + scope`

## 7. Paket Subscription

### `free`

- profil
- chat dasar
- lihat pengumuman sesuai yuridiksi

### `rt`

- operasional RT
- broadcast RT
- agenda dasar
- finance basic sesuai jabatan

### `rw`

- akses RW penuh sesuai yuridiksi
- dashboard RW
- custom group basic
- finance publish

### `rw_pro`

- semua fitur `rw`
- polling
- voice note
- custom group advanced
- export advanced

## 8. Modul Utama

## 8.1 Data Warga dan Kartu Keluarga

- CRUD data warga
- CRUD kartu keluarga
- anggota KK
- scope wilayah resmi
- validasi akses warga, kepala keluarga, dan operator

## 8.2 Dokumen

- upload dokumen
- preview dokumen
- status verifikasi
- kategori dokumen

## 8.3 Surat

Prinsip produk:

- aplikasi menerbitkan surat pengantar atau rekomendasi lingkungan
- dokumen legal final tetap bisa diterbitkan instansi luar

Scope surat:

- pengajuan oleh warga
- approval RT
- forward atau approval RW
- tracking status
- log dan notifikasi

## 8.4 Iuran

Prinsip iuran:

- unit tagihan adalah `per KK`
- mendukung multi-jenis iuran
- admin membuat periode lalu sistem generate tagihan
- warga upload bukti transfer
- admin verifikasi atau tolak pembayaran
- pembayaran cash bisa dicatat langsung

Status penting:

- periode: `draft`, `published`, `closed`
- tagihan: `unpaid`, `submitted_verification`, `paid`, `rejected_payment`
- payment: `submitted`, `verified`, `rejected`

UI yang sudah ada:

- list tagihan
- verifikasi pembayaran
- daftar periode
- daftar jenis iuran
- form buat periode
- form buat jenis iuran

Perubahan terbaru:

- detail tagihan sekarang menampilkan `Nama kepala keluarga`
- field `Nominal Default` di form periode sekarang memakai formatter Rupiah
  Indonesia, contoh `Rp 20.000`

## 8.5 Chat dan Pengumuman

Scope chat yang dipakai:

- inbox layanan warga
- grup RT
- forum RW
- pengumuman scoped
- scoped conversation untuk unit resmi

Message type:

- `text`
- `file`
- `voice`
- `poll`
- `system`

Pengumuman:

- operator RT hanya boleh membuat pengumuman untuk RT pada yuridiksi akun
  sendiri
- operator RW membuat pengumuman sesuai RW yuridiksinya
- sysadmin bisa audit atau broadcast sistem sesuai tool admin

Status implementasi chat:

- chat text dan file: aktif
- pengumuman: aktif
- polling: backend aktif, UI composer belum final
- voice note: backend aktif, UI composer belum final

Perubahan terbaru:

- official group chat untuk unit organisasi bisa dibuat atau disinkronkan
  otomatis dari `org_units`
- avatar grup chat sudah didukung
- kelola anggota grup mengikuti area yuridiksi dan tetap bisa dikurasi manual
- pengumuman sudah mendukung attachment dan statistik view
- foundation pin duration dan presence untuk chat sudah masuk backend

## 8.6 Organisasi

Layar organisasi yang sudah ada:

- overview workspace
- kelola unit
- kelola membership pengurus

Data yang ditampilkan:

- workspace aktif
- owner
- seat operator
- unit resmi dan custom
- pengurus, jabatan, masa bakti, status

Perubahan terbaru:

- unit `Karang Taruna` sudah masuk sebagai unit resmi
- struktur organisasi sekarang punya mode visual hierarkis berbentuk piramida
- unit atau pengurus yang belum disetting tidak lagi ditampilkan di layar
- lead member mengikuti urutan jabatan aktif tertinggi, bukan hanya flag
  `primary`
- display name dan avatar `workspace_member` dipakai untuk identitas pengurus

## 8.7 Finance Maker-Checker

Flow final:

1. maker membuat draft transaksi
2. maker submit draft
3. jika transaksi butuh checker, status menjadi `submitted`
4. checker approve atau reject
5. setelah `approved`, publish pengumuman kas dilakukan manual
6. setelah publish, `publish_status = published`

Aturan verification:

- semua `out` wajib 2-way verification
- `in` dengan `transfer` wajib 2-way verification
- `cash in` boleh auto-approved saat submit

Layar yang sudah ada:

- `FinanceListScreen`
- `FinanceFormScreen`
- `FinanceDetailScreen`

## 8.8 Subscription dan Midtrans

Prinsip subscription:

- warga daftar sebagai `free`
- upgrade operator dilakukan lewat flow subscription
- sysadmin tidak ikut flow pembelian biasa
- transaksi payment belum boleh langsung mengubah akses sampai status payment sah

Midtrans dipakai untuk checkout dan callback payment subscription.

## 8.9 Laporan Operasional

Tujuan modul:

- membantu admin scan kondisi RW atau RT dalam beberapa detik
- menonjolkan item yang perlu tindakan paling cepat
- membuka modul kerja yang relevan dengan filter awal yang tepat

Struktur layar terbaru:

- layer 1: alert urgent untuk iuran belum lunas, dokumen pending review, surat
  perlu approval, dan bukti transfer menunggu verifikasi
- layer 2: snapshot operasional berbentuk metric card yang lebih ringkas
- layer 3: detail drill-down untuk fokus kategori yang dipilih

Perubahan terbaru:

- dashboard laporan sekarang lebih bersih dan actionable
- CTA pada alert langsung membuka `iuran`, `dokumen`, atau `surat` dengan
  pre-filter
- metric card punya active state untuk fokus detail
- akses laporan operasional tetap dibatasi untuk admin wilayah

## 9. Collection Utama PocketBase

### Data inti

- `users`
- `warga`
- `kartu_keluarga`
- `anggota_kk`
- `dokumen`
- `surat`
- `surat_attachments`
- `surat_logs`

### Iuran

- `iuran_types`
- `iuran_periods`
- `iuran_bills`
- `iuran_payments`

### Chat dan announcement

- `conversations`
- `conversation_members`
- `messages`
- `message_reads`
- `announcements`
- `chat_polls`
- `chat_poll_options`
- `chat_poll_votes`

### SaaS dan organisasi

- `workspaces`
- `workspace_members`
- `org_units`
- `jabatan_master`
- `org_memberships`

### Finance

- `finance_accounts`
- `finance_transactions`
- `finance_approvals`

### Subscription

- `subscription_plans`
- `subscription_transactions`
- `role_requests`

## 10. Permission Contract Ringkas

### Backend / service

- service tidak boleh lagi mengandalkan `users.role` sebagai sumber utama
- akses final harus berbasis `workspace_member` aktif
- action sensitif harus cek `plan + jabatan + scope`

### UI

- tombol hanya muncul jika backend memang akan mengizinkan
- screen organisasi dan finance harus gate per capability, bukan per role legacy
- fitur premium chat tetap gate by `plan_code`

## 11. Status Implementasi Runtime Saat Ini

### Sudah aktif

- model akses `system_role + plan_code + jabatan + scope`
- migration foundation workspace, org, finance, chat scope
- organization screens
- finance screens
- announcement scoped
- attachment dan statistik view pengumuman
- iuran operasional dasar
- dashboard laporan operasional dengan CTA terfilter
- org chart hierarkis dan sinkronisasi grup chat unit
- fallback legacy role lama

### Belum final

- composer polling di chat room
- composer voice note di chat room
- integrasi otomatis `iuran -> finance_transactions`
- cleanup total ketergantungan ke `users.role`

## 12. Testing

Checklist detail ada di:

- `MARKDOWN/testing_matrix.md`
- `MARKDOWN/manual_smoke_runbook.md`

Status testing saat ini:

- auth, settings, subscription, dashboard, announcement, organization, finance,
  dan iuran: siap diuji via UI
- polling dan voice note: backend siap, UI belum final
- iuran ke ledger finance: belum selesai

## 13. Checklist Batch 10-13 Maret 2026

Perubahan yang harus dites satu per satu dari batch 10-13 Maret 2026:

1. alert `Laporan` membuka `iuran`, `dokumen`, dan `surat` dengan filter awal
   yang sesuai
2. dashboard `Laporan` tidak overflow pada mobile, tablet, dan web desktop
3. grup chat unit organisasi otomatis tersedia sesuai `org_units`
4. avatar grup chat bisa dilihat, diubah, dan dihapus dari menu `more`
5. kelola anggota grup hanya menawarkan anggota sesuai area yuridiksi
6. struktur organisasi hanya menampilkan unit dan pengurus yang sudah terset
7. lead member pada chart organisasi selalu memilih jabatan aktif tertinggi
8. pengumuman scoped mendukung attachment dan statistik view

## 14. Next Step Setelah Batch Ini Lolos Test

Urutan paling aman setelah testing batch hari ini:

1. sambungkan iuran ke ledger finance
2. tambah publish flow pengumuman kas dari iuran yang sudah terverifikasi
3. lengkapi composer polling di chat
4. lengkapi composer voice note di chat
5. cleanup ketergantungan legacy `users.role`

## 15. Catatan Penutup

README ini sekarang menjadi sumber baca utama untuk produk, SaaS model,
permission, blueprint implementasi, dan status testing. `RULES.md` sengaja
tetap terpisah karena fungsinya bukan dokumentasi aplikasi, tetapi aturan kerja
agent AI.
