import 'package:flutter/material.dart';

import '../../app/theme.dart';

// ═══════════════════════════════════════════════════════════════════
// APP TOAST — Micro-feedback Notifications
// Consistent toast/snackbar for user feedback across app
// ═══════════════════════════════════════════════════════════════════

enum ToastType { success, warning, error, info }

class AppToast {
  AppToast._();

  static void show(
    BuildContext context, {
    required String message,
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 3),
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    final colors = _getColors(type, context);
    final icon = _getIcon(type);

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: colors.foreground.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: colors.foreground, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: AppTheme.bodySmall.copyWith(
                  color: colors.foreground,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  messenger.hideCurrentSnackBar();
                  onAction();
                },
                style: TextButton.styleFrom(
                  foregroundColor: colors.foreground,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  actionLabel,
                  style: AppTheme.caption.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
        backgroundColor: colors.background,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: colors.foreground.withValues(alpha: 0.2),
          ),
        ),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        duration: duration,
        dismissDirection: DismissDirection.horizontal,
      ),
    );
  }

  static void success(BuildContext context, String message) {
    show(context, message: message, type: ToastType.success);
  }

  static void error(BuildContext context, String message) {
    show(context, message: message, type: ToastType.error);
  }

  static void warning(BuildContext context, String message) {
    show(context, message: message, type: ToastType.warning);
  }

  static void info(BuildContext context, String message) {
    show(context, message: message, type: ToastType.info);
  }

  static _ToastColors _getColors(ToastType type, BuildContext context) {
    final isDark = AppTheme.isDark(context);
    
    switch (type) {
      case ToastType.success:
        return _ToastColors(
          background: isDark
              ? AppTheme.statusSuccess.withValues(alpha: 0.15)
              : AppTheme.statusSuccess.withValues(alpha: 0.08),
          foreground: AppTheme.statusSuccess,
        );
      case ToastType.warning:
        return _ToastColors(
          background: isDark
              ? AppTheme.statusWarning.withValues(alpha: 0.15)
              : AppTheme.statusWarning.withValues(alpha: 0.08),
          foreground: AppTheme.statusWarning,
        );
      case ToastType.error:
        return _ToastColors(
          background: isDark
              ? AppTheme.statusError.withValues(alpha: 0.15)
              : AppTheme.statusError.withValues(alpha: 0.08),
          foreground: AppTheme.statusError,
        );
      case ToastType.info:
        return _ToastColors(
          background: isDark
              ? AppTheme.statusInfo.withValues(alpha: 0.15)
              : AppTheme.statusInfo.withValues(alpha: 0.08),
          foreground: AppTheme.statusInfo,
        );
    }
  }

  static IconData _getIcon(ToastType type) {
    switch (type) {
      case ToastType.success:
        return Icons.check_circle_rounded;
      case ToastType.warning:
        return Icons.warning_rounded;
      case ToastType.error:
        return Icons.error_rounded;
      case ToastType.info:
        return Icons.info_rounded;
    }
  }
}

class _ToastColors {
  final Color background;
  final Color foreground;

  const _ToastColors({
    required this.background,
    required this.foreground,
  });
}

// ═══════════════════════════════════════════════════════════════════
// LOADING OVERLAY — Full screen loading indicator
// ═══════════════════════════════════════════════════════════════════

class AppLoadingOverlay extends StatelessWidget {
  const AppLoadingOverlay({
    super.key,
    this.message,
  });

  final String? message;

  static void show(BuildContext context, {String? message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black38,
      builder: (_) => AppLoadingOverlay(message: message),
    );
  }

  static void hide(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.cardColorFor(context),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor),
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: 16),
                Text(
                  message!,
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.secondaryTextFor(context),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// CONFIRMATION DIALOG — Consistent confirmation dialogs
// ═══════════════════════════════════════════════════════════════════

class AppConfirmDialog {
  AppConfirmDialog._();

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Ya',
    String cancelLabel = 'Batal',
    bool isDanger = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          title,
          style: AppTheme.heading3,
        ),
        content: Text(
          message,
          style: AppTheme.bodyMedium.copyWith(
            color: AppTheme.secondaryTextFor(context),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: isDanger
                  ? AppTheme.statusError
                  : AppTheme.primaryColor,
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
