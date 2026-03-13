import 'package:flutter/material.dart';

import '../../app/theme.dart';

// ═══════════════════════════════════════════════════════════════════
// APP SKELETON — Loading Shimmer Components
// Smooth, animated placeholders for better loading UX
// ═══════════════════════════════════════════════════════════════════

class AppSkeleton extends StatefulWidget {
  const AppSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = 8,
    this.margin,
  });

  final double? width;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final baseColor = isDark
        ? const Color(0xFF2A3441)
        : const Color(0xFFE8EDF2);
    final highlightColor = isDark
        ? const Color(0xFF3A4451)
        : const Color(0xFFF4F7FA);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          margin: widget.margin,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(_animation.value - 1, 0),
              end: Alignment(_animation.value + 1, 0),
              colors: [baseColor, highlightColor, baseColor],
            ),
          ),
        );
      },
    );
  }
}

/// Skeleton for a card-like container
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({
    super.key,
    this.height = 100,
    this.margin,
  });

  final double height;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      margin: margin,
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.cardDecorationFor(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppSkeleton(width: 40, height: 40, borderRadius: 12),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSkeleton(
                      width: MediaQuery.of(context).size.width * 0.4,
                      height: 14,
                    ),
                    const SizedBox(height: 6),
                    AppSkeleton(
                      width: MediaQuery.of(context).size.width * 0.25,
                      height: 10,
                    ),
                  ],
                ),
              ),
              const AppSkeleton(width: 60, height: 22, borderRadius: 12),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              const AppSkeleton(width: 70, height: 20, borderRadius: 10),
              const SizedBox(width: 8),
              const AppSkeleton(width: 50, height: 20, borderRadius: 10),
              const Spacer(),
              const AppSkeleton(width: 80, height: 12),
            ],
          ),
        ],
      ),
    );
  }
}

/// Skeleton for list items
class SkeletonListItem extends StatelessWidget {
  const SkeletonListItem({
    super.key,
    this.showAvatar = true,
    this.showBadge = true,
    this.margin,
  });

  final bool showAvatar;
  final bool showBadge;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.cardDecorationFor(context),
      child: Row(
        children: [
          if (showAvatar) ...[
            const AppSkeleton(width: 44, height: 44, borderRadius: 14),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSkeleton(
                  width: MediaQuery.of(context).size.width * 0.45,
                  height: 14,
                ),
                const SizedBox(height: 6),
                AppSkeleton(
                  width: MediaQuery.of(context).size.width * 0.30,
                  height: 11,
                ),
              ],
            ),
          ),
          if (showBadge)
            const AppSkeleton(width: 55, height: 22, borderRadius: 12),
        ],
      ),
    );
  }
}

/// Skeleton for hero panel
class SkeletonHeroPanel extends StatelessWidget {
  const SkeletonHeroPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const AppSkeleton(width: 42, height: 42, borderRadius: 14),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSkeleton(
                  width: MediaQuery.of(context).size.width * 0.5,
                  height: 16,
                ),
                const SizedBox(height: 6),
                AppSkeleton(
                  width: MediaQuery.of(context).size.width * 0.7,
                  height: 12,
                ),
              ],
            ),
          ),
          const AppSkeleton(width: 32, height: 32, borderRadius: 16),
        ],
      ),
    );
  }
}

/// Skeleton for metric cards (dashboard/laporan)
class SkeletonMetricCard extends StatelessWidget {
  const SkeletonMetricCard({super.key, this.margin});

  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      margin: margin,
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.cardDecorationFor(context),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSkeleton(width: 24, height: 24, borderRadius: 8),
          SizedBox(height: 12),
          AppSkeleton(width: 60, height: 22),
          SizedBox(height: 6),
          AppSkeleton(width: 80, height: 11),
        ],
      ),
    );
  }
}

/// Skeleton for tabs/filters
class SkeletonTabs extends StatelessWidget {
  const SkeletonTabs({super.key, this.count = 3});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        count,
        (index) => Expanded(
          child: Container(
            margin: EdgeInsets.only(right: index < count - 1 ? 8 : 0),
            child: const AppSkeleton(height: 36, borderRadius: 10),
          ),
        ),
      ),
    );
  }
}

/// Full page skeleton with hero, search, tabs, and list
class SkeletonListPage extends StatelessWidget {
  const SkeletonListPage({
    super.key,
    this.showHero = true,
    this.showSearch = true,
    this.showTabs = true,
    this.itemCount = 5,
  });

  final bool showHero;
  final bool showSearch;
  final bool showTabs;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (showHero) ...[
          const SkeletonHeroPanel(),
          const SizedBox(height: 12),
        ],
        if (showSearch) ...[
          const AppSkeleton(height: 44, borderRadius: 12),
          const SizedBox(height: 12),
        ],
        if (showTabs) ...[
          const SkeletonTabs(),
          const SizedBox(height: 14),
        ],
        Expanded(
          child: ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            itemCount: itemCount,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, _) => const SkeletonListItem(),
          ),
        ),
      ],
    );
  }
}
