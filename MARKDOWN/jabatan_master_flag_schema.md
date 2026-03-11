# Jabatan Master Flag Schema

Tanggal pembaruan: 2026-03-11

Dokumen ini mengunci schema flag untuk `jabatan_master` agar implementasi
layar organisasi, finance maker-checker, iuran ke ledger, dan chat scoped tetap
sinkron.

## 1. Prinsip

- `jabatan` tidak butuh subscription
- `subscription` membuka fitur SaaS
- `jabatan` membuka aksi operasional
- `scope` membatasi wilayah dan unit
- fitur premium seperti `voice`, `polling`, `custom group advanced`, dan
  `export advanced` tetap milik `plan_code`, bukan milik jabatan

Urutan evaluasi akses:

1. user login dan punya `workspace_member` aktif
2. `system_role` valid
3. `plan_code` memenuhi paywall
4. `jabatan_master` memberi capability flag
5. `scope` unit dan yuridiksi cocok

## 2. Final Schema

### 2.1 Identity fields

| Field | Tipe | Keterangan |
| --- | --- | --- |
| `code` | text | kode unik jabatan, contoh `ketua_rw` |
| `label` | text | label tampilan |
| `unit_type` | select | `rw`, `rt`, `dkm`, `posyandu`, `custom`, `global` |
| `sort_order` | number | urutan tampilan |
| `is_active` | bool | status jabatan |

### 2.2 Capability flags minimum

| Field | Tipe | Fungsi |
| --- | --- | --- |
| `can_manage_workspace` | bool | ubah profil workspace, owner-level config, status workspace |
| `can_manage_unit` | bool | tambah, edit, arsip unit resmi atau custom di workspace |
| `can_manage_membership` | bool | assign jabatan, ubah masa bakti, aktifkan/nonaktifkan pengurus |
| `can_submit_finance` | bool | membuat dan submit transaksi kas |
| `can_approve_finance` | bool | approve atau reject transaksi kas |
| `can_publish_finance` | bool | publish transaksi approved ke pengumuman |
| `can_manage_schedule` | bool | kelola agenda atau jadwal resmi unit |
| `can_broadcast_unit` | bool | kirim broadcast atau announcement scoped ke unit |
| `can_manage_iuran` | bool | buat jenis iuran, periode, dan tagihan scoped |
| `can_verify_iuran_payment` | bool | verifikasi atau tolak pembayaran iuran |

## 3. Current Runtime vs Target

### 3.1 Sudah ada di runtime

- `can_submit_finance`
- `can_approve_finance`
- `can_manage_schedule`
- `can_broadcast_unit`

Sumber saat ini:

- [workspace_access_model.dart](c:/Users/User/Desktop/rukunwarga19-1/lib/shared/models/workspace_access_model.dart)

### 3.2 Perlu ditambahkan berikutnya

- `can_manage_workspace`
- `can_manage_unit`
- `can_manage_membership`
- `can_publish_finance`
- `can_manage_iuran`
- `can_verify_iuran_payment`

Alasan:

- layar organisasi butuh flag yang lebih presisi daripada sekadar plan
- publish finance sebaiknya tidak menumpang ke flag broadcast
- iuran dan ledger finance perlu dipisah antara pembuat tagihan dan verifikator

## 4. Bukan Flag Jabatan

Capability berikut jangan ditaruh di `jabatan_master`:

- `can_use_polling`
- `can_use_voice_note`
- `can_create_custom_group`
- `can_export_advanced`
- `can_view_dashboard_rw`

Alasannya:

- capability di atas ditentukan oleh `plan_code`
- bila dimasukkan ke jabatan, desain SaaS akan campur antara billing dan
  organisasi

## 5. Starter Preset Jabatan

Ini preset awal yang paling aman untuk v1.

| Jabatan | Workspace | Unit | Membership | Submit finance | Approve finance | Publish finance | Schedule | Broadcast | Manage iuran | Verify iuran |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `ketua_rw` | ya | ya | ya | tidak | ya | ya | ya | ya | ya | ya |
| `wakil_ketua_rw` | ya | ya | ya | tidak | ya | ya | ya | ya | ya | ya |
| `sekretaris_rw` | tidak | ya | ya | tidak | tidak | tidak | ya | ya | tidak | tidak |
| `bendahara_rw` | tidak | tidak | tidak | ya | tidak | tidak | tidak | tidak | ya | ya |
| `ketua_rt` | tidak | ya | ya | tidak | ya | ya | ya | ya | ya | ya |
| `wakil_ketua_rt` | tidak | ya | ya | tidak | ya | ya | ya | ya | ya | ya |
| `sekretaris_rt` | tidak | tidak | ya | tidak | tidak | tidak | ya | ya | tidak | tidak |
| `bendahara_rt` | tidak | tidak | tidak | ya | tidak | tidak | tidak | tidak | ya | ya |
| `ketua_dkm` | tidak | ya | ya | tidak | ya | ya | ya | ya | tidak | tidak |
| `wakil_ketua_dkm` | tidak | ya | ya | tidak | ya | ya | ya | ya | tidak | tidak |
| `admin_dkm` | tidak | tidak | tidak | tidak | tidak | tidak | ya | ya | tidak | tidak |
| `bendahara_dkm` | tidak | tidak | tidak | ya | tidak | tidak | tidak | tidak | tidak | tidak |
| `ketua_posyandu` | tidak | ya | ya | tidak | ya | ya | ya | ya | tidak | tidak |
| `wakil_ketua_posyandu` | tidak | ya | ya | tidak | ya | ya | ya | ya | tidak | tidak |
| `kader_posyandu` | tidak | tidak | tidak | tidak | tidak | tidak | ya | tidak | tidak | tidak |
| `bendahara_posyandu` | tidak | tidak | tidak | ya | tidak | tidak | tidak | tidak | tidak | tidak |
| `panitia_agustus` | tidak | tidak | tidak | tidak | tidak | tidak | ya | ya | tidak | tidak |
| `koordinator_ronda` | tidak | tidak | tidak | tidak | tidak | tidak | ya | ya | tidak | tidak |

Catatan:

- `ya` di tabel belum cukup untuk menjalankan aksi bila `plan_code` tidak cocok
- sysadmin tetap bypass jabatan flag
- preset ini bisa disesuaikan per unit, tapi jangan mengubah prinsip plan vs
  jabatan

## 6. Mapping Ke Prioritas Implementasi

### 6.1 Layar organisasi

Minimal flag yang wajib dipakai:

- `can_manage_workspace`
- `can_manage_unit`
- `can_manage_membership`

### 6.2 Finance maker-checker

Minimal flag yang wajib dipakai:

- `can_submit_finance`
- `can_approve_finance`
- `can_publish_finance`

### 6.3 Iuran ke ledger finance

Minimal flag yang wajib dipakai:

- `can_manage_iuran`
- `can_verify_iuran_payment`
- `can_submit_finance`
- `can_approve_finance`

### 6.4 Chat scoped announcement

Minimal flag yang wajib dipakai:

- `can_broadcast_unit`
- `can_manage_schedule`

Plan-level gate tetap berlaku untuk:

- `polling`
- `voice note`

## 7. Implementasi Model Dart Berikutnya

File yang harus diselaraskan saat flag baru ditambahkan:

- [workspace_access_model.dart](c:/Users/User/Desktop/rukunwarga19-1/lib/shared/models/workspace_access_model.dart)
- [workspace_access_service.dart](c:/Users/User/Desktop/rukunwarga19-1/lib/core/services/workspace_access_service.dart)
- [finance_service.dart](c:/Users/User/Desktop/rukunwarga19-1/lib/core/services/finance_service.dart)
- [iuran_service.dart](c:/Users/User/Desktop/rukunwarga19-1/lib/core/services/iuran_service.dart)

Tambahan method yang perlu ada di `WorkspaceAccessProfile`:

- `canManageWorkspace`
- `canManageUnit`
- `canManageMembership`
- `canPublishFinanceForUnit`
- `canManageIuranForUnit`
- `canVerifyIuranForUnit`
