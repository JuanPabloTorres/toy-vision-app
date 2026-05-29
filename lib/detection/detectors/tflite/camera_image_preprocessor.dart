import 'dart:typed_data';

import 'package:camera/camera.dart';

import '../../models/detection_frame.dart';
import '../../models/toy_model_config.dart';
import 'image_format_converter.dart';
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
/// Pipeline: CameraImage → [RawCameraFrame] → [ImageFormatConverter] (full-color
/// YUV420 / BGRA8888 → RGB) → resize to the model's input size → normalize →
/// [ModelInput]. The conversion and resize/normalize steps are pure and
/// unit-tested with synthetic data; only the thin `CameraImage` → `RawCameraFrame`
/// mapping needs a real frame.
///
/// Orientation note: this produces a buffer in the camera's native (sensor)
/// orientation. Rotating to display/upright orientation depends on device sensor
/// orientation and is deferred to on-device validation (Phase 2c.2) to avoid
/// guessing transforms without a real device.
///
/// Belongs to the detection layer only — never UI or business code. It saves and
/// uploads nothing; the image is read transiently to build the tensor.
class CameraImagePreprocessor {
  const CameraImagePreprocessor({
    ImageFormatConverter converter = const ImageFormatConverter(),
  }) : _converter = converter;

  final ImageFormatConverter _converter;

  ModelInput preprocess(DetectionFrame frame, ToyModelConfig config) {
    final image = frame.cameraImage;
    if (image == null) {
      throw const TfliteRuntimeException('No camera image to preprocess.');
    }
    final rgb = _converter.convert(_toRawFrame(image));
    return buildInputFromRgb(rgb.bytes, rgb.width, rgb.height, config);
  }

  /// Thin mapping from the plugin's `CameraImage` to the pure [RawCameraFrame].
  RawCameraFrame _toRawFrame(CameraImage image) {
    return RawCameraFrame(
      format: image.format.group,
      width: image.width,
      height: image.height,
      planes: [
        for (final p in image.planes)
          RawImagePlane(
            bytes: p.bytes,
            bytesPerRow: p.bytesPerRow,
            bytesPerPixel: p.bytesPerPixel,
          ),
      ],
    );
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
}
