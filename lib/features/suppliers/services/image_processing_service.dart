import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

// ── Result ────────────────────────────────────────────────────────────────────

class ProcessedImage {
  /// Optimized JPEG bytes — max 2000 px wide, quality 80.
  final Uint8List optimizedBytes;

  /// Thumbnail JPEG bytes — 400 px wide, quality 65.
  final Uint8List thumbnailBytes;

  final int width;
  final int height;

  const ProcessedImage({
    required this.optimizedBytes,
    required this.thumbnailBytes,
    required this.width,
    required this.height,
  });
}

// ── Input carrier (passed through compute isolate) ────────────────────────────

class _ProcessInput {
  final Uint8List bytes;
  _ProcessInput(this.bytes);
}

// ── Top-level isolate function ────────────────────────────────────────────────

ProcessedImage _processInIsolate(_ProcessInput input) {
  const maxWidth    = 2000;
  const thumbWidth  = 400;
  const quality     = 80;
  const thumbQuality = 65;

  final image = img.decodeImage(input.bytes);
  if (image == null) throw Exception('Unable to decode image. Please upload a JPG or PNG file.');

  // Resize main image (only downscale — never upscale)
  final img.Image main = image.width > maxWidth
      ? img.copyResize(image,
          width:         maxWidth,
          interpolation: img.Interpolation.linear)
      : image;

  // Resize thumbnail
  final img.Image thumb = img.copyResize(main,
      width:         thumbWidth,
      interpolation: img.Interpolation.linear);

  // Encode to JPEG
  final optimized = Uint8List.fromList(img.encodeJpg(main,  quality: quality));
  final thumbnail = Uint8List.fromList(img.encodeJpg(thumb, quality: thumbQuality));

  return ProcessedImage(
    optimizedBytes: optimized,
    thumbnailBytes: thumbnail,
    width:          main.width,
    height:         main.height,
  );
}

// ── Service ───────────────────────────────────────────────────────────────────

class ImageProcessingService {
  static const int maxUploadBytes = 10 * 1024 * 1024; // 10 MB

  /// Validates size, resizes to ≤ 2000 px, encodes as JPEG quality 80,
  /// and generates a 400 px JPEG thumbnail — all off the main thread.
  Future<ProcessedImage> process(Uint8List inputBytes) async {
    if (inputBytes.lengthInBytes > maxUploadBytes) {
      throw Exception(
          'File size exceeds 10 MB (${(inputBytes.lengthInBytes / 1048576).toStringAsFixed(1)} MB).');
    }
    return compute(_processInIsolate, _ProcessInput(inputBytes));
  }
}
