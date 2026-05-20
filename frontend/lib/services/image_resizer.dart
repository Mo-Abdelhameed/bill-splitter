import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Resize an image down to a maximum long-edge constraint while preserving
/// aspect ratio. If the image is already small enough, the input is returned
/// unchanged (no re-encode).
abstract class ImageResizer {
  Future<Uint8List> resize(Uint8List bytes, {required int maxLongEdge});
}

class ImageResizerImpl implements ImageResizer {
  @override
  Future<Uint8List> resize(
    Uint8List bytes, {
    required int maxLongEdge,
  }) async {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      // Could not decode — return original so the caller can still try
      // downstream consumers (or surface the failure there).
      return bytes;
    }
    final longest = decoded.width > decoded.height ? decoded.width : decoded.height;
    if (longest <= maxLongEdge) {
      return bytes;
    }
    final scale = maxLongEdge / longest;
    final newWidth = (decoded.width * scale).round();
    final newHeight = (decoded.height * scale).round();
    final resized = img.copyResize(
      decoded,
      width: newWidth,
      height: newHeight,
      interpolation: img.Interpolation.average,
    );
    return Uint8List.fromList(img.encodePng(resized));
  }
}
