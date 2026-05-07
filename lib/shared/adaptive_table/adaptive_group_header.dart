import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../design_system/spacing_tokens.dart';
import '../design_system/typography_tokens.dart';

/// Collapsible section header for grouped operational data.
///
/// Shows: accent dot · group title · count badge · collapse chevron.
/// Tapping the header toggles visibility of [children] with a smooth
/// SizeTransition animation.
///
/// Set [collapsible] = false for always-expanded sections.
class AdaptiveGroupHeader extends StatefulWidget {
  final String title;
  final int count;
  final Color? accentColor;
  final bool collapsible;
  final bool initiallyExpanded;
  final List<Widget> children;
  final EdgeInsets? headerPadding;

  const AdaptiveGroupHeader({
    super.key,
    required this.title,
    required this.count,
    required this.children,
    this.accentColor,
    this.collapsible = true,
    this.initiallyExpanded = true,
    this.headerPadding,
  });

  @override
  State<AdaptiveGroupHeader> createState() => _AdaptiveGroupHeaderState();
}

class _AdaptiveGroupHeaderState extends State<AdaptiveGroupHeader>
    with SingleTickerProviderStateMixin {
  late bool _expanded;
  late final AnimationController _ctrl;
  late final Animation<double> _expand;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: _expanded ? 1.0 : 0.0,
    );
    _expand = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    if (!widget.collapsible) return;
    setState(() => _expanded = !_expanded);
    if (_expanded) { _ctrl.forward(); } else { _ctrl.reverse(); }
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor ?? AppColors.accent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: _toggle,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: widget.headerPadding ??
                const EdgeInsets.symmetric(
                  horizontal: AdaptiveSpacing.groupHeaderPaddingH,
                  vertical: AdaptiveSpacing.groupHeaderPaddingV,
                ),
            child: Row(
              children: [
                // Accent dot
                Container(
                  width: 6,
                  height: 6,
                  decoration:
                      BoxDecoration(color: accent, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(widget.title,
                    style: AdaptiveTypography.groupHeaderLabel),
                const SizedBox(width: 8),
                // Count badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${widget.count}',
                      style: AdaptiveTypography.groupCount),
                ),
                if (widget.collapsible) ...[
                  const Spacer(),
                  AnimatedRotation(
                    turns: _expanded ? 0 : -0.25,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        // Children
        if (widget.collapsible)
          SizeTransition(
            sizeFactor: _expand,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: AdaptiveSpacing.groupBelowHeaderGap),
                ...widget.children,
              ],
            ),
          )
        else ...[
          SizedBox(height: AdaptiveSpacing.groupBelowHeaderGap),
          ...widget.children,
        ],
      ],
    );
  }
}
