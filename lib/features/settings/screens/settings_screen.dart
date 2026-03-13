import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../app/providers/theme_mode_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/area_access.dart';
import '../../../core/utils/error_classifier.dart';
import '../../../core/utils/formatters.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/widgets/app_surface.dart';
import '../../../shared/widgets/current_user_avatar.dart';

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
    final themeMode =
        ref.watch(themeModeProvider).asData?.value ?? ThemeMode.light;
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
    final isDarkMode = themeMode == ThemeMode.dark;
    final subscriptionSubtitle = authState.hasActiveSubscription
        ? authState.subscriptionExpiredAt != null
              ? 'Aktif sampai ${Formatters.tanggalWaktu(authState.subscriptionExpiredAt!)}'
              : 'Subscription aktif'
        : authState.requiresSubscription
        ? 'Status $subscriptionStatusLabel'
        : 'Role ini tidak membutuhkan subscription';

    final themeLabel = isDarkMode ? 'Mode Gelap aktif' : 'Mode Terang aktif';
    final themeSubtitle = isDarkMode
        ? 'Tema gelap dipakai di aplikasi untuk redupkan cahaya layar saat kerja malam.'
        : 'Tema terang dipakai di aplikasi untuk tampilan yang lebih cerah dan kontras di siang hari.';

    return Scaffold(
      body: AppPageBackground(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
        child: ListView(
          children: [
            _ProfileHero(nama: nama, email: email, roleLabel: roleLabel),
            const SizedBox(height: 14),
            // Inline summary chips row
            Row(
              children: [
                _SummaryChip(
                  label: roleLabel,
                  icon: Icons.badge_outlined,
                  tone: AppTheme.roleColor(authState.role),
                ),
                const SizedBox(width: 6),
                _SummaryChip(
                  label: _accessScopeLabel(authState.role),
                  icon: Icons.visibility_outlined,
                  tone: AppTheme.primaryColor,
                ),
                const SizedBox(width: 6),
                _SummaryChip(
                  label: subscriptionStatusLabel,
                  icon: Icons.workspace_premium_outlined,
                  tone: subscriptionColor,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SectionTitle(title: 'Akun'),
            const SizedBox(height: 8),
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
            const SizedBox(height: 14),
            _SectionTitle(title: 'Akses'),
            const SizedBox(height: 8),
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
                    title: 'Kelola Organisasi',
                    subtitle: 'Input unit organisasi dan penugasan pengurus',
                    badgeLabel: 'RW Scope',
                    badgeColor: AppTheme.primaryColor,
                    onTap: () => context.push(Routes.organizationManage),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            _SectionTitle(title: 'Aplikasi'),
            const SizedBox(height: 8),
            _ActionGroup(
              children: [
                _SettingsToggleTile(
                  icon: Icons.dark_mode_outlined,
                  title: themeLabel,
                  subtitle: themeSubtitle,
                  value: isDarkMode,
                  onChanged: (value) {
                    ref.read(themeModeProvider.notifier).toggleDarkMode(value);
                  },
                ),
                _SettingsActionTile(
                  icon: Icons.info_outlined,
                  title: 'Tentang Aplikasi',
                  subtitle: 'Versi ${AppConstants.appVersion}',
                  onTap: () {
                    showAboutDialog(
                      context: context,
                      applicationName: AppConstants.appFullName,
                      applicationVersion: AppConstants.appVersion,
                      children: [
                        const Text('Sistem Manajemen Rukun Warga'),
                        const SizedBox(height: 12),
                        const Text(
                          'Lihat Lisensi akan menampilkan lisensi paket Flutter, Riverpod, PocketBase SDK, GoRouter, notifikasi, file picker, printing, dan dependency open-source lain yang dipakai aplikasi ini.',
                        ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            showLicensePage(
                              context: context,
                              applicationName: AppConstants.appFullName,
                              applicationVersion: AppConstants.appVersion,
                            );
                          },
                          icon: const Icon(Icons.article_outlined),
                          label: const Text('Lihat Lisensi'),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: AppTheme.cardDecorationFor(
                context,
                color: AppTheme.errorColor.withValues(alpha: 0.04),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.logout_rounded,
                      color: AppTheme.errorColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Keluar',
                          style: AppTheme.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.errorColor,
                            fontSize: 13.5,
                          ),
                        ),
                        Text(
                          'Logout dari perangkat ini',
                          style: AppTheme.caption.copyWith(
                            color: AppTheme.textTertiary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 32,
                    child: OutlinedButton(
                      onPressed: () => _confirmLogout(context, ref),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.errorColor,
                        side: const BorderSide(color: AppTheme.errorColor),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Logout',
                        style: TextStyle(
                          color: AppTheme.errorColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
                  foregroundColor: Colors.white,
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
  });

  final String nama;
  final String email;
  final String roleLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.headerGradientFor(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -24,
            right: -14,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Row(
              children: [
                const CurrentUserAvatar(
                  size: 44,
                  backgroundColor: Colors.white,
                  textColor: AppTheme.primaryColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nama,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Role badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    gradient: AppTheme.warmGradient,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    roleLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
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
}

/// Compact inline chip to replace the tall summary cards
class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.icon,
    required this.tone,
  });

  final String label;
  final IconData icon;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: tone.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: tone.withValues(alpha: 0.12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: tone),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                label,
                style: AppTheme.caption.copyWith(
                  color: tone,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final titleColor = AppTheme.primaryTextFor(context);
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: AppTheme.caption.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            fontSize: 12,
            color: titleColor,
          ),
        ),
      ],
    );
  }
}

class _ActionGroup extends StatelessWidget {
  const _ActionGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecorationFor(context),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              const Divider(height: 1, indent: 56, endIndent: 12),
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
    final titleColor = AppTheme.primaryTextFor(context);
    final subtitleColor = AppTheme.tertiaryTextFor(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10),
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
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: AppTheme.caption.copyWith(
                        color: subtitleColor,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if ((badgeLabel ?? '').isNotEmpty) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: (badgeColor ?? AppTheme.primaryColor).withValues(
                      alpha: 0.10,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badgeLabel!,
                    style: AppTheme.caption.copyWith(
                      color: badgeColor ?? AppTheme.primaryColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: subtitleColor, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsToggleTile extends StatelessWidget {
  const _SettingsToggleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final titleColor = AppTheme.primaryTextFor(context);
    final subtitleColor = AppTheme.tertiaryTextFor(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppTheme.accentColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppTheme.accentColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: AppTheme.caption.copyWith(
                    color: subtitleColor,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
