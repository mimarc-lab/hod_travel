import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/itinerary_models.dart';
import '../services/map_view_mapper_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MapPinDetailCard
// ─────────────────────────────────────────────────────────────────────────────

/// Floating card that appears over the map when a pin is tapped.
///
/// Designed to sit in the bottom-right corner of the map area.
/// Slides in/out with an animated vertical offset.
/// Does NOT expose internal notes, task links, or approval status.
class MapPinDetailCard extends StatelessWidget {
  final TripMapMarker marker;
  final VoidCallback  onClose;
  final VoidCallback? onMovePin;

  const MapPinDetailCard({
    super.key,
    required this.marker,
    required this.onClose,
    this.onMovePin,
  });

  @override
  Widget build(BuildContext context) {
    final item      = marker.item;
    final day       = marker.day;
    final typeColor = item.type.color;

    return Container(
      width: 276,
      decoration: BoxDecoration(
        color:        AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: AppColors.border, width: 0.75),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withAlpha(22),
            blurRadius: 24,
            offset:     const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Type accent strip + header ─────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 10),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: typeColor, width: 3),
              ),
              borderRadius: const BorderRadius.only(
                topLeft:  Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Type badge
                      _TypeBadge(item: item),
                      const SizedBox(height: 6),
                      // Title
                      Text(
                        item.title,
                        style: AppTextStyles.heading3.copyWith(fontSize: 14),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Close button
                GestureDetector(
                  onTap: onClose,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(
                      Icons.close_rounded,
                      size:  18,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, thickness: 1, color: AppColors.divider),

          // ── Body ─────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Day + city reference
                _MetaRow(
                  icon:  Icons.calendar_today_outlined,
                  text:  _dayLabel(day),
                ),

                // Time
                if (item.startTime != null) ...[
                  const SizedBox(height: 5),
                  _MetaRow(
                    icon: Icons.schedule_outlined,
                    text: _timeLabel(item),
                  ),
                ],

                // Transport route: show "A → B" instead of a plain location
                if (marker.isTransportIcon) ...[
                  const SizedBox(height: 5),
                  _MetaRow(
                    icon: Icons.route_outlined,
                    text: _routeLabel(marker),
                  ),
                ] else if (item.location != null &&
                    item.location!.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  _MetaRow(
                    icon: Icons.place_outlined,
                    text: item.location!,
                  ),
                ],

                // Supplier
                if (item.supplierName != null &&
                    item.supplierName!.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  _MetaRow(
                    icon: Icons.storefront_outlined,
                    text: item.supplierName!,
                  ),
                ],

                // Description
                if (item.description != null &&
                    item.description!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Divider(height: 1, thickness: 1, color: AppColors.divider),
                  const SizedBox(height: 10),
                  Text(
                    item.description!,
                    style: AppTextStyles.bodySmall.copyWith(
                      height: 1.5,
                      fontSize: 12,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                // Move Pin button (location pins only, not transport)
                if (onMovePin != null && !marker.isTransportIcon) ...[
                  const SizedBox(height: 12),
                  Divider(height: 1, thickness: 1, color: AppColors.divider),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: onMovePin,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.my_location_rounded,
                            size: 13, color: AppColors.accent),
                        const SizedBox(width: 6),
                        Text(
                          'Move pin to exact location',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Extracts "A → B" from the marker's title for the detail card.
  /// Falls back to the raw title when no "to" separator is found.
  String _routeLabel(TripMapMarker m) {
    final title = m.item.title;
    // "from A to B" → "A → B"
    final fromToRe =
        RegExp(r'\bfrom\s+(.+?)\s+to\s+(.+)', caseSensitive: false);
    final m1 = fromToRe.firstMatch(title);
    if (m1 != null) return '${m1.group(1)!.trim()}  →  ${m1.group(2)!.trim()}';
    // "A to B" → "A → B"
    final toRe = RegExp(r'^(.+?)\s+to\s+(.+)$', caseSensitive: false);
    final m2 = toRe.firstMatch(title);
    if (m2 != null) return '${m2.group(1)!.trim()}  →  ${m2.group(2)!.trim()}';
    return title;
  }

  String _dayLabel(TripDayRef day) {
    final dateStr = day.date != null
        ? '  ·  ${DateFormat('d MMM').format(day.date!)}'
        : '';
    return 'Day ${day.number}  ·  ${day.city}$dateStr';
  }

  String _timeLabel(ItineraryItem item) {
    final start = _fmtTime(item.startTime!);
    if (item.endTime == null) return start;
    return '$start – ${_fmtTime(item.endTime!)}';
  }

  static String _fmtTime(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final p = t.period.name; // 'am' or 'pm'
    return '$h:$m $p';
  }
}

// ── _TypeBadge ────────────────────────────────────────────────────────────────

class _TypeBadge extends StatelessWidget {
  final ItineraryItem item;
  const _TypeBadge({required this.item});

  @override
  Widget build(BuildContext context) {
    final color = item.type.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color:        color.withAlpha(20),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(item.type.icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            item.type.label.toUpperCase(),
            style: AppTextStyles.overline.copyWith(
              color:         color,
              fontSize:      9,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

// ── _MetaRow ──────────────────────────────────────────────────────────────────

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String   text;
  const _MetaRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 12, color: AppColors.textMuted),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodySmall.copyWith(fontSize: 12),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
