import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/app_skeleton.dart';

class FinanceScreenShell extends StatelessWidget {
  const FinanceScreenShell({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.floatingActionButton,
  });

  final String title;
  final Widget child;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      floatingActionButton: floatingActionButton,
      body: child,
    );
  }
}

class FinanceSectionCard extends StatelessWidget {
  const FinanceSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.action,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecoration(),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTheme.bodyMedium.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: AppTheme.caption.copyWith(color: AppTheme.textTertiary)),
                    ],
                  ],
                ),
              ),
              action ?? const SizedBox.shrink(),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class FinanceEmptyState extends StatelessWidget {
  const FinanceEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final iconTone = isDark ? AppTheme.accentColor : AppTheme.primaryColor;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.paddingLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    iconTone.withValues(alpha: isDark ? 0.18 : 0.10),
                    AppTheme.accentColor.withValues(alpha: isDark ? 0.12 : 0.06),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(icon, size: 32, color: iconTone.withValues(alpha: 0.75)),
            ),
            const SizedBox(height: 18),
            Text(title, style: AppTheme.heading3, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
              message,
              style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    );
  }
}

/// Skeleton for finance transactions list
class FinanceListSkeleton extends StatelessWidget {
  const FinanceListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
      children: [
        // Hero skeleton
        const SkeletonHeroPanel(),
        const SizedBox(height: 12),
        // Setup card skeleton
        Container(
          padding: const EdgeInsets.all(12),
          decoration: AppTheme.cardDecorationFor(context),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSkeleton(width: 120, height: 14),
              SizedBox(height: 8),
              AppSkeleton(height: 12),
              SizedBox(height: 12),
              Row(
                children: [
                  AppSkeleton(width: 100, height: 24, borderRadius: 12),
                  SizedBox(width: 8),
                  AppSkeleton(width: 120, height: 24, borderRadius: 12),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Filter skeleton
        Container(
          padding: const EdgeInsets.all(12),
          decoration: AppTheme.cardDecorationFor(context),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSkeleton(width: 100, height: 14),
              SizedBox(height: 12),
              AppSkeleton(height: 48, borderRadius: 8),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: AppSkeleton(height: 48, borderRadius: 8)),
                  SizedBox(width: 12),
                  Expanded(child: AppSkeleton(height: 48, borderRadius: 8)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Transactions skeleton
        Container(
          padding: const EdgeInsets.all(12),
          decoration: AppTheme.cardDecorationFor(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppSkeleton(width: 120, height: 14),
              const SizedBox(height: 12),
              ...List.generate(3, (index) => const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: SkeletonCard(height: 130),
              )),
            ],
          ),
        ),
      ],
    );
  }
}

class FinanceAccessDenied extends StatelessWidget {
  const FinanceAccessDenied({
    super.key,
    this.title = 'Akses keuangan tidak tersedia',
    this.message =
        'Screen ini hanya tersedia untuk operator atau sysadmin yang memiliki hak keuangan pada unit terkait.',
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return FinanceScreenShell(
      title: 'Keuangan',
      child: FinanceEmptyState(
        icon: Icons.lock_outline_rounded,
        title: title,
        message: message,
      ),
    );
  }
}

class FinanceBadge extends StatelessWidget {
  const FinanceBadge({super.key, required this.label, this.color, this.icon});

  final String label;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tone = color ?? AppTheme.primaryColor;
    return AppBadge(
      label: label,
      icon: icon,
      type: _typeFromColor(tone),
    );
  }

  AppBadgeType _typeFromColor(Color color) {
    if (color == AppTheme.statusSuccess || color == AppTheme.successColor) {
      return AppBadgeType.success;
    } else if (color == AppTheme.statusWarning || color == AppTheme.warningColor) {
      return AppBadgeType.warning;
    } else if (color == AppTheme.statusError || color == AppTheme.errorColor) {
      return AppBadgeType.error;
    } else if (color == AppTheme.accentColor) {
      return AppBadgeType.success;
    }
    return AppBadgeType.info;
  }
}

String financeDirectionLabel(String direction) {
  switch (direction.trim().toLowerCase()) {
    case 'in':
      return 'Pemasukan';
    case 'out':
      return 'Pengeluaran';
    default:
      return direction;
  }
}

String financeApprovalStatusLabel(String status) {
  switch (status.trim().toLowerCase()) {
    case 'draft':
      return 'Draft';
    case 'submitted':
      return 'Submitted';
    case 'approved':
      return 'Approved';
    case 'rejected':
      return 'Rejected';
    default:
      return status;
  }
}

String financePublishStatusLabel(String status) {
  switch (status.trim().toLowerCase()) {
    case 'pending':
      return 'Pending Publish';
    case 'published':
      return 'Published';
    default:
      return status;
  }
}

Color financePublishStatusColor(String status) {
  switch (status.trim().toLowerCase()) {
    case 'published':
      return AppTheme.successColor;
    case 'pending':
    default:
      return AppTheme.warningColor;
  }
}
