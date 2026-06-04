import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart'
    show WriteBuffer, debugPrint, kDebugMode;
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';

import '../../models/bounding_box.dart';
import '../../models/detection_frame.dart';
import '../../models/raw_detection.dart';
import '../toy_detector.dart';
import 'mlkit_label_map.dart';

/// Real-time on-device object detector backed by Google ML Kit.
///
/// Phase 3.6 replaces the custom `tflite_flutter` pipeline. ML Kit ships its
/// own on-device classifier and runtime: it accepts raw [CameraImage] bytes
/// (YUV420 on Android, BGRA8888 on iOS), performs orientation-aware
/// preprocessing, runs detection + classification, and returns bounded objects
/// with optional labels. None of those concerns live in this codebase any
/// more.
///
/// Privacy: ML Kit is on-device by default — no Google account required, no
/// network call, no upload. Frames are read transiently to build the input
/// image and are never persisted by this detector.
///
/// Output contract: same [RawDetection] shape as before. Labels go through
/// [MlKitLabelMap] so the business layer (`ToyDetectionRules` /
/// `ToyCategoryRegistry`) keeps full control over what counts as a toy.
class MlKitObjectDetector implements ToyDetector {
  /// Public constructor used in production. The injected [sensorOrientation]
  /// is the back camera's static sensor rotation (typically 90° on Android
  /// phones) — ML Kit uses it to rotate the input to upright internally.
  MlKitObjectDetector({this.sensorOrientation = 90})
      : _detector = _defaultDetector();

  /// Test-only constructor that lets the caller inject a custom backing
  /// [ObjectDetector] (e.g. one configured with single-image mode for a unit
  /// test). Never used in production wiring.
  MlKitObjectDetector.withDetector(this._detector, {this.sensorOrientation = 0});

  static ObjectDetector _defaultDetector() => ObjectDetector(
        options: ObjectDetectorOptions(
          // Stream mode skips per-frame model warmup and assumes consecutive
          // frames are from a live camera — the exact use case for ToyVision.
          mode: DetectionMode.stream,
          classifyObjects: true,
          multipleObjects: true,
        ),
      );

  final ObjectDetector _detector;

  /// Back-camera sensor rotation in degrees (0/90/180/270). Most Android
  /// devices report 90 for the back camera. ML Kit applies this to rotate the
  /// input image to upright before running detection.
  final int sensorOrientation;

  bool _disposed = false;
  bool _firstDetectLogged = false;

  @override
  Future<void> initialize() async {
    // ML Kit lazily loads the model on first `processImage`; no warmup is
    // required. Kept as an async no-op to satisfy the [ToyDetector] contract.
    if (kDebugMode) {
      debugPrint(
        'ToyVisionDX: lifecycle.mlkit.initialize sensorOrientation='
        '$sensorOrientation',
      );
    }
  }

  @override
  Future<List<RawDetection>> detect(DetectionFrame frame) async {
    if (_disposed) return const [];
    final image = frame.cameraImage;
    if (image == null) return const [];

    final input = _toInputImage(image);
    if (input == null) {
      if (kDebugMode && !_firstDetectLogged) {
        _firstDetectLogged = true;
        debugPrint(
          'ToyVisionDX: lifecycle.mlkit.detect.first frame=${frame.frameIndex} '
          'inputImage=null (unsupported format raw=${image.format.raw})',
        );
      }
      return const [];
    }

    if (kDebugMode && !_firstDetectLogged) {
      _firstDetectLogged = true;
      debugPrint(
        'ToyVisionDX: lifecycle.mlkit.detect.first frame=${frame.frameIndex} '
        'imageSize=${image.width}x${image.height} '
        'formatRaw=${image.format.raw} planes=${image.planes.length} '
        'bytesPerRow=${image.planes.first.bytesPerRow}',
      );
    }

    final List<DetectedObject> objects;
    try {
      objects = await _detector.processImage(input);
    } catch (e) {
      // Defensive: ML Kit can throw on unsupported formats or transient
      // platform errors. Drop the frame rather than crashing the live loop.
      if (kDebugMode) {
        debugPrint('ToyVisionDX: mlkit.detect.error $e');
      }
      return const [];
    }

    final results = <RawDetection>[];
    for (final obj in objects) {
      results.add(_toRawDetection(obj, image.width, image.height));
    }
    return results;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _detector.close();
  }

  /// Build an [InputImage] from a plugin [CameraImage]. Returns null if the
  /// frame format isn't recognized — the live loop drops it silently.
  InputImage? _toInputImage(CameraImage image) {
    final bytes = _concatPlaneBytes(image);
    final rotation = InputImageRotationValue.fromRawValue(sensorOrientation) ??
        InputImageRotation.rotation0deg;
    final format = InputImageFormatValue.fromRawValue(image.format.raw as int);
    if (format == null) return null;
    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  /// Concatenate every plane's bytes into a single buffer. YUV420 on Android
  /// has three planes (Y, U, V); BGRA8888 on iOS has one. ML Kit's native
  /// side splits them back out using the metadata.
  Uint8List _concatPlaneBytes(CameraImage image) {
    final buf = WriteBuffer();
    for (final p in image.planes) {
      buf.putUint8List(p.bytes);
    }
    return buf.done().buffer.asUint8List();
  }

  /// Convert one [DetectedObject] into the app's [RawDetection] shape. The
  /// detector reports the box in input-image pixel coordinates (post-rotation
  /// from ML Kit), so we normalize to 0..1 against the image dimensions —
  /// width/height are swapped when the rotation is 90°/270° because ML Kit's
  /// post-rotation frame is rotated relative to the camera's native size.
  RawDetection _toRawDetection(
    DetectedObject obj,
    int rawWidth,
    int rawHeight,
  ) {
    final rotated = sensorOrientation == 90 || sensorOrientation == 270;
    final frameWidth = (rotated ? rawHeight : rawWidth).toDouble();
    final frameHeight = (rotated ? rawWidth : rawHeight).toDouble();
    final r = obj.boundingBox;
    final box = BoundingBox(
      x: _clamp01(r.left / frameWidth),
      y: _clamp01(r.top / frameHeight),
      width: _clamp01(r.width / frameWidth),
      height: _clamp01(r.height / frameHeight),
    );

    String text = MlKitLabelMap.unclassifiedLabel;
    double confidence = 0.5;
    if (obj.labels.isNotEmpty) {
      final sorted = [...obj.labels]
        ..sort((a, b) => b.confidence.compareTo(a.confidence));
      final top = sorted.first;
      text = MlKitLabelMap.toRegistryLabel(top.text);
      confidence = top.confidence;
    }

    return RawDetection(label: text, confidence: confidence, box: box);
  }

  static double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);
}
