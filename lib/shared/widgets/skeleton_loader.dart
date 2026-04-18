import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SkeletonBox — single shimmering placeholder block
// ─────────────────────────────────────────────────────────────────────────────

class SkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  final double radius;

  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.radius = 6,
  });

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) => Opacity(
        opacity: _anim.value,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SkeletonListItem — a single shimmer row (icon + two lines of text)
// ─────────────────────────────────────────────────────────────────────────────

class SkeletonListItem extends StatelessWidget {
  const SkeletonListItem({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pagePaddingH, vertical: AppSpacing.sm),
      child: Row(
        children: [
          const SkeletonBox(width: 36, height: 36, radius: 8),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: double.infinity, height: 13, radius: 4),
                const SizedBox(height: 6),
                SkeletonBox(width: MediaQuery.sizeOf(context).width * 0.4, height: 11, radius: 4),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.base),
          const SkeletonBox(width: 60, height: 22, radius: 6),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SkeletonList — N shimmer rows for list/table loading states
// ─────────────────────────────────────────────────────────────────────────────

class SkeletonList extends StatelessWidget {
  final int count;
  const SkeletonList({super.key, this.count = 5});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        count,
        (_) => const SkeletonListItem(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SkeletonCard — shimmer block for card-layout screens
// ─────────────────────────────────────────────────────────────────────────────

class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SkeletonBox(width: 40, height: 40, radius: 8),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SkeletonBox(width: double.infinity, height: 14),
                    const SizedBox(height: 6),
                    SkeletonBox(
                        width: MediaQuery.sizeOf(context).width * 0.3,
                        height: 11),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const SkeletonBox(width: double.infinity, height: 11),
          const SizedBox(height: 4),
          SkeletonBox(
              width: MediaQuery.sizeOf(context).width * 0.6, height: 11),
        ],
      ),
    );
  }
}
