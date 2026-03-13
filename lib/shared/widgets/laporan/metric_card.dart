import 'package:flutter/material.dart';

import '../../../app/theme.dart';

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.isActive = false,
    this.activeColor = AppTheme.statusInfo,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  final bool isActive;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    final labelColor = isActive
        ? activeColor
        : AppTheme.secondaryTextFor(context);
    final valueColor = isActive
        ? activeColor
        : AppTheme.primaryTextFor(context);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppTheme.fastDuration,
        padding: const EdgeInsets.all(14),
        decoration: AppTheme.cardDecorationFor(
          context,
          color: isActive ? activeColor.withValues(alpha: 0.10) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: isActive ? activeColor : AppTheme.statusInfo,
              size: 20,
            ),
            const SizedBox(height: 14),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: AppTypography.metricValue.copyWith(
                  fontSize: 28,
                  color: valueColor,
                  height: 1,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppTypography.metricLabel.copyWith(
                fontSize: 12,
                color: labelColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
