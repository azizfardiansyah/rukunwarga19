import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../features/auth/providers/auth_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final nama = user?.getStringValue('nama') ?? 'User';
    final email = user?.getStringValue('email') ?? '';
    final role = authState.role;

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        children: [
          // Profil
          Container(
            padding: const EdgeInsets.all(AppTheme.paddingLarge),
            color: AppTheme.primaryColor,
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white,
                  child: Text(
                    nama.isNotEmpty ? nama[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(nama,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                Text(email,
                    style: const TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    role.toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // Menu
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.person_outlined),
            title: const Text('Edit Profil'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Navigate to edit profile
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.lock_outlined),
            title: const Text('Ganti Password'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Change password dialog
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.info_outlined),
            title: const Text('Tentang Aplikasi'),
            subtitle: Text('Versi ${AppConstants.appVersion}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: AppConstants.appFullName,
                applicationVersion: AppConstants.appVersion,
                children: [
                  const Text('Sistem Manajemen Rukun Warga'),
                ],
              );
            },
          ),
          const Divider(height: 1),
          const SizedBox(height: 24),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: AppTheme.paddingMedium),
            child: OutlinedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Logout'),
                    content: const Text('Apakah Anda yakin ingin keluar?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Batal'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          ref.read(authProvider.notifier).logout();
                        },
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.errorColor),
                        child: const Text('Logout'),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.logout, color: AppTheme.errorColor),
              label: const Text('Logout',
                  style: TextStyle(color: AppTheme.errorColor)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.errorColor),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
