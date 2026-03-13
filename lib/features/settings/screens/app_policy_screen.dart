import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../shared/widgets/app_surface.dart';

class AppPolicyScreen extends StatelessWidget {
  const AppPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sections = <({String title, String body})>[
      (
        title: 'Tujuan Penggunaan',
        body:
            'Aplikasi ini dipakai untuk membantu operasional lingkungan seperti pendataan warga, pengelolaan KK, surat, dokumen, iuran, komunikasi, dan organisasi pengurus.',
      ),
      (
        title: 'Akun & Akses',
        body:
            'Setiap akun harus dipakai oleh pemiliknya sendiri. Hak akses admin, RT, RW, atau warga harus digunakan sesuai tugas, tidak boleh dipinjamkan, dan tidak boleh dipakai untuk melihat atau mengubah data di luar wewenang.',
      ),
      (
        title: 'Data Warga',
        body:
            'Data yang dimasukkan harus benar, relevan, dan diperbarui jika ada perubahan. Pengurus bertanggung jawab menjaga agar data warga, KK, foto, dan dokumen tidak diisi asal-asalan.',
      ),
      (
        title: 'Dokumen, Foto, dan Lampiran',
        body:
            'File yang diunggah harus berhubungan langsung dengan kebutuhan administrasi. Hindari mengunggah file pribadi yang tidak relevan, file palsu, atau konten yang melanggar privasi warga lain.',
      ),
      (
        title: 'Iuran & Transparansi',
        body:
            'Tagihan, verifikasi, dan publikasi kas harus dikelola secara jujur. Data pembayaran yang sudah diverifikasi harus bisa dipertanggungjawabkan agar laporan dan transparansi ke warga tetap dipercaya.',
      ),
      (
        title: 'Pengumuman & Chat',
        body:
            'Gunakan fitur komunikasi untuk koordinasi kerja, informasi lingkungan, dan pengumuman resmi. Hindari spam, ujaran merendahkan, fitnah, atau penyebaran informasi yang belum jelas kebenarannya.',
      ),
      (
        title: 'Privasi & Keamanan',
        body:
            'Jaga kerahasiaan data warga dan jangan menyebarkannya di luar kebutuhan operasional. Password harus dijaga, perangkat sebaiknya dikunci, dan logout jika perangkat dipakai bergantian.',
      ),
      (
        title: 'Perubahan Sistem',
        body:
            'Aplikasi dapat diperbarui dari waktu ke waktu untuk memperbaiki bug, menambah fitur, atau memperketat aturan penggunaan. Pengguna diharapkan menyesuaikan diri dengan perubahan yang diterapkan.',
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('View Lisensi')),
      body: AppPageBackground(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        child: ListView(
          children: [
            AppSurfaceCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ringkasan Aturan & Kebijakan',
                    style: AppTheme.heading4.copyWith(
                      color: AppTheme.primaryTextFor(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Halaman ini menjelaskan aturan penggunaan aplikasi dalam bahasa yang lebih mudah dipahami. Tujuannya agar pengurus dan warga tahu batas penggunaan sistem secara sehat, aman, dan profesional.',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.secondaryTextFor(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            for (var i = 0; i < sections.length; i++) ...[
              AppSurfaceCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sections[i].title,
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.primaryTextFor(context),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      sections[i].body,
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.secondaryTextFor(context),
                      ),
                    ),
                  ],
                ),
              ),
              if (i != sections.length - 1) const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}
