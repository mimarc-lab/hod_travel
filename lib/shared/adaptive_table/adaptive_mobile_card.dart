import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../design_system/radius_tokens.dart';
import '../design_system/shadow_tokens.dart';
import '../design_system/spacing_tokens.dart';

/// Mobile-optimised card using progressive disclosure.
///
/// Always visible: [primaryContent] + [trailingChip] + [actions].
/// Secondary info: [metaRow] (one line of collapsed secondary data).
/// Tertiary detail: [expandedContent] (revealed via [AdaptiveExpandableSection]
/// or toggled externally).
///
/// A 3px [accentBar] on the left edge provides at-a-glance status scanning,
/// consistent with the desktop row pattern.
class AdaptiveMobileCard extends StatefulWidget {
  final Widget primaryContent;
  final Widget? trailingChip;
  final Widget? metaRow;
  final Widget? expandedContent;
  final VoidCallback? onTap;
  final Color? accentBar;
  final Widget? actions;

  const AdaptiveMobileCard({
    super.key,
    required this.primaryContent,
    this.trailingChip,
    this.metaRow,
    this.expandedContent,
    this.onTap,
    this.accentBar,
    this.actions,
  });

  @override
  State<AdaptiveMobileCard> createState() => _AdaptiveMobileCardState();
}

class _AdaptiveMobileCardState extends State<AdaptiveMobileCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          transform: Matrix4.translationValues(0, _hovered ? -1 : 0, 0),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AdaptiveRadius.cardBorder,
            boxShadow:
                _hovered ? AdaptiveShadows.cardHover : AdaptiveShadows.cardResting,
          ),
          child: ClipRRect(
            borderRadius: AdaptiveRadius.cardBorder,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left accent bar
                  if (widget.accentBar != null)
                    Container(width: 3, color: widget.accentBar),

                  // Card body
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AdaptiveSpacing.rowPaddingH,
                        vertical: AdaptiveSpacing.rowPaddingV,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Primary row: title + chip + actions
                          Row(
                            children: [
                              Expanded(child: widget.primaryContent),
                              if (widget.trailingChip != null) ...[
                                const SizedBox(width: 8),
                                widget.trailingChip!,
                              ],
                              if (widget.actions != null) ...[
                                const SizedBox(width: 4),
                                widget.actions!,
                              ],
                            ],
                          ),

                          // Meta row (secondary info)
                          if (widget.metaRow != null) ...[
                            const SizedBox(height: 6),
                            widget.metaRow!,
                          ],

                          // Expanded / tertiary content
                          if (widget.expandedContent != null) ...[
                            const SizedBox(height: 8),
                            const Divider(height: 1, color: AppColors.divider),
                            const SizedBox(height: 8),
                            widget.expandedContent!,
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
