import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../shared/widgets/app_surface.dart';

/// Summary card for laporan statistics
class LaporanSummaryCard extends StatelessWidget {
  const LaporanSummaryCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardColorFor(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorderColorFor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const Spacer(),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: AppTheme.caption.copyWith(
                    color: AppTheme.secondaryTextFor(context),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: AppTheme.heading2.copyWith(
              color: AppTheme.primaryTextFor(context),
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: AppTheme.caption.copyWith(
              color: AppTheme.secondaryTextFor(context),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Detail card with title and content
class LaporanDetailCard extends StatelessWidget {
  const LaporanDetailCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 16, color: AppTheme.primaryColor),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: AppTheme.heading3.copyWith(
                  color: AppTheme.primaryTextFor(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// Table row for statistics
class LaporanTableRow extends StatelessWidget {
  const LaporanTableRow({
    super.key,
    required this.label,
    required this.value,
    required this.percentage,
    this.color,
    this.isHeader = false,
  });

  final String label;
  final String value;
  final double percentage;
  final Color? color;
  final bool isHeader;

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final barColor = color ?? AppTheme.primaryColor;

    if (isHeader) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark
              ? AppTheme.darkSurfaceRaised
              : AppTheme.primaryColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(
                label,
                style: AppTheme.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryTextFor(context),
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                value,
                textAlign: TextAlign.center,
                style: AppTheme.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryTextFor(context),
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                'Persentase',
                textAlign: TextAlign.right,
                style: AppTheme.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryTextFor(context),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: Text(
                  label,
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.primaryTextFor(context),
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  value,
                  textAlign: TextAlign.center,
                  style: AppTheme.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryTextFor(context),
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  '${percentage.toStringAsFixed(1)}%',
                  textAlign: TextAlign.right,
                  style: AppTheme.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: barColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage / 100,
              minHeight: 6,
              backgroundColor: barColor.withValues(alpha: isDark ? 0.15 : 0.1),
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
        ],
      ),
    );
  }
}
