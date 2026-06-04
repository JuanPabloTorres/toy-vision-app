import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

/// Phase 5.0.1 JPEG encoder for [CameraImage] → JPEG bytes.
///
/// Converts the camera plugin's YUV420 (Android) or BGRA8888 (iOS) buffer
/// into an [img.Image] using BT.601 limited-range coefficients, then
/// encodes to JPEG. Optionally scales the source down before encoding so
/// the HTTP payload stays small and the inference server can run faster.
///
/// Privacy: every intermediate buffer lives on the stack/heap of this
/// isolate only; nothing is written to disk. The caller (the
/// `RemoteVisionDetector`) sends the JPEG once and immediately discards
/// the byte buffer.
class CameraImageJpegEncoder {
  const CameraImageJpegEncoder({
    this.targetMaxSide = 480,
    this.jpegQuality = 60,
  });

  /// Longest side the encoded JPEG should have. Smaller = less bandwidth
  /// and faster server inference, at the cost of small-object recall.
  final int targetMaxSide;

  /// JPEG quality 1..100. 60 keeps payloads under ~50 KB for 480 px frames.
  final int jpegQuality;

  /// Encode one [CameraImage] to JPEG bytes. Returns null when the input
  /// format is not one we can decode (the live loop drops that frame).
  Uint8List? encode(CameraImage image) {
    final img.Image? rgb;
    switch (image.format.group) {
      case ImageFormatGroup.yuv420:
        rgb = _yuv420ToImage(image);
      case ImageFormatGroup.bgra8888:
        rgb = _bgra8888ToImage(image);
      // ignore: no_default_cases
      default:
        return null;
    }
    if (rgb == null) return null;

    final scaled = _maybeScaleDown(rgb);
    return img.encodeJpg(scaled, quality: jpegQuality);
  }

  img.Image _maybeScaleDown(img.Image src) {
    final maxSide = src.width > src.height ? src.width : src.height;
    if (maxSide <= targetMaxSide) return src;
    final scale = targetMaxSide / maxSide;
    final newW = (src.width * scale).round();
    final newH = (src.height * scale).round();
    return img.copyResize(src, width: newW, height: newH);
  }

  /// BT.601 limited-range YUV420 → RGB conversion. Handles the camera
  /// plugin's stride/padding quirks (row stride, pixel stride for U/V).
  img.Image? _yuv420ToImage(CameraImage image) {
    if (image.planes.length < 3) return null;
    final w = image.width;
    final h = image.height;

    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];
    final yBytes = yPlane.bytes;
    final uBytes = uPlane.bytes;
    final vBytes = vPlane.bytes;
    final yRowStride = yPlane.bytesPerRow;
    final uvRowStride = uPlane.bytesPerRow;
    final uvPixelStride = uPlane.bytesPerPixel ?? 1;

    final out = img.Image(width: w, height: h);

    for (var y = 0; y < h; y++) {
      final yRow = y * yRowStride;
      final uvRow = (y >> 1) * uvRowStride;
      for (var x = 0; x < w; x++) {
        final yIdx = yRow + x;
        final uvIdx = uvRow + (x >> 1) * uvPixelStride;
        if (yIdx >= yBytes.length ||
            uvIdx >= uBytes.length ||
            uvIdx >= vBytes.length) {
          continue;
        }
        final yVal = yBytes[yIdx];
        final uVal = uBytes[uvIdx];
        final vVal = vBytes[uvIdx];

        // BT.601, full-range coefficients. The /256 scaling avoids float
        // arithmetic per pixel.
        var r = yVal + ((1436 * (vVal - 128)) >> 10);
        var g = yVal -
            ((352 * (uVal - 128)) >> 10) -
            ((731 * (vVal - 128)) >> 10);
        var b = yVal + ((1814 * (uVal - 128)) >> 10);

        r = r < 0 ? 0 : (r > 255 ? 255 : r);
        g = g < 0 ? 0 : (g > 255 ? 255 : g);
        b = b < 0 ? 0 : (b > 255 ? 255 : b);

        out.setPixelRgb(x, y, r, g, b);
      }
    }
    return out;
  }

  /// BGRA8888 (iOS) → RGB. Just reorders channels.
  img.Image? _bgra8888ToImage(CameraImage image) {
    if (image.planes.isEmpty) return null;
    final w = image.width;
    final h = image.height;
    final bytes = image.planes[0].bytes;
    final rowStride = image.planes[0].bytesPerRow;
    final out = img.Image(width: w, height: h);
    for (var y = 0; y < h; y++) {
      final row = y * rowStride;
      for (var x = 0; x < w; x++) {
        final i = row + x * 4;
        if (i + 3 >= bytes.length) continue;
        final b = bytes[i];
        final g = bytes[i + 1];
        final r = bytes[i + 2];
        out.setPixelRgb(x, y, r, g, b);
      }
    }
    return out;
  }
}
