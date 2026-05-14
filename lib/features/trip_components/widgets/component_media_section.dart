import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/component_media.dart';
import '../../../data/repositories/component_media_repository.dart';
import '../../../data/repositories/supplier_media_repository.dart';
import 'supplier_media_picker_dialog.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ComponentMediaSection
//
// Shows media linked to a trip component. Allows adding from the supplier's
// library, toggling hero/visibility, editing caption override, and removing.
// Only renders when a supplier is linked (supplierId != null).
// ─────────────────────────────────────────────────────────────────────────────

class ComponentMediaSection extends StatefulWidget {
  final String                   componentId;
  final String                   teamId;
  final String?                  supplierId;
  final ComponentMediaRepository componentMediaRepo;
  final SupplierMediaRepository  supplierMediaRepo;

  const ComponentMediaSection({
    super.key,
    required this.componentId,
    required this.teamId,
    required this.supplierId,
    required this.componentMediaRepo,
    required this.supplierMediaRepo,
  });

  @override
  State<ComponentMediaSection> createState() => _ComponentMediaSectionState();
}

class _ComponentMediaSectionState extends State<ComponentMediaSection> {
  List<ComponentMedia>? _items;
  String?               _error;
  bool                  _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _error = null; });
    try {
      final items =
          await widget.componentMediaRepo.fetchForComponent(widget.componentId);
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _addFromLibrary() async {
    if (widget.supplierId == null) return;
    final alreadyIds = (_items ?? []).map((m) => m.supplierMediaId).toSet();
    if (!mounted) return;
    final chosen = await showSupplierMediaPicker(
      context,
      supplierId:         widget.supplierId!,
      alreadySelectedIds: alreadyIds,
      repo:               widget.supplierMediaRepo,
    );
    if (chosen.isEmpty || !mounted) return;

    setState(() => _saving = true);
    try {
      final added = <ComponentMedia>[];
      for (final m in chosen) {
        final cm = await widget.componentMediaRepo.add(
          teamId:          widget.teamId,
          componentId:     widget.componentId,
          supplierMediaId: m.id,
        );
        added.add(cm);
      }
      if (mounted) {
        setState(() {
          _items = [...(_items ?? []), ...added];
          _saving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add media: $e')),
        );
      }
    }
  }

  Future<void> _remove(ComponentMedia item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title:   const Text('Remove media?'),
        content: const Text('This removes the link from this component. The original media is not deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child:     const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child:     const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _saving = true);
    try {
      await widget.componentMediaRepo.remove(item.id);
      if (mounted) {
        setState(() {
          _items?.removeWhere((m) => m.id == item.id);
          _saving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove: $e')),
        );
      }
    }
  }

  Future<void> _setHero(ComponentMedia item) async {
    setState(() {
      _items = _items?.map((m) => m.copyWith(isHero: m.id == item.id)).toList();
    });
    try {
      await widget.componentMediaRepo.setHero(widget.componentId, item.id);
    } catch (_) {
      await _load();
    }
  }

  Future<void> _toggleVisibility(ComponentMedia item) async {
    final updated = item.copyWith(isVisible: !item.isVisible);
    setState(() {
      _items = _items?.map((m) => m.id == item.id ? updated : m).toList();
    });
    try {
      await widget.componentMediaRepo.update(updated);
    } catch (_) {
      await _load();
    }
  }

  Future<void> _editCaption(ComponentMedia item) async {
    final ctrl = TextEditingController(text: item.captionOverride ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title:   const Text('Caption Override'),
        content: TextField(
          controller:  ctrl,
          maxLines:    2,
          decoration:  const InputDecoration(
            hintText: 'Leave empty to use supplier media caption',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child:     const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(ctrl.text),
            child:     const Text('Save'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (result == null || !mounted) return;

    final updated = item.copyWith(
      captionOverride: result.trim().isEmpty ? null : result.trim(),
    );
    setState(() {
      _items = _items?.map((m) => m.id == item.id ? updated : m).toList();
    });
    try {
      await widget.componentMediaRepo.update(updated);
    } catch (_) {
      await _load();
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Selected Media', style: AppTextStyles.overline),
                  const SizedBox(height: 2),
                  Text(
                    widget.supplierId == null
                        ? 'Link a supplier above to pick media.'
                        : 'Media shown to clients in itinerary.',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            if (widget.supplierId != null && (_items?.isNotEmpty ?? false))
              TextButton.icon(
                onPressed: _saving ? null : _addFromLibrary,
                icon:  const Icon(Icons.add_photo_alternate_outlined, size: 16),
                label: const Text('Add'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  textStyle: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),

        if (_error != null)
          _ErrorBanner(message: _error!, onRetry: _load)
        else if (_items == null)
          const _Shimmer()
        else if (_items!.isEmpty)
          _EmptyState(
            hasSupplier: widget.supplierId != null,
            onAdd:       _addFromLibrary,
            saving:      _saving,
          )
        else
          _MediaList(
            items:              _items!,
            onRemove:           _remove,
            onSetHero:          _setHero,
            onToggleVisibility: _toggleVisibility,
            onEditCaption:      _editCaption,
          ),
      ],
    );
  }
}

// ── Media list ────────────────────────────────────────────────────────────────

class _MediaList extends StatelessWidget {
  final List<ComponentMedia>            items;
  final void Function(ComponentMedia)   onRemove;
  final void Function(ComponentMedia)   onSetHero;
  final void Function(ComponentMedia)   onToggleVisibility;
  final void Function(ComponentMedia)   onEditCaption;

  const _MediaList({
    required this.items,
    required this.onRemove,
    required this.onSetHero,
    required this.onToggleVisibility,
    required this.onEditCaption,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap:  true,
      physics:     const NeverScrollableScrollPhysics(),
      itemCount:   items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _MediaRow(
        item:               items[i],
        onRemove:           () => onRemove(items[i]),
        onSetHero:          () => onSetHero(items[i]),
        onToggleVisibility: () => onToggleVisibility(items[i]),
        onEditCaption:      () => onEditCaption(items[i]),
      ),
    );
  }
}

// ── Single media row ──────────────────────────────────────────────────────────

String _authUrl(String url) =>
    url.replaceFirst('/object/public/', '/object/authenticated/');

Map<String, String> _storageHeaders() {
  final token = Supabase.instance.client.auth.currentSession?.accessToken;
  return token != null ? {'Authorization': 'Bearer $token'} : {};
}

class _MediaRow extends StatelessWidget {
  final ComponentMedia item;
  final VoidCallback   onRemove;
  final VoidCallback   onSetHero;
  final VoidCallback   onToggleVisibility;
  final VoidCallback   onEditCaption;

  const _MediaRow({
    required this.item,
    required this.onRemove,
    required this.onSetHero,
    required this.onToggleVisibility,
    required this.onEditCaption,
  });

  @override
  Widget build(BuildContext context) {
    final media   = item.media;
    final preview = media?.previewUrl ?? '';

    return Container(
      decoration: BoxDecoration(
        color:        AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
            child: SizedBox(
              width:  72,
              height: 54,
              child: preview.isNotEmpty
                  ? Image.network(
                      _authUrl(preview),
                      headers:      _storageHeaders(),
                      fit:          BoxFit.cover,
                      errorBuilder: (_, _, _) => const ColoredBox(color: AppColors.border),
                    )
                  : const ColoredBox(color: AppColors.border),
            ),
          ),

          // Title / caption
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    media?.title.isNotEmpty == true
                        ? media!.title
                        : (media?.isVideo == true ? 'Video' : 'Image'),
                    style:    AppTextStyles.labelMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.effectiveCaption.isNotEmpty)
                    Text(
                      item.effectiveCaption,
                      style:    AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (item.isHero)
                        _Tag(label: 'Hero', color: AppColors.accent),
                      if (!item.isVisible)
                        _Tag(label: 'Hidden', color: AppColors.textMuted),
                      if (media?.isVideo == true)
                        _Tag(label: 'Video', color: AppColors.textSecondary),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Action buttons
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ActionBtn(
                icon:    item.isHero
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                color:   item.isHero ? AppColors.accent : AppColors.textMuted,
                tooltip: item.isHero ? 'Remove hero' : 'Set as hero',
                onTap:   onSetHero,
              ),
              _ActionBtn(
                icon:    item.isVisible
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color:   item.isVisible ? AppColors.textSecondary : AppColors.textMuted,
                tooltip: item.isVisible ? 'Hide' : 'Show',
                onTap:   onToggleVisibility,
              ),
              _ActionBtn(
                icon:    Icons.edit_outlined,
                color:   AppColors.textMuted,
                tooltip: 'Edit caption',
                onTap:   onEditCaption,
              ),
              _ActionBtn(
                icon:    Icons.delete_outline_rounded,
                color:   const Color(0xFFDC2626),
                tooltip: 'Remove',
                onTap:   onRemove,
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color  color;
  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        margin:  const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color:        color.withAlpha(20),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color:    color,
            fontSize: 9,
          ),
        ),
      );
}

class _ActionBtn extends StatelessWidget {
  final IconData     icon;
  final Color        color;
  final String       tooltip;
  final VoidCallback onTap;
  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: GestureDetector(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(icon, size: 16, color: color),
          ),
        ),
      );
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool         hasSupplier;
  final VoidCallback onAdd;
  final bool         saving;
  const _EmptyState({
    required this.hasSupplier,
    required this.onAdd,
    required this.saving,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color:        AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: AppColors.divider),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.photo_library_outlined,
            size:  32,
            color: hasSupplier ? AppColors.border : AppColors.divider,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            hasSupplier
                ? 'No media selected yet'
                : 'Link a supplier to pick media',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
          ),
          if (hasSupplier) ...[
            const SizedBox(height: 4),
            Text(
              'Images must first be uploaded in the supplier\'s profile.',
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
          if (hasSupplier) ...[
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: saving ? null : onAdd,
              icon:      const Icon(Icons.add_photo_alternate_outlined, size: 15),
              label:     const Text('Add from Library'),
              style:     OutlinedButton.styleFrom(
                foregroundColor: AppColors.accent,
                side:            const BorderSide(color: AppColors.accent),
                textStyle:       AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Shimmer placeholder ───────────────────────────────────────────────────────

class _Shimmer extends StatelessWidget {
  const _Shimmer();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(2, (_) => Container(
        height:      54,
        margin:      const EdgeInsets.only(bottom: 8),
        decoration:  BoxDecoration(
          color:        AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
        ),
      )),
    );
  }
}

// ── Error banner ──────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String       message;
  final VoidCallback onRetry;
  const _ErrorBanner({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color:        const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, size: 16, color: Color(0xFFDC2626)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: AppTextStyles.bodySmall.copyWith(color: const Color(0xFFDC2626))),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
