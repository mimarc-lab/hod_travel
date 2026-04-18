import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TripDestinationsEditor
//
// Chip-based editor for the trip destinations list.
// Each destination is shown as a removable chip.
// New destinations are typed in a text field and added with Enter or "Add".
// Blank and duplicate entries are silently rejected.
// ─────────────────────────────────────────────────────────────────────────────

class TripDestinationsEditor extends StatefulWidget {
  final List<String> initialDestinations;
  final ValueChanged<List<String>> onChanged;

  const TripDestinationsEditor({
    super.key,
    required this.initialDestinations,
    required this.onChanged,
  });

  @override
  State<TripDestinationsEditor> createState() =>
      _TripDestinationsEditorState();
}

class _TripDestinationsEditorState extends State<TripDestinationsEditor> {
  late List<String> _destinations;
  final _ctrl = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _destinations = List.from(widget.initialDestinations);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _add() {
    final val = _ctrl.text.trim();
    if (val.isEmpty) return;
    if (_destinations.any((d) => d.toLowerCase() == val.toLowerCase())) {
      _ctrl.clear();
      return;
    }
    setState(() => _destinations.add(val));
    _ctrl.clear();
    _focusNode.requestFocus();
    widget.onChanged(List.unmodifiable(_destinations));
  }

  void _remove(int index) {
    setState(() => _destinations.removeAt(index));
    widget.onChanged(List.unmodifiable(_destinations));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Existing chips ──────────────────────────────────────────────────
        if (_destinations.isNotEmpty) ...[
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: _destinations.asMap().entries.map((e) {
              return _DestinationChip(
                label: e.value,
                onRemove: () => _remove(e.key),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],

        // ── Add row ─────────────────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 42,
                child: TextField(
                  controller: _ctrl,
                  focusNode: _focusNode,
                  style: AppTextStyles.bodyMedium,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _add(),
                  decoration: InputDecoration(
                    hintText: 'Add city, e.g. Positano',
                    hintStyle: AppTextStyles.bodySmall,
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.base,
                      vertical: 0,
                    ),
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.inputRadius),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.inputRadius),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.inputRadius),
                      borderSide: const BorderSide(
                          color: AppColors.accent, width: 1.5),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            GestureDetector(
              onTap: _add,
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.base),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius:
                      BorderRadius.circular(AppSpacing.inputRadius),
                ),
                child: Center(
                  child: Text(
                    'Add',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── _DestinationChip ──────────────────────────────────────────────────────────

class _DestinationChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _DestinationChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.accentLight,
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
        border:
            Border.all(color: AppColors.accent.withAlpha(60), width: 0.75),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_on_outlined,
              size: 12, color: AppColors.accentDark),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.accentDark,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close_rounded,
                size: 13, color: AppColors.accentDark),
          ),
        ],
      ),
    );
  }
}
