import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/supabase/app_db.dart';
import '../../../data/models/itinerary_models.dart';
import '../../../data/models/run_sheet_item.dart';
import '../../../data/models/run_sheet_share_token.dart';
import '../../../data/models/run_sheet_view_mode.dart';
import '../../../data/models/trip_component_model.dart';
import '../services/run_sheet_pdf_export.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RunSheetShareDialog
//
// Lets the trip director generate role-scoped shareable links.
// Steps:
//   1. Select a role (Driver / Guide / Operations / Director) — dropdown
//   2. (Optional) Set an expiry — dropdown
//   3. Generate → token created in Supabase, link copied to clipboard
// ─────────────────────────────────────────────────────────────────────────────

class RunSheetShareDialog extends StatefulWidget {
  final String             tripId;
  final String             tripName;
  final List<RunSheetItem> allItems;
  final List<TripDay>      days;

  const RunSheetShareDialog({
    super.key,
    required this.tripId,
    required this.tripName,
    required this.allItems,
    required this.days,
  });

  @override
  State<RunSheetShareDialog> createState() => _RunSheetShareDialogState();
}

class _RunSheetShareDialogState extends State<RunSheetShareDialog> {
  RunSheetViewMode _selectedMode   = RunSheetViewMode.driver;
  _Expiry          _selectedExpiry = _Expiry.never;
  bool             _isGenerating   = false;
  bool             _isExportingPdf = false;
  RunSheetShareToken? _generated;
  String?          _error;

  static const _baseUrl = 'https://app.houseofdreammaker.com/run-sheet';

  String _linkFor(RunSheetShareToken t) =>
      '$_baseUrl/${t.tripId}?token=${t.token}';

  Future<void> _generate() async {
    setState(() { _isGenerating = true; _error = null; _generated = null; });

    try {
      final repos = AppRepositories.instance;
      if (repos == null) throw Exception('Not connected');

      final expiry = switch (_selectedExpiry) {
        _Expiry.h24   => DateTime.now().add(const Duration(hours: 24)),
        _Expiry.d7    => DateTime.now().add(const Duration(days: 7)),
        _Expiry.d30   => DateTime.now().add(const Duration(days: 30)),
        _Expiry.never => null,
      };

      final token = await repos.runSheetShares.createToken(
        tripId:    widget.tripId,
        teamId:    repos.currentTeamId,
        viewMode:  _selectedMode,
        createdBy: repos.currentUserId,
        label:     '${_selectedMode.label} — ${widget.tripName}',
        expiresAt: expiry,
      );

      setState(() { _generated = token; });

      // Auto-copy to clipboard
      await Clipboard.setData(ClipboardData(text: _linkFor(token)));
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      setState(() { _isGenerating = false; });
    }
  }

  Future<void> _exportPdf() async {
    setState(() { _isExportingPdf = true; _error = null; });
    try {
      Map<String, TripComponent> componentsMap = {};
      try {
        final repo = AppRepositories.instance?.components;
        if (repo != null) {
          final all = await repo.fetchForTrip(widget.tripId);
          for (final c in all) {
            if (c.itineraryItemId != null) {
              componentsMap[c.itineraryItemId!] = c;
            }
          }
        }
      } catch (_) {}

      await RunSheetPdfExport.share(
        tripName:   widget.tripName,
        allItems:   widget.allItems,
        days:       widget.days,
        viewMode:   _selectedMode,
        components: componentsMap,
      );
    } catch (_) {
      setState(() { _error = 'Could not generate PDF. Please try again.'; });
    } finally {
      setState(() { _isExportingPdf = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.share_rounded,
                      size: 18, color: AppColors.accent),
                  const SizedBox(width: 8),
                  Text('Share Run Sheet Access',
                      style: AppTextStyles.heading3),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded,
                        size: 18, color: AppColors.textMuted),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Generate a role-scoped link. Each role sees only the '
                'items and notes relevant to their function.',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Role + Expiry dropdowns side by side
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: _LabeledDropdown<RunSheetViewMode>(
                      label:   'Role',
                      value:   _selectedMode,
                      items:   RunSheetViewMode.values,
                      builder: (m) => _roleItem(m),
                      onChanged: (m) {
                        if (m == null) return;
                        setState(() {
                          _selectedMode = m;
                          _generated    = null;
                          _error        = null;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: _LabeledDropdown<_Expiry>(
                      label:   'Expires',
                      value:   _selectedExpiry,
                      items:   _Expiry.values,
                      builder: (e) => _expiryItem(e),
                      onChanged: (e) {
                        if (e == null) return;
                        setState(() {
                          _selectedExpiry = e;
                          _generated      = null;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // Error
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          size: 14, color: Color(0xFF991B1B)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!,
                            style: AppTextStyles.bodySmall
                                .copyWith(color: const Color(0xFF991B1B))),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.base),
              ],

              // Generated link
              if (_generated != null) ...[
                _GeneratedLinkCard(
                  link:      _linkFor(_generated!),
                  mode:      _generated!.viewMode,
                  expiresAt: _generated!.expiresAt,
                ),
                const SizedBox(height: AppSpacing.base),
              ],

              // Generate link button
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isGenerating || _isExportingPdf ? null : _generate,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: _isGenerating
                      ? const SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.link_rounded, size: 16),
                  label: Text(
                    _generated == null ? 'Generate Link' : 'Regenerate Link',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Divider
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text('or',
                        style: AppTextStyles.labelSmall
                            .copyWith(color: AppColors.textMuted)),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              // Export PDF button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isGenerating || _isExportingPdf ? null : _exportPdf,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: _isExportingPdf
                      ? const SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.textSecondary),
                        )
                      : const Icon(Icons.picture_as_pdf_rounded, size: 16),
                  label: Text(
                    _isExportingPdf ? 'Generating PDF…' : 'Export PDF',
                    style: AppTextStyles.labelSmall.copyWith(
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Dropdown item builders ──────────────────────────────────────────────────

  DropdownMenuItem<RunSheetViewMode> _roleItem(RunSheetViewMode m) =>
      DropdownMenuItem(
        value: m,
        child: Row(
          children: [
            Icon(m.icon, size: 14, color: m.color),
            const SizedBox(width: 8),
            Text(m.label,
                style: AppTextStyles.bodySmall.copyWith(color: m.color)),
          ],
        ),
      );

  DropdownMenuItem<_Expiry> _expiryItem(_Expiry e) => DropdownMenuItem(
        value: e,
        child: Text(e.label, style: AppTextStyles.bodySmall),
      );
}

// ── Reusable labeled dropdown ─────────────────────────────────────────────────

class _LabeledDropdown<T> extends StatelessWidget {
  final String                         label;
  final T                              value;
  final List<T>                        items;
  final DropdownMenuItem<T> Function(T) builder;
  final ValueChanged<T?>               onChanged;

  const _LabeledDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.builder,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.labelSmall),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color:        AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(8),
            border:       Border.all(color: AppColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value:       value,
              isExpanded:  true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                  size: 16, color: AppColors.textSecondary),
              style:       AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textPrimary),
              dropdownColor: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              items:       items.map(builder).toList(),
              onChanged:   onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Expiry enum ───────────────────────────────────────────────────────────────

enum _Expiry { never, h24, d7, d30 }

extension _ExpiryLabel on _Expiry {
  String get label => switch (this) {
    _Expiry.never => 'Never',
    _Expiry.h24   => '24 hours',
    _Expiry.d7    => '7 days',
    _Expiry.d30   => '30 days',
  };
}

// ── Generated link card ───────────────────────────────────────────────────────

class _GeneratedLinkCard extends StatefulWidget {
  final String           link;
  final RunSheetViewMode mode;
  final DateTime?        expiresAt;

  const _GeneratedLinkCard({
    required this.link,
    required this.mode,
    this.expiresAt,
  });

  @override
  State<_GeneratedLinkCard> createState() => _GeneratedLinkCardState();
}

class _GeneratedLinkCardState extends State<_GeneratedLinkCard> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.link));
    setState(() { _copied = true; });
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() { _copied = false; });
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.mode.color;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(8),
        border:       Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  size: 13, color: Color(0xFF16A34A)),
              const SizedBox(width: 6),
              Text(
                'Link generated — copied to clipboard',
                style: AppTextStyles.labelSmall.copyWith(
                  color:      const Color(0xFF15803D),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color:        color.withAlpha(15),
                  borderRadius: BorderRadius.circular(4),
                  border:       Border.all(color: color.withAlpha(60)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(widget.mode.icon, size: 10, color: color),
                    const SizedBox(width: 4),
                    Text(widget.mode.label,
                        style: AppTextStyles.overline
                            .copyWith(color: color, letterSpacing: 0.4)),
                  ],
                ),
              ),
              if (widget.expiresAt != null) ...[
                const SizedBox(width: 8),
                Text(
                  'Expires ${_fmtExpiry(widget.expiresAt!)}',
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.textMuted),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color:        AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(6),
              border:       Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.link,
                    style: AppTextStyles.labelSmall.copyWith(
                      color:      AppColors.textSecondary,
                      fontFamily: 'monospace',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _copy,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _copied
                        ? const Icon(Icons.check_rounded,
                            key: ValueKey('check'),
                            size: 14, color: Color(0xFF16A34A))
                        : const Icon(Icons.copy_rounded,
                            key: ValueKey('copy'),
                            size: 14, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmtExpiry(DateTime dt) {
    final diff = dt.difference(DateTime.now());
    if (diff.inHours < 24) return 'in ${diff.inHours}h';
    return 'in ${diff.inDays}d';
  }
}

// ── Entry point ───────────────────────────────────────────────────────────────

Future<void> showRunSheetShareDialog(
  BuildContext context, {
  required String             tripId,
  required String             tripName,
  required List<RunSheetItem> allItems,
  required List<TripDay>      days,
}) {
  return showDialog(
    context: context,
    builder: (_) => RunSheetShareDialog(
      tripId:   tripId,
      tripName: tripName,
      allItems: allItems,
      days:     days,
    ),
  );
}
