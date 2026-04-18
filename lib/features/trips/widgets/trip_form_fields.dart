import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/team_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Shared form widgets used by CreateTripScreen and EditTripScreen.
// ─────────────────────────────────────────────────────────────────────────────

class TripSectionLabel extends StatelessWidget {
  final String label;
  const TripSectionLabel({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTextStyles.labelMedium.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class TripFormTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String? Function(String?)? validator;
  final int maxLines;

  const TripFormTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.validator,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLines,
      style: AppTextStyles.bodyMedium,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.bodySmall,
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: const BorderSide(color: AppColors.statusBlockedText),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: const BorderSide(
              color: AppColors.statusBlockedText, width: 1.5),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class TripDateButton extends StatelessWidget {
  final DateTime? date;
  final String hint;
  final VoidCallback onTap;

  const TripDateButton({
    super.key,
    required this.date,
    required this.hint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 15, color: AppColors.textMuted),
            const SizedBox(width: AppSpacing.sm),
            Text(
              date != null ? DateFormat('d MMM yyyy').format(date!) : hint,
              style:
                  date != null ? AppTextStyles.bodyMedium : AppTextStyles.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class TripGuestCounter extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const TripGuestCounter(
      {super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CounterBtn(
              icon: Icons.remove,
              onTap: value > 1 ? () => onChanged(value - 1) : null),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: AppSpacing.base),
            child: Text('$value',
                style: AppTextStyles.bodyMedium
                    .copyWith(fontWeight: FontWeight.w600)),
          ),
          _CounterBtn(
              icon: Icons.add,
              onTap: value < 50 ? () => onChanged(value + 1) : null),
        ],
      ),
    );
  }
}

class _CounterBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _CounterBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 46,
        decoration: const BoxDecoration(color: AppColors.surfaceAlt),
        child: Icon(
          icon,
          size: 16,
          color: onTap != null ? AppColors.textSecondary : AppColors.textMuted,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class TripLeadDropdown extends StatelessWidget {
  final String? selected;
  final List<TeamMember> members;
  final ValueChanged<String?> onChanged;

  const TripLeadDropdown({
    super.key,
    required this.selected,
    required this.members,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final validSelected =
        members.any((m) => m.userId == selected) ? selected : null;

    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: validSelected,
          hint: Text(
            members.isEmpty ? 'Loading members…' : 'Select team member',
            style: AppTextStyles.bodySmall,
          ),
          isExpanded: true,
          icon: const Icon(Icons.unfold_more_rounded,
              size: 18, color: AppColors.textMuted),
          style: AppTextStyles.bodyMedium,
          items: members.map((m) {
            final name = m.profile?.name ?? m.userId;
            return DropdownMenuItem(
              value: m.userId,
              child: Text(name, style: AppTextStyles.bodyMedium),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
