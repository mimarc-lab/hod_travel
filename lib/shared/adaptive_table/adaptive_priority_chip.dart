import 'package:flutter/material.dart';
import '../design_system/radius_tokens.dart';
import '../design_system/spacing_tokens.dart';
import '../design_system/typography_tokens.dart';

/// Generic priority tier — maps cleanly from TaskPriority, SupplierTier,
/// or any future priority enum via the static [from] factory helpers.
enum AdaptivePriority { low, medium, high, critical }

extension AdaptivePriorityDisplay on AdaptivePriority {
  String get label => switch (this) {
        AdaptivePriority.low      => 'Low',
        AdaptivePriority.medium   => 'Medium',
        AdaptivePriority.high     => 'High',
        AdaptivePriority.critical => 'Critical',
      };

  // Muted palette — avoids aggressive SaaS neons
  Color get backgroundColor => switch (this) {
        AdaptivePriority.low      => const Color(0xFFF3F4F6), // cool gray
        AdaptivePriority.medium   => const Color(0xFFFEF3C7), // muted gold
        AdaptivePriority.high     => const Color(0xFFFEE2E2), // muted red
        AdaptivePriority.critical => const Color(0xFFFFDDD5), // deeper red
      };

  Color get textColor => switch (this) {
        AdaptivePriority.low      => const Color(0xFF6B7280),
        AdaptivePriority.medium   => const Color(0xFF92400E),
        AdaptivePriority.high     => const Color(0xFF991B1B),
        AdaptivePriority.critical => const Color(0xFF7F1D1D),
      };
}

/// Priority indicator chip with optional dot prefix.
class AdaptivePriorityChip extends StatelessWidget {
  final AdaptivePriority priority;
  final bool compact;
  final bool showDot;

  const AdaptivePriorityChip({
    super.key,
    required this.priority,
    this.compact = false,
    this.showDot = false,
  });

  /// Convenience factory: map a string value like 'high' → AdaptivePriority.
  static AdaptivePriority fromString(String v) => switch (v.toLowerCase()) {
        'low'      => AdaptivePriority.low,
        'medium'   => AdaptivePriority.medium,
        'high'     => AdaptivePriority.high,
        'critical' => AdaptivePriority.critical,
        _          => AdaptivePriority.medium,
      };

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
        color: priority.backgroundColor,
        borderRadius: AdaptiveRadius.chipSmallBorder,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: priority.textColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            priority.label,
            style: (compact
                    ? AdaptiveTypography.chipLabelCompact
                    : AdaptiveTypography.chipLabel)
                .copyWith(color: priority.textColor),
          ),
        ],
      ),
    );
  }
}
