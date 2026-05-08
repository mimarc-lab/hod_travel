import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../data/models/trip_component_model.dart';
import '../../../shared/adaptive_table/adaptive_column.dart';
import '../../../shared/adaptive_table/adaptive_mobile_card.dart';
import '../../../shared/adaptive_table/adaptive_row.dart';
import '../../../shared/adaptive_table/adaptive_row_actions.dart';
import '../../../shared/adaptive_table/adaptive_status_chip.dart';
import '../../../shared/design_system/responsive_breakpoints.dart';
import '../../../shared/design_system/typography_tokens.dart';

// ── Column definitions ─────────────────────────────────────────────────────────

/// Adaptive column set for trip components.
///
/// PRIMARY   → always visible   (Title, Status)
/// SECONDARY → tablet + desktop (Supplier, Date, Start, City)
/// TERTIARY  → desktop only     (End Time, Contact, Booking Ref)
List<AdaptiveColumn<TripComponent>> componentColumns() => [
      AdaptiveColumn<TripComponent>(
        key: 'title',
        label: 'Title',
        priority: ColumnPriority.primary,
        flex: 3,
        builder: (item) => _TitleCell(item: item),
      ),
      AdaptiveColumn<TripComponent>(
        key: 'status',
        label: 'Status',
        priority: ColumnPriority.primary,
        width: 110,
        builder: (item) => AdaptiveStatusChip(
          label: item.status.label,
          backgroundColor: item.status.bgColor,
          textColor: item.status.color,
          compact: true,
        ),
      ),
      AdaptiveColumn<TripComponent>(
        key: 'supplier',
        label: 'Supplier',
        priority: ColumnPriority.secondary,
        width: 140,
        builder: (item) => Text(
          item.supplierName ?? '—',
          style: item.supplierName != null
              ? AdaptiveTypography.secondaryCell
              : AdaptiveTypography.tertiaryCell,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      AdaptiveColumn<TripComponent>(
        key: 'date',
        label: 'Date',
        priority: ColumnPriority.secondary,
        width: 90,
        builder: (item) => item.startDate != null
            ? Text(
                DateFormat('d MMM').format(item.startDate!),
                style: AdaptiveTypography.secondaryCell,
              )
            : Text('—', style: AdaptiveTypography.tertiaryCell),
      ),
      AdaptiveColumn<TripComponent>(
        key: 'startTime',
        label: 'Start',
        priority: ColumnPriority.secondary,
        width: 80,
        builder: (item) => Text(
          _fmt12(item.startTime),
          style: item.startTime != null
              ? AdaptiveTypography.secondaryCell
              : AdaptiveTypography.tertiaryCell,
        ),
      ),
      AdaptiveColumn<TripComponent>(
        key: 'city',
        label: 'City',
        priority: ColumnPriority.secondary,
        width: 90,
        builder: (item) => Text(
          item.city ?? '—',
          style: item.city != null
              ? AdaptiveTypography.secondaryCell
              : AdaptiveTypography.tertiaryCell,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      AdaptiveColumn<TripComponent>(
        key: 'endTime',
        label: 'End',
        priority: ColumnPriority.tertiary,
        width: 80,
        builder: (item) => Text(
          _fmt12(item.endTime),
          style: item.endTime != null
              ? AdaptiveTypography.secondaryCell
              : AdaptiveTypography.tertiaryCell,
        ),
      ),
      AdaptiveColumn<TripComponent>(
        key: 'contact',
        label: 'Contact',
        priority: ColumnPriority.tertiary,
        width: 140,
        builder: (item) => item.primaryContactName != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.primaryContactName!,
                    style: AdaptiveTypography.secondaryCell,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.primaryContactPhone != null)
                    Text(
                      item.primaryContactPhone!,
                      style: AdaptiveTypography.tertiaryCell,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              )
            : Text('—', style: AdaptiveTypography.tertiaryCell),
      ),
      AdaptiveColumn<TripComponent>(
        key: 'bookingRef',
        label: 'Booking Ref.',
        priority: ColumnPriority.tertiary,
        width: 130,
        builder: (item) => Text(
          item.supplierBookingReference ?? '—',
          style: item.supplierBookingReference != null
              ? AdaptiveTypography.tertiaryCell
                  .copyWith(fontWeight: FontWeight.w500)
              : AdaptiveTypography.tertiaryCell,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ];

// ── ComponentRow — adaptive entry point ───────────────────────────────────────

/// Renders a [TripComponent] as:
/// - Desktop/Tablet: [AdaptiveRow] with adaptive columns
/// - Mobile: [AdaptiveMobileCard] with progressive disclosure
class ComponentRow extends StatelessWidget {
  final TripComponent component;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ComponentRow({
    super.key,
    required this.component,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final layout = AdaptiveBreakpoints.layoutOf(context);

    final actionsWidget = AdaptiveRowActions<TripComponent>(
      item: component,
      actions: [
        AdaptiveAction<TripComponent>(
          label: 'Edit',
          icon: Icons.edit_outlined,
          onTap: (_) => onEdit(),
        ),
        AdaptiveAction<TripComponent>(
          label: 'Delete',
          icon: Icons.delete_outline_rounded,
          isDestructive: true,
          onTap: (_) => onDelete(),
        ),
      ],
    );

    if (layout == Layout.mobile) {
      return AdaptiveMobileCard(
        onTap: onEdit,
        accentBar: component.effectiveColor,
        primaryContent: _MobilePrimaryContent(component: component),
        trailingChip: AdaptiveStatusChip(
          label: component.status.label,
          backgroundColor: component.status.bgColor,
          textColor: component.status.color,
          compact: true,
        ),
        metaRow: _MobileMetaRow(component: component),
        actions: actionsWidget,
      );
    }

    return AdaptiveRow<TripComponent>(
      item: component,
      columns: componentColumns(),
      layout: layout,
      onTap: onEdit,
      accentBar: component.effectiveColor,
      actionsWidget: actionsWidget,
    );
  }
}

// ── ComponentColumnHeader ─────────────────────────────────────────────────────

/// Column label row aligned to [ComponentRow] desktop layout. Hidden on mobile.
class ComponentColumnHeader extends StatelessWidget {
  final double hPad;
  const ComponentColumnHeader({super.key, required this.hPad});

  @override
  Widget build(BuildContext context) {
    final layout = AdaptiveBreakpoints.layoutOf(context);
    if (layout == Layout.mobile) return const SizedBox.shrink();

    final cols =
        componentColumns().where((c) => c.visibleFor(layout)).toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(hPad + 19, 6, hPad + 36, 4),
      child: Row(
        children: [
          for (int i = 0; i < cols.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            cols[i].sized(
              Text(cols[i].label, style: AdaptiveTypography.columnHeader),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Title column cell (desktop/tablet) ───────────────────────────────────────

class _TitleCell extends StatelessWidget {
  final TripComponent item;
  const _TitleCell({required this.item});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          item.title,
          style: AdaptiveTypography.primaryCell.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          item.componentType.label,
          style: AdaptiveTypography.primarySubCell,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ── Type icon tile ────────────────────────────────────────────────────────────

class _TypeIconTile extends StatelessWidget {
  final ComponentType type;
  final IconData effectiveIcon;
  final Color effectiveColor;

  const _TypeIconTile({
    required this.type,
    required this.effectiveIcon,
    required this.effectiveColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: effectiveColor.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(effectiveIcon, size: 15, color: effectiveColor),
    );
  }
}

// ── Mobile card content ───────────────────────────────────────────────────────

class _MobilePrimaryContent extends StatelessWidget {
  final TripComponent component;
  const _MobilePrimaryContent({required this.component});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TypeIconTile(
          type: component.componentType,
          effectiveIcon: component.effectiveIcon,
          effectiveColor: component.effectiveColor,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                component.title,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF111111),
                  height: 1.3,
                  letterSpacing: -0.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (component.supplierName != null &&
                  component.supplierName!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  component.supplierName!,
                  style: AdaptiveTypography.primarySubCell,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MobileMetaRow extends StatelessWidget {
  final TripComponent component;
  const _MobileMetaRow({required this.component});

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    if (component.startDate != null) {
      parts.add(DateFormat('d MMM').format(component.startDate!));
    }
    if (component.city != null && component.city!.isNotEmpty) {
      parts.add(component.city!);
    }
    if (component.startTime != null) {
      parts.add(_fmt12(component.startTime));
    }
    if (parts.isEmpty) return const SizedBox.shrink();

    return Text(
      parts.join(' · '),
      style: AdaptiveTypography.tertiaryCell,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

// ── Time formatter ────────────────────────────────────────────────────────────

/// Converts "HH:MM" or "HH:MM:SS" 24-hour string to "h:mm AM/PM".
/// Returns "—" when [raw] is null or unparseable.
String _fmt12(String? raw) {
  if (raw == null) return '—';
  final parts = raw.split(':');
  if (parts.length < 2) return raw;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return raw;
  final tod    = TimeOfDay(hour: h, minute: m);
  final hh     = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
  final mm     = m.toString().padLeft(2, '0');
  final period = tod.period == DayPeriod.am ? 'AM' : 'PM';
  return '$hh:$mm $period';
}
