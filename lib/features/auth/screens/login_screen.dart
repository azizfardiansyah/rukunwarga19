import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/utils/error_classifier.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await ref
          .read(authProvider.notifier)
          .login(_emailController.text.trim(), _passwordController.text);
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
    final isDark = AppTheme.isDark(context);
    final heroGradient = AppTheme.headerGradientFor(context);
    final subtitleColor = Colors.white.withValues(alpha: 0.76);
    
    // Warna untuk form container di dark mode
    final formBgColor = isDark 
        ? AppTheme.cardColorFor(context).withValues(alpha: 0.95)
        : Colors.white.withValues(alpha: 0.92);
    final formBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.25);
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: heroGradient),
        child: Stack(
          children: [
            Positioned(
              top: -36,
              right: -18,
              child: _AuthGlow(
                size: 156,
                color: AppTheme.accentColor.withValues(alpha: isDark ? 0.10 : 0.16),
              ),
            ),
            Positioned(
              top: 210,
              left: -54,
              child: _AuthGlow(
                size: 148,
                color: Colors.white.withValues(alpha: isDark ? 0.05 : 0.10),
              ),
            ),
            Positioned(
              bottom: -28,
              right: 42,
              child: _AuthGlow(
                size: 154,
                color: AppTheme.primaryLight.withValues(alpha: isDark ? 0.10 : 0.16),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppTheme.paddingLarge),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                          ),
                          child: const Icon(
                            Icons.location_city_rounded,
                            size: 48,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'RukunWarga',
                          style: AppTheme.heading1.copyWith(
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sistem Manajemen Rukun Warga',
                          style: AppTheme.bodySmall.copyWith(
                            fontSize: 13,
                            color: subtitleColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 28),
                        // Form container dengan dark mode support
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: formBgColor,
                            borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
                            border: Border.all(color: formBorderColor),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
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
                                  'Masuk ke Akun',
                                  style: AppTheme.heading3.copyWith(
                                    color: AppTheme.primaryTextFor(context),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Masuk untuk mengelola data warga, layanan, dan komunikasi wilayah.',
                                  style: AppTheme.bodySmall.copyWith(
                                    color: AppTheme.secondaryTextFor(context),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),

                                // Email field dengan styling yang lebih baik
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  autofillHints: const [AutofillHints.email],
                                  style: TextStyle(
                                    color: AppTheme.primaryTextFor(context),
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'Email',
                                    labelStyle: TextStyle(
                                      color: AppTheme.secondaryTextFor(context),
                                    ),
                                    prefixIcon: Icon(
                                      Icons.email_outlined,
                                      color: AppTheme.secondaryTextFor(context),
                                    ),
                                    filled: true,
                                    fillColor: isDark 
                                        ? Colors.white.withValues(alpha: 0.05)
                                        : Colors.grey.withValues(alpha: 0.05),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                      borderSide: BorderSide(
                                        color: AppTheme.cardBorderColorFor(context),
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                      borderSide: BorderSide(
                                        color: AppTheme.cardBorderColorFor(context),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                      borderSide: const BorderSide(
                                        color: AppTheme.primaryColor,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Email wajib diisi';
                                    }
                                    if (!value.contains('@')) {
                                      return 'Email tidak valid';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),

                                // Password field dengan styling yang lebih baik
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  autofillHints: const [AutofillHints.password],
                                  style: TextStyle(
                                    color: AppTheme.primaryTextFor(context),
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    labelStyle: TextStyle(
                                      color: AppTheme.secondaryTextFor(context),
                                    ),
                                    prefixIcon: Icon(
                                      Icons.lock_outlined,
                                      color: AppTheme.secondaryTextFor(context),
                                    ),
                                    filled: true,
                                    fillColor: isDark 
                                        ? Colors.white.withValues(alpha: 0.05)
                                        : Colors.grey.withValues(alpha: 0.05),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                      borderSide: BorderSide(
                                        color: AppTheme.cardBorderColorFor(context),
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                      borderSide: BorderSide(
                                        color: AppTheme.cardBorderColorFor(context),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                      borderSide: const BorderSide(
                                        color: AppTheme.primaryColor,
                                        width: 2,
                                      ),
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        color: AppTheme.secondaryTextFor(context),
                                      ),
                                      onPressed: () {
                                        setState(() => _obscurePassword = !_obscurePassword);
                                      },
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Password wajib diisi';
                                    }
                                    return null;
                                  },
                                  onFieldSubmitted: (_) {
                                    if (!_isLoading) _login();
                                  },
                                ),
                                const SizedBox(height: 24),

                                SizedBox(
                                  height: 52,
                                  child: FilledButton(
                                    onPressed: _isLoading ? null : _login,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppTheme.primaryColor,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                      ),
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Text(
                                            'Masuk',
                                            style: AppTheme.buttonText.copyWith(
                                              fontSize: 15,
                                              color: Colors.white,
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Belum punya akun? ',
                                      style: AppTheme.bodySmall.copyWith(
                                        color: AppTheme.secondaryTextFor(context),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => context.go(Routes.register),
                                      child: Text(
                                        'Daftar',
                                        style: AppTheme.bodySmall.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.primaryColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
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
