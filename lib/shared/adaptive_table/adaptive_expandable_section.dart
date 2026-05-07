import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../design_system/radius_tokens.dart';

/// Animated accordion that reveals [child] when tapped.
///
/// [header] is always visible and acts as the tap target.
/// The content area fades + slides in using SizeTransition + FadeTransition.
///
/// Use inline on desktop for row-level expansion, or wrap in a bottom sheet
/// adapter on mobile for full-screen detail views.
class AdaptiveExpandableSection extends StatefulWidget {
  final Widget header;
  final Widget child;
  final bool initiallyExpanded;
  final Duration duration;
  final EdgeInsets? contentPadding;

  const AdaptiveExpandableSection({
    super.key,
    required this.header,
    required this.child,
    this.initiallyExpanded = false,
    this.duration = const Duration(milliseconds: 220),
    this.contentPadding,
  });

  @override
  State<AdaptiveExpandableSection> createState() =>
      _AdaptiveExpandableSectionState();
}

class _AdaptiveExpandableSectionState extends State<AdaptiveExpandableSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _expand;
  late final Animation<double> _fade;
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
    _ctrl = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: _expanded ? 1.0 : 0.0,
    );
    _expand = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    _fade   = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _ctrl.forward();
    } else {
      _ctrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(onTap: _toggle, child: widget.header),
        SizeTransition(
          sizeFactor: _expand,
          child: FadeTransition(
            opacity: _fade,
            child: Container(
              margin: const EdgeInsets.only(top: 8),
              padding: widget.contentPadding ?? const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: AdaptiveRadius.rowBorder,
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              child: widget.child,
            ),
          ),
        ),
      ],
    );
  }
}
