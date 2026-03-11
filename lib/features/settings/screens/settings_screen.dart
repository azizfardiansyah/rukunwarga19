import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/area_access.dart';
import '../../../core/utils/error_classifier.dart';
import '../../../core/utils/formatters.dart';
import '../../../features/auth/providers/auth_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _openEditWarga(BuildContext context, WidgetRef ref) async {
    final auth = ref.read(authProvider);
    if (auth.user == null) {
      return;
    }

    try {
      final access = await resolveAreaAccessContext(auth);
      if (!context.mounted) {
        return;
      }

      final wargaId = access.wargaId ?? '';
      final kkId = access.kkId ?? '';

      if (wargaId.isNotEmpty) {
        await context.push('${Routes.wargaForm}?id=$wargaId');
        return;
      }

      if (kkId.isNotEmpty) {
        await context.push('${Routes.wargaForm}?noKk=$kkId');
        return;
      }

      await context.push(Routes.wargaForm);
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ErrorClassifier.showErrorSnackBar(context, error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final nama = _displayName(user);
    final email = user?.getStringValue('email') ?? '';
    final roleLabel = AppConstants.roleLabel(authState.role);
    final isSysadmin = authState.isSysadmin;
    final canOpenOrganization =
        authState.isSysadmin || authState.hasRwWideAccess;
    final canSelfSubscribe = AppConstants.canSelfSubscribe(authState.role);
    final canRequestUnsubscribe = AppConstants.canRequestUnsubscribe(
      authState.role,
    );
    final effectiveSubscriptionStatus = authState.effectiveSubscriptionStatus;
    final subscriptionStatusLabel = authState.requiresSubscription
        ? AppConstants.subscriptionStatusLabel(effectiveSubscriptionStatus)
        : canSelfSubscribe
        ? 'Bisa upgrade'
        : 'Tidak tersedia';
    final subscriptionColor = _subscriptionColor(effectiveSubscriptionStatus);
    final subscriptionSubtitle = authState.hasActiveSubscription
        ? authState.subscriptionExpiredAt != null
              ? 'Aktif sampai ${Formatters.tanggalWaktu(authState.subscriptionExpiredAt!)}'
              : 'Subscription aktif'
        : authState.requiresSubscription
        ? 'Status $subscriptionStatusLabel'
        : 'Role ini tidak membutuhkan subscription';

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.paddingMedium,
          AppTheme.paddingMedium,
          AppTheme.paddingMedium,
          AppTheme.paddingLarge,
        ),
        children: [
          _ProfileHero(
            nama: nama,
            email: email,
            roleLabel: roleLabel,
            subscriptionLabel: subscriptionStatusLabel,
            subscriptionColor: subscriptionColor,
            requiresSubscription: authState.requiresSubscription,
            hasActiveSubscription: authState.hasActiveSubscription,
          ),
          const SizedBox(height: 18),
          _SectionTitle(title: 'Ringkasan'),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: _SummaryCard(
                      title: 'Role',
                      value: roleLabel,
                      icon: Icons.badge_outlined,
                      tone: AppTheme.roleColor(authState.role),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _SummaryCard(
                      title: 'Akses',
                      value: _accessScopeLabel(authState.role),
                      icon: Icons.visibility_outlined,
                      tone: AppTheme.primaryColor,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _SummaryCard(
                      title: 'Subscription',
                      value: subscriptionStatusLabel,
                      icon: Icons.workspace_premium_outlined,
                      tone: subscriptionColor,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _SummaryCard(
                      title: 'Akun',
                      value: authState.isAuthenticated ? 'Aktif' : 'Offline',
                      icon: Icons.verified_user_outlined,
                      tone: AppTheme.successColor,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 22),
          _SectionTitle(title: 'Akun'),
          const SizedBox(height: 10),
          _ActionGroup(
            children: [
              _SettingsActionTile(
                icon: Icons.person_outlined,
                title: 'Edit Profil',
                subtitle: 'Kelola data profil dan identitas akun',
                onTap: () => _openEditWarga(context, ref),
              ),
              _SettingsActionTile(
                icon: Icons.lock_outlined,
                title: 'Ganti Password',
                subtitle: 'Perbarui password untuk keamanan akun',
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SectionTitle(title: 'Akses'),
          const SizedBox(height: 10),
          _ActionGroup(
            children: [
              _SettingsActionTile(
                icon: Icons.workspace_premium_outlined,
                title: 'Subscription & Pembayaran',
                subtitle: canSelfSubscribe
                    ? authState.role == AppConstants.roleWarga
                          ? 'Pilih role admin dan bayar untuk aktivasi akses premium'
                          : subscriptionSubtitle
                    : 'Role ini tidak memakai checkout subscription',
                badgeLabel: subscriptionStatusLabel,
                badgeColor: canSelfSubscribe && authState.requiresSubscription
                    ? subscriptionColor
                    : AppTheme.primaryColor,
                onTap: () => context.push(Routes.subscription),
              ),
              if (canRequestUnsubscribe)
                _SettingsActionTile(
                  icon: Icons.person_off_outlined,
                  title: 'Unsubscribe',
                  subtitle:
                      'Langsung kembali ke role Warga dan nonaktifkan akses admin',
                  onTap: () => context.push(Routes.roleRequests),
                ),
              if (isSysadmin)
                _SettingsActionTile(
                  icon: Icons.admin_panel_settings_outlined,
                  title: 'Manajemen User & Role',
                  subtitle:
                      'Review pengajuan, ubah role, dan kelola subscription',
                  badgeLabel: 'Sysadmin',
                  badgeColor: AppTheme.primaryDark,
                  onTap: () => context.push(Routes.userManagement),
                ),
              if (canOpenOrganization)
                _SettingsActionTile(
                  icon: Icons.account_tree_outlined,
                  title: 'Organisasi & Pengurus',
                  subtitle:
                      'Kelola workspace, unit organisasi, dan penugasan jabatan',
                  badgeLabel: 'RW Scope',
                  badgeColor: AppTheme.primaryColor,
                  onTap: () => context.push(Routes.organization),
                ),
            ],
          ),
          const SizedBox(height: 18),
          _SectionTitle(title: 'Aplikasi'),
          const SizedBox(height: 10),
          _ActionGroup(
            children: [
              _SettingsActionTile(
                icon: Icons.info_outlined,
                title: 'Tentang Aplikasi',
                subtitle: 'Versi ${AppConstants.appVersion}',
                onTap: () {
                  showAboutDialog(
                    context: context,
                    applicationName: AppConstants.appFullName,
                    applicationVersion: AppConstants.appVersion,
                    children: const [Text('Sistem Manajemen Rukun Warga')],
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(AppTheme.paddingMedium),
            decoration: AppTheme.cardDecoration(
              color: AppTheme.errorColor.withValues(alpha: 0.04),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.logout_rounded, color: AppTheme.errorColor),
                    const SizedBox(width: 10),
                    Text(
                      'Keluar dari perangkat ini',
                      style: AppTheme.bodyLarge.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.errorColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Gunakan ini jika Anda selesai memakai aplikasi di perangkat saat ini.',
                  style: AppTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmLogout(context, ref),
                    icon: const Icon(Icons.logout, color: AppTheme.errorColor),
                    label: const Text(
                      'Logout',
                      style: TextStyle(color: AppTheme.errorColor),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.errorColor),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _displayName(dynamic user) {
    final nama = user?.getStringValue('nama') ?? '';
    if (nama.isNotEmpty) {
      return nama;
    }

    final name = user?.getStringValue('name') ?? '';
    if (name.isNotEmpty) {
      return name;
    }

    final email = user?.getStringValue('email') ?? '';
    if (email.isNotEmpty) {
      return email.split('@').first;
    }

    return 'User';
  }

  static String _accessScopeLabel(String role) {
    final normalizedRole = AppConstants.normalizeRole(role);

    if (AppConstants.isSysadminRole(normalizedRole)) {
      return 'Semua wilayah';
    }
    if (AppConstants.hasRwWideAccess(normalizedRole)) {
      return 'Lingkup RW';
    }
    if (normalizedRole == AppConstants.roleAdminRt) {
      return 'Lingkup RT';
    }

    return 'Akses warga';
  }

  static Color _subscriptionColor(String status) {
    switch (status) {
      case AppConstants.subscriptionStatusActive:
        return AppTheme.successColor;
      case AppConstants.subscriptionStatusExpired:
        return AppTheme.errorColor;
      case AppConstants.subscriptionStatusInactive:
      default:
        return AppTheme.warningColor;
    }
  }

  static Future<void> _confirmLogout(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Logout'),
            content: const Text('Apakah Anda yakin ingin keluar?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.errorColor,
                ),
                child: const Text('Logout'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || !context.mounted) {
      return;
    }

    ref.read(authProvider.notifier).logout();
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.nama,
    required this.email,
    required this.roleLabel,
    required this.subscriptionLabel,
    required this.subscriptionColor,
    required this.requiresSubscription,
    required this.hasActiveSubscription,
  });

  final String nama;
  final String email;
  final String roleLabel;
  final String subscriptionLabel;
  final Color subscriptionColor;
  final bool requiresSubscription;
  final bool hasActiveSubscription;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.headerGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -32,
            right: -18,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -26,
            left: -12,
            child: Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppTheme.paddingLarge),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white,
                      child: Text(
                        nama.isNotEmpty ? nama[0].toUpperCase() : '?',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nama,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            email,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.82),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _HeroBadge(
                      label: roleLabel,
                      background: Colors.white.withValues(alpha: 0.18),
                      foreground: Colors.white,
                    ),
                    _HeroBadge(
                      label: subscriptionLabel,
                      background: subscriptionColor.withValues(alpha: 0.2),
                      foreground: Colors.white,
                    ),
                    _HeroBadge(
                      label: requiresSubscription
                          ? (hasActiveSubscription
                                ? 'Akses premium aktif'
                                : 'Perlu aktivasi')
                          : 'Akses standar',
                      background: Colors.white.withValues(alpha: 0.14),
                      foreground: Colors.white,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.tone,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.paddingMedium),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: tone),
          ),
          const SizedBox(height: 12),
          Text(title, style: AppTheme.caption),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.w800),
    );
  }
}

class _ActionGroup extends StatelessWidget {
  const _ActionGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecoration(),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              const Divider(height: 1, indent: 68, endIndent: 16),
          ],
        ],
      ),
    );
  }
}

class _SettingsActionTile extends StatelessWidget {
  const _SettingsActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badgeLabel,
    this.badgeColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? badgeLabel;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.paddingMedium,
            vertical: 14,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppTheme.primaryColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: AppTheme.bodyMedium.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if ((badgeLabel ?? '').isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: (badgeColor ?? AppTheme.primaryColor)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              badgeLabel!,
                              style: AppTheme.caption.copyWith(
                                color: badgeColor ?? AppTheme.primaryColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle, style: AppTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTheme.caption.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
