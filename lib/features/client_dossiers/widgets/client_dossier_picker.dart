import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/client_dossier_model.dart';
import '../providers/client_dossier_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ClientDossierPicker
//
// Displays a current dossier selection with the ability to search and pick
// another.  Used in the trip creation/edit form to link a dossier to a trip.
// ─────────────────────────────────────────────────────────────────────────────

class ClientDossierPicker extends StatelessWidget {
  final ClientDossier? selected;
  final ClientDossierProvider provider;
  final ValueChanged<ClientDossier?> onChanged;

  const ClientDossierPicker({
    super.key,
    required this.selected,
    required this.provider,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final result = await showDossierPickerSheet(context, provider: provider);
        if (result != null) onChanged(result);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.person_outline_rounded,
                size: 16, color: AppColors.textMuted),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: selected == null
                  ? Text('Link a client dossier (optional)',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textMuted))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(selected!.displayName,
                            style: AppTextStyles.labelMedium.copyWith(
                                fontWeight: FontWeight.w600)),
                        if (selected!.typicalTripType != null)
                          Text(selected!.typicalTripType!.label,
                              style: AppTextStyles.labelSmall
                                  .copyWith(color: AppColors.textMuted)),
                      ],
                    ),
            ),
            if (selected != null) ...[
              GestureDetector(
                onTap: () => onChanged(null),
                child: Icon(Icons.close_rounded,
                    size: 14, color: AppColors.textMuted),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Icon(Icons.arrow_drop_down_rounded,
                size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

// ── Picker sheet ──────────────────────────────────────────────────────────────

Future<ClientDossier?> showDossierPickerSheet(
  BuildContext context, {
  required ClientDossierProvider provider,
}) {
  return showModalBottomSheet<ClientDossier>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _DossierPickerSheet(provider: provider),
  );
}

class _DossierPickerSheet extends StatefulWidget {
  final ClientDossierProvider provider;
  const _DossierPickerSheet({required this.provider});

  @override
  State<_DossierPickerSheet> createState() => _DossierPickerSheetState();
}

class _DossierPickerSheetState extends State<_DossierPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<ClientDossier> get _filtered {
    final q = _query.toLowerCase();
    if (q.isEmpty) return widget.provider.dossiers;
    return widget.provider.dossiers.where((d) {
      return d.displayName.toLowerCase().contains(q) ||
          (d.homeBase?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollCtrl) => Column(
        children: [
          // Handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Select Client Dossier', style: AppTextStyles.heading3),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v),
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search clients…',
                    hintStyle:
                        AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                    prefixIcon: const Icon(Icons.search_rounded,
                        size: 16, color: AppColors.textMuted),
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.surfaceAlt,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
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
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListenableBuilder(
              listenable: widget.provider,
              builder: (context, _) {
                final items = _filtered;
                if (items.isEmpty) {
                  return Center(
                    child: Text('No clients found',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textMuted)),
                  );
                }
                return ListView.separated(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  itemCount: items.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: AppColors.divider),
                  itemBuilder: (_, i) {
                    final d = items[i];
                    return _DossierPickerRow(
                      dossier: d,
                      onTap: () => Navigator.of(context).pop(d),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DossierPickerRow extends StatelessWidget {
  final ClientDossier dossier;
  final VoidCallback onTap;
  const _DossierPickerRow({required this.dossier, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.accentFaint,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                dossier.displayName.isNotEmpty
                    ? dossier.displayName[0].toUpperCase()
                    : '?',
                style: AppTextStyles.labelMedium
                    .copyWith(color: AppColors.accent, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dossier.displayName,
                      style: AppTextStyles.labelMedium
                          .copyWith(fontWeight: FontWeight.w600)),
                  if (dossier.homeBase != null || dossier.typicalTripType != null)
                    Text(
                      [
                        if (dossier.typicalTripType != null)
                          dossier.typicalTripType!.label,
                        if (dossier.homeBase != null) dossier.homeBase,
                      ].join(' · '),
                      style: AppTextStyles.labelSmall
                          .copyWith(color: AppColors.textMuted),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 16, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
