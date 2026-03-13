import 'package:flutter/material.dart';

import '../../app/theme.dart';

class MenuItemCard extends StatefulWidget {
  const MenuItemCard({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.iconBgColor,
    this.badge,
    this.helperText,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? iconBgColor;
  final Widget? badge;
  final String? helperText;

  @override
  State<MenuItemCard> createState() => _MenuItemCardState();
}

class _MenuItemCardState extends State<MenuItemCard> {
  bool _isPressed = false;

  void _setPressed(bool value) {
    if (_isPressed == value) {
      return;
    }
    setState(() => _isPressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final iconColor =
        widget.iconColor ?? AppColors.moduleIconColor(widget.label);
    final iconBg =
        widget.iconBgColor ?? AppColors.moduleIconBackground(widget.label);

    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        duration: AppTheme.fastDuration,
        scale: _isPressed ? 0.98 : 1,
        child: AnimatedContainer(
          duration: AppTheme.fastDuration,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: AppTheme.cardDecorationFor(
            context,
            borderRadius: AppTheme.radiusLarge,
            color: _isPressed
                ? (isDark ? AppTheme.darkSurfaceRaised : AppColors.bgWhite)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: isDark
                          ? iconColor.withValues(alpha: 0.18)
                          : iconBg,
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusMedium,
                      ),
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Center(
                          child: Icon(widget.icon, color: iconColor, size: 24),
                        ),
                        if (widget.badge != null)
                          Positioned(top: -6, right: -6, child: widget.badge!),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_outward_rounded,
                    size: 18,
                    color: AppTheme.tertiaryTextFor(context),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                widget.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.menuLabel.copyWith(
                  color: AppTheme.primaryTextFor(context),
                ),
              ),
              if ((widget.helperText ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  widget.helperText!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.menuHelper.copyWith(
                    color: AppTheme.secondaryTextFor(context),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
