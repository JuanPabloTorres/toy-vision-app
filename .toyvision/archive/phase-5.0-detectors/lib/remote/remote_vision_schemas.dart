// Wire-shape Dart models for the local vision server JSON.
//
// Matches `tools/vision_server/schemas.py` 1:1. Manual serialization keeps
// the build graph free of code-gen dependencies; the surface is small
// enough that a generator would be overkill.

class RemoteDetectRequest {
  const RemoteDetectRequest({
    required this.frameIndex,
    required this.width,
    required this.height,
    this.imageJpegBase64,
    this.prompts,
  });

  final int frameIndex;
  final int width;
  final int height;

  /// JPEG-encoded image bytes, base64-encoded. Null in Phase 5.0 wire-up;
  /// populated in Phase 5.0.1 when real detection lands.
  final String? imageJpegBase64;

  /// Optional override of the server's default prompts list.
  final List<String>? prompts;

  Map<String, dynamic> toJson() => {
        'frame_index': frameIndex,
        'width': width,
        'height': height,
        if (imageJpegBase64 != null) 'image_jpeg_base64': imageJpegBase64,
        if (prompts != null) 'prompts': prompts,
      };
}

class RemoteBox {
  const RemoteBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final double x;
  final double y;
  final double width;
  final double height;

  factory RemoteBox.fromJson(Map<String, dynamic> j) => RemoteBox(
        x: (j['x'] as num).toDouble(),
        y: (j['y'] as num).toDouble(),
        width: (j['width'] as num).toDouble(),
        height: (j['height'] as num).toDouble(),
      );
}

class RemoteDetection {
  const RemoteDetection({
    required this.label,
    required this.mappedLabel,
    required this.confidence,
    required this.box,
  });

  /// Raw label from the detector (e.g. `"toy car"`). Kept for diagnostics.
  final String label;

  /// Pre-mapped registry label (e.g. `"toy_car"`). This is the field the
  /// Flutter business layer consumes.
  final String mappedLabel;
  final double confidence;
  final RemoteBox box;

  factory RemoteDetection.fromJson(Map<String, dynamic> j) => RemoteDetection(
        label: j['label'] as String,
        mappedLabel: j['mapped_label'] as String,
        confidence: (j['confidence'] as num).toDouble(),
        box: RemoteBox.fromJson(j['box'] as Map<String, dynamic>),
      );
}

class RemoteDetectResponse {
  const RemoteDetectResponse({
    required this.detections,
    required this.model,
    required this.latencyMs,
  });

  final List<RemoteDetection> detections;
  final String model;
  final int latencyMs;

  factory RemoteDetectResponse.fromJson(Map<String, dynamic> j) {
    final list = (j['detections'] as List)
        .cast<Map<String, dynamic>>()
        .map(RemoteDetection.fromJson)
        .toList(growable: false);
    return RemoteDetectResponse(
      detections: list,
      model: j['model'] as String,
      latencyMs: j['latency_ms'] as int,
    );
  }
}

/// Thrown by the client/detector when the server is unreachable, returns
/// a non-2xx response, or the JSON cannot be parsed. The detector
/// converts this into an empty detection list at the live loop so the UI
/// never crashes.
class RemoteVisionException implements Exception {
  const RemoteVisionException(this.message);
  final String message;

  @override
  String toString() => 'RemoteVisionException: $message';
}
