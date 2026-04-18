import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/itinerary_models.dart';

/// Premium client-facing card for a single itinerary item.
///
/// Design principles:
/// - White card, generous padding, no border chrome
/// - Left colour strip tied to item type (subtle, 3px)
/// - Type shown as elegant all-caps overline
/// - Title large and confident
/// - Supporting details in muted secondary text
/// - No internal fields (status, notes, task IDs) exposed
class ClientItemCard extends StatelessWidget {
  final ItineraryItem item;

  const ClientItemCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final typeColor = item.type.color;
    final timeStr   = _timeRange(item);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left colour strip
            Container(width: 3, color: typeColor),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Type label + time on same row
                    Row(
                      children: [
                        _TypeBadge(type: item.type),
                        const Spacer(),
                        if (timeStr != null)
                          Text(timeStr,
                              style: AppTextStyles.labelMedium.copyWith(
                                  color: AppColors.textMuted)),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Title
                    Text(
                      item.title,
                      style: AppTextStyles.heading2.copyWith(
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary),
                    ),

                    // Description
                    if (item.description != null &&
                        item.description!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        item.description!,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.55,
                        ),
                      ),
                    ],

                    // Location + supplier row
                    if (_hasDetail(item)) ...[
                      const SizedBox(height: 12),
                      _DetailRow(item: item),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static bool _hasDetail(ItineraryItem item) =>
      (item.location != null && item.location!.isNotEmpty) ||
      (item.supplierName != null && item.supplierName!.isNotEmpty);
}

// ── Type badge ────────────────────────────────────────────────────────────────

class _TypeBadge extends StatelessWidget {
  final ItemType type;
  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: type.color.withAlpha(18),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        type.label.toUpperCase(),
        style: AppTextStyles.overline.copyWith(
          color: type.color,
          letterSpacing: 1.2,
          fontSize: 9.5,
        ),
      ),
    );
  }
}

// ── Detail row (location + supplier) ─────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final ItineraryItem item;
  const _DetailRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final hasLocation = item.location != null && item.location!.isNotEmpty;
    final hasSupplier = item.supplierName != null && item.supplierName!.isNotEmpty;

    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: 4,
      children: [
        if (hasLocation)
          _DetailChip(
            icon: Icons.location_on_outlined,
            text: item.location!,
          ),
        if (hasSupplier)
          _DetailChip(
            icon: Icons.storefront_outlined,
            text: item.supplierName!,
          ),
      ],
    );
  }
}

class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _DetailChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(
          text,
          style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted),
        ),
      ],
    );
  }
}

// ── Time helpers ──────────────────────────────────────────────────────────────

String? _timeRange(ItineraryItem item) {
  final s = item.startTime;
  final e = item.endTime;
  if (s == null) return null;
  final start = _fmt(s);
  if (e == null) return start;
  return '$start – ${_fmt(e)}';
}

String _fmt(TimeOfDay t) {
  final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
  final m = t.minute.toString().padLeft(2, '0');
  final p = t.period == DayPeriod.am ? 'am' : 'pm';
  return '$h:$m $p';
}
