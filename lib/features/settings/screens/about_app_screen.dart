import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/app_surface.dart';

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final menus = <({IconData icon, String title, String description})>[
      (
        icon: Icons.dashboard_customize_outlined,
        title: 'Dashboard',
        description:
            'Pusat ringkasan cepat untuk melihat kondisi warga, KK, surat, dokumen, iuran, dan prioritas kerja harian.',
      ),
      (
        icon: Icons.people_alt_outlined,
        title: 'Data Warga & KK',
        description:
            'Dipakai untuk mengelola identitas warga, komposisi keluarga, alamat, kontak, dan relasi ke akun pengguna.',
      ),
      (
        icon: Icons.description_outlined,
        title: 'Dokumen & Surat',
        description:
            'Membantu admin menyimpan dokumen warga, memantau pengajuan, dan memproses surat pengantar sampai selesai.',
      ),
      (
        icon: Icons.payments_outlined,
        title: 'Iuran & Keuangan',
        description:
            'Mengelola tagihan iuran, verifikasi pembayaran, ledger kas, dan publikasi transparansi ke warga.',
      ),
      (
        icon: Icons.campaign_outlined,
        title: 'Pengumuman & Chat',
        description:
            'Untuk komunikasi cepat, publikasi informasi lingkungan, koordinasi pengurus, dan diskusi internal.',
      ),
      (
        icon: Icons.account_tree_outlined,
        title: 'Organisasi & Settings',
        description:
            'Mengatur struktur pengurus, akses unit, profil akun, password, tema, subscription, dan preferensi aplikasi.',
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Tentang Aplikasi')),
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
                    AppConstants.appFullName,
                    style: AppTheme.heading4.copyWith(
                      color: AppTheme.primaryTextFor(context),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Versi ${AppConstants.appVersion}',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Aplikasi ini membantu pengurus RW, RT, dan warga mengelola operasional lingkungan dalam satu tempat. Fokus utamanya adalah data warga, administrasi, iuran, komunikasi, dan transparansi kerja pengurus.',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.secondaryTextFor(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            AppSurfaceCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Menu Utama',
                    style: AppTheme.heading4.copyWith(
                      color: AppTheme.primaryTextFor(context),
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (var i = 0; i < menus.length; i++) ...[
                    _MenuExplainTile(
                      icon: menus[i].icon,
                      title: menus[i].title,
                      description: menus[i].description,
                    ),
                    if (i != menus.length - 1)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Divider(height: 1),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuExplainTile extends StatelessWidget {
  const _MenuExplainTile({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppTheme.primaryColor, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.primaryTextFor(context),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.secondaryTextFor(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
