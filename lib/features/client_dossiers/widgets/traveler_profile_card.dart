import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/client_traveler_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TravelerProfileCard
// ─────────────────────────────────────────────────────────────────────────────

class TravelerProfileCard extends StatelessWidget {
  final ClientTraveler traveler;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const TravelerProfileCard({
    super.key,
    required this.traveler,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDECEA)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withAlpha(6),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.base),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.accentFaint,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.accentLight, width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    traveler.name.isNotEmpty
                        ? traveler.name[0].toUpperCase()
                        : '?',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),

                // Name + role + age
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              traveler.name,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                                height: 1.3,
                              ),
                            ),
                          ),
                          _RoleBadge(label: traveler.role.label),
                        ],
                      ),
                      if (traveler.ageBracket != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          traveler.ageBracket!.label,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Actions
                if (onEdit != null || onDelete != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'edit') onEdit?.call();
                      if (v == 'delete') onDelete?.call();
                    },
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    itemBuilder: (_) => [
                      if (onEdit != null)
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(children: [
                            Icon(Icons.edit_outlined, size: 14),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ]),
                        ),
                      if (onDelete != null)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(children: [
                            Icon(Icons.delete_outline_rounded,
                                size: 14, color: Color(0xFFB00020)),
                            SizedBox(width: 8),
                            Text('Remove',
                                style: TextStyle(color: Color(0xFFB00020))),
                          ]),
                        ),
                    ],
                    child: Icon(
                      Icons.more_horiz_rounded,
                      size: 18,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Notes / flags section
          if (_hasNotes) ...[
            Divider(height: 1, color: AppColors.divider),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.base, AppSpacing.md, AppSpacing.base, AppSpacing.base),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _buildNoteRows(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool get _hasNotes =>
      traveler.dietaryNotes != null ||
      traveler.activityNotes != null ||
      traveler.medicalNotes != null ||
      traveler.roomingNotes != null;

  List<Widget> _buildNoteRows() {
    final rows = <Widget>[];
    if (traveler.dietaryNotes != null) {
      rows.add(_NoteRow(
        icon: Icons.restaurant_outlined,
        label: 'Dietary',
        text: traveler.dietaryNotes!,
        accent: const Color(0xFFF59E0B),
      ));
    }
    if (traveler.medicalNotes != null) {
      rows.add(_NoteRow(
        icon: Icons.medical_information_outlined,
        label: 'Medical',
        text: traveler.medicalNotes!,
        accent: const Color(0xFFEF4444),
      ));
    }
    if (traveler.roomingNotes != null) {
      rows.add(_NoteRow(
        icon: Icons.hotel_outlined,
        label: 'Rooming',
        text: traveler.roomingNotes!,
        accent: AppColors.textMuted,
      ));
    }
    if (traveler.activityNotes != null) {
      rows.add(_NoteRow(
        icon: Icons.directions_run_outlined,
        label: 'Activities',
        text: traveler.activityNotes!,
        accent: AppColors.textMuted,
      ));
    }
    return rows;
  }
}

class _RoleBadge extends StatelessWidget {
  final String label;
  const _RoleBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.accentFaint,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accentLight),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppColors.accent,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

class _NoteRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String text;
  final Color accent;

  const _NoteRow({
    required this.icon,
    required this.label,
    required this.text,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 13, color: accent),
          const SizedBox(width: 7),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  TextSpan(
                    text: text,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textPrimary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TravelerFormSheet — inline bottom sheet to add/edit a traveler
// ─────────────────────────────────────────────────────────────────────────────

Future<ClientTraveler?> showTravelerFormSheet(
  BuildContext context, {
  required String dossierId,
  ClientTraveler? existing,
}) {
  return showModalBottomSheet<ClientTraveler>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) =>
        _TravelerFormSheet(dossierId: dossierId, existing: existing),
  );
}

class _TravelerFormSheet extends StatefulWidget {
  final String dossierId;
  final ClientTraveler? existing;
  const _TravelerFormSheet({required this.dossierId, this.existing});

  @override
  State<_TravelerFormSheet> createState() => _TravelerFormSheetState();
}

class _TravelerFormSheetState extends State<_TravelerFormSheet> {
  final _nameCtrl = TextEditingController();
  final _dietaryCtrl = TextEditingController();
  final _roomingCtrl = TextEditingController();
  final _activityCtrl = TextEditingController();
  final _medicalCtrl = TextEditingController();
  final _personalityCtrl = TextEditingController();

  TravelerRole _role = TravelerRole.guest;
  AgeBracket? _ageBracket;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e.name;
      _dietaryCtrl.text = e.dietaryNotes ?? '';
      _roomingCtrl.text = e.roomingNotes ?? '';
      _activityCtrl.text = e.activityNotes ?? '';
      _medicalCtrl.text = e.medicalNotes ?? '';
      _personalityCtrl.text = e.personalityNotes ?? '';
      _role = e.role;
      _ageBracket = e.ageBracket;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dietaryCtrl.dispose();
    _roomingCtrl.dispose();
    _activityCtrl.dispose();
    _medicalCtrl.dispose();
    _personalityCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (_nameCtrl.text.trim().isEmpty) return;
    final traveler =
        (widget.existing ??
                ClientTraveler(
                  id: '',
                  dossierId: widget.dossierId,
                  name: '',
                  createdAt: DateTime.now(),
                ))
            .copyWith(
              name: _nameCtrl.text.trim(),
              role: _role,
              ageBracket: _ageBracket,
              dietaryNotes: _dietaryCtrl.text.trim().isNotEmpty
                  ? _dietaryCtrl.text.trim()
                  : null,
              roomingNotes: _roomingCtrl.text.trim().isNotEmpty
                  ? _roomingCtrl.text.trim()
                  : null,
              activityNotes: _activityCtrl.text.trim().isNotEmpty
                  ? _activityCtrl.text.trim()
                  : null,
              medicalNotes: _medicalCtrl.text.trim().isNotEmpty
                  ? _medicalCtrl.text.trim()
                  : null,
              personalityNotes: _personalityCtrl.text.trim().isNotEmpty
                  ? _personalityCtrl.text.trim()
                  : null,
            );
    Navigator.of(context).pop(traveler);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  widget.existing == null ? 'Add Traveler' : 'Edit Traveler',
                  style: AppTextStyles.heading3,
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            _SheetField(label: 'Full name *', ctrl: _nameCtrl),
            const SizedBox(height: 14),

            _label('Role'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: TravelerRole.values.map((r) {
                final sel = _role == r;
                return GestureDetector(
                  onTap: () => setState(() => _role = r),
                  child: _ChoiceChip(label: r.label, selected: sel),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            _label('Age bracket'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: AgeBracket.values.map((b) {
                final sel = _ageBracket == b;
                return GestureDetector(
                  onTap: () => setState(() => _ageBracket = sel ? null : b),
                  child: _ChoiceChip(label: b.label, selected: sel),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            _SheetField(label: 'Dietary notes', ctrl: _dietaryCtrl),
            const SizedBox(height: 10),
            _SheetField(label: 'Rooming notes', ctrl: _roomingCtrl),
            const SizedBox(height: 10),
            _SheetField(label: 'Activity notes', ctrl: _activityCtrl),
            const SizedBox(height: 10),
            _SheetField(
              label: 'Medical / accessibility notes',
              ctrl: _medicalCtrl,
            ),
            const SizedBox(height: 10),
            _SheetField(
              label: 'Personality / preference notes',
              ctrl: _personalityCtrl,
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: _save,
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(
                      AppSpacing.buttonRadius,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    widget.existing == null ? 'Add Traveler' : 'Save Changes',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
  );
}

class _SheetField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final int? maxLines;

  const _SheetField({required this.label, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: AppColors.surfaceAlt,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
              borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  const _ChoiceChip({required this.label, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: selected ? AppColors.accentFaint : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
        border: Border.all(
          color: selected ? AppColors.accent : AppColors.border,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: selected ? AppColors.accent : AppColors.textSecondary,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          fontSize: 11,
        ),
      ),
    );
  }
}
