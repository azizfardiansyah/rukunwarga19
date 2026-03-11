# Prompt Standar Polish UI/UX

Tanggal pembaruan: 2026-03-11

Dokumen ini berisi prompt standar untuk memoles seluruh UI project
RukunWarga agar tampilan lebih modern, tidak terlihat usang, tetap enak
dilihat, dan konsisten dengan Material Design 3++ plus sentuhan glassmorphism
yang terkontrol.

## Tujuan

- membuat seluruh screen terasa modern, rapi, dan konsisten
- memperbaiki hierarchy visual, spacing, typography, warna, dan state UI
- mempertahankan akurasi informasi dan konteks yuridiksi
- memastikan setiap elemen yang tampil punya fungsi yang jelas
- menghindari UI hiasan yang ramai tapi miskin informasi

## Prompt Utama

Gunakan prompt ini saat melakukan polish UI/UX:

```text
Polish seluruh UI project ini agar terlihat modern, bersih, premium, dan tidak usang, dengan dasar Material Design 3++ dan sentuhan glassmorphism yang halus, fungsional, dan konsisten.

Tujuan utama:
- tingkatkan visual quality semua screen tanpa merusak flow bisnis yang sudah ada
- pastikan setiap informasi yang tampil relevan, akurat, sesuai scope user, dan tidak menyesatkan
- buat hierarchy visual yang jelas: mana informasi utama, sekunder, status, aksi, dan warning
- semua screen harus terasa satu sistem desain yang sama, bukan kumpulan layar yang acak

Aturan visual:
- gunakan Material Design 3 sebagai dasar komponen, elevation, shape, state, dan motion
- tambahkan feel "Material 3++": spacing lebih lega, surface lebih refined, card lebih intentional, iconography lebih rapi, dan status lebih mudah dipindai
- gunakan glassmorphism secara halus pada hero panel, floating action area, top summary card, filter bar, atau overlay penting
- glass effect harus tetap readable: blur ringan, border tipis transparan, surface tint terkontrol, jangan membuat teks susah dibaca
- hindari tampilan jadul seperti card abu polos, border keras, gradient murahan, shadow berlebihan, dan ikon yang tidak konsisten
- hindari efek dekoratif yang tidak punya fungsi

Aturan informasi:
- setiap text, chip, badge, summary, dan metadata harus make sense terhadap data nyata
- jangan tampilkan label, angka, status, CTA, atau badge jika datanya kosong, tidak valid, atau tidak relevan
- semua status harus akurat sesuai state backend, misalnya draft, submitted, approved, rejected, published, unpaid, paid
- semua informasi yuridiksi harus jelas saat penting, misalnya RT, RW, unit, DKM, Posyandu, atau workspace
- tampilkan informasi paling penting lebih dulu, detail sekunder di bawahnya
- empty state, loading state, error state, dan success feedback harus informatif dan tidak generik

Aturan layout:
- rapikan rhythm spacing vertikal dan horizontal agar konsisten
- perjelas struktur halaman: app bar, hero/summary, filter/search, list/content, sticky action bila perlu
- gunakan section header yang jelas pada screen yang padat data
- pada list dan detail screen, prioritaskan scanability: status, nominal, tanggal, nama, unit, dan aksi harus cepat terbaca
- tombol utama dan sekunder harus jelas prioritasnya

Aturan per komponen:
- AppBar: lebih bersih, modern, title hierarchy jelas, action tidak terlalu ramai
- Card: radius modern, padding lega, shadow lembut, border tipis bila perlu
- Chip/status badge: singkat, kontras cukup, mudah dibedakan antar status
- Form: label jelas, helper text berguna, error message spesifik
- List item: metadata penting ditata rapi, action tidak menumpuk
- Dialog/bottom sheet: padat tapi elegan, fokus ke satu keputusan utama
- FAB/action bar: terasa penting tapi tidak mengganggu

Aturan warna dan tema:
- pertahankan identitas hijau/komunitas project ini, tapi naikkan kualitas tone dan kontras
- gunakan semantic color yang jelas untuk success, warning, danger, info, pending
- jangan gunakan warna hanya untuk dekorasi; warna harus membantu memahami state

Aturan aksesibilitas:
- pastikan contrast aman
- target tap nyaman di mobile
- teks penting jangan terlalu kecil
- jangan mengandalkan warna saja untuk menyampaikan status

Aturan implementasi:
- apply ke semua screen
- pertahankan struktur route, state management, service, dan logic bisnis
- utamakan refactor visual yang reusable melalui theme, widget bersama, dan design token
- jika ada screen yang sangat padat, sederhanakan tampilan tanpa menghilangkan informasi penting

Output yang diharapkan:
- UI terasa modern, konsisten, dan enak dipakai harian
- informasi lebih mudah dipindai
- status dan aksi lebih jelas
- tidak ada elemen visual yang tampil "hiasan doang"
- semua screen terasa satu keluarga desain yang matang
```

## Prinsip Wajib

### 1. Informasi harus benar

- status wajib berasal dari state nyata
- label tombol harus sesuai aksi sebenarnya
- angka summary harus sinkron dengan data list
- data kosong tidak boleh dibuat seolah ada

### 2. Visual harus membantu keputusan

- warna, chip, dan icon harus membantu user memahami kondisi
- informasi prioritas harus langsung terlihat
- aksi utama tidak boleh tenggelam

### 3. Glassmorphism harus terkontrol

- gunakan hanya pada surface tertentu
- tetap prioritaskan readability
- jangan jadikan semua card seperti kaca
- blur dan transparency harus ringan

### 4. Material 3 tetap fondasi

- gunakan komponen Material sebagai base
- polish dilakukan lewat token, shape, spacing, tint, shadow, dan motion
- jangan membuat UI yang bertentangan dengan pola interaksi Android modern

## Standar Visual per Screen

### Dashboard

- hero section harus terasa premium, informatif, dan cepat dipindai
- summary cards harus menunjukkan angka yang benar-benar penting
- grid menu harus konsisten secara ukuran, spacing, dan hierarki
- badge role harus jelas tapi tidak norak

### List Screen

- search, filter, dan sort harus rapi dan tidak berat
- setiap list item harus punya hierarchy:
  - judul utama
  - metadata penting
  - status
  - aksi
- informasi duplikat harus dikurangi

### Detail Screen

- tampilkan ringkasan utama di atas
- status dan timeline harus jelas
- data panjang dibagi per section
- CTA utama ditempatkan dekat konteks keputusan

### Form Screen

- kelompokkan field berdasarkan konteks
- bedakan field wajib dan opsional dengan jelas
- helper text hanya muncul jika memang membantu
- formatter nominal, tanggal, dan nomor harus konsisten

### Chat dan Pengumuman

- bubble chat harus lebih ringan dan modern
- polling, voice note, file, dan system message harus punya visual berbeda
- pengumuman resmi harus terlihat lebih authoritative
- metadata pengirim, badge, dan scope harus jelas saat relevan

### Keuangan

- nominal harus sangat mudah dibaca
- status maker-checker harus terlihat jelas
- transaksi in/out harus mudah dibedakan
- publish status dan approval trail harus mudah dipahami

### Organisasi

- struktur unit, jabatan, dan masa bakti harus rapi
- membership aktif dan nonaktif harus mudah dibedakan
- relationship antar unit jangan membingungkan

## Anti-Pattern yang Harus Dihindari

- card penuh gradient tanpa hierarchy isi
- terlalu banyak warna aksen dalam satu layar
- glass effect kuat yang membuat teks kabur
- ikon campur aduk style
- tombol terlalu banyak dalam satu baris
- badge terlalu ramai
- semua informasi diberi bobot yang sama
- placeholder text yang tidak informatif
- empty state generik yang tidak menjelaskan langkah berikutnya

## Output Review yang Diharapkan dari AI

Saat AI diminta polish UI, hasil review atau implementasinya minimal harus
menjawab:

- apa masalah visual utama screen ini saat ini
- apa yang diubah pada hierarchy, spacing, card, warna, dan action
- apa yang diubah agar informasi lebih akurat dan lebih mudah dipahami
- widget atau token reusable apa yang dibuat agar konsisten di semua screen

## Checklist Hasil Polish

- tampilan lebih modern dan tidak terlihat usang
- konsisten antar screen
- readable di mobile
- status, nominal, tanggal, dan scope mudah dipindai
- CTA utama jelas
- empty/loading/error state rapi
- glassmorphism terasa premium tapi tetap fungsional
- tidak ada informasi palsu, dummy, atau dekoratif tanpa makna

