# Iuran - Product & System Spec

Dokumen ini merangkum kebutuhan final untuk menu `Iuran` yang sudah dibahas dan diimplementasikan tahap awal.

Fokus dokumen:
- alur proses transaksi iuran
- kebutuhan menu aplikasi
- schema PocketBase final v1
- status workflow tagihan dan pembayaran
- role dan akses per aktor
- laporan wajib admin RT/RW
- batasan v1 dan pengembangan lanjutan

---

## 1. Prinsip Produk

- Modul `Iuran` dipakai untuk penagihan operasional lingkungan tingkat RT/RW.
- Unit tagihan adalah `per KK`, bukan per warga.
- Sistem harus mendukung `multi-jenis iuran`.
- Nominal iuran:
  - bisa berubah per periode
  - bisa dioverride untuk KK tertentu
- Pembayaran warga tidak langsung dianggap lunas.
- Semua pembayaran warga harus diverifikasi admin terlebih dahulu.
- Untuk v1, metode pembayaran cukup:
  - `cash`
  - `transfer + upload bukti`

---

## 2. Keputusan Produk Final

### Unit tagihan
- `per KK`

### Model iuran
- `multi-jenis`

### Frekuensi
- `mingguan`
- `bulanan`
- `tahunan`
- `insidental`

### Nominal
- bisa berubah per periode
- bisa berbeda per target KK tertentu

### Metode pembayaran
- `cash`
- `transfer + upload bukti`

### Aturan pembayaran
- pembayaran harus `full`
- tidak ada cicilan
- tidak ada denda

### Scope operasional
- `admin_rt` bisa buat, edit, dan verifikasi iuran di scope RT sendiri
- `admin_rw` dan `admin_rw_pro` bisa operasional iuran RT dalam RW yang sama
- `warga` hanya bisa melihat dan membayar tagihan KK miliknya

### Yang sengaja di-skip dulu
- mutasi warga pindah / KK berubah
- denda keterlambatan
- split bill / partial payment

---

## 3. Role dan Akses

### warga
- melihat tagihan aktif KK miliknya
- melihat riwayat pembayaran KK miliknya
- upload bukti transfer

### admin_rt
- membuat jenis iuran
- membuat periode iuran
- memilih target semua KK atau KK tertentu
- menggenerate tagihan per KK
- mencatat pembayaran cash
- memverifikasi bukti transfer
- menolak bukti transfer
- melihat rekap iuran di wilayah RT sendiri

### admin_rw / admin_rw_pro
- memantau iuran lintas RT dalam RW yang sama
- membuat dan mengelola periode iuran lintas RT dalam RW
- memverifikasi pembayaran lintas RT dalam RW
- melihat rekap RW

### sysadmin
- audit penuh
- bukan aktor operasional utama harian

---

## 4. Struktur Menu Iuran

### Untuk warga
- `Iuran`
  - `Aktif`
  - `Riwayat`

### Untuk admin
- `Iuran`
  - `Tagihan`
  - `Verifikasi`
  - `Periode`
  - `Jenis`

Catatan UX:
- tidak perlu menu utama baru
- cukup satu menu `Iuran` dengan subtab sesuai role

---

## 5. Alur Proses Transaksi Iuran di Aplikasi

### Flow admin
1. Admin membuka menu `Iuran`.
2. Admin menambahkan `Jenis Iuran` bila belum ada.
3. Admin membuat `Periode Iuran`.
4. Admin menentukan:
   - jenis iuran
   - nama periode
   - frekuensi
   - nominal default
   - jatuh tempo
   - target semua KK atau KK tertentu
5. Jika perlu, admin memberi nominal override untuk KK tertentu.
6. Sistem membuat `bill/tagihan` per KK.
7. Periode langsung berstatus `published`.

### Flow warga
1. Warga membuka menu `Iuran`.
2. Warga melihat tagihan aktif KK miliknya.
3. Warga memilih metode transfer.
4. Warga upload bukti transfer.
5. Sistem menyimpan payment ke status `submitted`.
6. Tagihan berubah ke status `submitted_verification`.

### Flow pembayaran cash
1. Admin menerima pembayaran cash dari warga.
2. Admin membuka tagihan terkait.
3. Admin menekan aksi `Catat Cash`.
4. Sistem membuat payment `verified`.
5. Tagihan langsung berubah ke `paid`.

### Flow verifikasi admin
1. Admin membuka tab `Verifikasi`.
2. Admin melihat daftar payment dengan status `submitted`.
3. Admin membuka bukti transfer.
4. Admin memilih:
   - `Verifikasi`
   - `Tolak`
5. Jika diverifikasi:
   - payment -> `verified`
   - bill -> `paid`
6. Jika ditolak:
   - payment -> `rejected`
   - bill -> `rejected_payment`
   - warga dapat upload ulang bukti baru

---

## 6. Workflow Status

### Status periode
- `draft`
- `published`
- `closed`

### Status tagihan
- `unpaid`
- `submitted_verification`
- `paid`
- `rejected_payment`

### Status pembayaran
- `submitted`
- `verified`
- `rejected`

### Arti status periode
- `draft`: periode belum diterbitkan
- `published`: periode aktif dan tagihan berjalan
- `closed`: periode sudah ditutup

### Arti status tagihan
- `unpaid`: tagihan belum dibayar
- `submitted_verification`: warga sudah upload bukti dan menunggu verifikasi
- `paid`: tagihan lunas
- `rejected_payment`: bukti pembayaran ditolak admin

### Arti status pembayaran
- `submitted`: bukti pembayaran baru masuk
- `verified`: pembayaran valid
- `rejected`: pembayaran ditolak

---

## 7. Schema PocketBase

### Collection `iuran_types`
Tujuan: master jenis iuran.

Field:
- `code` - text
- `label` - text
- `description` - text
- `default_amount` - number
- `default_frequency` - select
- `is_active` - bool
- `sort_order` - number
- `created` - autodate
- `updated` - autodate

### Collection `iuran_periods`
Tujuan: satu periode/tagihan massal untuk jenis iuran tertentu.

Field:
- `iuran_type` - relation iuran_types
- `type_label` - text
- `title` - text
- `description` - text
- `frequency` - select
- `default_amount` - number
- `due_date` - date
- `status` - select
- `target_mode` - select
- `created_by` - relation users
- `published_at` - date
- `rt` - number
- `rw` - number
- `desa_code` - text
- `kecamatan_code` - text
- `kabupaten_code` - text
- `provinsi_code` - text
- `desa_kelurahan` - text
- `kecamatan` - text
- `kabupaten_kota` - text
- `provinsi` - text
- `created` - autodate
- `updated` - autodate

### Collection `iuran_bills`
Tujuan: tagihan aktual per KK.

Field:
- `period` - relation iuran_periods
- `iuran_type` - relation iuran_types
- `kk` - relation kartu_keluarga
- `bill_number` - text
- `title` - text
- `type_label` - text
- `kk_number` - text
- `kk_holder_name` - text
- `frequency` - text
- `amount` - number
- `status` - select
- `due_date` - date
- `payment_method` - select
- `payer_note` - text
- `submitted_by` - relation users
- `submitted_at` - date
- `verified_by` - relation users
- `verified_at` - date
- `rejection_note` - text
- `paid_at` - date
- `rt` - number
- `rw` - number
- `desa_code` - text
- `kecamatan_code` - text
- `kabupaten_code` - text
- `provinsi_code` - text
- `desa_kelurahan` - text
- `kecamatan` - text
- `kabupaten_kota` - text
- `provinsi` - text
- `created` - autodate
- `updated` - autodate

### Collection `iuran_payments`
Tujuan: record transaksi pembayaran warga/admin.

Field:
- `bill` - relation iuran_bills
- `kk` - relation kartu_keluarga
- `submitted_by` - relation users
- `method` - select
- `amount` - number
- `proof_file` - file
- `note` - text
- `review_note` - text
- `status` - select
- `submitted_at` - date
- `verified_by` - relation users
- `verified_at` - date
- `rejection_note` - text
- `created` - autodate
- `updated` - autodate

---

## 8. Aturan Sistem Penting

- Satu tagihan dibuat `per KK`.
- Satu payment selalu terkait ke satu `bill`.
- Nominal payment harus sama dengan nominal bill.
- Payment transfer tidak boleh langsung `paid`.
- Cash yang dicatat admin boleh langsung `verified`.
- Warga tidak boleh melihat tagihan KK lain.
- Admin hanya boleh mengelola iuran sesuai area scope.

---

## 9. Laporan Wajib

### Admin RT / RW
- total tagihan
- total lunas
- total tunggakan
- daftar belum bayar per periode
- pemasukan per periode
- rekap per jenis iuran

### Bentuk laporan v1
- summary card
- daftar bill belum bayar
- rekap total per periode
- rekap total per jenis iuran

---

## 10. Kebutuhan UI/UX

### Screen warga
- daftar tagihan aktif
- daftar riwayat tagihan lunas
- status chip jelas
- upload bukti transfer
- melihat catatan penolakan

### Screen admin
- tab `Tagihan`
- tab `Verifikasi`
- tab `Periode`
- tab `Jenis`
- pencarian cepat
- aksi `Catat Cash`
- aksi `Verifikasi`
- aksi `Tolak`

---

## 11. Notifikasi yang Dibutuhkan

### Untuk warga
- periode iuran baru terbit
- bukti transfer berhasil dikirim
- pembayaran diverifikasi
- pembayaran ditolak

### Untuk admin
- ada bukti transfer baru menunggu verifikasi

Catatan:
- notifikasi realtime penuh belum menjadi bagian final v1 iuran
- tetapi event ini harus disiapkan sebagai titik integrasi

---

## 12. Seed Master Jenis Iuran Saat Ini

Seed awal yang sudah ada:
- `Iuran Kebersihan`
- `Iuran Keamanan`
- `Kas Sosial`
- `Kegiatan Warga`
- `Iuran Tahunan Lingkungan`

Seed ini hanya starter, bukan daftar final mutlak.

---

## 13. Scope Implementasi Saat Ini

Sudah ada:
- collection PocketBase lengkap
- seed `iuran_types`
- admin membuat jenis iuran
- admin membuat periode iuran
- admin generate tagihan per KK
- warga upload bukti transfer
- admin verifikasi / tolak pembayaran
- admin catat pembayaran cash

Belum ada:
- export laporan iuran
- dashboard laporan iuran detail
- reminder otomatis jatuh tempo
- payment gateway untuk iuran warga
- mutasi KK terhadap tagihan lama
- denda keterlambatan
- cicilan / partial payment

---

## 14. Out of Scope V1

- denda otomatis
- cicilan
- migrasi tagihan saat KK pecah/gabung
- rekonsiliasi bank otomatis
- integrasi Midtrans untuk iuran warga
- approval multilayer di atas RW

---

## 15. Prioritas Implementasi

### Tahap 1
- schema PocketBase
- jenis iuran
- periode iuran
- generate bill per KK

### Tahap 2
- upload bukti transfer warga
- verifikasi admin
- catat cash

### Tahap 3
- laporan dan rekap
- notifikasi
- export data
