import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/trip_document.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DocumentCard — displays a single trip document row with type badge, status
// chip, expiry warning, and action menu.
// ─────────────────────────────────────────────────────────────────────────────

class DocumentCard extends StatelessWidget {
  final TripDocument doc;
  final VoidCallback?  onTap;
  final VoidCallback?  onEdit;
  final VoidCallback?  onArchive;
  final VoidCallback?  onMarkReviewed;
  final VoidCallback?  onMarkApproved;

  const DocumentCard({
    super.key,
    required this.doc,
    this.onTap,
    this.onEdit,
    this.onArchive,
    this.onMarkReviewed,
    this.onMarkApproved,
  });

  @override
  Widget build(BuildContext context) {
    final isExpired      = doc.isExpired;
    final isExpiringSoon = doc.isExpiringSoon;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pagePaddingH,
          vertical:   AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color:        AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          border: Border.all(
            color: isExpired
                ? const Color(0xFFFCA5A5)
                : isExpiringSoon
                    ? const Color(0xFFFDE68A)
                    : AppColors.border,
          ),
          boxShadow: const [
            BoxShadow(
              color:      AppColors.shadow,
              blurRadius: 4,
              offset:     Offset(0, 1),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left accent strip — type colour
              Container(width: 3, color: doc.documentType.color),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical:   12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header row
                      Row(
                        children: [
                          _TypeBadge(type: doc.documentType),
                          const SizedBox(width: AppSpacing.sm),
                          _StatusChip(status: doc.status),
                          const Spacer(),
                          _ActionMenu(
                            doc:            doc,
                            onEdit:         onEdit,
                            onArchive:      onArchive,
                            onMarkReviewed: onMarkReviewed,
                            onMarkApproved: onMarkApproved,
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      // Title
                      Text(
                        doc.title,
                        style: AppTextStyles.heading3,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 4),

                      // Meta row
                      Wrap(
                        spacing:    12,
                        runSpacing: 3,
                        children: [
                          if (doc.fileName?.isNotEmpty ?? false)
                            _MetaItem(
                              icon:  Icons.insert_drive_file_outlined,
                              label: doc.fileName!,
                            ),
                          if (doc.fileSizeLabel.isNotEmpty)
                            _MetaItem(
                              icon:  Icons.data_usage_outlined,
                              label: doc.fileSizeLabel,
                            ),
                          if (doc.expiryDate != null)
                            _MetaItem(
                              icon:  isExpired
                                  ? Icons.error_outline_rounded
                                  : isExpiringSoon
                                      ? Icons.warning_amber_rounded
                                      : Icons.event_outlined,
                              label: 'Expires ${DateFormat('d MMM yyyy').format(doc.expiryDate!)}',
                              color: isExpired
                                  ? const Color(0xFFDC2626)
                                  : isExpiringSoon
                                      ? const Color(0xFFD97706)
                                      : null,
                            ),
                          if (doc.isClientVisible)
                            _MetaItem(
                              icon:  Icons.visibility_outlined,
                              label: 'Client visible',
                              color: AppColors.accent,
                            ),
                        ],
                      ),

                      // Expiry warning
                      if (isExpired || isExpiringSoon) ...[
                        const SizedBox(height: 6),
                        _ExpiryWarning(expired: isExpired),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _TypeBadge extends StatelessWidget {
  final DocumentType type;
  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color:        type.bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(type.icon, size: 10, color: type.color),
          const SizedBox(width: 4),
          Text(
            type.label.toUpperCase(),
            style: AppTextStyles.overline.copyWith(
              color:         type.color,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final DocumentStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color:        status.bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.label.toUpperCase(),
        style: AppTextStyles.overline.copyWith(
          color:         status.color,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color?   color;
  const _MetaItem({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textMuted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: c),
        const SizedBox(width: 3),
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(color: c),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _ExpiryWarning extends StatelessWidget {
  final bool expired;
  const _ExpiryWarning({required this.expired});

  @override
  Widget build(BuildContext context) {
    final bg     = expired ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB);
    final border = expired ? const Color(0xFFFCA5A5) : const Color(0xFFFDE68A);
    final text   = expired ? const Color(0xFFB91C1C) : const Color(0xFF92400E);
    final msg    = expired ? 'Document has expired' : 'Expiring within 30 days';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color:        bg,
        borderRadius: BorderRadius.circular(5),
        border:       Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            expired ? Icons.error_outline_rounded : Icons.warning_amber_rounded,
            size:  11,
            color: text,
          ),
          const SizedBox(width: 5),
          Text(msg, style: AppTextStyles.labelSmall.copyWith(color: text)),
        ],
      ),
    );
  }
}

class _ActionMenu extends StatelessWidget {
  final TripDocument  doc;
  final VoidCallback? onEdit;
  final VoidCallback? onArchive;
  final VoidCallback? onMarkReviewed;
  final VoidCallback? onMarkApproved;
  const _ActionMenu({
    required this.doc,
    this.onEdit,
    this.onArchive,
    this.onMarkReviewed,
    this.onMarkApproved,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (v) {
        if (v == 'edit')     onEdit?.call();
        if (v == 'archive')  onArchive?.call();
        if (v == 'reviewed') onMarkReviewed?.call();
        if (v == 'approved') onMarkApproved?.call();
        if (v == 'open')     _openUrl(doc.fileUrl);
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'open',
          child: Row(children: [
            Icon(Icons.open_in_new_rounded, size: 15, color: AppColors.textSecondary),
            SizedBox(width: 8),
            Text('Open / Download'),
          ]),
        ),
        if (onEdit != null)
          const PopupMenuItem(
            value: 'edit',
            child: Row(children: [
              Icon(Icons.edit_outlined, size: 15, color: AppColors.textSecondary),
              SizedBox(width: 8),
              Text('Edit'),
            ]),
          ),
        if (onMarkReviewed != null &&
            doc.status == DocumentStatus.uploaded)
          const PopupMenuItem(
            value: 'reviewed',
            child: Row(children: [
              Icon(Icons.rate_review_outlined, size: 15, color: AppColors.textSecondary),
              SizedBox(width: 8),
              Text('Mark Reviewed'),
            ]),
          ),
        if (onMarkApproved != null &&
            doc.status != DocumentStatus.approved)
          const PopupMenuItem(
            value: 'approved',
            child: Row(children: [
              Icon(Icons.check_circle_outline_rounded, size: 15, color: Color(0xFF16A34A)),
              SizedBox(width: 8),
              Text('Mark Approved', style: TextStyle(color: Color(0xFF16A34A))),
            ]),
          ),
        const PopupMenuDivider(),
        if (onArchive != null)
          const PopupMenuItem(
            value: 'archive',
            child: Row(children: [
              Icon(Icons.archive_outlined, size: 15, color: AppColors.textMuted),
              SizedBox(width: 8),
              Text('Archive', style: TextStyle(color: AppColors.textMuted)),
            ]),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.all(4),
        child: const Icon(
          Icons.more_horiz_rounded,
          size:  16,
          color: AppColors.textMuted,
        ),
      ),
    );
  }

  void _openUrl(String url) {
    // URL launching requires url_launcher — log for now
    debugPrint('[DocumentCard] open: $url');
  }
}
