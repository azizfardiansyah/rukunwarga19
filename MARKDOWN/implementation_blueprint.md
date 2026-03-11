# Implementation Blueprint

Tanggal pembaruan: 2026-03-11

Dokumen ini menurunkan model SaaS final ke blueprint implementasi yang bisa
dipakai untuk migrasi backend, auth, chat, keuangan, dan subscription.

Dokumen turunan yang harus dibaca bersama blueprint ini:

- `MARKDOWN/jabatan_master_flag_schema.md`
- `MARKDOWN/service_permission_matrix.md`
- `MARKDOWN/ui_permission_matrix.md`

## 1. Prinsip Implementasi

- jangan lagi mengandalkan `users.role` sebagai sumber akses utama
- akses final harus berbasis `workspace_member`
- `system_role`, `plan_code`, `jabatan`, dan `scope` harus dipisah
- legacy role `admin_rt`, `admin_rw`, `admin_rw_pro` dipakai hanya untuk fase
  transisi
- satu user boleh punya banyak membership lintas workspace
- satu user boleh punya banyak jabatan di dalam satu workspace

## 2. Collection Model Final

### 2.1 Existing collection yang harus dipertahankan

- `users`
- `warga`
- `kartu_keluarga`
- `anggota_kk`
- `dokumen`
- `surat_requests` dan lampirannya
- `iuran_types`
- `iuran_periods`
- `iuran_bills`
- `iuran_payments`
- `conversations`
- `conversation_members`
- `messages`
- `announcements`
- `subscription_plans`
- `subscription_transactions`

### 2.2 New collection yang perlu ditambahkan

#### `workspaces`

Tujuan:
- 1 RW atau yuridiksi utama = 1 workspace data

Field minimum:
- `code`
- `name`
- `rw`
- `desa_code`
- `kecamatan_code`
- `kabupaten_code`
- `provinsi_code`
- `desa_kelurahan`
- `kecamatan`
- `kabupaten_kota`
- `provinsi`
- `owner_member` -> relation `workspace_members`
- `status` -> `active`, `inactive`

#### `workspace_members`

Tujuan:
- sumber akses utama per user per workspace

Field minimum:
- `workspace` -> relation `workspaces`
- `user` -> relation `users`
- `system_role` -> `warga`, `operator`, `sysadmin`
- `plan_code` -> `free`, `rt`, `rw`, `rw_pro`
- `subscription_status` -> `inactive`, `active`, `expired`
- `subscription_started`
- `subscription_expired`
- `is_owner`
- `owner_rank`
- `scope_type` -> `rw`, `rt`, `unit`
- `scope_rt`
- `scope_rw`
- `org_unit` -> relation `org_units`, opsional
- `is_active`

Catatan:
- collection ini menggantikan fungsi bisnis dari `users.role`
- 1 user bisa punya banyak record `workspace_members`

#### `org_units`

Tujuan:
- menyimpan unit resmi dan unit custom di dalam workspace

Field minimum:
- `workspace`
- `type` -> `rw`, `rt`, `dkm`, `posyandu`, `custom`
- `name`
- `code`
- `parent_unit`
- `scope_rt`
- `scope_rw`
- `is_official`
- `status`

#### `jabatan_master`

Tujuan:
- master jabatan operasional

Field minimum:
- `code`
- `label`
- `unit_type`
- `sort_order`
- `can_submit_finance`
- `can_approve_finance`
- `can_manage_schedule`
- `can_broadcast_unit`
- `is_active`

#### `org_memberships`

Tujuan:
- relasi user ke jabatan pada unit tertentu

Field minimum:
- `workspace`
- `user`
- `workspace_member`
- `org_unit`
- `jabatan`
- `is_primary`
- `started_at`
- `ended_at`
- `status`
- `period_label`

#### `chat_polls`

Tujuan:
- data polling per message

Field minimum:
- `workspace`
- `conversation`
- `message`
- `title`
- `allow_multiple_choice`
- `allow_anonymous_vote`
- `status` -> `open`, `closed`
- `closed_at`

#### `chat_poll_options`

Field minimum:
- `poll`
- `label`
- `sort_order`

#### `chat_poll_votes`

Field minimum:
- `poll`
- `option`
- `user`
- `workspace_member`
- `created`

#### `finance_accounts`

Tujuan:
- dompet kas per unit

Field minimum:
- `workspace`
- `org_unit`
- `code`
- `label`
- `type` -> `cash`, `bank`
- `is_active`

#### `finance_transactions`

Tujuan:
- buku kas in/out lintas unit

Field minimum:
- `workspace`
- `org_unit`
- `account`
- `source_module` -> `manual`, `iuran`, `surat`, `event`
- `direction` -> `in`, `out`
- `category`
- `title`
- `description`
- `amount`
- `payment_method` -> `cash`, `transfer`
- `proof_file`
- `maker_member`
- `maker_jabatan_snapshot`
- `approval_status` -> `draft`, `submitted`, `approved`, `rejected`
- `publish_status` -> `pending`, `published`
- `submitted_at`
- `approved_at`
- `published_at`

#### `finance_approvals`

Tujuan:
- jejak checker per transaksi

Field minimum:
- `transaction`
- `checker_member`
- `checker_jabatan_snapshot`
- `decision` -> `approved`, `rejected`
- `note`
- `created`

### 2.3 Existing collection yang perlu diubah

#### `subscription_plans`

Ganti fokus dari `target_role` ke:
- `plan_code`
- `target_system_role`
- `scope_level`
- `feature_flags`

Contoh `feature_flags`:
- `chat_basic`
- `broadcast_rt`
- `broadcast_rw`
- `custom_group_basic`
- `custom_group_advanced`
- `agenda_basic`
- `agenda_advanced`
- `finance_basic`
- `finance_publish`
- `voice_note`
- `polling`
- `export_advanced`

#### `subscription_transactions`

Tambahkan:
- `workspace`
- `workspace_member`
- `plan_code`
- `seat_target`

Legacy `target_role` dipertahankan sementara untuk migrasi.

#### `conversations`

Tambahkan:
- `workspace`
- `scope_type` -> `private_support`, `rt`, `rw`, `dkm`, `posyandu`, `custom`, `developer_support`
- `org_unit`
- `required_plan_code`

#### `messages`

Tambahkan:
- `workspace`
- `sender_member`
- `message_type` -> tambah `voice`, `poll`, `system`
- `voice_duration_seconds`
- `poll`
- `sender_badge_label`

#### `announcements`

Tambahkan:
- `workspace`
- `org_unit`
- `source_module` -> `manual`, `finance`, `chat`, `system`
- `publish_state` -> `draft`, `published`
- `published_by_member`

## 3. Access Matrix

### 3.1 Base matrix by `system_role + plan_code`

| system_role | plan_code | Scope default | Data warga | Broadcast | Agenda | Finance | Custom group | Chat voice/poll |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| warga | free | diri sendiri | diri sendiri | tidak | lihat saja | tidak | tidak | tidak |
| operator | rt | RT sendiri | RT sendiri | RT sendiri | basic RT | basic RT | tidak | tidak |
| operator | rw | RW sendiri | RW sendiri | RW sendiri | basic RW | basic RW | basic | tidak |
| operator | rw_pro | RW sendiri | RW sendiri | RW sendiri | advanced | advanced | advanced | ya |
| sysadmin | n/a | global | global | global | global | audit | global | global |

### 3.2 Modifier by jabatan

| Jabatan | Modifier |
| --- | --- |
| bendahara_* | boleh input transaksi kas |
| ketua_* / wakil_* | boleh approve transaksi kas |
| admin_dkm / ketua_dkm / wakil_ketua_dkm | boleh kelola jadwal khotib dan tarawih sesuai unit |
| koordinator_ronda | boleh kelola jadwal ronda jika plan mengizinkan |
| panitia_agustus | boleh kelola agenda Agustus jika plan mengizinkan |

### 3.3 Rule penting

- plan membuka fitur
- jabatan membuka aksi operasional
- scope membatasi wilayah dan unit
- jika plan aktif tapi jabatan tidak sesuai, user hanya bisa lihat
- jika jabatan sesuai tapi plan tidak mengizinkan, aksi tetap ditolak

## 4. Chat Scope ke Schema dan API

### 4.1 Scope conversation final

- `private_support`
- `rt`
- `rw`
- `dkm`
- `posyandu`
- `custom`
- `developer_support`

### 4.2 Message type final

- `text`
- `file`
- `voice`
- `poll`
- `system`

### 4.3 API minimum

- `GET /api/rukunwarga/chat/bootstrap?workspaceId=...`
- `GET /api/rukunwarga/chat/conversations/{conversationId}/messages`
- `POST /api/rukunwarga/chat/conversations/{conversationId}/messages`
- `POST /api/rukunwarga/chat/conversations/{conversationId}/voice`
- `POST /api/rukunwarga/chat/conversations/{conversationId}/polls`
- `POST /api/rukunwarga/chat/polls/{pollId}/vote`
- `GET /api/rukunwarga/chat/announcements?workspaceId=...`
- `POST /api/rukunwarga/chat/announcements`
- `POST /api/rukunwarga/chat/announcements/{id}/publish`

### 4.4 Aturan chat final

- badge chat diambil dari snapshot `jabatan` dan `system_role`
- warga hanya dapat akses sesuai conversation yang relevan
- `developer_support` adalah kanal support produk, bukan DM bebas ke semua dev
- voice note hanya aktif jika `plan_code = rw_pro` atau sysadmin
- polling hanya aktif jika `plan_code = rw_pro` atau sysadmin
- broadcast tetap tunduk ke yuridiksi dan scope

## 5. Flow Keuangan `maker-checker`

### 5.1 Flow transaksi `out`

1. bendahara membuat draft transaksi
2. bendahara submit transaksi
3. checker `ketua/wakil` review
4. jika approve -> status `approved`
5. jika reject -> status `rejected`
6. setelah approved, publish pengumuman dilakukan manual
7. setelah publish, `publish_status = published`

### 5.2 Flow transaksi `in`

Kas masuk manual:
1. bendahara input
2. admin/checker verifikasi
3. publish manual bila perlu

Kas masuk dari transfer iuran:
1. warga upload bukti transfer
2. admin verifikasi payment
3. sistem atau admin membuat `finance_transaction direction = in`
4. publish manual bila perlu

### 5.3 Rule final

- semua `pengeluaran` wajib maker-checker
- semua `pemasukan transfer` wajib maker-checker
- `cash masuk` boleh langsung diverifikasi admin
- publish pengumuman tidak otomatis
- publish hanya boleh setelah approval final

## 6. Mapping Fitur ke Paket

### `free`

- profil warga
- lihat KK sendiri
- chat basic text/file
- lihat pengumuman

### `rt`

- operasional RT
- data warga RT
- broadcast RT
- agenda dasar RT
- iuran dan kas dasar RT

### `rw`

- semua fitur plan `rt` dalam scope RW
- dashboard RW
- laporan RW
- custom group basic
- agenda komunitas dasar
- kas dan approval dasar RW

### `rw_pro`

- semua fitur plan `rw`
- voice note
- polling
- custom group advanced
- agenda advanced
- transparansi kas dan publish finance
- export advanced

## 7. Urutan Migrasi Aman

### Tahap 1

- tambah collection baru
- backfill `workspaces`
- backfill `workspace_members` dari role lama
- backfill `org_units` default RW dan RT

### Tahap 2

- ubah hook dan API agar baca `workspace_members`
- pertahankan fallback ke role lama

### Tahap 3

- migrasi chat ke `sender_member`, `workspace`, dan scope baru
- tambah voice dan polling

### Tahap 4

- tambah finance collections
- hubungkan verifikasi iuran ke finance `in`

### Tahap 5

- hapus ketergantungan bisnis ke `users.role`
- jadikan role lama hanya alias migrasi atau hapus total

## 8. Output yang Harus Ada Setelah Implementasi

- workspace scoped access jalan
- billing per seat jalan
- chat support, custom group, voice, polling jalan sesuai plan
- maker-checker finance jalan
- pengumuman finance publish manual jalan
- testing per role dan transaksi bisa dieksekusi end-to-end
