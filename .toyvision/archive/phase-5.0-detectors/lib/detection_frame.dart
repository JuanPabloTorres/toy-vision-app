import 'package:camera/camera.dart';

/// Neutral input wrapper handed to a [ToyDetector] for one frame.
///
/// This is the single, controlled place the camera plugin's [CameraImage] type
/// enters the detection layer, so plugin details don't leak across the codebase.
/// The mock detector uses only [frameIndex]; the future TFLite detector will
/// read [cameraImage]. The image is used transiently and never persisted.
class DetectionFrame {
  const DetectionFrame({
    required this.cameraImage,
    required this.frameIndex,
    required this.capturedAt,
  });

  /// The raw camera frame, when available. Null in mock/test paths.
  final CameraImage? cameraImage;

  /// Monotonic index of accepted (processed) frames since the last reset.
  final int frameIndex;

  final DateTime capturedAt;
}
