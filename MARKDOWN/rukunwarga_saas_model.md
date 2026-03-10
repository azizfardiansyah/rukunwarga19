# RukunWarga SaaS Model

## Overview

RukunWarga adalah aplikasi manajemen komunitas berbasis **Software as a
Service (SaaS)** yang ditujukan untuk pengelolaan data warga, kartu
keluarga, dokumen, iuran, dan komunikasi di tingkat RT/RW dan iklan.

Aplikasi ini menggunakan pendekatan:

-   **Freemium untuk warga**
-   **Subscription untuk pengurus RT/RW**

Target utama monetisasi adalah **Admin RW** yang membutuhkan akses penuh
terhadap data wilayahnya.

------------------------------------------------------------------------

# Konsep SaaS

**Software as a Service (SaaS)** adalah model bisnis dimana software
digunakan melalui internet dengan sistem **langganan (subscription)**.

User tidak membeli aplikasi, tetapi **membayar untuk menggunakan layanan
software**.

Karakteristik SaaS:

-   berbasis cloud
-   pembayaran bulanan atau tahunan
-   update software otomatis
-   tidak perlu instalasi server sendiri

------------------------------------------------------------------------

# Target Pengguna

## 1. Warga

Fungsi utama:

-   melihat data pribadi
-   melihat data KK
-   upload dokumen
-   menerima pengumuman
-   komunikasi dengan pengurus

Model:

    Free

Tujuan:

-   meningkatkan adopsi aplikasi
-   membuat database warga lengkap

------------------------------------------------------------------------

## 2. Admin RT

Pengurus tingkat RT.

Akses:

-   data warga dalam RT
-   verifikasi dokumen
-   pengumuman RT
-   laporan sederhana

Model:

    Subscription

------------------------------------------------------------------------

## 3. Admin RW

Pengurus tingkat RW.

Ini adalah **target monetisasi utama**.

Akses:

-   seluruh data warga
-   seluruh data KK
-   dashboard demografi
-   statistik wilayah
-   laporan iuran
-   export laporan

------------------------------------------------------------------------

# Paket Harga

## Free (Warga)

Harga:

    Rp0

Fitur:

-   profil warga
-   lihat KK sendiri
-   upload dokumen
-   chat pengurus
-   pengumuman RW

------------------------------------------------------------------------

## Admin RT

Harga:

    Rp30.000 / bulan

Fitur:

-   data warga RT
-   verifikasi dokumen
-   pengumuman RT
-   laporan RT

------------------------------------------------------------------------

## Admin RW

Harga:

    Rp100.000 / bulan

Fitur:

-   akses semua data warga
-   akses semua KK
-   dashboard statistik
-   laporan iuran
-   export data

------------------------------------------------------------------------

## RW Pro

Harga:

    Rp250.000 / bulan

Fitur tambahan:

-   OCR scan KK
-   parsing otomatis anggota keluarga
-   laporan PDF otomatis
-   arsip surat digital
-   integrasi pembayaran iuran

------------------------------------------------------------------------

# Value Produk untuk RW

Dashboard yang tersedia untuk RW:

-   total warga
-   total kartu keluarga
-   statistik usia
-   statistik pekerjaan
-   statistik pendidikan
-   jumlah anak
-   jumlah lansia
-   jumlah rumah
-   jumlah pendatang

Dashboard ini membantu:

-   laporan ke kelurahan
-   data sensus wilayah
-   pengelolaan bantuan sosial
-   monitoring iuran

------------------------------------------------------------------------

# Model Revenue

Contoh perhitungan:

100 RW × Rp100.000 = Rp10.000.000 / bulan

Jika berkembang:

1000 RW × Rp100.000 = Rp100.000.000 / bulan

Pendapatan bersifat **recurring revenue** (berulang setiap bulan).

------------------------------------------------------------------------

# Strategi Pertumbuhan (Growth Strategy)

Pendekatan yang digunakan:

**Bottom-up adoption**

Urutan adopsi:

Warga → RT → RW

Strategi:

1.  Warga menggunakan aplikasi gratis.
2.  Data warga dan KK terkumpul.
3.  Pengurus RW melihat manfaat dashboard.
4.  RW berlangganan untuk akses penuh.

------------------------------------------------------------------------

# Sistem Subscription

Field tambahan pada collection `users`:

-   role
-   subscription_plan
-   subscription_expired

Contoh data:

role: admin_rw\
subscription_plan: rw_basic\
subscription_expired: 2026-04-01

------------------------------------------------------------------------

# Logic Akses Fitur

Contoh logika:

if role == admin_rw\
cek subscription\
jika aktif → buka dashboard\
jika expired → tampilkan halaman upgrade

------------------------------------------------------------------------

# Fitur yang Dikunci (Paywall)

Fitur berikut hanya tersedia untuk user berlangganan:

-   akses data warga seluruh RW
-   akses data KK seluruh RW
-   dashboard statistik
-   export laporan
-   laporan iuran

------------------------------------------------------------------------

# Keunggulan Model SaaS

-   pendapatan stabil
-   update fitur tanpa instalasi ulang
-   data tersentralisasi
-   scalable ke banyak wilayah

------------------------------------------------------------------------

# Visi Produk

Menjadi **platform manajemen komunitas digital untuk RT/RW di
Indonesia** yang memudahkan:

-   administrasi warga
-   pengelolaan dokumen
-   komunikasi warga
-   laporan wilayah
-   transparansi iuran
