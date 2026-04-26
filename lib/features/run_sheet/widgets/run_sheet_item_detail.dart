import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/supabase/app_db.dart';
import '../../../data/models/itinerary_models.dart';
import '../../../data/models/run_sheet_instruction_template.dart';
import '../../../data/models/run_sheet_item.dart';
import '../providers/run_sheet_provider.dart';
import '../services/run_sheet_instruction_template_service.dart';
import '../services/run_sheet_view_mode.dart';
import 'operational_instructions_section.dart';
import 'run_sheet_contact_block.dart';
import 'run_sheet_status_chip.dart';

// ─────────────────────────────────────────────────────────────────────────────
// showRunSheetItemDetail — opens a scrollable bottom sheet for a RunSheetItem.
// Shows: overview, contacts, instructions (with suggestion banner), notes.
// ─────────────────────────────────────────────────────────────────────────────

void showRunSheetItemDetail(
  BuildContext context, {
  required RunSheetItem     item,
  required RunSheetProvider provider,
}) {
  showModalBottomSheet(
    context:            context,
    isScrollControlled: true,
    backgroundColor:    Colors.transparent,
    builder: (_) => _ItemDetailSheet(item: item, provider: provider),
  );
}

// ─────────────────────────────────────────────────────────────────────────────

class _ItemDetailSheet extends StatefulWidget {
  final RunSheetItem     item;
  final RunSheetProvider provider;
  const _ItemDetailSheet({required this.item, required this.provider});

  @override
  State<_ItemDetailSheet> createState() => _ItemDetailSheetState();
}

class _ItemDetailSheetState extends State<_ItemDetailSheet> {
  late final RunSheetInstructionTemplateService _templateService;
  late RunSheetItem _item;
  SuggestedInstructions? _suggestions;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    final repos = AppRepositories.instance;
    _templateService = RunSheetInstructionTemplateService(
      repo:   repos?.runSheetInstructionTemplates,
      teamId: repos?.currentTeamId,
    );
    _templateService.suggestFor(_item.type.dbValue).then((s) {
      if (mounted) setState(() => _suggestions = s);
    });
  }

  Future<void> _saveInstructions(
    String? operational,
    String? contingency,
    String? escalation,
    InstructionsSource source,
  ) async {
    await widget.provider.saveInstructions(
      _item,
      operational: operational,
      contingency:  contingency,
      escalation:   escalation,
      source:        source,
    );
    // Refresh local reference so the read-view shows the saved text
    setState(() {
      _item = _item.copyWith(
        operationalInstructions: operational,
        contingencyInstructions: contingency,
        escalationInstructions:  escalation,
        instructionsSource:      source,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewMode = widget.provider.viewMode;
    return DraggableScrollableSheet(
      initialChildSize: 0.70,
      minChildSize:     0.40,
      maxChildSize:     0.95,
      expand:           false,
      builder: (context, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color:        AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Drag handle
              const _DragHandle(),

              // Header
              _DetailHeader(
                item:     _item,
                provider: widget.provider,
                onStatusChanged: (s) => setState(() {
                  widget.provider.updateStatus(_item, s);
                  _item = _item.copyWith(status: s);
                }),
              ),

              const Divider(height: 1, color: AppColors.border),

              // Scrollable body
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding:    const EdgeInsets.all(AppSpacing.base),
                  children: [
                    // Overview
                    _OverviewSection(item: _item),

                    if (_item.hasContacts) ...[
                      const SizedBox(height: AppSpacing.base),
                      _DetailSectionLabel(label: 'CONTACTS'),
                      const SizedBox(height: AppSpacing.sm),
                      RunSheetContactBlock(item: _item),
                    ],

                    const SizedBox(height: AppSpacing.base),
                    OperationalInstructionsSection(
                      key:         ValueKey(_item.id),
                      item:        _item,
                      suggestions: _suggestions,
                      onSave:      _saveInstructions,
                    ),

                    // Notes section
                    if (_hasNotes(viewMode)) ...[
                      const SizedBox(height: AppSpacing.base),
                      const _DetailSectionLabel(label: 'NOTES'),
                      const SizedBox(height: AppSpacing.sm),
                      _NotesSection(item: _item, viewMode: viewMode),
                    ],

                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  bool _hasNotes(RunSheetViewMode viewMode) {
    if (RunSheetRoleFilter.showOpsNotes(viewMode) && _item.hasOpsNotes) return true;
    if (RunSheetRoleFilter.showLogisticsNotes(viewMode) && _item.hasLogistics) return true;
    if (RunSheetRoleFilter.showTransportNotes(viewMode) && _item.hasTransportNotes) return true;
    if (RunSheetRoleFilter.showGuideNotes(viewMode) && _item.hasGuideNotes) return true;
    return false;
  }
}

// ── Drag handle ───────────────────────────────────────────────────────────────

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Container(
        width:  36,
        height: 4,
        decoration: BoxDecoration(
          color:        AppColors.border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _DetailHeader extends StatelessWidget {
  final RunSheetItem     item;
  final RunSheetProvider provider;
  final void Function(RunSheetStatus) onStatusChanged;

  const _DetailHeader({
    required this.item,
    required this.provider,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.base, 0, AppSpacing.base, AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3, height: 42,
            color: item.type.color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TypeBadge(type: item.type),
                const SizedBox(height: 4),
                Text(item.title, style: AppTextStyles.heading2),
              ],
            ),
          ),
          RunSheetStatusButton(
            current:   item.status,
            onChanged: onStatusChanged,
          ),
        ],
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final ItemType type;
  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color:        type.color.withAlpha(15),
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
              color: type.color, letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Overview ──────────────────────────────────────────────────────────────────

class _OverviewSection extends StatelessWidget {
  final RunSheetItem item;
  const _OverviewSection({required this.item});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];

    {
      final timeStr = item.startTime != null
          ? _fmtTime(item.startTime!)
          : item.timeBlock.label;
      final endStr = item.endTime != null ? ' – ${_fmtTime(item.endTime!)}' : '';
      rows.add(_InfoRow(
        icon:  Icons.schedule_rounded,
        label: '$timeStr$endStr',
      ));
    }
    if (item.location?.isNotEmpty ?? false) {
      rows.add(_InfoRow(icon: Icons.place_outlined, label: item.location!));
    }
    if (item.supplierName?.isNotEmpty ?? false) {
      rows.add(_InfoRow(
          icon: Icons.storefront_outlined, label: item.supplierName!));
    }
    if (item.description?.isNotEmpty ?? false) {
      rows.add(_InfoRow(
          icon: Icons.notes_rounded, label: item.description!, maxLines: 4));
    }
    if (item.responsibleName?.isNotEmpty ?? false) {
      rows.add(_InfoRow(
          icon: Icons.person_outline_rounded,
          label: 'Responsible: ${item.responsibleName!}'));
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _DetailSectionLabel(label: 'OVERVIEW'),
        const SizedBox(height: AppSpacing.sm),
        ...rows.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: r,
            )),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  final int      maxLines;
  const _InfoRow({required this.icon, required this.label, this.maxLines = 2});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 12, color: AppColors.textMuted),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary, height: 1.4),
            maxLines:  maxLines,
            overflow:  TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ── Notes ─────────────────────────────────────────────────────────────────────

class _NotesSection extends StatelessWidget {
  final RunSheetItem     item;
  final RunSheetViewMode viewMode;
  const _NotesSection({required this.item, required this.viewMode});

  @override
  Widget build(BuildContext context) {
    final widgets = <Widget>[];

    if (RunSheetRoleFilter.showTransportNotes(viewMode) && item.hasTransportNotes) {
      widgets.add(_NoteBlock(
        icon:   Icons.directions_car_outlined,
        label:  'DRIVER NOTE',
        text:   item.transportNotes!,
        bg:     const Color(0xFFEFF6FF),
        border: const Color(0xFFBFDBFE),
        color:  const Color(0xFF1E40AF),
      ));
    }

    if (RunSheetRoleFilter.showGuideNotes(viewMode) && item.hasGuideNotes) {
      widgets.add(_NoteBlock(
        icon:   Icons.hiking_rounded,
        label:  'GUIDE NOTE',
        text:   item.guideNotes!,
        bg:     const Color(0xFFF0FDF4),
        border: const Color(0xFFBBF7D0),
        color:  const Color(0xFF166534),
      ));
    }

    if (RunSheetRoleFilter.showLogisticsNotes(viewMode) && item.hasLogistics) {
      widgets.add(_NoteBlock(
        icon:   Icons.local_shipping_outlined,
        label:  'LOGISTICS',
        text:   item.logisticsNotes!,
        bg:     const Color(0xFFEFF6FF),
        border: const Color(0xFFBFDBFE),
        color:  const Color(0xFF1E40AF),
      ));
    }

    if (RunSheetRoleFilter.showOpsNotes(viewMode) && item.hasOpsNotes) {
      widgets.add(_NoteBlock(
        icon:   Icons.sticky_note_2_outlined,
        label:  'OPS NOTE',
        text:   item.opsNotes!,
        bg:     const Color(0xFFFFFBEB),
        border: const Color(0xFFFDE68A),
        color:  const Color(0xFF92400E),
      ));
    }

    return Column(
      children: widgets
          .map((w) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: w,
              ))
          .toList(),
    );
  }
}

class _NoteBlock extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   text;
  final Color    bg;
  final Color    border;
  final Color    color;
  const _NoteBlock({
    required this.icon,
    required this.label,
    required this.text,
    required this.bg,
    required this.border,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color:        bg,
        borderRadius: BorderRadius.circular(6),
        border:       Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.overline
                      .copyWith(color: color, letterSpacing: 0.8),
                ),
                const SizedBox(height: 3),
                Text(
                  text,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: color.withAlpha(200), height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _DetailSectionLabel extends StatelessWidget {
  final String label;
  const _DetailSectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTextStyles.overline
          .copyWith(color: AppColors.textMuted, letterSpacing: 1.5),
    );
  }
}

String _fmtTime(TimeOfDay t) {
  final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
  final m = t.minute.toString().padLeft(2, '0');
  final p = t.period == DayPeriod.am ? 'am' : 'pm';
  return '$h:$m $p';
}
