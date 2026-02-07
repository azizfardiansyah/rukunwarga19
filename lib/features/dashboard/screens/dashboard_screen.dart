import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../features/auth/providers/auth_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final userName = authState.user?.getStringValue('nama') ?? 'User';
    final role = authState.role;

    return Scaffold(
      appBar: AppBar(
        title: const Text('RW 19'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push(Routes.notifikasi),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Greeting
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.paddingMedium),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppTheme.primaryColor,
                      child: Text(
                        userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Selamat datang,', style: AppTheme.bodySmall),
                          Text(userName, style: AppTheme.heading3),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.roleColor(role),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              role.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Quick Stats
            Text('Statistik', style: AppTheme.heading3),
            const SizedBox(height: 8),
            Row(
              children: [
                _StatCard(
                  icon: Icons.people,
                  label: 'Warga',
                  value: '-',
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 8),
                _StatCard(
                  icon: Icons.family_restroom,
                  label: 'KK',
                  value: '-',
                  color: AppTheme.secondaryColor,
                ),
                const SizedBox(width: 8),
                _StatCard(
                  icon: Icons.description,
                  label: 'Surat',
                  value: '-',
                  color: AppTheme.accentColor,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Menu Grid
            Text('Menu', style: AppTheme.heading3),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [
                _MenuCard(
                  icon: Icons.people,
                  label: 'Data Warga',
                  onTap: () => context.go(Routes.warga),
                ),
                _MenuCard(
                  icon: Icons.family_restroom,
                  label: 'Kartu Keluarga',
                  onTap: () => context.push(Routes.kartuKeluarga),
                ),
                _MenuCard(
                  icon: Icons.badge,
                  label: 'Dokumen',
                  onTap: () => context.push(Routes.dokumen),
                ),
                _MenuCard(
                  icon: Icons.description,
                  label: 'Surat',
                  onTap: () => context.push(Routes.surat),
                ),
                _MenuCard(
                  icon: Icons.payments,
                  label: 'Iuran',
                  onTap: () => context.push(Routes.iuran),
                ),
                _MenuCard(
                  icon: Icons.campaign,
                  label: 'Pengumuman',
                  onTap: () => context.push(Routes.announcements),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 4),
              Text(value,
                  style: AppTheme.heading2.copyWith(color: color)),
              Text(label, style: AppTheme.caption),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: AppTheme.primaryColor),
              const SizedBox(height: 8),
              Text(
                label,
                style: AppTheme.bodySmall,
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
