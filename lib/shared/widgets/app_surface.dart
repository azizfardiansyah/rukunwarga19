import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'current_user_avatar.dart';

class AppPageBackground extends StatelessWidget {
  const AppPageBackground({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(14, 8, 14, 14),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.surfaceGradient),
      child: SafeArea(
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class AppSurfaceCard extends StatelessWidget {
  const AppSurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: AppTheme.cardDecoration(),
      child: child,
    );
  }
}

/// Signature accent card with colored left stripe
class AppAccentCard extends StatelessWidget {
  const AppAccentCard({
    super.key,
    required this.child,
    required this.accentColor,
    this.padding = const EdgeInsets.all(14),
    this.margin,
    this.onTap,
  });

  final Widget child;
  final Color accentColor;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: AppTheme.accentCardDecoration(accentColor: accentColor),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Row(
            children: [
              Container(width: 4, color: accentColor),
              Expanded(
                child: Padding(padding: padding, child: child),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor.withValues(alpha: 0.10),
                    AppTheme.accentColor.withValues(alpha: 0.06),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(
                icon,
                size: 32,
                color: AppTheme.primaryColor.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 18),
            Text(title, style: AppTheme.heading3, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
              message,
              style: AppTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    );
  }
}

class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Signature accent dot
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTheme.heading3),
              if ((subtitle ?? '').isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: AppTheme.bodySmall),
              ],
            ],
          ),
        ),
        if (action != null) ...[action!],
      ],
    );
  }
}

class AppHeroPanel extends StatelessWidget {
  const AppHeroPanel({
    super.key,
    required this.title,
    required this.subtitle,
    this.eyebrow,
    this.icon,
    this.chips = const [],
    this.trailing,
    this.showCurrentUserAvatar = true,
  });

  final String title;
  final String subtitle;
  final String? eyebrow;
  final IconData? icon;
  final List<Widget> chips;
  final Widget? trailing;
  final bool showCurrentUserAvatar;

  @override
  Widget build(BuildContext context) {
    final hasEyebrow = (eyebrow ?? '').isNotEmpty;
    final trailingWidget = trailing;
    final trailingChildren = trailingWidget == null
        ? null
        : <Widget>[trailingWidget];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor.withValues(alpha: 0.12),
                  AppTheme.accentColor.withValues(alpha: 0.06),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.primaryColor, size: 18),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: AppTheme.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: AppTheme.caption.copyWith(
                    color: AppTheme.textTertiary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        if (trailing != null || showCurrentUserAvatar || hasEyebrow) ...[
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...?trailingChildren,
              if (showCurrentUserAvatar) ...[
                if (trailingChildren != null) const SizedBox(width: 8),
                const CurrentUserAvatar(size: 32),
              ],
              if (hasEyebrow) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    eyebrow!,
                    style: AppTheme.caption.copyWith(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class AppHeroBadge extends StatelessWidget {
  const AppHeroBadge({
    super.key,
    required this.label,
    required this.foregroundColor,
    required this.backgroundColor,
    this.icon,
  });

  final String label;
  final Color foregroundColor;
  final Color backgroundColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: foregroundColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppTheme.caption.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class AppSearchBar extends StatelessWidget {
  const AppSearchBar({
    super.key,
    required this.hintText,
    required this.onChanged,
    this.controller,
    this.value = '',
  });

  final String hintText;
  final TextEditingController? controller;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecoration(borderRadius: AppTheme.radiusMedium),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: AppTheme.bodySmall.copyWith(color: AppTheme.textTertiary),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: AppTheme.textTertiary,
            size: 18,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          fillColor: Colors.transparent,
          filled: true,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          suffixIcon: value.isEmpty
              ? null
              : IconButton(
                  onPressed: () => onChanged(''),
                  icon: Icon(
                    Icons.close_rounded,
                    color: AppTheme.textTertiary,
                    size: 16,
                  ),
                ),
        ),
        onChanged: onChanged,
        style: AppTheme.bodyMedium.copyWith(fontSize: 13),
      ),
    );
  }
}
