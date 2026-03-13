import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../core/utils/error_classifier.dart';
import '../../../shared/widgets/app_surface.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _hideOldPassword = true;
  bool _hideNewPassword = true;
  bool _hideConfirmPassword = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(authServiceProvider)
          .changePassword(
            oldPassword: _oldPasswordController.text,
            newPassword: _newPasswordController.text,
            newPasswordConfirm: _confirmPasswordController.text,
          );
      await ref.read(authProvider.notifier).refreshAuth();
      if (!mounted) {
        return;
      }
      ErrorClassifier.showSuccessSnackBar(
        context,
        'Password berhasil diperbarui. Gunakan password baru saat login berikutnya.',
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ErrorClassifier.showErrorSnackBar(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final formTheme = Theme.of(context).copyWith(
      inputDecorationTheme: Theme.of(context).inputDecorationTheme.copyWith(
        prefixIconColor: AppTheme.secondaryTextFor(context),
        suffixIconColor: AppTheme.tertiaryTextFor(context),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Ganti Password')),
      body: AppPageBackground(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        child: Theme(
          data: formTheme,
          child: ListView(
            children: [
              AppSurfaceCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Keamanan Akun',
                      style: AppTheme.heading4.copyWith(
                        color: AppTheme.primaryTextFor(context),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Masukkan password lama Anda, lalu buat password baru minimal 8 karakter agar akun tetap aman.',
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
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _passwordField(
                        controller: _oldPasswordController,
                        label: 'Password Lama',
                        icon: Icons.lock_outline_rounded,
                        obscureText: _hideOldPassword,
                        onToggle: () => setState(
                          () => _hideOldPassword = !_hideOldPassword,
                        ),
                        validator: (value) {
                          if ((value ?? '').isEmpty) {
                            return 'Password lama wajib diisi';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      _passwordField(
                        controller: _newPasswordController,
                        label: 'Password Baru',
                        icon: Icons.enhanced_encryption_rounded,
                        obscureText: _hideNewPassword,
                        onToggle: () => setState(
                          () => _hideNewPassword = !_hideNewPassword,
                        ),
                        validator: (value) {
                          if ((value ?? '').isEmpty) {
                            return 'Password baru wajib diisi';
                          }
                          if ((value ?? '').length < 8) {
                            return 'Password minimal 8 karakter';
                          }
                          if (value == _oldPasswordController.text) {
                            return 'Password baru harus berbeda dari password lama';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      _passwordField(
                        controller: _confirmPasswordController,
                        label: 'Konfirmasi Password Baru',
                        icon: Icons.verified_user_outlined,
                        obscureText: _hideConfirmPassword,
                        onToggle: () => setState(
                          () => _hideConfirmPassword = !_hideConfirmPassword,
                        ),
                        validator: (value) {
                          if ((value ?? '').isEmpty) {
                            return 'Konfirmasi password wajib diisi';
                          }
                          if (value != _newPasswordController.text) {
                            return 'Konfirmasi password belum sama';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _isSubmitting ? null : _submit,
                          icon: _isSubmitting
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.lock_reset_rounded),
                          label: Text(
                            _isSubmitting
                                ? 'Memperbarui Password...'
                                : 'Simpan Password Baru',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool obscureText,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(
            obscureText
                ? Icons.visibility_off_rounded
                : Icons.visibility_rounded,
          ),
        ),
      ),
    );
  }
}
