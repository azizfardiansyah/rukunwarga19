import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/error_classifier.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool? _obscureConfirmPassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _namaController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await ref
          .read(authProvider.notifier)
          .register(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            passwordConfirm: _confirmPasswordController.text,
            name: _namaController.text.trim(),
            role: AppConstants.roleWarga,
          );
    } catch (e) {
      if (mounted) {
        ErrorClassifier.showErrorSnackBar(context, e);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final obscureConfirmPassword = _obscureConfirmPassword ?? true;
    final heroGradient = AppTheme.headerGradientFor(context);
    final subtitleColor = Colors.white.withValues(alpha: 0.82);
    final isDark = AppTheme.isDark(context);

    // Form container colors for dark mode support
    final formBgColor = isDark 
        ? const Color(0xFF152238) 
        : Colors.white.withValues(alpha: 0.95);
    final formBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.4);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: heroGradient),
        child: Stack(
          children: [
            Positioned(
              top: -60,
              right: -30,
              child: _AuthGlow(
                size: 180,
                color: AppTheme.accentColor.withValues(alpha: 0.22),
              ),
            ),
            Positioned(
              top: 180,
              left: -48,
              child: _AuthGlow(
                size: 140,
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
            Positioned(
              bottom: -32,
              right: 36,
              child: _AuthGlow(
                size: 160,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppTheme.paddingLarge),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => context.go(Routes.login),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusXLarge,
                                ),
                              ),
                            ),
                            icon: const Icon(
                              Iconsax.arrow_left_2,
                              size: 18,
                            ),
                            label: const Text('Kembali'),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Container(
                          width: 84,
                          height: 84,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.24),
                            ),
                          ),
                          child: const Icon(
                            Iconsax.user_add,
                            size: 42,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Daftar Akun Warga',
                          style: AppTheme.heading1.copyWith(
                            color: Colors.white,
                            fontSize: 31,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Buat akun warga untuk mulai mengakses layanan, pengajuan surat, dan data keluarga.',
                          style: AppTheme.bodySmall.copyWith(
                            color: subtitleColor,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 28),
                        // Form card with dark mode support
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: formBgColor,
                                borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
                                border: Border.all(color: formBorderColor),
                                boxShadow: isDark ? null : [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 24,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Lengkapi data akun',
                                  style: AppTheme.heading3.copyWith(
                                    color: isDark ? Colors.white : AppTheme.primaryTextFor(context),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Isi data akun utama lebih dulu. Pengaturan peran dan wilayah bisa dilengkapi setelah akun aktif.',
                                  style: AppTheme.bodySmall.copyWith(
                                    color: isDark 
                                        ? Colors.white.withValues(alpha: 0.7) 
                                        : AppTheme.secondaryTextFor(context),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 18),
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? AppTheme.accentColor.withValues(alpha: 0.15)
                                        : AppTheme.accentColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusMedium,
                                    ),
                                    border: Border.all(
                                      color: AppTheme.accentColor.withValues(
                                        alpha: isDark ? 0.35 : 0.28,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Iconsax.verify,
                                        size: 20,
                                        color: isDark 
                                            ? AppTheme.accentColor 
                                            : AppTheme.primaryDark,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'Pendaftaran publik akan membuat akun warga terlebih dahulu. Akses fitur pengurus bisa dibuka nanti sesuai paket langganan dan wilayah yang dikelola.',
                                          style: AppTheme.bodySmall.copyWith(
                                            color: isDark 
                                                ? Colors.white.withValues(alpha: 0.9)
                                                : AppTheme.primaryTextFor(context),
                                            height: 1.45,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                                TextFormField(
                                  controller: _namaController,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [AutofillHints.name],
                                  style: TextStyle(
                                    color: isDark ? Colors.white : null,
                                  ),
                                  decoration: _fieldDecoration(
                                    context,
                                    label: 'Nama Lengkap',
                                    icon: Iconsax.user,
                                    isDark: isDark,
                                  ),
                                  validator: (value) =>
                                      value == null || value.trim().isEmpty
                                      ? 'Nama wajib diisi'
                                      : null,
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [AutofillHints.email],
                                  style: TextStyle(
                                    color: isDark ? Colors.white : null,
                                  ),
                                  decoration: _fieldDecoration(
                                    context,
                                    label: 'Email',
                                    icon: Iconsax.sms,
                                    isDark: isDark,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Email wajib diisi';
                                    }
                                    if (!value.contains('@')) {
                                      return 'Email tidak valid';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [
                                    AutofillHints.newPassword,
                                  ],
                                  style: TextStyle(
                                    color: isDark ? Colors.white : null,
                                  ),
                                  decoration: _fieldDecoration(
                                    context,
                                    label: 'Password',
                                    icon: Iconsax.lock,
                                    isDark: isDark,
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Iconsax.eye_slash
                                            : Iconsax.eye,
                                        color: isDark 
                                            ? Colors.white.withValues(alpha: 0.6)
                                            : null,
                                      ),
                                      onPressed: () => setState(
                                        () => _obscurePassword =
                                            !_obscurePassword,
                                      ),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Password wajib diisi';
                                    }
                                    if (value.length < 8) {
                                      return 'Password minimal 8 karakter';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _confirmPasswordController,
                                  obscureText: obscureConfirmPassword,
                                  textInputAction: TextInputAction.done,
                                  autofillHints: const [
                                    AutofillHints.newPassword,
                                  ],
                                  style: TextStyle(
                                    color: isDark ? Colors.white : null,
                                  ),
                                  onFieldSubmitted: (_) {
                                    if (!_isLoading) {
                                      _register();
                                    }
                                  },
                                  decoration: _fieldDecoration(
                                    context,
                                    label: 'Konfirmasi Password',
                                    icon: Iconsax.lock_1,
                                    isDark: isDark,
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        obscureConfirmPassword
                                            ? Iconsax.eye_slash
                                            : Iconsax.eye,
                                        color: isDark 
                                            ? Colors.white.withValues(alpha: 0.6)
                                            : null,
                                      ),
                                      onPressed: () => setState(
                                        () => _obscureConfirmPassword =
                                            !obscureConfirmPassword,
                                      ),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Konfirmasi password wajib diisi';
                                    }
                                    if (value != _passwordController.text) {
                                      return 'Password tidak sama';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 24),
                                SizedBox(
                                  height: 54,
                                  child: FilledButton(
                                    onPressed: _isLoading ? null : _register,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppTheme.primaryColor,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            height: 22,
                                            width: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Text(
                                            'Daftar',
                                            style: AppTheme.buttonText.copyWith(
                                              fontSize: 15,
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Sudah punya akun? ',
                                      style: AppTheme.bodySmall.copyWith(
                                        color: isDark 
                                            ? Colors.white.withValues(alpha: 0.7) 
                                            : AppTheme.secondaryTextFor(context),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => context.go(Routes.login),
                                      style: TextButton.styleFrom(
                                        foregroundColor: isDark 
                                            ? AppTheme.primaryLight 
                                            : AppTheme.primaryColor,
                                      ),
                                      child: Text(
                                        'Masuk',
                                        style: AppTheme.bodySmall.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: isDark 
                                              ? AppTheme.primaryLight 
                                              : AppTheme.primaryColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(
    BuildContext context, {
    required String label,
    required IconData icon,
    Widget? suffixIcon,
    bool isDark = false,
  }) {
    final fillColor = isDark 
        ? const Color(0xFF1E3250)
        : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.15)
        : AppTheme.dividerColor.withValues(alpha: 0.95);
    final labelColor = isDark 
        ? Colors.white.withValues(alpha: 0.8)
        : null;
    final iconColor = isDark 
        ? Colors.white.withValues(alpha: 0.6)
        : null;

    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: labelColor),
      prefixIcon: Icon(icon, color: iconColor),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: fillColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        borderSide: const BorderSide(color: AppTheme.errorColor),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        borderSide: const BorderSide(color: AppTheme.errorColor, width: 1.8),
      ),
    );
  }
}

class _AuthGlow extends StatelessWidget {
  const _AuthGlow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color,
              blurRadius: size * 0.6,
              spreadRadius: size * 0.08,
            ),
          ],
        ),
      ),
    );
  }
}
