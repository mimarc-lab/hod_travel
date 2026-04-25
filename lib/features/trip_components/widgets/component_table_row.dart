import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/trip_component_model.dart';
import '../providers/components_provider.dart';
import 'component_status_chip.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Column widths
// ─────────────────────────────────────────────────────────────────────────────

abstract class ComponentColumns {
  static const double name        = 200.0;
  static const double supplier    = 150.0;
  static const double category    = 130.0;
  static const double city        = 100.0;
  static const double serviceDate = 100.0;
  static const double startTime   =  90.0;
  static const double endTime     =  90.0;
  static const double contact     = 150.0;
  static const double status      = 110.0;
  static const double bookingRef  = 130.0;
  static const double actions     =  32.0;

  static const double totalWidth =
      name + supplier + category + city + serviceDate + startTime +
      endTime + contact + status + bookingRef + actions +
      AppSpacing.pagePaddingH * 2;
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────

class ComponentTableHeader extends StatelessWidget {
  const ComponentTableHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      color: AppColors.surfaceAlt,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePaddingH),
      child: Row(
        children: [
          _H('ITEM NAME',       ComponentColumns.name),
          _H('SUPPLIER',        ComponentColumns.supplier),
          _H('CATEGORY',        ComponentColumns.category),
          _H('CITY',            ComponentColumns.city),
          _H('SERVICE DATE',    ComponentColumns.serviceDate),
          _H('START TIME',      ComponentColumns.startTime),
          _H('END TIME',        ComponentColumns.endTime),
          _H('CONTACT ON SITE', ComponentColumns.contact),
          _H('STATUS',          ComponentColumns.status),
          _H('BOOKING REF.',    ComponentColumns.bookingRef),
          const SizedBox(width: ComponentColumns.actions),
        ],
      ),
    );
  }
}

class _H extends StatelessWidget {
  final String label;
  final double width;
  const _H(this.label, this.width);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(label,
          style: AppTextStyles.tableHeader,
          overflow: TextOverflow.ellipsis),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Desktop table row
// ─────────────────────────────────────────────────────────────────────────────

class ComponentTableRow extends StatelessWidget {
  final TripComponent component;
  final ComponentsProvider provider;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  const ComponentTableRow({
    super.key,
    required this.component,
    required this.provider,
    required this.onTap,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: AppColors.surfaceAlt,
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pagePaddingH, vertical: AppSpacing.sm),
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.divider))),
          child: Row(
            children: [
              // Item Name
              SizedBox(
                width: ComponentColumns.name,
                child: Text(component.title,
                    style: AppTextStyles.tableCell
                        .copyWith(fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis),
              ),

              // Supplier
              SizedBox(
                width: ComponentColumns.supplier,
                child: Text(component.supplierName ?? '—',
                    style: AppTextStyles.tableCell
                        .copyWith(color: component.supplierName == null
                            ? AppColors.textMuted
                            : null),
                    overflow: TextOverflow.ellipsis),
              ),

              // Category badge
              SizedBox(
                width: ComponentColumns.category,
                child: _CategoryBadge(type: component.componentType),
              ),

              // City
              SizedBox(
                width: ComponentColumns.city,
                child: Text(component.locationName ?? '—',
                    style: AppTextStyles.tableCell
                        .copyWith(color: component.locationName == null
                            ? AppColors.textMuted
                            : null),
                    overflow: TextOverflow.ellipsis),
              ),

              // Service date
              SizedBox(
                width: ComponentColumns.serviceDate,
                child: component.startDate != null
                    ? Text(
                        DateFormat('d MMM').format(component.startDate!),
                        style: AppTextStyles.tableCell,
                      )
                    : Text('—',
                        style: AppTextStyles.tableCell
                            .copyWith(color: AppColors.textMuted)),
              ),

              // Start time
              SizedBox(
                width: ComponentColumns.startTime,
                child: Text(component.startTime ?? '—',
                    style: AppTextStyles.tableCell.copyWith(
                        color: component.startTime == null
                            ? AppColors.textMuted
                            : null)),
              ),

              // End time
              SizedBox(
                width: ComponentColumns.endTime,
                child: Text(component.endTime ?? '—',
                    style: AppTextStyles.tableCell.copyWith(
                        color: component.endTime == null
                            ? AppColors.textMuted
                            : null)),
              ),

              // Contact on site
              SizedBox(
                width: ComponentColumns.contact,
                child: component.primaryContactName != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(component.primaryContactName!,
                              style: AppTextStyles.tableCell,
                              overflow: TextOverflow.ellipsis),
                          if (component.primaryContactPhone != null)
                            Text(component.primaryContactPhone!,
                                style: AppTextStyles.tableCell.copyWith(
                                    fontSize: 11,
                                    color: AppColors.textMuted),
                                overflow: TextOverflow.ellipsis),
                        ],
                      )
                    : Text('—',
                        style: AppTextStyles.tableCell
                            .copyWith(color: AppColors.textMuted)),
              ),

              // Status
              SizedBox(
                width: ComponentColumns.status,
                child: ComponentStatusChip(status: component.status, small: true),
              ),

              // Booking reference
              SizedBox(
                width: ComponentColumns.bookingRef,
                child: Text(component.supplierBookingReference ?? '—',
                    style: AppTextStyles.tableCell.copyWith(
                        color: component.supplierBookingReference == null
                            ? AppColors.textMuted
                            : null),
                    overflow: TextOverflow.ellipsis),
              ),

              // Actions
              SizedBox(
                width: ComponentColumns.actions,
                child: _RowMenu(component: component, provider: provider, onEdit: onEdit),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Category badge
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryBadge extends StatelessWidget {
  final ComponentType type;
  const _CategoryBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: type.bgColor,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(type.icon, size: 11, color: type.color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              type.label,
              style: AppTextStyles.labelSmall.copyWith(
                  color: type.color, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Row actions menu
// ─────────────────────────────────────────────────────────────────────────────

class _RowMenu extends StatelessWidget {
  final TripComponent component;
  final ComponentsProvider provider;
  final VoidCallback onEdit;
  const _RowMenu(
      {required this.component, required this.provider, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (value) async {
        if (value == 'edit') onEdit();
        if (value == 'delete') {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Delete component?'),
              content:
                  Text('Delete "${component.title}"? This cannot be undone.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                FilledButton(
                  style:
                      FilledButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Delete'),
                ),
              ],
            ),
          );
          if (confirmed == true) provider.deleteComponent(component.id);
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'edit', child: Text('Edit')),
        const PopupMenuDivider(),
        const PopupMenuItem(
            value: 'delete',
            child: Text('Delete', style: TextStyle(color: Colors.red))),
      ],
      child: const Icon(Icons.more_horiz_rounded,
          size: 16, color: AppColors.textMuted),
    );
  }
}
