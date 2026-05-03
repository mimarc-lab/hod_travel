import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/supplier_media.dart';
import '../../../data/repositories/supplier_media_repository.dart';
import '../services/media_upload_service.dart';
import 'media_grid.dart';
import 'media_upload_dialog.dart';
import 'media_viewer_modal.dart';

class SupplierMediaSection extends StatefulWidget {
  final String                   supplierId;
  final String                   teamId;
  final SupplierMediaRepository  repository;

  const SupplierMediaSection({
    super.key,
    required this.supplierId,
    required this.teamId,
    required this.repository,
  });

  @override
  State<SupplierMediaSection> createState() => _SupplierMediaSectionState();
}

class _SupplierMediaSectionState extends State<SupplierMediaSection> {
  List<SupplierMedia> _items    = [];
  bool                _loading  = true;
  String?             _error;
  late final MediaUploadService _svc;

  @override
  void initState() {
    super.initState();
    _svc = MediaUploadService(repo: widget.repository);
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final items = await widget.repository.fetchForSupplier(widget.supplierId);
      if (mounted) setState(() { _items = items; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('MEDIA LIBRARY', style: AppTextStyles.overline),
            if (!_loading)
              _AddBtn(onTap: _handleAdd),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),

        if (_loading)
          const _Shimmer()
        else if (_error != null)
          _ErrorBanner(message: _error!, onRetry: _load)
        else
          MediaGrid(
            items:       _items,
            showControls: true,
            onTap:       (i, _) => showMediaViewer(
              context,
              items:        _items,
              initialIndex: i,
            ),
            onEdit:    _handleEdit,
            onSetHero: _handleSetHero,
            onDelete:  _handleDelete,
          ),
      ],
    );
  }

  // ── Handlers ────────────────────────────────────────────────────────────────

  Future<void> _handleAdd() async {
    if (!mounted) return;
    final media = await showMediaUploadDialog(
      context,
      service:    _svc,
      supplierId: widget.supplierId,
      teamId:     widget.teamId,
    );
    if (media != null && mounted) {
      setState(() => _items = [
        if (media.isHero)
          for (final i in _items) i.copyWith(isHero: false)
        else
          ..._items,
        media,
      ]);
    }
  }

  Future<void> _handleSetHero(SupplierMedia m) async {
    try {
      await widget.repository.setHero(widget.supplierId, m.id);
      if (mounted) {
        setState(() => _items = [
          for (final i in _items) i.copyWith(isHero: i.id == m.id),
        ]);
      }
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _handleDelete(SupplierMedia m) async {
    final label = m.title.isNotEmpty ? '"${m.title}"' : 'this item';
    final ok    = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape:   RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title:   Text('Remove media?', style: AppTextStyles.heading3),
        content: Text('Remove $label from the media library.',
            style: AppTextStyles.bodySmall),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: AppTextStyles.labelMedium),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Remove',
                style: AppTextStyles.labelMedium
                    .copyWith(color: const Color(0xFFB00020))),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await widget.repository.deactivate(m.id);
      if (mounted) {
        setState(() => _items = _items.where((i) => i.id != m.id).toList());
      }
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _handleEdit(SupplierMedia m) async {
    final titleCtrl   = TextEditingController(text: m.title);
    final captionCtrl = TextEditingController(text: m.caption ?? '');
    var   isHero      = m.isHero;

    final updated = await showDialog<SupplierMedia>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Dialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize:       MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Edit Media', style: AppTextStyles.heading3),
                  const SizedBox(height: 20),
                  _EditField(label: 'Title',   ctrl: titleCtrl),
                  const SizedBox(height: 12),
                  _EditField(label: 'Caption', ctrl: captionCtrl, maxLines: 2),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: () => set(() => isHero = !isHero),
                    child: Row(
                      children: [
                        Icon(
                          isHero ? Icons.star_rounded : Icons.star_outline_rounded,
                          size:  18,
                          color: isHero ? AppColors.accent : AppColors.textMuted,
                        ),
                        const SizedBox(width: 8),
                        Text('Hero image',
                            style: AppTextStyles.labelMedium.copyWith(
                              color: isHero
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child:     Text('Cancel', style: AppTextStyles.labelMedium),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        onPressed: () => Navigator.of(ctx).pop(
                          m.copyWith(
                            title:   titleCtrl.text.trim(),
                            caption: captionCtrl.text.trim().isEmpty
                                ? null
                                : captionCtrl.text.trim(),
                            isHero:  isHero,
                          ),
                        ),
                        child: Text('Save',
                            style: AppTextStyles.labelMedium
                                .copyWith(color: Colors.white)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    titleCtrl.dispose();
    captionCtrl.dispose();

    if (updated == null || !mounted) return;
    try {
      // If hero is being set, clear others first to respect the unique constraint.
      if (updated.isHero && !m.isHero) {
        await widget.repository.clearHero(widget.supplierId);
      }
      final saved = await widget.repository.update(updated);
      if (mounted) {
        setState(() => _items = [
          for (final i in _items)
            if (i.id == saved.id)
              saved
            else
              saved.isHero ? i.copyWith(isHero: false) : i,
        ]);
      }
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:          Text(msg),
        backgroundColor:  const Color(0xFFB00020),
        behavior:         SnackBarBehavior.floating,
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _AddBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _AddBtn({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color:        AppColors.accentFaint,
          borderRadius: BorderRadius.circular(8),
          border:       Border.all(color: AppColors.accentLight),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, size: 14, color: AppColors.accent),
            const SizedBox(width: 4),
            Text('Add Media',
                style: AppTextStyles.labelSmall.copyWith(color: AppColors.accent)),
          ],
        ),
      ),
    );
  }
}

class _Shimmer extends StatelessWidget {
  const _Shimmer();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap:    true,
      physics:       const NeverScrollableScrollPhysics(),
      gridDelegate:  const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:   3,
        crossAxisSpacing: 12,
        mainAxisSpacing:  12,
        childAspectRatio: 3 / 2,
      ),
      itemCount:   3,
      itemBuilder: (_, _) => Container(
        decoration: BoxDecoration(
          color:        AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String       message;
  final VoidCallback onRetry;
  const _ErrorBanner({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color:        const Color(0xFFFFF0F0),
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: const Color(0xFFFFCDD2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 16, color: Color(0xFFB00020)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: AppTextStyles.labelSmall
                    .copyWith(color: const Color(0xFFB00020))),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text('Retry',
                style: AppTextStyles.labelSmall.copyWith(color: AppColors.accent)),
          ),
        ],
      ),
    );
  }
}

class _EditField extends StatelessWidget {
  final String              label;
  final TextEditingController ctrl;
  final int                 maxLines;
  const _EditField({required this.label, required this.ctrl, this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 5),
        TextField(
          controller: ctrl,
          maxLines:   maxLines,
          style:      AppTextStyles.bodySmall,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border:        OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.accent)),
          ),
        ),
      ],
    );
  }
}
