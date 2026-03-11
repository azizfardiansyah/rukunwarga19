import 'package:flutter/material.dart';

import '../../../app/theme.dart';

class OrganizationScreenShell extends StatelessWidget {
  const OrganizationScreenShell({
    super.key,
    required this.title,
    required this.child,
    this.floatingActionButton,
    this.actions,
  });

  final String title;
  final Widget child;
  final Widget? floatingActionButton;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      floatingActionButton: floatingActionButton,
      body: child,
    );
  }
}

class OrganizationSectionCard extends StatelessWidget {
  const OrganizationSectionCard({
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

class OrganizationEmptyState extends StatelessWidget {
  const OrganizationEmptyState({
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
            Text(title, textAlign: TextAlign.center, style: AppTheme.heading3),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class OrganizationAccessDenied extends StatelessWidget {
  const OrganizationAccessDenied({
    super.key,
    this.title = 'Akses organisasi tidak tersedia',
    this.message =
        'Screen ini hanya tersedia untuk operator RW atau sysadmin dengan workspace aktif.',
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return OrganizationScreenShell(
      title: 'Organisasi',
      child: OrganizationEmptyState(
        icon: Icons.lock_outline_rounded,
        title: title,
        message: message,
      ),
    );
  }
}

class OrganizationBadge extends StatelessWidget {
  const OrganizationBadge({super.key, required this.label, this.color});

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
