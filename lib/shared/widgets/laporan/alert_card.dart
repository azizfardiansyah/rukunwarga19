import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../app_badge.dart';

enum AlertStatus { error, warning, success, info }

class AlertCard extends StatelessWidget {
  const AlertCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.ctaLabel,
    required this.onTap,
    required this.status,
    this.value,
    this.meta,
    this.icon = Icons.warning_amber_rounded,
  });

  final String title;
  final String subtitle;
  final String? value;
  final String ctaLabel;
  final VoidCallback onTap;
  final AlertStatus status;
  final String? meta;
  final IconData icon;

  Color get _statusColor {
    switch (status) {
      case AlertStatus.error:
        return AppTheme.statusError;
      case AlertStatus.warning:
        return AppTheme.statusWarning;
      case AlertStatus.success:
        return AppTheme.statusSuccess;
      case AlertStatus.info:
        return AppTheme.statusInfo;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor;
    final isDark = AppTheme.isDark(context);
    final textColor = AppTheme.primaryTextFor(context);
    final secondaryColor = AppTheme.secondaryTextFor(context);

    return AnimatedContainer(
      duration: AppTheme.fastDuration,
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecorationFor(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppBadge(
                      label: status.name.toUpperCase(),
                      type: switch (status) {
                        AlertStatus.error => AppBadgeType.error,
                        AlertStatus.warning => AppBadgeType.warning,
                        AlertStatus.success => AppBadgeType.success,
                        AlertStatus.info => AppBadgeType.info,
                      },
                      size: AppBadgeSize.small,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      style: AppTheme.heading3.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if ((value ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              value!,
              style: AppTypography.metricValue.copyWith(
                fontSize: 30,
                color: color,
                height: 1,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: AppTheme.bodyMedium.copyWith(
              fontSize: 14,
              color: secondaryColor,
            ),
          ),
          if ((meta ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              meta!,
              style: AppTheme.caption.copyWith(
                fontSize: 12,
                color: AppTheme.tertiaryTextFor(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: Text(
                ctaLabel,
                style: AppTheme.buttonText.copyWith(
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          if (isDark) const SizedBox.shrink(),
        ],
      ),
    );
  }
}
