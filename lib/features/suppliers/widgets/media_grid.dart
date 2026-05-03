import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/supplier_media.dart';
import 'media_card.dart';

class MediaGrid extends StatelessWidget {
  final List<SupplierMedia>               items;
  final bool                              showControls;
  final void Function(int, SupplierMedia)? onTap;
  final void Function(SupplierMedia)?     onEdit;
  final void Function(SupplierMedia)?     onSetHero;
  final void Function(SupplierMedia)?     onDelete;

  const MediaGrid({
    super.key,
    required this.items,
    this.showControls = false,
    this.onTap,
    this.onEdit,
    this.onSetHero,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const _EmptyState();

    final w    = MediaQuery.sizeOf(context).width;
    final cols = w < 500 ? 2 : w < 900 ? 3 : 4;

    return GridView.builder(
      shrinkWrap:    true,
      physics:       const NeverScrollableScrollPhysics(),
      gridDelegate:  SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:   cols,
        crossAxisSpacing: 12,
        mainAxisSpacing:  12,
        childAspectRatio: 3 / 2,
      ),
      itemCount:   items.length,
      itemBuilder: (_, i) {
        final m = items[i];
        return MediaCard(
          key:          ValueKey(m.id),
          media:        m,
          showControls: showControls,
          onTap:        () => onTap?.call(i, m),
          onEdit:       () => onEdit?.call(m),
          onSetHero:    () => onSetHero?.call(m),
          onDelete:     () => onDelete?.call(m),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color:        AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: AppColors.border),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_library_outlined, size: 36, color: AppColors.textMuted),
            const SizedBox(height: 10),
            Text('No media yet',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
            const SizedBox(height: 4),
            Text('Add photos or videos to build the media library',
                style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
