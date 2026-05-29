import 'dart:typed_data';

import 'package:camera/camera.dart';

import '../../models/detection_frame.dart';
import '../../models/toy_model_config.dart';
import 'tflite_runtime_exception.dart';

/// A model input tensor: a flat, normalized float buffer plus its dimensions.
class ModelInput {
  ModelInput({
    required this.data,
    required this.height,
    required this.width,
    this.batch = 1,
    this.channels = 3,
  });

  final Float32List data;
  final int batch;
  final int height;
  final int width;
  final int channels;

  int get expectedLength => batch * height * width * channels;
}

/// Prepares a [DetectionFrame]'s camera image into a normalized model input.
///
/// Pipeline: CameraImage (YUV420) → RGB buffer → resize to the model's input
/// size → normalize → [ModelInput]. The pixel resize/normalize step
/// ([buildInputFromRgb]) is pure and unit-tested. The CameraImage→RGB extraction
/// needs a real frame and is a documented foundation (see below).
///
/// Belongs to the detection layer only — never UI or business code. It saves and
/// uploads nothing; the image is read transiently to build the tensor.
class CameraImagePreprocessor {
  const CameraImagePreprocessor();

  ModelInput preprocess(DetectionFrame frame, ToyModelConfig config) {
    final image = frame.cameraImage;
    if (image == null) {
      throw const TfliteRuntimeException('No camera image to preprocess.');
    }
    final rgb = _extractRgb(image);
    return buildInputFromRgb(rgb.bytes, rgb.width, rgb.height, config);
  }

  /// Pure nearest-neighbor resize + normalization. Returns a `[1, h, w, 3]`
  /// buffer where each value is `(pixel - inputMean) / inputStd`.
  static ModelInput buildInputFromRgb(
    Uint8List rgb,
    int srcWidth,
    int srcHeight,
    ToyModelConfig config,
  ) {
    final w = config.inputWidth;
    final h = config.inputHeight;
    final out = Float32List(w * h * 3);
    final mean = config.inputMean;
    final std = config.inputStd == 0 ? 1.0 : config.inputStd;

    var o = 0;
    for (var y = 0; y < h; y++) {
      final sy = ((y * srcHeight) ~/ h).clamp(0, srcHeight - 1);
      for (var x = 0; x < w; x++) {
        final sx = ((x * srcWidth) ~/ w).clamp(0, srcWidth - 1);
        final si = (sy * srcWidth + sx) * 3;
        out[o++] = (rgb[si] - mean) / std;
        out[o++] = (rgb[si + 1] - mean) / std;
        out[o++] = (rgb[si + 2] - mean) / std;
      }
    }
    return ModelInput(data: out, width: w, height: h);
  }

  /// Foundation extraction: supports YUV420 by mapping the luminance (Y) plane
  /// to grayscale RGB. Full-color chroma conversion lands in Phase 2c.1; this is
  /// crash-safe and produces a correctly-shaped buffer. Unsupported formats fail
  /// safely with a [TfliteRuntimeException].
  _RgbImage _extractRgb(CameraImage image) {
    if (image.format.group != ImageFormatGroup.yuv420) {
      throw TfliteRuntimeException(
        'Unsupported camera image format: ${image.format.group}',
      );
    }
    final w = image.width;
    final h = image.height;
    final yPlane = image.planes.first;
    final rowStride = yPlane.bytesPerRow;
    final bytes = yPlane.bytes;
    final rgb = Uint8List(w * h * 3);

    var o = 0;
    for (var y = 0; y < h; y++) {
      final row = y * rowStride;
      for (var x = 0; x < w; x++) {
        final lum = bytes[row + x];
        rgb[o++] = lum;
        rgb[o++] = lum;
        rgb[o++] = lum;
      }
    }
    return _RgbImage(rgb, w, h);
  }
}

class _RgbImage {
  _RgbImage(this.bytes, this.width, this.height);
  final Uint8List bytes;
  final int width;
  final int height;
}
