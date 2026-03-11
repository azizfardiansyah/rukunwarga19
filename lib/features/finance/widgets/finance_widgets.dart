import 'package:flutter/material.dart';

import '../../../app/theme.dart';

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
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.paddingLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: AppTheme.textSecondary),
            const SizedBox(height: 12),
            Text(title, style: AppTheme.heading3, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              message,
              style: AppTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
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
  const FinanceBadge({super.key, required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tone = color ?? AppTheme.primaryColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTheme.caption.copyWith(
          color: tone,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
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
