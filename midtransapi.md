# Midtrans Snap API

Dokumentasi implementasi payment gateway Midtrans Snap untuk project RukunWarga, termasuk perubahan role `warga`, flow subscription admin, testing Sandbox, dan catatan proses yang sudah dibahas.

---

## 1. Role dan aturan bisnis

### Role aktif di collection `users`
- `warga`
- `admin_rt`
- `admin_rw`
- `admin_rw_pro`
- `sysadmin`

### Aturan register
- Semua user yang daftar dari aplikasi otomatis dibuat sebagai `warga`.
- Role `sysadmin` tidak bisa dibeli dan tidak muncul di alur subscription.
- Tiga role berbayar yang bisa dipilih di menu `Subscription & Pembayaran`:
  - `admin_rt`
  - `admin_rw`
  - `admin_rw_pro`

### Aturan upgrade
1. User daftar atau login sebagai `warga`.
2. User buka `Settings > Subscription & Pembayaran`.
3. User pilih paket admin.
4. App buat checkout Midtrans Snap lewat PocketBase.
5. User bayar di Midtrans Sandbox.
6. Setelah pembayaran sukses:
   - `users.role` berubah ke role target
   - `users.subscription_plan` terisi
   - `users.subscription_status = active`
   - `users.subscription_started` terisi
   - `users.subscription_expired` terisi

### Aturan unsubscribe
- Unsubscribe sekarang langsung otomatis.
- Saat user admin klik `Unsubscribe` dan berhasil:
  - `users.role` kembali ke `warga`
  - `subscription_plan` dikosongkan
  - `subscription_status = inactive`
  - `subscription_started = null`
  - `subscription_expired = null`
- Setelah sukses, app menampilkan notifikasi elegan lalu route ke dashboard utama.

---

## 2. Arsitektur yang dipakai

Project ini memakai:
- Flutter sebagai client
- PocketBase sebagai backend utama
- Midtrans Snap sebagai payment gateway

Server Key Midtrans disimpan di PocketBase. Flutter tidak memegang Server Key.

Flow teknis:
1. Flutter login ke PocketBase.
2. Flutter memanggil custom API PocketBase.
3. PocketBase membuat transaksi ke Midtrans Snap.
4. PocketBase menyimpan transaksi ke `subscription_transactions`.
5. Flutter menerima `snapToken` dan `redirectUrl`.
6. User membayar di halaman Midtrans Sandbox.
7. PocketBase sinkron status via webhook atau `GET status`.
8. Jika sukses, PocketBase mengubah role user dan status subscription.

---

## 3. Endpoint custom yang dipakai

### GET `/api/rukunwarga/payments/subscription/plans`
Mengambil daftar paket aktif dari collection `subscription_plans`.

### POST `/api/rukunwarga/payments/subscription/snap`
Membuat checkout Midtrans Snap.

Body contoh:

```json
{
  "planCode": "admin_rw_monthly"
}
```

Response inti:

```json
{
  "orderId": "SUB-...",
  "snapToken": "xxx",
  "redirectUrl": "https://app.sandbox.midtrans.com/..."
}
```

### GET `/api/rukunwarga/payments/subscription/status/{orderId}`
Sinkron manual ke Midtrans Status API dan mengembalikan status transaksi terbaru.

### POST `/api/rukunwarga/payments/subscription/midtrans-notification`
Webhook Midtrans. Dipakai untuk update status otomatis bila `RW_MIDTRANS_NOTIFICATION_URL` sudah publik.

### POST `/api/rukunwarga/account/unsubscribe`
Route custom untuk self-unsubscribe. Setelah sukses, role user kembali ke `warga`.

---

## 4. Schema PocketBase

### Collection `users`

Field penting:
- `role` `select`
  - `warga`
  - `admin_rt`
  - `admin_rw`
  - `admin_rw_pro`
  - `sysadmin`
- `subscription_plan` `select`
- `subscription_status` `select`
  - `inactive`
  - `active`
  - `expired`
- `subscription_started` `date`
- `subscription_expired` `date`

### Collection `subscription_plans`

Field:
- `code`
- `name`
- `description`
- `target_role`
- `amount`
- `duration_days`
- `currency`
- `is_active`
- `sort_order`

Seed default dev:
- `admin_rt_monthly`
- `admin_rw_monthly`
- `admin_rw_pro_monthly`

### Collection `subscription_transactions`

Field penting:
- `subscriber`
- `plan_code`
- `target_role`
- `plan_name`
- `gross_amount`
- `period_days`
- `order_id`
- `snap_token`
- `redirect_url`
- `payment_state`
- `transaction_status`
- `payment_type`
- `subscription_applied`
- `subscription_started`
- `subscription_expired`
- `raw_midtrans_response`
- `raw_notification`

### Collection `role_requests`

Sekarang statusnya legacy untuk kebutuhan lama. Flow unsubscribe aktif tidak lagi bergantung pada collection ini.

---

## 5. Environment variable PocketBase

Set env di terminal yang dipakai untuk menjalankan PocketBase:

```powershell
$env:RW_MIDTRANS_IS_PRODUCTION="false"
$env:RW_MIDTRANS_SERVER_KEY="SB-Mid-server-xxxxxxxx"
$env:RW_MIDTRANS_CLIENT_KEY="SB-Mid-client-xxxxxxxx"
$env:RW_MIDTRANS_MERCHANT_ID="Mxxxxxxxx"
$env:RW_MIDTRANS_NOTIFICATION_URL="https://<public-url>/api/rukunwarga/payments/subscription/midtrans-notification"
$env:RW_MIDTRANS_FINISH_URL="https://<app-url>/#/settings"
```

Jalankan PocketBase:

```powershell
cd pocketbase_0.36.2_windows_amd64
.\pocketbase.exe serve --dev
```

Atau gunakan script lokal:

```powershell
powershell -ExecutionPolicy Bypass -File .\start-pocketbase-dev.ps1
```

Catatan:
- Dev wajib pakai **Sandbox**
- Jangan pakai key Production untuk testing dev
- `RW_MIDTRANS_NOTIFICATION_URL` harus URL publik jika webhook ingin diuji dari lokal

---

## 6. Cara test dev end-to-end

### Persiapan
1. Pastikan MAP Midtrans ada di environment **Sandbox**.
2. Jalankan migration PocketBase.

```powershell
cd pocketbase_0.36.2_windows_amd64
.\pocketbase.exe migrate up
```

3. Jalankan PocketBase dengan env Midtrans Sandbox.
4. Jalankan Flutter app.

### Test upgrade role
1. Register user baru.
2. Pastikan record `users.role` langsung terisi `warga`.
3. Login sebagai user tersebut.
4. Buka `Settings > Subscription & Pembayaran`.
5. Pilih salah satu paket:
   - Admin RT
   - Admin RW
   - Admin RW Pro
6. Klik `Buat Checkout`.
7. Klik `Buka Pembayaran`.
8. Selesaikan pembayaran di Midtrans Sandbox.
9. Kembali ke app.
10. Klik `Cek Status Midtrans`.
11. Klik `Refresh Akses`.

### Hasil yang harus terjadi
- `subscription_transactions.payment_state` menjadi `paid`
- `users.role` berubah dari `warga` ke role target
- `users.subscription_status = active`
- `users.subscription_expired` terisi

### Test unsubscribe
1. Login sebagai user admin aktif.
2. Buka `Settings > Unsubscribe`.
3. Konfirmasi unsubscribe.
4. Setelah sukses:
   - app menampilkan notifikasi sukses
   - app route ke dashboard utama
   - `users.role` kembali ke `warga`
   - subscription dinonaktifkan

---

## 7. Simulasi transaksi berhasil di Sandbox

Jika checkout sudah terbentuk dan status masih `pending`, transaksi harus diselesaikan lewat simulator Sandbox Midtrans, bukan transfer bank nyata.

Alur test:
1. Klik `Buka Pembayaran`.
2. Lihat metode pembayaran di halaman Snap.
3. Gunakan simulator sesuai metode dari halaman testing Midtrans.
4. Selesaikan simulasi pembayaran.
5. Kembali ke app.
6. Klik `Cek Status Midtrans`.
7. Klik `Refresh Akses`.

Kalau webhook belum aktif karena `Notification URL` belum publik, status tetap bisa disinkronkan manual lewat endpoint:

```text
GET /api/rukunwarga/payments/subscription/status/{orderId}
```

Penting:
- Jangan bayar transaksi Sandbox dengan rekening atau aplikasi bank asli.
- Gunakan simulator atau kredensial uji resmi Midtrans.

---

## 8. Proses yang sudah disepakati

### Flow role
- Register => role default `warga`
- `warga` memilih paket admin di menu subscription
- Bayar sukses => role berubah otomatis
- Unsubscribe sukses => kembali ke `warga`

### Flow Midtrans di project ini
- Flutter tidak menyimpan Server Key
- PocketBase memanggil Snap API
- PocketBase memegang logika status, webhook, apply role, dan subscription
- `subscription_plans` menjadi sumber tagihan dan durasi
- `subscription_transactions` menjadi sumber histori checkout dan pembayaran

### Catatan operasional
- Untuk dev, `RW_MIDTRANS_IS_PRODUCTION=false`
- Untuk webhook lokal, gunakan tunnel seperti `ngrok` atau `cloudflared`
- Jika webhook belum aktif, pakai `Cek Status Midtrans`

---

## 9. Link resmi Midtrans yang relevan

- Snap Integration Guide:
  - https://docs.midtrans.com/docs/snap-snap-integration-guide
- Built-in Interface / SNAP overview:
  - https://docs.midtrans.com/docs/snap
- Testing Payment on Sandbox:
  - https://docs.midtrans.com/docs/testing-payment-on-sandbox
- HTTP Notification / Webhooks:
  - https://docs.midtrans.com/docs/https-notification-webhooks
- GET Status API Requests:
  - https://docs.midtrans.com/docs/get-status-api-requests
- Account Overview / Sandbox environment:
  - https://docs.midtrans.com/docs/midtrans-account
- Technical Reference & Developer Tools:
  - https://docs.midtrans.com/docs/technical-reference

---

## 10. Ringkasan keputusan implementasi

- Role dasar user aplikasi adalah `warga`, bukan `user`
- Upgrade role admin dilakukan lewat pembayaran Midtrans, tanpa approval sysadmin
- `sysadmin` tidak masuk flow subscription
- Unsubscribe dilakukan langsung oleh user dan langsung update database
- Tagihan dan durasi paket diambil dari collection `subscription_plans`
- Status transaksi dicatat di `subscription_transactions`
