import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../data/models/approval_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ApprovalStatusChip — compact read-only chip
// ─────────────────────────────────────────────────────────────────────────────

class ApprovalStatusChip extends StatelessWidget {
  final ApprovalStatus status;
  final bool compact;

  const ApprovalStatusChip({
    super.key,
    required this.status,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: status.bgColor,
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: compact ? 10 : 11, color: status.textColor),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: AppTextStyles.labelSmall.copyWith(
              color: status.textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ApprovalActionBar — shown in detail panels; respects role permissions
// ─────────────────────────────────────────────────────────────────────────────

class ApprovalActionBar extends StatelessWidget {
  final ApprovalStatus current;
  final bool canApprove;     // from RoleService
  final bool canSubmit;      // from RoleService
  final VoidCallback onSubmitForReview;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback? onReturnToDraft;

  const ApprovalActionBar({
    super.key,
    required this.current,
    required this.canApprove,
    required this.canSubmit,
    required this.onSubmitForReview,
    required this.onApprove,
    required this.onReject,
    this.onReturnToDraft,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: current.bgColor.withAlpha(80),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: current.textColor.withAlpha(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ApprovalStatusChip(status: current),
              const Spacer(),
              if (_showReturnToDraft)
                _TextAction(
                  label: 'Return to Draft',
                  color: AppColors.textSecondary,
                  onTap: onReturnToDraft ?? () {},
                ),
            ],
          ),
          if (_showActions) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                if (_showSubmit)
                  Expanded(
                    child: _ActionBtn(
                      label: 'Submit for Review',
                      icon: Icons.send_rounded,
                      bg: const Color(0xFFFEF3C7),
                      fg: const Color(0xFF92400E),
                      onTap: onSubmitForReview,
                    ),
                  ),
                if (_showSubmit && _showApproveReject)
                  const SizedBox(width: AppSpacing.sm),
                if (_showApproveReject) ...[
                  Expanded(
                    child: _ActionBtn(
                      label: 'Approve',
                      icon: Icons.check_rounded,
                      bg: const Color(0xFFD1FAE5),
                      fg: const Color(0xFF065F46),
                      onTap: onApprove,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _ActionBtn(
                      label: 'Reject',
                      icon: Icons.close_rounded,
                      bg: const Color(0xFFFEE2E2),
                      fg: const Color(0xFF991B1B),
                      onTap: onReject,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  bool get _showSubmit =>
      canSubmit && current == ApprovalStatus.draft;

  bool get _showApproveReject =>
      canApprove && current == ApprovalStatus.pendingReview;

  bool get _showReturnToDraft =>
      canApprove &&
      (current == ApprovalStatus.approved ||
       current == ApprovalStatus.rejected);

  bool get _showActions => _showSubmit || _showApproveReject;
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.bg,
    required this.fg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 5),
            Text(label,
                style: AppTextStyles.labelMedium.copyWith(
                    color: fg, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _TextAction extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _TextAction({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(label,
          style: AppTextStyles.labelSmall.copyWith(
              color: color, decoration: TextDecoration.underline)),
    );
  }
}
