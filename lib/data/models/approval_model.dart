import 'package:flutter/material.dart';

enum ApprovalStatus { draft, pendingReview, approved, rejected }

/// Parse a DB approval_status string to [ApprovalStatus].
ApprovalStatus approvalStatusFromDb(String s) => switch (s) {
  'ready_for_review' => ApprovalStatus.pendingReview,
  'approved'         => ApprovalStatus.approved,
  'rejected'         => ApprovalStatus.rejected,
  _                  => ApprovalStatus.draft,
};

extension ApprovalStatusDisplay on ApprovalStatus {
  String get dbValue => switch (this) {
        ApprovalStatus.draft         => 'draft',
        ApprovalStatus.pendingReview => 'ready_for_review',
        ApprovalStatus.approved      => 'approved',
        ApprovalStatus.rejected      => 'rejected',
      };

  String get label {
    switch (this) {
      case ApprovalStatus.draft:         return 'Draft';
      case ApprovalStatus.pendingReview: return 'Pending Review';
      case ApprovalStatus.approved:      return 'Approved';
      case ApprovalStatus.rejected:      return 'Rejected';
    }
  }

  IconData get icon {
    switch (this) {
      case ApprovalStatus.draft:         return Icons.edit_note_rounded;
      case ApprovalStatus.pendingReview: return Icons.hourglass_empty_rounded;
      case ApprovalStatus.approved:      return Icons.check_circle_outline_rounded;
      case ApprovalStatus.rejected:      return Icons.cancel_outlined;
    }
  }

  Color get bgColor {
    switch (this) {
      case ApprovalStatus.draft:         return const Color(0xFFF3F4F6);
      case ApprovalStatus.pendingReview: return const Color(0xFFFEF3C7);
      case ApprovalStatus.approved:      return const Color(0xFFD1FAE5);
      case ApprovalStatus.rejected:      return const Color(0xFFFEE2E2);
    }
  }

  Color get textColor {
    switch (this) {
      case ApprovalStatus.draft:         return const Color(0xFF6B7280);
      case ApprovalStatus.pendingReview: return const Color(0xFF92400E);
      case ApprovalStatus.approved:      return const Color(0xFF065F46);
      case ApprovalStatus.rejected:      return const Color(0xFF991B1B);
    }
  }
}
