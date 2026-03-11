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
      padding: const EdgeInsets.all(10),
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
                      style: AppTheme.bodySmall.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (subtitle?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 1),
                      Text(
                        subtitle!,
                        style: AppTheme.caption.copyWith(
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              action ?? const SizedBox.shrink(),
            ],
          ),
          const SizedBox(height: 8),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 28, color: AppTheme.primaryColor),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTheme.bodySmall.copyWith(
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTheme.caption,
          ),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: tone,
        ),
      ),
    );
  }
}
