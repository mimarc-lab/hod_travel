import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/itinerary_models.dart';
import '../providers/itinerary_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// showAddDaySheet — shared entry point used by panel, chips row, and empty state
// ─────────────────────────────────────────────────────────────────────────────

void showAddDaySheet(
  BuildContext context, {
  required ItineraryProvider provider,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => _AddDayForm(provider: provider),
  );
}

void showEditDaySheet(
  BuildContext context, {
  required ItineraryProvider provider,
  required TripDay day,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => _EditDayForm(provider: provider, day: day),
  );
}

class _EditDayForm extends StatefulWidget {
  final ItineraryProvider provider;
  final TripDay day;
  const _EditDayForm({required this.provider, required this.day});

  @override
  State<_EditDayForm> createState() => _EditDayFormState();
}

class _EditDayFormState extends State<_EditDayForm> {
  late final TextEditingController _cityCtrl;
  late final TextEditingController _labelCtrl;
  late DateTime? _date;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _cityCtrl  = TextEditingController(text: widget.day.city);
    _labelCtrl = TextEditingController(text: widget.day.label ?? '');
    _date      = widget.day.date;
  }

  @override
  void dispose() {
    _cityCtrl.dispose();
    _labelCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final city     = _cityCtrl.text.trim();
    if (city.isEmpty) return;
    final newLabel = _labelCtrl.text.trim();
    setState(() => _saving = true);
    try {
      // Must set BOTH title and label — _dayFromRow stores the DB `title`
      // column into both fields, so copyWith(label:) alone leaves title at
      // the old value, which _dayToRow then picks up via `d.title ?? d.label`.
      await widget.provider.upsertDay(widget.day.copyWith(
        city:       city,
        date:       _date,
        clearDate:  _date == null,
        title:      newLabel.isEmpty ? null : newLabel,
        clearTitle: newLabel.isEmpty,
        label:      newLabel.isEmpty ? null : newLabel,
        clearLabel: newLabel.isEmpty,
      ));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.provider.error ?? e.toString()),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppColors.accent,
            onPrimary: Colors.white,
            surface: AppColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.base, AppSpacing.base, AppSpacing.base, AppSpacing.base + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.base),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text('Edit Day ${widget.day.dayNumber}', style: AppTextStyles.heading3),
          const SizedBox(height: AppSpacing.base),

          Text('CITY *', style: AppTextStyles.overline),
          const SizedBox(height: 5),
          _DayTextField(controller: _cityCtrl, hint: 'e.g. Lake Bled, Athens'),
          const SizedBox(height: AppSpacing.base),

          Text('DATE', style: AppTextStyles.overline),
          const SizedBox(height: 5),
          _DayDatePicker(date: _date, onTap: _pickDate, onClear: () => setState(() => _date = null)),
          const SizedBox(height: AppSpacing.base),

          Text('DAY THEME', style: AppTextStyles.overline),
          const SizedBox(height: 5),
          _DayTextField(controller: _labelCtrl, hint: 'e.g. Arrival & Scenic Drive — optional'),
          const SizedBox(height: AppSpacing.lg),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddDayForm extends StatefulWidget {
  final ItineraryProvider provider;
  const _AddDayForm({required this.provider});

  @override
  State<_AddDayForm> createState() => _AddDayFormState();
}

class _AddDayFormState extends State<_AddDayForm> {
  final _cityCtrl  = TextEditingController();
  final _labelCtrl = TextEditingController();
  DateTime? _date;
  bool _saving = false;

  @override
  void dispose() {
    _cityCtrl.dispose();
    _labelCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final city = _cityCtrl.text.trim();
    if (city.isEmpty) return;
    setState(() => _saving = true);
    final errorBefore = widget.provider.error;
    await widget.provider.addDay(
      city: city,
      date: _date,
      label: _labelCtrl.text.trim().isEmpty ? null : _labelCtrl.text.trim(),
    );
    if (!mounted) return;
    // If a new error appeared, stay open and show a snackbar.
    if (widget.provider.error != null && widget.provider.error != errorBefore) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.provider.error!),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppColors.accent,
            onPrimary: Colors.white,
            surface: AppColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.base, AppSpacing.base, AppSpacing.base, AppSpacing.base + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.base),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Text('Add Day', style: AppTextStyles.heading3),
          const SizedBox(height: AppSpacing.base),

          // City
          Text('CITY *', style: AppTextStyles.overline),
          const SizedBox(height: 5),
          TextField(
            controller: _cityCtrl,
            autofocus: true,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'e.g. Lake Bled, Athens',
              hintStyle: AppTextStyles.bodySmall,
              filled: true,
              fillColor: AppColors.surfaceAlt,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
            ),
          ),
          const SizedBox(height: AppSpacing.base),

          // Date
          Text('DATE', style: AppTextStyles.overline),
          const SizedBox(height: 5),
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _date == null
                          ? 'Optional — pick a date'
                          : DateFormat('EEEE, d MMMM yyyy').format(_date!),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: _date == null
                            ? AppColors.textMuted
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (_date != null)
                    GestureDetector(
                      onTap: () => setState(() => _date = null),
                      child: const Icon(Icons.close_rounded,
                          size: 14, color: AppColors.textMuted),
                    )
                  else
                    const Icon(Icons.calendar_today_outlined,
                        size: 13, color: AppColors.textMuted),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.base),

          // Label (optional theme/headline)
          Text('DAY THEME', style: AppTextStyles.overline),
          const SizedBox(height: 5),
          TextField(
            controller: _labelCtrl,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'e.g. Arrival & Scenic Drive — optional',
              hintStyle: AppTextStyles.bodySmall,
              filled: true,
              fillColor: AppColors.surfaceAlt,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Add Day'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DayNavigatorPanel — vertical sidebar for desktop/tablet (220px)
// ─────────────────────────────────────────────────────────────────────────────

class DayNavigatorPanel extends StatelessWidget {
  final ItineraryProvider provider;
  const DayNavigatorPanel({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.base, AppSpacing.base, AppSpacing.base, AppSpacing.sm),
            child: Text('DAYS', style: AppTextStyles.overline),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: AppSpacing.base),
              itemCount: provider.days.length,
              itemBuilder: (context, index) {
                final isSelected = provider.selectedDayIndex == index;
                return _DayTile(
                  day: provider.days[index],
                  isSelected: isSelected,
                  onTap: () => provider.selectDay(index),
                  provider: provider,
                );
              },
            ),
          ),

          // Add Day button — pinned at bottom of panel
          const Divider(height: 1, color: AppColors.border),
          InkWell(
            onTap: () => showAddDaySheet(context, provider: provider),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.base, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.add_rounded,
                      size: 15, color: AppColors.accent),
                  const SizedBox(width: 6),
                  Text('Add Day',
                      style: AppTextStyles.labelMedium
                          .copyWith(color: AppColors.accent)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayTile extends StatelessWidget {
  final TripDay day;
  final bool isSelected;
  final VoidCallback onTap;
  final ItineraryProvider provider;

  const _DayTile({
    required this.day,
    required this.isSelected,
    required this.onTap,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppColors.accentFaint : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: isSelected ? AppColors.accentFaint : AppColors.surfaceAlt,
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
        child: Row(
          children: [
            // Left accent bar
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 3,
              height: 52,
              color: isSelected ? AppColors.accent : Colors.transparent,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Day ${day.dayNumber}  ·  ${day.date != null ? DateFormat('d MMM').format(day.date!) : ''}',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: isSelected ? AppColors.accent : AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      day.city,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: isSelected
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (day.label != null)
                      Text(
                        day.label!,
                        style: AppTextStyles.labelSmall
                            .copyWith(color: AppColors.textMuted),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ),
            // Edit button — visible on hover/selected
            if (isSelected)
              GestureDetector(
                onTap: () => showEditDaySheet(context,
                    provider: provider, day: day),
                child: Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: Icon(Icons.edit_outlined,
                      size: 14, color: AppColors.textMuted),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DayChipsRow — horizontal scroll row for mobile
// ─────────────────────────────────────────────────────────────────────────────

class DayChipsRow extends StatefulWidget {
  final ItineraryProvider provider;
  const DayChipsRow({super.key, required this.provider});

  @override
  State<DayChipsRow> createState() => _DayChipsRowState();
}

class _DayChipsRowState extends State<DayChipsRow> {
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: ListView.separated(
        controller: _scrollCtrl,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pagePaddingH, vertical: 8),
        itemCount: widget.provider.days.length + 1, // +1 for Add Day chip
        separatorBuilder: (_, i) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == widget.provider.days.length) {
            // "+ Add Day" chip at the end
            return GestureDetector(
              onTap: () => showAddDaySheet(context, provider: widget.provider),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_rounded,
                          size: 14, color: AppColors.accent),
                      const SizedBox(width: 4),
                      Text('Add Day',
                          style: AppTextStyles.labelSmall
                              .copyWith(color: AppColors.accent)),
                    ],
                  ),
                ),
              ),
            );
          }
          final day = widget.provider.days[index];
          final isSelected = widget.provider.selectedDayIndex == index;
          return _DayChip(
            day: day,
            isSelected: isSelected,
            onTap: () => widget.provider.selectDay(index),
          );
        },
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  final TripDay day;
  final bool isSelected;
  final VoidCallback onTap;

  const _DayChip({
    required this.day,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.border,
          ),
        ),
        child: Center(
          child: Text(
            'Day ${day.dayNumber} · ${day.city}',
            style: AppTextStyles.labelSmall.copyWith(
              color: isSelected ? Colors.white : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared form field helpers (used by Add + Edit day forms)
// ─────────────────────────────────────────────────────────────────────────────

class _DayTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  const _DayTextField({required this.controller, required this.hint});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: false,
      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.bodySmall,
        filled: true,
        fillColor: AppColors.surfaceAlt,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
      ),
    );
  }
}

class _DayDatePicker extends StatelessWidget {
  final DateTime? date;
  final VoidCallback onTap;
  final VoidCallback onClear;
  const _DayDatePicker(
      {required this.date, required this.onTap, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                date == null
                    ? 'Optional — pick a date'
                    : DateFormat('EEEE, d MMMM yyyy').format(date!),
                style: AppTextStyles.bodySmall.copyWith(
                  color: date == null
                      ? AppColors.textMuted
                      : AppColors.textPrimary,
                ),
              ),
            ),
            if (date != null)
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close_rounded,
                    size: 14, color: AppColors.textMuted),
              )
            else
              const Icon(Icons.calendar_today_outlined,
                  size: 13, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
