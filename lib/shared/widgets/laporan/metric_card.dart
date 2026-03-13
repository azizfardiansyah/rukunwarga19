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
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive
                ? activeColor.withValues(alpha: 0.35)
                : AppTheme.lightGray,
            width: isActive ? 1.5 : 1,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.12),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
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
                style: AppTheme.heading1.copyWith(
                  fontSize: 28,
                  color: isActive ? activeColor : AppTheme.darkGray,
                  height: 1,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppTheme.labelMedium.copyWith(
                fontSize: 12,
                color: AppTheme.statusInfo,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
