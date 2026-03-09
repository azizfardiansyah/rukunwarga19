import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/role_management_service.dart';
import '../../../core/utils/error_classifier.dart';
import '../../../features/auth/providers/auth_provider.dart';

class RoleRequestScreen extends ConsumerStatefulWidget {
  const RoleRequestScreen({super.key});

  @override
  ConsumerState<RoleRequestScreen> createState() => _RoleRequestScreenState();
}

class _RoleRequestScreenState extends ConsumerState<RoleRequestScreen> {
  bool _isSubmitting = false;

  Future<void> _showSuccessNotice() async {
    var autoCloseScheduled = false;

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'unsubscribe-success',
      barrierColor: Colors.black.withValues(alpha: 0.28),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        if (!autoCloseScheduled) {
          autoCloseScheduled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Future<void>.delayed(const Duration(milliseconds: 1600), () {
              if (!dialogContext.mounted) {
                return;
              }
              final navigator = Navigator.of(
                dialogContext,
                rootNavigator: true,
              );
              if (navigator.canPop()) {
                navigator.pop();
              }
            });
          });
        }

        return Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.paddingLarge),
            child: Material(
              color: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 340),
                padding: const EdgeInsets.all(AppTheme.paddingLarge),
                decoration: BoxDecoration(
                  gradient: AppTheme.headerGradient,
                  borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryDark.withValues(alpha: 0.24),
                      blurRadius: 28,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 74,
                      height: 74,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.verified_rounded,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Unsubscribe Berhasil',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Akun Anda sudah kembali menjadi Warga. Mengarahkan ke dashboard utama.',
                      textAlign: TextAlign.center,
                      style: AppTheme.bodyMedium.copyWith(
                        color: Colors.white.withValues(alpha: 0.88),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );

        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _unsubscribe() async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Unsubscribe'),
            content: const Text(
              'Aksi ini akan langsung menurunkan akun Anda ke role Warga dan menonaktifkan subscription admin. Lanjutkan?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Ya, Unsubscribe'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref.read(roleManagementServiceProvider).unsubscribeCurrentUser();
      if (!mounted) {
        return;
      }

      await _showSuccessNotice();
      if (!mounted) {
        return;
      }

      await ref.read(authProvider.notifier).refreshAuth();
      if (!mounted) {
        return;
      }

      context.go(Routes.dashboard);
    } catch (e) {
      if (!mounted) {
        return;
      }
      ErrorClassifier.showErrorSnackBar(context, e);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    if (!AppConstants.canRequestUnsubscribe(auth.role)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Unsubscribe')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(AppTheme.paddingLarge),
            child: Text(
              'Role saat ini tidak membutuhkan proses unsubscribe.',
              style: AppTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Unsubscribe')),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.paddingMedium),
        children: [
          AppTheme.glassContainer(
            opacity: 0.78,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Role Saat Ini', style: AppTheme.heading3),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    AppConstants.roleLabel(auth.role),
                    style: AppTheme.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Begitu unsubscribe dijalankan, akun langsung kembali ke role Warga tanpa review sysadmin.',
                  style: AppTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppTheme.glassContainer(
            opacity: 0.76,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dampak Unsubscribe', style: AppTheme.heading3),
                const SizedBox(height: 12),
                _impactItem('Role berubah menjadi Warga'),
                _impactItem('Subscription admin langsung dinonaktifkan'),
                _impactItem('Akses fitur premium admin langsung dicabut'),
                if (auth.subscriptionExpiredAt != null)
                  _impactItem(
                    'Masa aktif sebelumnya tidak dipakai lagi setelah unsubscribe',
                  ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _unsubscribe,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.person_off_rounded),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.errorColor,
                    ),
                    label: const Text('Unsubscribe Sekarang'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _impactItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              color: AppTheme.errorColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Icon(
              Icons.remove_rounded,
              size: 16,
              color: AppTheme.errorColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: AppTheme.bodySmall)),
        ],
      ),
    );
  }
}
