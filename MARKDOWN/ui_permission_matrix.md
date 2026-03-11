# UI Permission Matrix

Tanggal pembaruan: 2026-03-11

Dokumen ini menurunkan permission backend ke visibilitas layar, tombol, dan
aksi UI. Tujuannya supaya layar baru tidak menampilkan tombol yang backend
sebenarnya akan tolak.

## 1. Aturan UI

Urutan cek UI:

1. user login
2. `workspace_member` aktif tersedia
3. `system_role` dan `plan_code` memenuhi akses layar
4. `jabatan` memenuhi action button
5. `scope` cocok dengan unit atau yuridiksi data

## 2. Screen Matrix Saat Ini

| Screen | Route | Akses buka layar | Tombol utama | Gate tombol | Status |
| --- | --- | --- | --- | --- | --- |
| `DashboardScreen` | `/` | semua user login | lihat ringkasan | data tetap terscope | current |
| `SettingsScreen` | `/settings` | semua user login | refresh auth, buka subscription | sesuai status subscription | current |
| `SubscriptionScreen` | `/subscription` | user login | pilih plan, buat checkout, cek status | self-subscribe rule | current |
| `ChatListScreen` | `/chat` | semua user login | buka conversation, buat announcement | announcement butuh operator + plan | current |
| `ChatRoomScreen` | `/chat/:id` | anggota conversation | kirim text, file, forward | text/file cukup `free`, poll atau voice pakai gate plan | current |
| `AnnouncementScreen` | `/pengumuman` | semua user login | lihat pengumuman | create hanya operator yang punya hak | current |
| `IuranListScreen` | `/iuran` | semua user login | bayar transfer, catat cash, review payment | warga hanya submit milik sendiri, operator sesuai area | current |
| `IuranFormScreen` | `/iuran/form` | operator | buat jenis dan periode iuran | target final pakai `can_manage_iuran` | current |
| `UserRoleManagementScreen` | `/settings/user-management` | sysadmin | ubah role, subscription | sysadmin only | current |

## 3. Tombol dan Komponen Yang Perlu Disinkronkan

### 3.1 ChatRoomScreen

| Komponen | Muncul untuk | Syarat |
| --- | --- | --- |
| input text | semua anggota conversation | access conversation valid |
| upload file | semua anggota conversation | access conversation valid |
| tombol voice | `operator` | `plan_code = rw_pro` |
| tombol create poll | `operator` | `plan_code = rw_pro` |
| widget vote poll | semua anggota conversation | poll masih `open` |
| tombol publish announcement dari unit | `operator` | `can_broadcast_unit` + scope cocok |

### 3.2 IuranListScreen

| Komponen | Muncul untuk | Syarat |
| --- | --- | --- |
| upload transfer | `warga` | bill milik KK sendiri, belum lunas |
| catat cash | `operator` | target final `can_verify_iuran_payment` |
| verifikasi transfer | `operator` | target final `can_verify_iuran_payment` |
| tolak transfer | `operator` | target final `can_verify_iuran_payment` |

### 3.3 SubscriptionScreen

| Komponen | Muncul untuk | Syarat |
| --- | --- | --- |
| daftar plan | user login | berdasarkan `getPlans()` |
| buat checkout | user login | plan bisa dibeli oleh akun itu |
| cek status | user login | ada `orderId` checkout |

## 4. Screen Matrix Baru Yang Harus Dibuat

### 4.1 Organisasi

| Screen rencana | Route usulan | Akses buka layar | Tombol utama | Gate tombol |
| --- | --- | --- | --- | --- |
| `OrganizationWorkspaceScreen` | `/organisasi` | `operator` minimal `rw` | edit profil workspace, lihat owner, lihat unit | `can_manage_workspace` untuk edit |
| `OrganizationUnitScreen` | `/organisasi/unit` | `operator` minimal `rw` | tambah unit, edit unit, arsip unit | `can_manage_unit` |
| `OrganizationMembershipScreen` | `/organisasi/membership` | `operator` minimal `rw` | assign jabatan, ubah masa bakti, aktif/nonaktifkan pengurus | `can_manage_membership` |
| `OrganizationStructureScreen` | `/organisasi/struktur` | semua user login | lihat struktur RW, RT, DKM, Posyandu | read-only, tidak butuh operator |

Catatan:

- `jabatan_master` edit sebaiknya tidak masuk ke layar operator biasa
- jika perlu, buat `JabatanMasterAdminScreen` khusus sysadmin

### 4.2 Finance

| Screen rencana | Route usulan | Akses buka layar | Tombol utama | Gate tombol |
| --- | --- | --- | --- | --- |
| `FinanceListScreen` | `/finance` | `operator` minimal `rt` | filter transaksi, buka detail | salah satu flag finance atau sysadmin |
| `FinanceFormScreen` | `/finance/form` | `operator` | buat draft, submit | `can_submit_finance` |
| `FinanceDetailScreen` | `/finance/:id` | `operator` | approve, reject, publish | approve pakai `can_approve_finance`, publish pakai `can_publish_finance` |
| `FinanceApprovalHistorySheet` | modal di detail | `operator` | lihat trail checker | boleh jika bisa baca transaksi |

### 4.3 Chat Enhancement

| Screen rencana | Lokasi | Akses buka layar | Tombol utama | Gate tombol |
| --- | --- | --- | --- | --- |
| `ChatPollComposerSheet` | dari `ChatRoomScreen` | `operator` | buat polling | `plan_code = rw_pro` |
| `ChatVoiceRecorderSheet` | dari `ChatRoomScreen` | `operator` | rekam dan kirim voice | `plan_code = rw_pro` |
| `ScopedConversationFormSheet` | dari `ChatListScreen` | `operator` minimal `rw` | pilih unit, buat grup | custom group by plan, unit-scoped opsional `can_broadcast_unit` atau `can_manage_schedule` |

## 5. UI Flow Prioritas

Urutan implementasi layar yang paling sinkron:

1. `OrganizationWorkspaceScreen`
2. `OrganizationUnitScreen`
3. `OrganizationMembershipScreen`
4. `FinanceListScreen`
5. `FinanceFormScreen`
6. `FinanceDetailScreen`
7. sambungkan aksi iuran ke ledger finance
8. tambah composer `poll` dan `voice` di `ChatRoomScreen`

## 6. Anti-Pattern Yang Harus Dihindari

- jangan tampilkan tombol hanya berdasarkan role legacy `admin_rt/admin_rw/admin_rw_pro`
- jangan tampilkan tombol approve hanya karena user operator
- jangan pakai `plan_code` saja untuk aksi yang butuh jabatan
- jangan pakai jabatan saja untuk fitur premium seperti `polling` dan `voice`

## 7. File UI Yang Akan Tersentuh

Current screens:

- [chat_room_screen.dart](c:/Users/User/Desktop/rukunwarga19-1/lib/features/chat/screens/chat_room_screen.dart)
- [chat_list_screen.dart](c:/Users/User/Desktop/rukunwarga19-1/lib/features/chat/screens/chat_list_screen.dart)
- [announcement_screen.dart](c:/Users/User/Desktop/rukunwarga19-1/lib/features/chat/screens/announcement_screen.dart)
- [iuran_list_screen.dart](c:/Users/User/Desktop/rukunwarga19-1/lib/features/iuran/screens/iuran_list_screen.dart)
- [iuran_form_screen.dart](c:/Users/User/Desktop/rukunwarga19-1/lib/features/iuran/screens/iuran_form_screen.dart)
- [subscription_screen.dart](c:/Users/User/Desktop/rukunwarga19-1/lib/features/settings/screens/subscription_screen.dart)

Planned screens:

- `lib/features/organization/screens/...`
- `lib/features/finance/screens/...`
