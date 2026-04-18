import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/supabase/app_db.dart';
import '../../../data/models/run_sheet_share_token.dart';
import '../../../data/models/run_sheet_view_mode.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RunSheetShareDialog
//
// Lets the trip director generate role-scoped shareable links.
// Steps:
//   1. Select a role (Driver / Guide / Operations / Director)
//   2. (Optional) Set an expiry
//   3. Generate → token created in Supabase, link copied to clipboard
// ─────────────────────────────────────────────────────────────────────────────

class RunSheetShareDialog extends StatefulWidget {
  final String tripId;
  final String tripName;

  const RunSheetShareDialog({
    super.key,
    required this.tripId,
    required this.tripName,
  });

  @override
  State<RunSheetShareDialog> createState() => _RunSheetShareDialogState();
}

class _RunSheetShareDialogState extends State<RunSheetShareDialog> {
  RunSheetViewMode _selectedMode = RunSheetViewMode.driver;
  _Expiry          _selectedExpiry = _Expiry.never;
  bool             _isGenerating = false;
  RunSheetShareToken? _generated;
  String?          _error;

  static const _baseUrl = 'https://app.hodtravel.com/run-sheet';

  String _linkFor(RunSheetShareToken t) =>
      '$_baseUrl/${t.tripId}?token=${t.token}';

  Future<void> _generate() async {
    setState(() { _isGenerating = true; _error = null; _generated = null; });

    try {
      final repos = AppRepositories.instance;
      if (repos == null) throw Exception('Not connected');

      final userId = repos.currentUserId ?? '';
      final expiry = switch (_selectedExpiry) {
        _Expiry.h24  => DateTime.now().add(const Duration(hours: 24)),
        _Expiry.d7   => DateTime.now().add(const Duration(days: 7)),
        _Expiry.d30  => DateTime.now().add(const Duration(days: 30)),
        _Expiry.never => null,
      };

      final token = await repos.runSheetShares.createToken(
        tripId:    widget.tripId,
        teamId:    repos.currentTeamId ?? '',
        viewMode:  _selectedMode,
        createdBy: userId,
        label:     '${_selectedMode.label} — ${widget.tripName}',
        expiresAt: expiry,
      );

      setState(() { _generated = token; });

      // Auto-copy to clipboard
      await Clipboard.setData(ClipboardData(text: _linkFor(token)));
    } catch (e) {
      setState(() { _error = 'Could not generate link. Please try again.'; });
    } finally {
      setState(() { _isGenerating = false; });
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

              // Role selector
              Text('Select role', style: AppTextStyles.labelSmall),
              const SizedBox(height: 8),
              _RoleGrid(
                selected: _selectedMode,
                onSelected: (m) => setState(() {
                  _selectedMode = m;
                  _generated    = null;
                  _error        = null;
                }),
              ),
              const SizedBox(height: AppSpacing.base),

              // Expiry selector
              Text('Link expires', style: AppTextStyles.labelSmall),
              const SizedBox(height: 8),
              _ExpiryRow(
                selected: _selectedExpiry,
                onSelected: (e) => setState(() {
                  _selectedExpiry = e;
                  _generated      = null;
                }),
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
                  link: _linkFor(_generated!),
                  mode: _generated!.viewMode,
                  expiresAt: _generated!.expiresAt,
                ),
                const SizedBox(height: AppSpacing.base),
              ],

              // Generate button
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isGenerating ? null : _generate,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: _isGenerating
                      ? const SizedBox(
                          width: 14,
                          height: 14,
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
            ],
          ),
        ),
      ),
    );
  }
}

// ── Role selector grid ────────────────────────────────────────────────────────

class _RoleGrid extends StatelessWidget {
  final RunSheetViewMode            selected;
  final ValueChanged<RunSheetViewMode> onSelected;

  const _RoleGrid({required this.selected, required this.onSelected});

  static const _modes = RunSheetViewMode.values;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _modes.map((m) => _RoleCard(
        mode:     m,
        isActive: m == selected,
        onTap:    () => onSelected(m),
      )).toList(),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final RunSheetViewMode mode;
  final bool             isActive;
  final VoidCallback     onTap;

  const _RoleCard({
    required this.mode,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = mode.color;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 210,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:        isActive ? color.withAlpha(15) : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border:       Border.all(
            color: isActive ? color.withAlpha(100) : AppColors.border,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color:        isActive
                    ? color.withAlpha(20)
                    : AppColors.border.withAlpha(60),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                mode.icon,
                size: 14,
                color: isActive ? color : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mode.label,
                    style: AppTextStyles.labelSmall.copyWith(
                      color:      isActive ? color : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    mode.accessScope,
                    style: AppTextStyles.overline.copyWith(
                      color: isActive
                          ? color.withAlpha(160)
                          : AppColors.textMuted,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
            if (isActive)
              Icon(Icons.check_circle_rounded, size: 14, color: color),
          ],
        ),
      ),
    );
  }
}

// ── Expiry selector ───────────────────────────────────────────────────────────

enum _Expiry { never, h24, d7, d30 }

extension _ExpiryLabel on _Expiry {
  String get label => switch (this) {
    _Expiry.never => 'Never',
    _Expiry.h24   => '24 hours',
    _Expiry.d7    => '7 days',
    _Expiry.d30   => '30 days',
  };
}

class _ExpiryRow extends StatelessWidget {
  final _Expiry            selected;
  final ValueChanged<_Expiry> onSelected;

  const _ExpiryRow({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      children: _Expiry.values.map((e) {
        final active = e == selected;
        return GestureDetector(
          onTap: () => onSelected(e),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color:        active
                  ? AppColors.accent.withAlpha(18)
                  : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(20),
              border:       Border.all(
                color: active
                    ? AppColors.accent.withAlpha(120)
                    : AppColors.border,
              ),
            ),
            child: Text(
              e.label,
              style: AppTextStyles.labelSmall.copyWith(
                color:      active
                    ? AppColors.accentDark
                    : AppColors.textSecondary,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
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
          // Role badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
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
                    Text(
                      widget.mode.label,
                      style: AppTextStyles.overline.copyWith(
                        color: color, letterSpacing: 0.4),
                    ),
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
          // Link row
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
                            size: 14,
                            color: Color(0xFF16A34A))
                        : const Icon(Icons.copy_rounded,
                            key: ValueKey('copy'),
                            size: 14,
                            color: AppColors.textSecondary),
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
  required String tripId,
  required String tripName,
}) {
  return showDialog(
    context: context,
    builder: (_) => RunSheetShareDialog(
      tripId:   tripId,
      tripName: tripName,
    ),
  );
}
