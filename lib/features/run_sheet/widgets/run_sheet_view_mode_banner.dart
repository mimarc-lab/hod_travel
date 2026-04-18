import 'package:flutter/material.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/run_sheet_view_mode.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RunSheetViewModeBanner
//
// Shown at the top of the run sheet when viewing in a non-director role.
// Makes the active view mode immediately obvious to the viewer.
// ─────────────────────────────────────────────────────────────────────────────

class RunSheetViewModeBanner extends StatelessWidget {
  final RunSheetViewMode mode;

  const RunSheetViewModeBanner({super.key, required this.mode});

  @override
  Widget build(BuildContext context) {
    final color   = mode.color;
    final bgColor = mode.bgColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical:   10,
      ),
      decoration: BoxDecoration(
        color:  bgColor,
        border: Border(bottom: BorderSide(color: color.withAlpha(60))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color:        color.withAlpha(18),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(mode.icon, size: 14, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${mode.label} View',
                  style: AppTextStyles.labelSmall.copyWith(
                    color:      color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  mode.description,
                  style: AppTextStyles.labelSmall.copyWith(
                    color:      color.withAlpha(180),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          // Access scope pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color:        color.withAlpha(18),
              borderRadius: BorderRadius.circular(20),
              border:       Border.all(color: color.withAlpha(60)),
            ),
            child: Text(
              mode.accessScope,
              style: AppTextStyles.overline.copyWith(
                color:         color,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
