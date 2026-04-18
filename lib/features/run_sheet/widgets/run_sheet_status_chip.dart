import 'package:flutter/material.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/run_sheet_item.dart';

class RunSheetStatusChip extends StatelessWidget {
  final RunSheetStatus status;
  final bool compact;

  const RunSheetStatusChip({
    super.key,
    required this.status,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical:   compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color:        status.bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: compact ? 9 : 10, color: status.color),
          SizedBox(width: compact ? 3 : 4),
          Text(
            status.label,
            style: AppTextStyles.overline.copyWith(
              color:         status.color,
              fontSize:      compact ? 9 : 10,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quick status change button ──────────────────────────────────────────────

class RunSheetStatusButton extends StatelessWidget {
  final RunSheetStatus current;
  final ValueChanged<RunSheetStatus> onChanged;

  const RunSheetStatusButton({
    super.key,
    required this.current,
    required this.onChanged,
  });

  static const _options = RunSheetStatus.values;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<RunSheetStatus>(
      initialValue: current,
      onSelected:   onChanged,
      tooltip:      'Change status',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      itemBuilder: (_) => _options.map((s) {
        final active = s == current;
        return PopupMenuItem(
          value: s,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Icon(s.icon, size: 13, color: s.color),
              const SizedBox(width: 8),
              Text(
                s.label,
                style: TextStyle(
                  fontSize:   13,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  color:      active ? s.color : const Color(0xFF374151),
                ),
              ),
              if (active) ...[
                const Spacer(),
                Icon(Icons.check_rounded, size: 13, color: s.color),
              ],
            ],
          ),
        );
      }).toList(),
      child: RunSheetStatusChip(status: current),
    );
  }
}
