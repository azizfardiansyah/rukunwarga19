# Service Permission Matrix

Tanggal pembaruan: 2026-03-11

Dokumen ini adalah kontrak permission untuk backend, service layer, dan
collection endpoint yang dipakai atau akan dipakai selama migrasi model SaaS
baru.

## 1. Aturan Evaluasi

Setiap operasi harus dievaluasi dengan urutan yang sama:

1. `auth user` valid
2. punya `workspace_member` aktif
3. `system_role` valid
4. `plan_code` memenuhi gate fitur
5. `jabatan_master` memenuhi capability flag
6. `scope` unit dan yuridiksi cocok

## 2. Organization dan Access

| Domain | Service atau endpoint | Operasi | Minimal role | Minimal plan | Flag jabatan | Scope | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| access | `WorkspaceAccessService.getCurrentAccessProfile()` | baca profil akses aktif | semua user login | `free` | tidak | workspace aktif user | current |
| access | `WorkspaceAccessService.getOrgUnits()` | lihat unit di workspace | `operator` | `rt` | tidak | sesuai workspace | current |
| access | `WorkspaceAccessService.getJabatanMaster()` | lihat master jabatan | `operator` | `rt` | tidak | global read-only | current |
| access | `WorkspaceAccessService.getOrgMemberships()` | lihat pengurus unit | `operator` | `rt` | tidak | unit yang relevan | current |
| org | `GET /api/collections/workspace_members/records` | lihat seat dan member workspace | `operator` | `rw` | `can_manage_membership` untuk full management, tanpa flag hanya read sesuai scope | workspace | target |
| org | `POST /api/collections/org_units/records` | tambah unit resmi atau custom | `operator` | `rw` | `can_manage_unit` | workspace dan yuridiksi | target |
| org | `PATCH /api/collections/org_units/records/:id` | edit atau arsip unit | `operator` | `rw` | `can_manage_unit` | unit terkait | target |
| org | `POST /api/collections/org_memberships/records` | assign jabatan ke anggota | `operator` | `rw` | `can_manage_membership` | unit terkait | target |
| org | `PATCH /api/collections/org_memberships/records/:id` | ubah masa bakti atau status pengurus | `operator` | `rw` | `can_manage_membership` | unit terkait | target |
| org | `POST/PATCH /api/collections/jabatan_master/records` | CRUD master jabatan | `sysadmin` | n/a | n/a | global | target |
| org | `PATCH /api/collections/workspaces/records/:id` | ubah profil workspace | `operator` | `rw` | `can_manage_workspace` | workspace sendiri | target |

## 3. Finance Maker-Checker

| Domain | Service atau endpoint | Operasi | Minimal role | Minimal plan | Flag jabatan | Scope | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| finance | `FinanceService.getAccounts()` | lihat akun kas unit | `operator` | `rt` | tidak | unit yang bisa diakses | current |
| finance | `FinanceService.getTransactions()` | lihat ledger transaksi | `operator` | `rt` | salah satu dari submit, approve, publish atau sysadmin | unit yang relevan | current |
| finance | `FinanceService.getApprovals()` | lihat histori approval | `operator` | `rt` | submit, approve, publish atau sysadmin | transaksi yang relevan | current |
| finance | `FinanceService.createTransaction()` | buat draft atau submit transaksi | `operator` | `rt` untuk RT, `rw` untuk RW atau unit resmi di RW | `can_submit_finance` | unit terkait | current |
| finance | `FinanceService.approveTransaction()` | approve transaksi | `operator` | `rt` untuk RT, `rw` untuk RW atau unit resmi di RW | `can_approve_finance` | unit terkait, bukan maker sendiri | current |
| finance | `FinanceService.rejectTransaction()` | reject transaksi | `operator` | `rt` untuk RT, `rw` untuk RW atau unit resmi di RW | `can_approve_finance` | unit terkait, bukan maker sendiri | current |
| finance | `FinanceService.publishTransaction()` | publish transaksi approved ke announcement | `operator` | `rw` atau `rw_pro` | `can_publish_finance` | yuridiksi transaksi | target |
| finance | `POST /api/collections/finance_transactions/records` | cash in | `operator` | `rt` atau `rw` | `can_submit_finance` | unit terkait | current |
| finance | `POST /api/collections/finance_approvals/records` | checker decision | `operator` | `rt` atau `rw` | `can_approve_finance` | unit terkait | current |

Catatan:

- `cash in` boleh auto-approved
- `transfer in` wajib maker-checker
- `out` wajib maker-checker
- publish finance jangan lagi mengandalkan `can_broadcast_unit` saja

## 4. Iuran ke Finance

| Domain | Service atau endpoint | Operasi | Minimal role | Minimal plan | Flag jabatan | Scope | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| iuran | `IuranService.fetchList()` | lihat tagihan dan payment | `warga` atau `operator` | `free` atau aktif | tidak | sesuai area access | current |
| iuran | `IuranService.createType()` | buat jenis iuran | `operator` | `rt` atau `rw` | `can_manage_iuran` | yuridiksi terkait | target |
| iuran | `IuranService.createPeriod()` | buat periode dan bill | `operator` | `rt` atau `rw` | `can_manage_iuran` | yuridiksi terkait | target |
| iuran | `IuranService.submitTransfer()` | warga submit bukti transfer | `warga` | `free` | tidak | bill milik KK sendiri | current |
| iuran | `IuranService.recordCashPayment()` | admin catat cash masuk | `operator` | `rt` atau `rw` | `can_verify_iuran_payment` | yuridiksi tagihan | target |
| iuran | `IuranService.verifyPayment()` | admin verifikasi transfer | `operator` | `rt` atau `rw` | `can_verify_iuran_payment` | yuridiksi tagihan | target |
| iuran-finance | `IuranService.recordCashPayment()` + `FinanceService.createTransaction()` | buat ledger `in/cash` | sistem atau operator | `rt` atau `rw` | `can_submit_finance` | unit iuran terkait | target |
| iuran-finance | `IuranService.verifyPayment()` + `FinanceService.createTransaction()` | buat ledger `in/transfer` status `submitted` | sistem atau operator | `rt` atau `rw` | `can_submit_finance` | unit iuran terkait | target |
| iuran-finance | `FinanceService.approveTransaction()` | checker final transfer iuran | `operator` | `rt` atau `rw` | `can_approve_finance` | unit iuran terkait | target |
| iuran-finance | `FinanceService.publishTransaction()` | publish pengumuman iuran in | `operator` | `rw` atau `rw_pro` | `can_publish_finance` | yuridiksi transaksi | target |

## 5. Chat, Polling, Voice, Announcement

| Domain | Service atau endpoint | Operasi | Minimal role | Minimal plan | Flag jabatan | Scope | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| chat | `ChatService.bootstrap()` | load inbox dan groups | semua user login | `free` | tidak | conversation yang sah | current |
| chat | `ChatService.getMessages()` | baca isi conversation | semua user login | `free` | tidak | conversation yang sah | current |
| chat | `ChatService.sendMessage()` | kirim text atau file | semua user login | `free` | tidak | conversation yang sah | current |
| chat | `ChatService.sendVoiceMessage()` | kirim voice note | `operator` | `rw_pro` | tidak | conversation yang sah | current |
| chat | `ChatService.createPoll()` | buat polling | `operator` | `rw_pro` | tidak | conversation yang sah | current |
| chat | `ChatService.votePoll()` | vote polling | semua user login | `free` | tidak | anggota conversation | current |
| chat | `ChatService.createScopedConversation()` | buat custom group | `operator` | `rw` | `can_manage_schedule` atau `can_broadcast_unit` bila unit-scoped | workspace atau unit terkait | current |
| chat | `ChatService.createAnnouncement()` | publish announcement umum | `operator` | `rt` untuk RT, `rw` untuk RW atau unit resmi | `can_broadcast_unit` bila scoped ke unit | yuridiksi announcement | current |
| chat | `POST /api/collections/announcements/records` | finance announcement | `operator` | `rw` atau `rw_pro` | `can_publish_finance` | yuridiksi transaksi | target |

## 6. Subscription dan Seat

| Domain | Service atau endpoint | Operasi | Minimal role | Minimal plan | Flag jabatan | Scope | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| subscription | `SubscriptionPaymentService.getPlans()` | lihat plan yang bisa dibeli | user login | sesuai rule current plan | tidak | akun sendiri | current |
| subscription | `SubscriptionPaymentService.createCheckout()` | checkout seat | user login | sesuai role self-subscribe | tidak | workspace member aktif | current |
| subscription | `SubscriptionPaymentService.getStatus()` | refresh status order | user login | sesuai rule current plan | tidak | order sendiri | current |
| seat | `workspace_members` sync dari pembayaran | aktifkan `plan_code` seat | sistem | n/a | tidak | workspace member target | current |

## 7. Prioritas Implementasi Berdasarkan Matrix

Urutan yang paling sinkron:

1. tambah flag baru di `jabatan_master`
2. buat `OrganizationService` untuk CRUD unit dan membership
3. revisi `FinanceService.publishTransaction()` agar pakai `can_publish_finance`
4. sambungkan `IuranService` ke `FinanceService`
5. lengkapi UI chat untuk `poll` dan `voice`

## 8. Rule Anti-Bocor

- plan tidak boleh menggantikan jabatan
- jabatan tidak boleh menggantikan plan
- semua list harus tetap tersaring oleh workspace dan unit
- maker tidak boleh approve transaksi sendiri
- `admin_rt` legacy tidak boleh lolos ke feature gate `rw_pro`
