import 'package:flutter/material.dart';
import '../design_system/radius_tokens.dart';
import '../design_system/spacing_tokens.dart';
import '../design_system/typography_tokens.dart';

/// Universal operational status chip.
///
/// Caller supplies background + text colors directly — this widget is
/// intentionally data-model agnostic so it works across Tasks, Budget,
/// Suppliers, Run Sheets, and any future module.
class AdaptiveStatusChip extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final bool compact;

  const AdaptiveStatusChip({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact
            ? AdaptiveSpacing.chipPaddingHCompact
            : AdaptiveSpacing.chipPaddingH,
        vertical: compact
            ? AdaptiveSpacing.chipPaddingVCompact
            : AdaptiveSpacing.chipPaddingV,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: AdaptiveRadius.chipSmallBorder,
      ),
      child: Text(
        label,
        style: (compact
                ? AdaptiveTypography.chipLabelCompact
                : AdaptiveTypography.chipLabel)
            .copyWith(color: textColor),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
