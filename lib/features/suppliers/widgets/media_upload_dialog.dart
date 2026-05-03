import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/supplier_media.dart';
import '../services/media_upload_service.dart';

Future<SupplierMedia?> showMediaUploadDialog(
  BuildContext context, {
  required MediaUploadService service,
  required String             supplierId,
  required String             teamId,
}) =>
    showDialog<SupplierMedia>(
      context:           context,
      barrierDismissible: false,
      builder:           (_) => _Dialog(
        service:    service,
        supplierId: supplierId,
        teamId:     teamId,
      ),
    );

// ── Dialog ────────────────────────────────────────────────────────────────────

class _Dialog extends StatefulWidget {
  final MediaUploadService service;
  final String             supplierId;
  final String             teamId;
  const _Dialog({
    required this.service,
    required this.supplierId,
    required this.teamId,
  });

  @override
  State<_Dialog> createState() => _DialogState();
}

class _DialogState extends State<_Dialog> with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  // Image
  Uint8List? _imageBytes;
  String?    _imageName;

  // Video
  bool       _useUrl       = true;
  final      _videoUrlCtrl = TextEditingController();
  String?    _videoPreviewUrl;
  Uint8List? _videoBytes;
  String?    _videoName;

  // Common
  final _titleCtrl   = TextEditingController();
  final _captionCtrl = TextEditingController();
  bool  _isHero      = false;
  bool  _uploading   = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _videoUrlCtrl.addListener(_onVideoUrlChanged);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _titleCtrl.dispose();
    _captionCtrl.dispose();
    _videoUrlCtrl.dispose();
    super.dispose();
  }

  void _onVideoUrlChanged() {
    final thumb = _ytThumbnail(_videoUrlCtrl.text);
    if (thumb != _videoPreviewUrl) setState(() => _videoPreviewUrl = thumb);
  }

  Future<void> _pickImage() async {
    final r = await FilePicker.platform.pickFiles(
      type:             FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png'],
      withData:         true,
    );
    if (r != null && r.files.isNotEmpty) {
      final f = r.files.first;
      setState(() { _imageBytes = f.bytes; _imageName = f.name; });
    }
  }

  Future<void> _pickVideo() async {
    final r = await FilePicker.platform.pickFiles(
      type:     FileType.video,
      withData: true,
    );
    if (r != null && r.files.isNotEmpty) {
      final f = r.files.first;
      setState(() { _videoBytes = f.bytes; _videoName = f.name; });
    }
  }

  static String? _ytThumbnail(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    String? id;
    if (uri.host.contains('youtu.be')) {
      id = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
    } else if (uri.host.contains('youtube.com')) {
      id = uri.queryParameters['v'];
    }
    return id != null ? 'https://img.youtube.com/vi/$id/hqdefault.jpg' : null;
  }

  Future<void> _upload() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Title is required.');
      return;
    }

    final isImage = _tabs.index == 0;
    if (isImage && _imageBytes == null) {
      setState(() => _error = 'Please select an image file.');
      return;
    }
    if (!isImage && _useUrl && _videoUrlCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please enter a video URL.');
      return;
    }
    if (!isImage && !_useUrl && _videoBytes == null) {
      setState(() => _error = 'Please select a video file.');
      return;
    }

    setState(() { _uploading = true; _error = null; });

    try {
      final caption = _captionCtrl.text.trim();
      final spec = isImage
          ? MediaUploadSpec(
              bytes:     _imageBytes,
              fileName:  _imageName,
              mediaType: SupplierMediaType.image,
              title:     title,
              caption:   caption.isEmpty ? null : caption,
              isHero:    _isHero,
            )
          : _useUrl
              ? MediaUploadSpec(
                  videoUrl:  _videoUrlCtrl.text.trim(),
                  mediaType: SupplierMediaType.video,
                  title:     title,
                  caption:   caption.isEmpty ? null : caption,
                  isHero:    _isHero,
                )
              : MediaUploadSpec(
                  bytes:     _videoBytes,
                  fileName:  _videoName,
                  mediaType: SupplierMediaType.video,
                  title:     title,
                  caption:   caption.isEmpty ? null : caption,
                  isHero:    _isHero,
                );

      final media = await widget.service.upload(
        supplierId: widget.supplierId,
        teamId:     widget.teamId,
        spec:       spec,
      );
      if (mounted) Navigator.of(context).pop(media);
    } catch (e) {
      if (mounted) setState(() { _uploading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize:       MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 12, 0),
                child: Row(
                  children: [
                    Text('Add Media', style: AppTextStyles.heading3),
                    const Spacer(),
                    IconButton(
                      icon:      const Icon(Icons.close_rounded, size: 20),
                      onPressed: _uploading ? null : () => Navigator.of(context).pop(),
                      color:     AppColors.textSecondary,
                    ),
                  ],
                ),
              ),

              // ── Tab bar ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                child: TabBar(
                  controller:            _tabs,
                  labelStyle:            AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.w600),
                  unselectedLabelStyle:  AppTextStyles.labelMedium,
                  labelColor:            AppColors.accent,
                  unselectedLabelColor:  AppColors.textSecondary,
                  indicatorColor:        AppColors.accent,
                  indicatorSize:         TabBarIndicatorSize.label,
                  dividerColor:          AppColors.border,
                  tabs: const [Tab(text: 'Image'), Tab(text: 'Video')],
                ),
              ),

              // ── Tab content (fixed height) ───────────────────────────
              SizedBox(
                height: 200,
                child: TabBarView(
                  controller: _tabs,
                  physics:    const NeverScrollableScrollPhysics(),
                  children: [
                    _ImageTab(bytes: _imageBytes, onPick: _pickImage),
                    _VideoTab(
                      useUrl:         _useUrl,
                      urlCtrl:        _videoUrlCtrl,
                      videoBytes:     _videoBytes,
                      videoPreviewUrl: _videoPreviewUrl,
                      onToggle:       (v) => setState(() => _useUrl = v),
                      onPickVideo:    _pickVideo,
                    ),
                  ],
                ),
              ),

              // ── Common fields ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LabeledField(label: 'Title *', ctrl: _titleCtrl),
                    const SizedBox(height: 12),
                    _LabeledField(label: 'Caption', ctrl: _captionCtrl, maxLines: 2),
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: () => setState(() => _isHero = !_isHero),
                      child: Row(
                        children: [
                          Icon(
                            _isHero
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size:  18,
                            color: _isHero ? AppColors.accent : AppColors.textMuted,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Set as hero image',
                            style: AppTextStyles.labelMedium.copyWith(
                              color: _isHero
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Error ────────────────────────────────────────────────
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
                  child: Text(
                    _error!,
                    style: AppTextStyles.labelSmall
                        .copyWith(color: const Color(0xFFB00020)),
                  ),
                ),

              // ── Actions ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _uploading
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: Text('Cancel', style: AppTextStyles.labelMedium),
                    ),
                    const SizedBox(width: 12),
                    _UploadBtn(uploading: _uploading, onTap: _uploading ? null : _upload),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Image tab ─────────────────────────────────────────────────────────────────

class _ImageTab extends StatelessWidget {
  final Uint8List?   bytes;
  final VoidCallback onPick;
  const _ImageTab({required this.bytes, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: GestureDetector(
        onTap: onPick,
        child: bytes != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox.expand(
                  child: Image.memory(bytes!, fit: BoxFit.cover),
                ),
              )
            : _PickZone(
                icon:  Icons.add_photo_alternate_outlined,
                label: 'Click to select image',
                hint:  'JPG or PNG · max 10 MB',
              ),
      ),
    );
  }
}

// ── Video tab ─────────────────────────────────────────────────────────────────

class _VideoTab extends StatelessWidget {
  final bool                  useUrl;
  final TextEditingController urlCtrl;
  final Uint8List?            videoBytes;
  final String?               videoPreviewUrl;
  final void Function(bool)   onToggle;
  final VoidCallback          onPickVideo;
  const _VideoTab({
    required this.useUrl,
    required this.urlCtrl,
    required this.videoBytes,
    required this.videoPreviewUrl,
    required this.onToggle,
    required this.onPickVideo,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Toggle
          Row(
            children: [
              _Chip(label: 'External URL', selected: useUrl,  onTap: () => onToggle(true)),
              const SizedBox(width: 8),
              _Chip(label: 'Upload MP4',   selected: !useUrl, onTap: () => onToggle(false)),
            ],
          ),
          const SizedBox(height: 12),

          if (useUrl) ...[
            TextField(
              controller: urlCtrl,
              style:      AppTextStyles.bodySmall,
              decoration: InputDecoration(
                hintText: 'https://youtube.com/watch?v=...',
                hintStyle: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border:        OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.accent)),
              ),
            ),
            if (videoPreviewUrl != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 60,
                  child: Image.network(
                    videoPreviewUrl!,
                    fit:          BoxFit.cover,
                    width:        double.infinity,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ],
          ] else
            GestureDetector(
              onTap: onPickVideo,
              child: videoBytes != null
                  ? _PickZone(
                      icon:  Icons.check_circle_outline_rounded,
                      label: 'Video selected',
                      tint:  AppColors.accent,
                    )
                  : _PickZone(
                      icon:  Icons.video_file_outlined,
                      label: 'Click to select MP4',
                    ),
            ),
        ],
      ),
    );
  }
}

// ── Shared sub-widgets ────────────────────────────────────────────────────────

class _PickZone extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String?  hint;
  final Color?   tint;
  const _PickZone({required this.icon, required this.label, this.hint, this.tint});

  @override
  Widget build(BuildContext context) {
    final color = tint ?? AppColors.textMuted;
    return Container(
      decoration: BoxDecoration(
        color:        AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: AppColors.border),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 30, color: color),
            const SizedBox(height: 8),
            Text(label,
                style: AppTextStyles.labelSmall.copyWith(color: color)),
            if (hint != null) ...[
              const SizedBox(height: 3),
              Text(hint!,
                  style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textMuted, fontSize: 10)),
            ],
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String   label;
  final bool     selected;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color:        selected ? AppColors.accentFaint : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(20),
          border:       Border.all(
            color: selected ? AppColors.accentLight : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color:      selected ? AppColors.accent : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String              label;
  final TextEditingController ctrl;
  final int                 maxLines;
  const _LabeledField({required this.label, required this.ctrl, this.maxLines = 1});

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

class _UploadBtn extends StatelessWidget {
  final bool         uploading;
  final VoidCallback? onTap;
  const _UploadBtn({required this.uploading, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color:        onTap != null ? AppColors.accent : AppColors.border,
          borderRadius: BorderRadius.circular(8),
        ),
        child: uploading
            ? const SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Text('Upload',
                style: AppTextStyles.labelMedium.copyWith(color: Colors.white)),
      ),
    );
  }
}
