# Surat - Product & System Spec

Dokumen ini merangkum kebutuhan final untuk menu `Surat` yang sudah dibahas.

Fokus dokumen:
- alur proses pengajuan dan approval
- kebutuhan menu aplikasi
- schema PocketBase yang disarankan
- daftar final `jenis_surat`
- field umum dan field tambahan per jenis surat
- matrix approval RT dan RW
- template status workflow
- kebutuhan notifikasi, log, laporan, dan output surat

---

## 1. Prinsip Produk

- RT/RW app menerbitkan `surat pengantar`, `surat keterangan lingkungan`, atau `rekomendasi awal`.
- Dokumen legal final tetap bisa diterbitkan instansi lain seperti Kelurahan, Kecamatan, Dukcapil, KUA, atau Kepolisian.
- Flow surat harus terasa seperti workflow layanan, bukan sekadar form statis.

---

## 2. Role dan Akses

### warga
- mengajukan surat
- melihat riwayat surat
- melihat status proses
- mengunggah revisi
- mengunduh hasil surat jika selesai

### admin_rt
- menerima pengajuan surat warga dalam RT sendiri
- review data dan lampiran
- approve, reject, atau minta revisi
- meneruskan surat ke RW bila memang perlu approval lanjutan
- upload hasil surat jika final di level RT

### admin_rw / admin_rw_pro
- menerima surat eskalasi dari RT
- review final
- approve final / reject / minta revisi
- upload atau finalisasi output surat level RW

### sysadmin
- audit penuh
- bukan aktor operasional utama harian

---

## 3. Struktur Menu Surat

### Untuk warga
- `Ajukan Surat`
- `Surat Saya`
- `Detail & Status`

### Untuk admin_rt
- `Verifikasi Surat`
- `Perlu Revisi`
- `Selesai`
- `Ditolak`

### Untuk admin_rw / admin_rw_pro
- `Eskalasi Surat RW`
- `Final Approval`

Catatan UX:
- tidak perlu menu utama baru
- cukup perluas menu `Surat` menjadi workflow yang jelas

---

## 4. Alur Proses Pengajuan Surat di Aplikasi

### Flow warga
1. Warga buka menu `Surat`.
2. Warga masuk ke `Ajukan Surat`.
3. Warga memilih jenis surat.
4. App menampilkan form dinamis sesuai jenis surat.
5. Warga mengisi data dan mengunggah lampiran bila perlu.
6. Warga menekan `Kirim Pengajuan`.
7. Record masuk ke status `submitted`.
8. Warga memantau progres di `Surat Saya`.

### Flow admin RT
1. Admin RT buka `Verifikasi Surat`.
2. Admin RT review pengajuan masuk sesuai wilayah.
3. Admin RT melakukan salah satu aksi:
   - `approve`
   - `need_revision`
   - `reject`
   - `forward to RW`
4. Jika surat final cukup di RT, admin RT bisa upload output surat dan menandai `completed`.

### Flow admin RW
1. Admin RW buka `Eskalasi Surat RW`.
2. Admin RW review surat yang sudah lolos RT.
3. Admin RW melakukan salah satu aksi:
   - approve final
   - reject
   - minta revisi
4. Admin RW upload atau finalisasi surat hasil.

---

## 5. Daftar Final Jenis Surat

### Kependudukan
- `domisili`
- `pengantar_ktp`
- `pengantar_kia`
- `pengantar_skck`
- `pengantar_pindah_keluar`
- `pengantar_pindah_datang`

### Keluarga
- `pengantar_kelahiran`
- `pengantar_tambah_anggota_kk`
- `pengantar_perubahan_kk`
- `pengantar_pecah_kk`
- `pengantar_gabung_kk`
- `pengantar_nikah`

### Sosial dan pendidikan
- `sktm_pendidikan`
- `sktm_kesehatan`
- `sktm_umum`

### Usaha dan pekerjaan
- `keterangan_usaha`
- `domisili_usaha`

### Kematian
- `pengantar_kematian`
- `keterangan_kematian_lingkungan`
- `pengantar_pemakaman`
- `pengantar_ahli_waris`

### Lingkungan
- `domisili_sementara`
- `keterangan_tinggal_lingkungan`
- `keterangan_belum_menikah`
- `keterangan_janda_duda`

---

## 6. Schema PocketBase untuk Surat

### Collection `surat_requests`
Tujuan: record utama pengajuan surat.

Field:
- `warga` - relation warga
- `kk` - relation kartu_keluarga
- `jenis_surat` - select
- `category` - select
- `title` - text
- `purpose` - text
- `status` - select
- `approval_level` - select: `rt`, `rw`
- `rt` - text
- `rw` - text
- `desa_code` - text
- `kecamatan_code` - text
- `kabupaten_code` - text
- `provinsi_code` - text
- `submitted_by` - relation users
- `submitted_at` - date
- `reviewed_by_rt` - relation users
- `reviewed_at_rt` - date
- `review_note_rt` - text
- `reviewed_by_rw` - relation users
- `reviewed_at_rw` - date
- `review_note_rw` - text
- `output_number` - text
- `output_file` - file
- `finalized_at` - date
- `created` - autodate
- `updated` - autodate

### Collection `surat_attachments`
Tujuan: lampiran pengajuan.

Field:
- `request` - relation surat_requests
- `file` - file
- `label` - text
- `created` - autodate

### Collection `surat_logs`
Tujuan: audit log proses surat.

Field:
- `request` - relation surat_requests
- `actor` - relation users
- `action` - text
- `description` - text
- `created` - autodate

### Collection `surat_templates`
Opsional tapi sangat disarankan untuk output surat.

Field:
- `jenis_surat`
- `title`
- `template_body`
- `requires_rw_approval`
- `is_active`

---

## 7. Field Umum untuk Semua Surat

Semua jenis surat minimal memakai field umum berikut:
- warga pemohon
- KK terkait
- jenis surat
- kategori surat
- tujuan / keperluan
- status
- approval level
- scope wilayah
- submitter
- timestamp submit
- reviewer RT
- reviewer RW
- catatan review
- nomor surat hasil
- file output final

---

## 8. Field Tambahan per Jenis Surat

### domisili
- `alamat_domisili`
- `lama_tinggal`
- `tujuan_penggunaan`

### pengantar_ktp / pengantar_kia
- `keperluan`
- `nomor_identitas_lama` opsional

### pengantar_skck
- `keperluan_skck`
- `institusi_tujuan`

### pengantar_kelahiran
- `nama_bayi`
- `tanggal_lahir_bayi`
- `tempat_lahir_bayi`
- `nama_ayah`
- `nama_ibu`

### pengantar_tambah_anggota_kk / pengantar_perubahan_kk
- `nama_anggota_baru`
- `hubungan_keluarga`
- `alasan_perubahan`

### pengantar_pecah_kk / pengantar_gabung_kk
- `kk_asal`
- `kk_tujuan`
- `alasan`

### pengantar_nikah
- `nama_pasangan`
- `tanggal_rencana_nikah`
- `lokasi_kua_atau_tempat`

### sktm_pendidikan / sktm_kesehatan / sktm_umum
- `nama_penerima`
- `institusi_tujuan`
- `alasan_permohonan`

### keterangan_usaha / domisili_usaha
- `nama_usaha`
- `jenis_usaha`
- `alamat_usaha`
- `lama_usaha`

### pengantar_pindah_keluar / pengantar_pindah_datang
- `alamat_asal`
- `alamat_tujuan`
- `jumlah_pengikut`
- `alasan_pindah`

### pengantar_kematian / keterangan_kematian_lingkungan
- `nama_almarhum`
- `tanggal_meninggal`
- `tempat_meninggal`
- `sebab_meninggal`
- `hubungan_pelapor`

### pengantar_ahli_waris
- `nama_almarhum`
- `daftar_ahli_waris`
- `keperluan`

### pengantar_pemakaman
- `nama_almarhum`
- `lokasi_pemakaman`
- `jadwal_pemakaman`

---

## 9. Approval Matrix Surat

### Cukup approve RT
Surat internal lingkungan yang tidak perlu legalisasi berjenjang:
- `domisili_sementara`
- `keterangan_tinggal_lingkungan`
- `keterangan_belum_menikah`
- `keterangan_janda_duda`
- `keterangan_kematian_lingkungan`
- `pengantar_pemakaman`

### Harus naik ke RW
Surat yang biasanya dipakai ke instansi luar atau butuh validasi berjenjang:
- `domisili`
- `pengantar_ktp`
- `pengantar_kia`
- `pengantar_skck`
- `pengantar_kelahiran`
- `pengantar_tambah_anggota_kk`
- `pengantar_perubahan_kk`
- `pengantar_pecah_kk`
- `pengantar_gabung_kk`
- `pengantar_nikah`
- `sktm_pendidikan`
- `sktm_kesehatan`
- `sktm_umum`
- `keterangan_usaha`
- `domisili_usaha`
- `pengantar_pindah_keluar`
- `pengantar_pindah_datang`
- `pengantar_kematian`
- `pengantar_ahli_waris`

### Aturan praktis
- default surat internal: cukup RT
- default surat ke instansi luar: RT lalu RW

---

## 10. Template Status Workflow Surat

### Workflow RT only
- `draft`
- `submitted`
- `need_revision`
- `approved_rt`
- `completed`
- `rejected`

### Workflow RT ke RW
- `draft`
- `submitted`
- `need_revision`
- `approved_rt`
- `forwarded_to_rw`
- `approved_rw`
- `completed`
- `rejected`

### Arti status
- `draft`: belum dikirim
- `submitted`: sudah dikirim warga
- `need_revision`: perlu perbaikan warga
- `approved_rt`: lolos review RT
- `forwarded_to_rw`: menunggu review RW
- `approved_rw`: lolos review RW
- `completed`: surat final tersedia
- `rejected`: ditolak

---

## 11. Kebutuhan UI/UX Surat

### Screen warga
- list jenis surat
- form dinamis per jenis
- upload lampiran
- riwayat surat
- tracker status
- download hasil surat

### Screen admin
- daftar surat masuk
- filter per status
- filter per jenis surat
- detail warga dan KK
- preview lampiran
- tombol approve / revisi / tolak / forward

---

## 12. Notifikasi Surat

### warga
- surat berhasil diajukan
- surat perlu revisi
- surat disetujui RT
- surat diteruskan ke RW
- surat selesai
- surat ditolak

### admin_rt
- pengajuan surat baru masuk
- warga mengirim revisi

### admin_rw
- surat baru diteruskan dari RT

---

## 13. Pencarian, Filter, dan Laporan

### Filter
- jenis surat
- status
- periode
- warga / no KK
- RT/RW

### Laporan sederhana
- jumlah pengajuan per jenis
- surat pending
- surat perlu revisi
- surat selesai
- surat ditolak

---

## 14. Audit dan Logging

Semua aksi penting harus tercatat:
- ajukan surat
- approve RT
- reject RT
- minta revisi RT
- forward ke RW
- approve RW
- reject RW
- upload output surat

Audit minimal menyimpan:
- actor
- action
- target record
- waktu
- catatan perubahan

---

## 15. Output dan Dokumen Final

Setelah surat selesai, sistem idealnya mendukung:
- nomor surat
- file hasil surat
- tanggal finalisasi
- siapa yang memfinalkan

Untuk v1, output bisa berupa:
- file upload manual oleh admin
- atau template surat sederhana di tahap berikutnya

---

## 16. Out of Scope V1

- template DOC/PDF generator yang sangat kompleks
- tanda tangan digital tersertifikasi
- approval multi-level di atas RW
- integrasi legal document engine eksternal

---

## 17. Prioritas Implementasi

### Tahap 1
- menu surat dasar
- daftar jenis surat
- form pengajuan
- lampiran
- verifikasi RT
- status tracking

### Tahap 2
- eskalasi RW
- output surat
- export PDF/print
- log lebih lengkap

### Tahap 3
- template generator otomatis
- reminder otomatis
- dashboard laporan lanjutan
