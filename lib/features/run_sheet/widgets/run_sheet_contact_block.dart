import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/run_sheet_item.dart';

class RunSheetContactBlock extends StatelessWidget {
  final RunSheetItem item;

  const RunSheetContactBlock({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final hasPrimary = item.primaryContactName?.isNotEmpty ?? false;
    final hasBackup  = item.backupContactName?.isNotEmpty  ?? false;
    if (!hasPrimary && !hasBackup) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7FF),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.contacts_outlined,
                  size: 11, color: Color(0xFF1D4ED8)),
              const SizedBox(width: 5),
              Text(
                'CONTACTS',
                style: AppTextStyles.overline.copyWith(
                  color: const Color(0xFF1D4ED8),
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (hasPrimary)
            _ContactRow(
              label: 'Primary',
              name:  item.primaryContactName!,
              phone: item.primaryContactPhone,
            ),
          if (hasPrimary && hasBackup)
            const SizedBox(height: 6),
          if (hasBackup)
            _ContactRow(
              label: 'Backup',
              name:  item.backupContactName!,
              phone: item.backupContactPhone,
              muted: true,
            ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final String  label;
  final String  name;
  final String? phone;
  final bool    muted;

  const _ContactRow({
    required this.label,
    required this.name,
    this.phone,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    final nameColor = muted ? AppColors.textSecondary : AppColors.textPrimary;
    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted),
          ),
        ),
        Expanded(
          child: Text(
            name,
            style: AppTextStyles.bodySmall.copyWith(
              color:      nameColor,
              fontWeight: muted ? FontWeight.w400 : FontWeight.w600,
            ),
          ),
        ),
        if (phone != null && phone!.isNotEmpty)
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: phone!));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$phone copied'),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.phone_rounded,
                      size: 11, color: Color(0xFF1D4ED8)),
                  const SizedBox(width: 4),
                  Text(
                    phone!,
                    style: AppTextStyles.labelSmall.copyWith(
                      color:      const Color(0xFF1D4ED8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
