import 'package:flutter/material.dart';
import '../../core/constants/app_text_styles.dart';
import '../../data/models/user_model.dart';

/// Small colored badge showing a user's AppRole.
class RoleBadge extends StatelessWidget {
  final AppRole role;
  final bool compact;

  const RoleBadge({super.key, required this.role, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors(role);
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 8, vertical: compact ? 2 : 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        role.label,
        style: AppTextStyles.labelSmall.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
          fontSize: compact ? 10 : 11,
        ),
      ),
    );
  }

  (Color, Color) _colors(AppRole role) {
    switch (role) {
      case AppRole.admin:
        return (const Color(0xFFEDE9FE), const Color(0xFF5B21B6));
      case AppRole.tripLead:
        return (const Color(0xFFDBEAFE), const Color(0xFF1D4ED8));
      case AppRole.staff:
        return (const Color(0xFFF3F4F6), const Color(0xFF374151));
      case AppRole.finance:
        return (const Color(0xFFD1FAE5), const Color(0xFF065F46));
    }
  }
}
