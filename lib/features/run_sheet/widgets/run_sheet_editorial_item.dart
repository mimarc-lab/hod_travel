import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/supabase/app_db.dart';
import '../../../data/models/itinerary_models.dart';
import '../../../data/models/run_sheet_instruction_template.dart';
import '../../../data/models/run_sheet_item.dart';
import '../../../data/models/trip_component_model.dart';
import '../../client_view/client_view_theme.dart';
import '../providers/run_sheet_provider.dart';
import '../services/component_booking_rows.dart';
import '../services/run_sheet_view_mode.dart';
import 'run_sheet_contact_block.dart';
import 'run_sheet_item_detail.dart';
import 'run_sheet_status_chip.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RunSheetEditorialItem — editorial-style rendering of a single run-sheet item.
//
// Shares the same content (time, type, status, contacts, role notes, booking
// details, instructions) as RunSheetItemCard but presents it in the Client
// View editorial style: no card border, no shadow, hairline separators,
// Inter font, linen palette.
// ─────────────────────────────────────────────────────────────────────────────

class RunSheetEditorialItem extends StatefulWidget {
  final RunSheetItem     item;
  final RunSheetProvider provider;
  final double           hPad;

  const RunSheetEditorialItem({
    super.key,
    required this.item,
    required this.provider,
    this.hPad = 40.0,
  });

  @override
  State<RunSheetEditorialItem> createState() => _RunSheetEditorialItemState();
}

class _RunSheetEditorialItemState extends State<RunSheetEditorialItem> {
  TripComponent? _component;

  @override
  void initState() {
    super.initState();
    _loadComponent();
  }

  @override
  void didUpdateWidget(RunSheetEditorialItem old) {
    super.didUpdateWidget(old);
    if (old.item.itineraryItemId != widget.item.itineraryItemId) {
      _component = null;
      _loadComponent();
    }
  }

  Future<void> _loadComponent() async {
    final id = widget.item.itineraryItemId;
    if (id == null) return;
    final repo = AppRepositories.instance?.components;
    if (repo == null) return;
    try {
      final c = await repo.fetchByItineraryItemId(id);
      if (mounted && c != null) setState(() => _component = c);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final item        = widget.item;
    final isComplete  = item.status == RunSheetStatus.completed;
    final isCancelled = item.status == RunSheetStatus.cancelled;

    return GestureDetector(
      onTap: () => showRunSheetItemDetail(
          context, item: item, provider: widget.provider),
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: (isComplete || isCancelled) ? 0.5 : 1.0,
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: widget.hPad, vertical: 22),
          child: _EditorialBody(
            item:      item,
            provider:  widget.provider,
            component: _component,
          ),
        ),
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _EditorialBody extends StatelessWidget {
  final RunSheetItem     item;
  final RunSheetProvider provider;
  final TripComponent?   component;

  const _EditorialBody({
    required this.item,
    required this.provider,
    this.component,
  });

  @override
  Widget build(BuildContext context) {
    final showOps       = RunSheetRoleFilter.showOpsNotes(provider.viewMode);
    final showLogistics = RunSheetRoleFilter.showLogisticsNotes(provider.viewMode);
    final showTransport = RunSheetRoleFilter.showTransportNotes(provider.viewMode);
    final showGuide     = RunSheetRoleFilter.showGuideNotes(provider.viewMode);

    final bookingRows = component != null
        ? buildComponentBookingRows(component!)
        : <BookingRow>[];

    final timeStr     = _buildTimeStr();
    final typeLabel   = item.type.label.toUpperCase();
    final timeTypeLine = timeStr.isNotEmpty
        ? '$timeStr  ·  $typeLabel'
        : typeLabel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Time · Type + status button
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(timeTypeLine, style: ClientViewTheme.itemTime),
            ),
            RunSheetStatusButton(
              current:   item.status,
              onChanged: (s) => provider.updateStatus(item, s),
            ),
          ],
        ),
        const SizedBox(height: 5),

        // Title
        Text(item.title, style: ClientViewTheme.itemTitle),

        // Location / Supplier
        if (_hasMetaRow) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 16,
            runSpacing: 2,
            children: [
              if (item.location?.isNotEmpty ?? false)
                _MetaLine(
                    icon: Icons.place_outlined, label: item.location!),
              if (item.supplierName?.isNotEmpty ?? false)
                _MetaLine(
                    icon: Icons.storefront_outlined, label: item.supplierName!),
            ],
          ),
        ],

        // Description
        if (item.description?.isNotEmpty ?? false) ...[
          const SizedBox(height: 8),
          Text(item.description!,
              style: ClientViewTheme.itemDescription),
        ],

        // Booking details (from linked TripComponent)
        if (bookingRows.isNotEmpty) ...[
          const SizedBox(height: 14),
          _BookingBlock(rows: bookingRows),
        ],

        // Contacts
        if (item.hasContacts) ...[
          const SizedBox(height: 12),
          RunSheetContactBlock(item: item),
        ],

        // Role-specific notes — keep coloured blocks for easy crew scanning
        if (showTransport && item.hasTransportNotes) ...[
          const SizedBox(height: 12),
          _NotesBlock(
            icon:        Icons.directions_car_outlined,
            label:       'DRIVER NOTE',
            text:        item.transportNotes!,
            bgColor:     const Color(0xFFEFF6FF),
            borderColor: const Color(0xFFBFDBFE),
            textColor:   const Color(0xFF1E40AF),
            iconColor:   const Color(0xFF3B82F6),
          ),
        ],
        if (showGuide && item.hasGuideNotes) ...[
          const SizedBox(height: 12),
          _NotesBlock(
            icon:        Icons.hiking_rounded,
            label:       'GUIDE NOTE',
            text:        item.guideNotes!,
            bgColor:     const Color(0xFFF0FDF4),
            borderColor: const Color(0xFFBBF7D0),
            textColor:   const Color(0xFF166534),
            iconColor:   const Color(0xFF16A34A),
          ),
        ],
        if (showLogistics && item.hasLogistics) ...[
          const SizedBox(height: 12),
          _NotesBlock(
            icon:        Icons.local_shipping_outlined,
            label:       'LOGISTICS',
            text:        item.logisticsNotes!,
            bgColor:     const Color(0xFFEFF6FF),
            borderColor: const Color(0xFFBFDBFE),
            textColor:   const Color(0xFF1E40AF),
            iconColor:   const Color(0xFF3B82F6),
          ),
        ],
        if (showOps && item.hasOpsNotes) ...[
          const SizedBox(height: 12),
          _NotesBlock(
            icon:        Icons.sticky_note_2_outlined,
            label:       'OPS NOTE',
            text:        item.opsNotes!,
            bgColor:     const Color(0xFFFFFBEB),
            borderColor: const Color(0xFFFDE68A),
            textColor:   const Color(0xFF92400E),
            iconColor:   const Color(0xFFF59E0B),
          ),
        ],

        // Operational instructions
        if (item.hasInstructions) ...[
          const SizedBox(height: 12),
          _InstructionsSection(
            operational: item.operationalInstructions,
            contingency: item.contingencyInstructions,
            escalation:  item.escalationInstructions,
          ),
        ],

        // Suggest badge — director-only; hidden on role share links
        if (!item.hasInstructions &&
            !provider.viewMode.isRestricted &&
            DefaultInstructionTemplates.hasTemplatesFor(item.type.dbValue)) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color:        const Color(0xFFF0FDFA),
              borderRadius: BorderRadius.circular(5),
              border:       Border.all(
                  color: const Color(0xFF0F766E).withAlpha(50)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_awesome_rounded,
                    size: 11, color: Color(0xFF0F766E)),
                const SizedBox(width: 5),
                Text(
                  'Suggested instructions available — tap to review',
                  style: AppTextStyles.labelSmall
                      .copyWith(color: const Color(0xFF0F766E)),
                ),
              ],
            ),
          ),
        ],

        // Responsible person
        if (item.responsibleName?.isNotEmpty ?? false) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.person_outline_rounded,
                  size: 12, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text('Responsible: ', style: ClientViewTheme.itemMeta),
              Text(
                item.responsibleName!,
                style: ClientViewTheme.itemMeta.copyWith(
                  color:      AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  bool get _hasMetaRow =>
      (item.location?.isNotEmpty ?? false) ||
      (item.supplierName?.isNotEmpty ?? false);

  String _buildTimeStr() {
    if (item.startTime != null) {
      final s = _fmtTime(item.startTime!);
      if (item.endTime != null) return '$s – ${_fmtTime(item.endTime!)}';
      return s;
    }
    return item.timeBlock.label;
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _MetaLine extends StatelessWidget {
  final IconData icon;
  final String   label;
  const _MetaLine({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: ClientViewTheme.muted),
        const SizedBox(width: 4),
        Text(label,
            style: ClientViewTheme.itemMeta
                .copyWith(color: ClientViewTheme.secondary)),
      ],
    );
  }
}

class _NotesBlock extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   text;
  final Color    bgColor;
  final Color    borderColor;
  final Color    textColor;
  final Color    iconColor;

  const _NotesBlock({
    required this.icon,
    required this.label,
    required this.text,
    required this.bgColor,
    required this.borderColor,
    required this.textColor,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color:        bgColor,
        borderRadius: BorderRadius.circular(6),
        border:       Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 12, color: iconColor),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTextStyles.overline.copyWith(
                      color:         textColor,
                      letterSpacing: 0.8,
                    )),
                const SizedBox(height: 3),
                Text(text,
                    style: AppTextStyles.bodySmall.copyWith(
                      color:  textColor.withAlpha(200),
                      height: 1.5,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingBlock extends StatelessWidget {
  final List<BookingRow> rows;
  const _BookingBlock({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:        const Color(0xFFF5F4F2),
        borderRadius: BorderRadius.circular(8),
        border:       Border.all(color: ClientViewTheme.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Text(
              'BOOKING DETAILS',
              style: AppTextStyles.overline.copyWith(
                color:         ClientViewTheme.muted,
                letterSpacing: 1.0,
              ),
            ),
          ),
          const Divider(height: 1, color: ClientViewTheme.hairline),
          for (int i = 0; i < rows.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 140,
                    child: Text(rows[i].key,
                        style: ClientViewTheme.itemMeta),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(rows[i].value,
                        style: ClientViewTheme.itemMeta.copyWith(
                          color:      AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        )),
                  ),
                ],
              ),
            ),
            if (i < rows.length - 1)
              const Divider(height: 1, color: ClientViewTheme.hairline),
          ],
        ],
      ),
    );
  }
}

class _InstructionsSection extends StatelessWidget {
  final String? operational;
  final String? contingency;
  final String? escalation;
  const _InstructionsSection({
    this.operational,
    this.contingency,
    this.escalation,
  });

  @override
  Widget build(BuildContext context) {
    final sections = <(String, String)>[];
    if (operational?.isNotEmpty == true) sections.add(('OPERATIONAL', operational!));
    if (contingency?.isNotEmpty == true) sections.add(('CONTINGENCY', contingency!));
    if (escalation?.isNotEmpty  == true) sections.add(('ESCALATION',  escalation!));
    if (sections.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < sections.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          Text(sections[i].$1,
              style: AppTextStyles.overline.copyWith(
                color:         ClientViewTheme.muted,
                letterSpacing: 0.8,
              )),
          const SizedBox(height: 3),
          Text(sections[i].$2,
              style: AppTextStyles.bodySmall.copyWith(
                color:  ClientViewTheme.secondary,
                height: 1.5,
              )),
        ],
      ],
    );
  }
}

// ── Helper ────────────────────────────────────────────────────────────────────

String _fmtTime(TimeOfDay t) {
  final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
  final m = t.minute.toString().padLeft(2, '0');
  final p = t.period == DayPeriod.am ? 'am' : 'pm';
  return '$h:$m $p';
}
