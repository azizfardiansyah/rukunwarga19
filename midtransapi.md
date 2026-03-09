# Midtrans Snap API Integration

Dokumentasi proses integrasi Midtrans Snap API untuk pembayaran langganan SaaS RukunWarga.

---

## 1. Konfigurasi API

- **Server Key**: Digunakan di backend untuk membuat transaksi.
- **Client Key**: Digunakan di frontend (opsional, jika pakai Snap JS).
- **Merchant ID**: Identitas akun Midtrans.
- **Mode dev wajib Sandbox**: pada screenshot dashboard yang aktif terlihat **Production**. Untuk testing dev, pindahkan environment ke **Sandbox** dan jangan pakai key produksi di repo/app.
- **Server Key harus dirahasiakan**: jangan ditaruh di Flutter. Simpan di environment PocketBase.

---

## 2. Alur Proses Pembayaran

### a. User Memilih Paket Langganan
- User klik tombol "Upgrade" atau "Bayar".

### b. Backend Membuat Transaksi ke Midtrans
- Backend (PocketBase/Node/PHP) mengirim request ke endpoint Snap API:

---

## 3. Arsitektur yang dipakai di project ini

Project ini adalah:
- **Flutter app** sebagai client
- **PocketBase** sebagai backend utama
- Belum ada backend Node/PHP terpisah

Karena itu integrasi paling pas untuk repo ini adalah:
- **Custom API dibuat di PocketBase `pb_hooks/main.pb.js`**
- Flutter memanggil API custom via `pb.send(...)`
- PocketBase yang memegang **Server Key Midtrans**
- Midtrans mengirim **webhook** ke endpoint PocketBase

Flow v1:
1. Flutter login ke PocketBase.
2. Flutter panggil `POST /api/rukunwarga/payments/subscription/snap`.
3. PocketBase buat transaksi ke Midtrans Snap.
4. PocketBase simpan record `subscription_transactions`.
5. Flutter menerima `snapToken` dan `redirectUrl`.
6. Setelah user bayar, Midtrans hit webhook PocketBase.
7. PocketBase sinkron status ke Midtrans Status API.
8. Jika sukses, field subscription di `users` diperbarui.

---

## 4. Endpoint custom yang sudah disiapkan

### GET `/api/rukunwarga/payments/subscription/plans`
Mengambil daftar paket subscription dari collection `subscription_plans`.
Default seed dev:
- `admin_rt_monthly`
- `admin_rw_monthly`
- `admin_rw_pro_monthly`

### POST `/api/rukunwarga/payments/subscription/snap`
Membuat transaksi Snap.

Body:

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
Sinkron status transaksi ke Midtrans Status API dan mengembalikan status terbaru.

### POST `/api/rukunwarga/payments/subscription/midtrans-notification`
Webhook Midtrans. Endpoint ini memverifikasi `signature_key`, lalu sinkron ulang status transaksi dari Midtrans.

---

## 5. Data model PocketBase yang ditambahkan

### Field baru di `users`
- `subscription_plan`
- `subscription_status`
- `subscription_started`
- `subscription_expired`

### Collection baru `subscription_transactions`
Menyimpan:
- subscriber
- plan
- nominal
- `order_id`
- `snap_token`
- `redirect_url`
- payment state lokal
- status raw Midtrans
- hasil apply subscription

### Collection baru `subscription_plans`
Menyimpan konfigurasi paket:
- `code`
- `name`
- `description`
- `target_role`
- `amount`
- `duration_days`
- `currency`
- `is_active`
- `sort_order`

---

## 6. Environment variable PocketBase

Set sebelum menjalankan PocketBase:

```powershell
$env:RW_MIDTRANS_IS_PRODUCTION="false"
$env:RW_MIDTRANS_SERVER_KEY="SB-Mid-server-xxxxxxxx"
$env:RW_MIDTRANS_CLIENT_KEY="SB-Mid-client-xxxxxxxx"
$env:RW_MIDTRANS_MERCHANT_ID="Mxxxxxxxx"
$env:RW_MIDTRANS_NOTIFICATION_URL="https://<public-url>/api/rukunwarga/payments/subscription/midtrans-notification"
$env:RW_MIDTRANS_FINISH_URL="https://<app-url>/#/settings"
```

Lalu jalankan PocketBase dari folder:

```powershell
cd pocketbase_0.36.2_windows_amd64
.\pocketbase.exe serve --http=127.0.0.1:8090
```

Catatan:
- `RW_MIDTRANS_NOTIFICATION_URL` harus URL publik kalau webhook Midtrans mau masuk ke mesin lokal. Untuk dev lokal, pakai tunnel seperti `ngrok` atau `cloudflared`.
- `RW_MIDTRANS_FINISH_URL` opsional. Kalau belum ada halaman khusus, boleh arahkan ke settings atau dashboard web.

---

## 7. Cara test di dev

1. Pastikan dashboard Midtrans ada di **Sandbox**, bukan Production.
2. Jalankan migration PocketBase agar collection `subscription_plans` ikut dibuat.

```powershell
cd pocketbase_0.36.2_windows_amd64
.\pocketbase.exe migrate up
```

3. Jalankan PocketBase dengan env var di atas.
4. Buka dashboard PocketBase dan pastikan collection `subscription_plans` berisi data aktif:
   - `admin_rt_monthly`
   - `admin_rw_monthly`
   - `admin_rw_pro_monthly`
5. Jalankan Flutter app.
6. Login pakai user yang role-nya memang wajib subscription, misalnya `admin_rw`.
7. Buka `Settings > Subscription & Pembayaran`.
8. Pastikan kartu paket menampilkan `Tagihan` dan `Durasi` dari database, bukan pesan "mengikuti konfigurasi server".
9. Klik `Buat Checkout`.
10. Klik `Buka Pembayaran`.
11. Selesaikan pembayaran dengan data uji Sandbox Midtrans.
12. Kembali ke app, klik `Cek Status Midtrans`, lalu `Refresh Akses`.
13. Alternatif verifikasi via endpoint:

```powershell
GET /api/rukunwarga/payments/subscription/status/{orderId}
```

14. Verifikasi field user:
- `subscription_plan`
- `subscription_status = active`
- `subscription_expired`

Kalau webhook belum bisa masuk karena URL lokal tidak publik, status masih bisa dipaksa sinkron lewat endpoint `status/{orderId}`.

---

## 8. Kenapa pendekatan ini yang paling cocok

- Tidak membocorkan **Server Key** ke Flutter.
- Tetap satu backend: **PocketBase**.
- Cocok dengan arsitektur repo saat ini yang langsung memakai PocketBase SDK.
- Bisa dites di dev tanpa harus menambah server Node/PHP baru.
- Sudah siap untuk dipakai lagi nanti buat payment flow lain, misalnya iuran warga.
