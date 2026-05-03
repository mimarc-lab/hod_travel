import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/supplier_media.dart';
import '../../../data/repositories/supplier_media_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// showSupplierMediaPicker
//
// Presents a bottom sheet of the supplier's active media. The caller passes
// [alreadySelectedIds] so already-linked items show a checkmark. Returns the
// list of newly chosen items (not including already-selected ones).
// ─────────────────────────────────────────────────────────────────────────────

Future<List<SupplierMedia>> showSupplierMediaPicker(
  BuildContext context, {
  required String supplierId,
  required Set<String> alreadySelectedIds,
  required SupplierMediaRepository repo,
}) async {
  final result = await showModalBottomSheet<List<SupplierMedia>>(
    context:            context,
    isScrollControlled: true,
    backgroundColor:    Colors.transparent,
    builder: (_) => _PickerSheet(
      supplierId:          supplierId,
      alreadySelectedIds:  alreadySelectedIds,
      repo:                repo,
    ),
  );
  return result ?? [];
}

// ─────────────────────────────────────────────────────────────────────────────

class _PickerSheet extends StatefulWidget {
  final String                  supplierId;
  final Set<String>             alreadySelectedIds;
  final SupplierMediaRepository repo;

  const _PickerSheet({
    required this.supplierId,
    required this.alreadySelectedIds,
    required this.repo,
  });

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  List<SupplierMedia>? _items;
  String?              _error;
  final Set<String>    _picked = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await widget.repo.fetchForSupplier(widget.supplierId);
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  void _toggle(SupplierMedia m) {
    if (widget.alreadySelectedIds.contains(m.id)) return;
    setState(() {
      if (_picked.contains(m.id)) {
        _picked.remove(m.id);
      } else {
        _picked.add(m.id);
      }
    });
  }

  void _confirm() {
    final chosen = (_items ?? [])
        .where((m) => _picked.contains(m.id))
        .toList();
    Navigator.of(context).pop(chosen);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: const BoxDecoration(
        color:        AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          _handle(),
          _header(),
          const Divider(height: 1, color: AppColors.divider),
          Expanded(child: _body()),
          if ((_items?.isNotEmpty ?? false)) _footer(),
        ],
      ),
    );
  }

  Widget _handle() => Center(
        child: Container(
          margin:     const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          width:      36,
          height:     4,
          decoration: BoxDecoration(
            color:        AppColors.border,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  Widget _header() => Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pagePaddingH,
          vertical:   AppSpacing.sm,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text('Select Media', style: AppTextStyles.heading3),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(<SupplierMedia>[]),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );

  Widget _body() {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.textMuted, size: 32),
            const SizedBox(height: AppSpacing.sm),
            Text(_error!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
            const SizedBox(height: AppSpacing.base),
            OutlinedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_items == null) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    if (_items!.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.photo_library_outlined, size: 40, color: AppColors.border),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'No media in this supplier\'s library yet.',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding:          const EdgeInsets.all(AppSpacing.pagePaddingH),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:   3,
        crossAxisSpacing: 8,
        mainAxisSpacing:  8,
        childAspectRatio: 3 / 2,
      ),
      itemCount:   _items!.length,
      itemBuilder: (_, i) => _Tile(
        media:       _items![i],
        isPicked:    _picked.contains(_items![i].id),
        isLinked:    widget.alreadySelectedIds.contains(_items![i].id),
        onTap:       () => _toggle(_items![i]),
      ),
    );
  }

  Widget _footer() {
    final count = _picked.length;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pagePaddingH,
          vertical:   AppSpacing.base,
        ),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: count > 0 ? _confirm : null,
            child: Text(count == 0
                ? 'Select media to add'
                : 'Add $count item${count == 1 ? '' : 's'}'),
          ),
        ),
      ),
    );
  }
}

// ── Grid tile ─────────────────────────────────────────────────────────────────

String _authUrl(String url) =>
    url.replaceFirst('/object/public/', '/object/authenticated/');

Map<String, String> _storageHeaders() {
  final token = Supabase.instance.client.auth.currentSession?.accessToken;
  return token != null ? {'Authorization': 'Bearer $token'} : {};
}

class _Tile extends StatelessWidget {
  final SupplierMedia media;
  final bool          isPicked;
  final bool          isLinked;
  final VoidCallback  onTap;

  const _Tile({
    required this.media,
    required this.isPicked,
    required this.isLinked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final preview = media.previewUrl;

    return GestureDetector(
      onTap: isLinked ? null : onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Image
            preview.isNotEmpty
                ? Image.network(
                    _authUrl(preview),
                    headers:      _storageHeaders(),
                    fit:          BoxFit.cover,
                    errorBuilder: (_, _, _) => const ColoredBox(color: AppColors.surfaceAlt),
                  )
                : const ColoredBox(color: AppColors.surfaceAlt),

            // Dim for already-linked
            if (isLinked)
              Container(color: Colors.black.withAlpha(80)),

            // Selection overlay
            if (isPicked)
              Container(color: AppColors.accent.withAlpha(50)),

            // Title gradient
            Align(
              alignment: Alignment.bottomLeft,
              child: Container(
                width:  double.infinity,
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin:  Alignment.topCenter,
                    end:    Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xBB000000)],
                  ),
                ),
                child: media.title.isNotEmpty
                    ? Text(
                        media.title,
                        style:    AppTextStyles.labelSmall.copyWith(color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    : const SizedBox.shrink(),
              ),
            ),

            // Check icon — already linked
            if (isLinked)
              const Positioned(
                top:   6,
                right: 6,
                child: _Badge(
                  icon:    Icons.check_circle_rounded,
                  color:   Colors.white70,
                  bgColor: Colors.transparent,
                ),
              ),

            // Check icon — just picked
            if (isPicked && !isLinked)
              Positioned(
                top:   6,
                right: 6,
                child: _Badge(
                  icon:    Icons.check_circle_rounded,
                  color:   Colors.white,
                  bgColor: AppColors.accent,
                ),
              ),

            // Video badge
            if (media.isVideo)
              const Center(
                child: Icon(Icons.play_circle_filled_rounded, color: Colors.white70, size: 28),
              ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final Color    bgColor;

  const _Badge({required this.icon, required this.color, required this.bgColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width:      22,
      height:     22,
      decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
      child:      Icon(icon, size: 20, color: color),
    );
  }
}
