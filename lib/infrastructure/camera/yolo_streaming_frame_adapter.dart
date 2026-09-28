import 'dart:typed_data';

import '../../domain/toy/normalized_box.dart';
import '../../domain/scene/spatial_observation.dart';
import '../../perception/perception_models.dart';

class CameraFrameAdapterException implements Exception {
  const CameraFrameAdapterException(this.message);
  final String message;

  @override
  String toString() => 'CameraFrameAdapterException: $message';
}

/// Converts the plugin's native stream payload without applying semantic
/// label rules. Every valid box remains evidence for hybrid fusion.
class YoloStreamingFrameAdapter {
  const YoloStreamingFrameAdapter();

  CameraPerceptionFrame adapt(
    Map<String, dynamic> payload, {
    DateTime? timestamp,
    SpatialObservation spatial = const SpatialObservation.unavailable(),
  }) {
    final bytes = _imageBytes(payload['originalImage']);
    if (bytes == null || bytes.isEmpty) {
      throw const CameraFrameAdapterException(
        'Native stream did not include originalImage pixels',
      );
    }
    final detections = <DetectorProposal>[];
    final rawDetections = payload['detections'];
    if (rawDetections is List) {
      for (final raw in rawDetections) {
        if (raw is! Map) continue;
        final box = _normalizedBox(raw['normalizedBox']);
        final confidence = (raw['confidence'] as num?)?.toDouble();
        if (box == null || !box.isValid || confidence == null) continue;
        detections.add(
          DetectorProposal(
            bounds: box,
            confidence: confidence.clamp(0.0, 1.0),
            knownClass: raw['className'] as String?,
          ),
        );
      }
    }
    return CameraPerceptionFrame(
      frameId: (payload['frameNumber'] as num?)?.toInt() ?? 0,
      timestamp: timestamp ?? DateTime.now(),
      encodedImage: bytes,
      detectorProposals: detections,
      nativeInferenceMs: (payload['processingTimeMs'] as num?)?.toDouble() ?? 0,
      nativeFps: (payload['fps'] as num?)?.toDouble() ?? 0,
      // The native live-camera path reports boxes after camera rotation, but
      // sends the original sensor bitmap. The analyzer must orient the pixels
      // to this upright coordinate space before using the boxes.
      detectorCoordinatesAreUpright: true,
      spatial: spatial,
    );
  }

  Uint8List? _imageBytes(Object? value) {
    if (value is Uint8List) return value;
    if (value is List<int>) return Uint8List.fromList(value);
    if (value is List) {
      return Uint8List.fromList(
        value.whereType<num>().map((n) => n.toInt()).toList(),
      );
    }
    return null;
  }

  NormalizedBox? _normalizedBox(Object? value) {
    if (value is! Map) return null;
    final left = (value['left'] as num?)?.toDouble();
    final top = (value['top'] as num?)?.toDouble();
    final right = (value['right'] as num?)?.toDouble();
    final bottom = (value['bottom'] as num?)?.toDouble();
    if (left == null || top == null || right == null || bottom == null) {
      return null;
    }
    return NormalizedBox(
      x: left,
      y: top,
      width: right - left,
      height: bottom - top,
    ).clamp();
  }
}
