import 'package:flutter/material.dart';
import '../../../data/models/itinerary_models.dart';
import '../client_view_theme.dart';
import '../services/itinerary_copy_formatter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AccommodationFeatureSection
//
// Premium property introduction block for hotel/accommodation items.
// Feels like a considered property introduction, not a database record.
//
// Layout:
//   YOUR ACCOMMODATION          (gold label)
//   ──────────────────          (hairline)
//   [Property Name]             (large light heading)
//   [description italic]        (optional)
//   Feature · Feature · Feature (dot-separated meta)
// ─────────────────────────────────────────────────────────────────────────────

class AccommodationFeatureSection extends StatelessWidget {
  final ItineraryItem item;

  const AccommodationFeatureSection({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    // The supplier name is the property — prefer it over the item title
    final propertyName = (item.supplierName != null &&
            item.supplierName!.trim().isNotEmpty)
        ? item.supplierName!.trim()
        : item.title;

    final description = ItineraryCopyFormatter.formatDescription(item.description);
    final location    = item.location?.trim();
    final timeStr     = ItineraryCopyFormatter.formatTimeRange(item.startTime, item.endTime);

    return Padding(
      padding: const EdgeInsets.only(top: ClientViewTheme.accomTopPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label row + rule
          Row(
            children: [
              Text('YOUR ACCOMMODATION', style: ClientViewTheme.accomLabel),
              const SizedBox(width: 16),
              Expanded(
                child: Container(height: 0.5, color: ClientViewTheme.gold.withAlpha(80)),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Check-in time if known (understated)
          if (timeStr != null) ...[
            Text(timeStr, style: ClientViewTheme.itemTime),
            const SizedBox(height: 6),
          ],

          // Property name
          Text(propertyName, style: ClientViewTheme.accomName),

          // Description
          if (description != null) ...[
            const SizedBox(height: 10),
            Text(description, style: ClientViewTheme.accomDesc),
          ],

          // Location meta
          if (location != null && location.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(location, style: ClientViewTheme.accomFeatures),
          ],

          const SizedBox(height: ClientViewTheme.accomTopPad),

          // Closing hairline
          Container(height: 0.5, color: ClientViewTheme.hairline),
        ],
      ),
    );
  }
}
