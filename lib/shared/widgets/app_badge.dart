import 'package:flutter/material.dart';

import '../../app/theme.dart';

enum AppBadgeType { success, warning, error, info, neutral }

enum AppBadgeSize { small, medium, large }

enum AppBadgeStyle { solid, soft }

class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.label,
    this.type = AppBadgeType.info,
    this.size = AppBadgeSize.medium,
    this.style = AppBadgeStyle.soft,
    this.icon,
  });

  final String label;
  final AppBadgeType type;
  final AppBadgeSize size;
  final AppBadgeStyle style;
  final IconData? icon;

  Color _baseColor(BuildContext context) {
    switch (type) {
      case AppBadgeType.success:
        return AppTheme.statusSuccess;
      case AppBadgeType.warning:
        return AppTheme.statusWarning;
      case AppBadgeType.error:
        return AppTheme.statusError;
      case AppBadgeType.info:
        return AppTheme.statusInfo;
      case AppBadgeType.neutral:
        return AppTheme.tertiaryTextFor(context);
    }
  }

  EdgeInsets _padding() {
    switch (size) {
      case AppBadgeSize.small:
        return const EdgeInsets.symmetric(horizontal: 7, vertical: 4);
      case AppBadgeSize.medium:
        return const EdgeInsets.symmetric(horizontal: 9, vertical: 5);
      case AppBadgeSize.large:
        return const EdgeInsets.symmetric(horizontal: 11, vertical: 7);
    }
  }

  TextStyle _textStyle(Color color) {
    switch (size) {
      case AppBadgeSize.small:
        return AppTheme.caption.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
        );
      case AppBadgeSize.medium:
        return AppTheme.caption.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        );
      case AppBadgeSize.large:
        return AppTheme.bodySmall.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: color,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = _baseColor(context);
    final isDark = AppTheme.isDark(context);
    final background = style == AppBadgeStyle.solid
        ? baseColor
        : baseColor.withValues(alpha: isDark ? 0.20 : 0.10);
    final foreground = style == AppBadgeStyle.solid ? Colors.white : baseColor;

    return AnimatedContainer(
      duration: AppTheme.fastDuration,
      padding: _padding(),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: style == AppBadgeStyle.soft
            ? Border.all(color: baseColor.withValues(alpha: 0.18))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: size == AppBadgeSize.large ? 13 : 11,
              color: foreground,
            ),
            const SizedBox(width: 4),
          ],
          Text(label, style: _textStyle(foreground)),
        ],
      ),
    );
  }
}
