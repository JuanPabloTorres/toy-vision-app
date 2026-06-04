import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;

import '../../models/bounding_box.dart';
import '../../models/detection_frame.dart';
import '../../models/raw_detection.dart';
import '../toy_detector.dart';
import 'camera_image_jpeg_encoder.dart';
import 'remote_vision_client.dart';
import 'remote_vision_config.dart';
import 'remote_vision_schemas.dart';

/// [ToyDetector] backed by the Python local vision server.
///
/// Phase 5.0 wire-up: each accepted frame, the detector POSTs the frame
/// index + dimensions to `/detect` and parses the JSON response. No image
/// bytes are sent yet; the placeholder server returns frame-indexed fake
/// boxes. Phase 5.0.1 adds JPEG encoding of the [CameraImage] so YOLO-
/// World can run on real content.
///
/// Failure handling: if the server is unreachable, returns 5xx, or the
/// response is malformed, [detect] returns an empty list and logs the
/// reason. The live loop drops the frame instead of crashing. The
/// surrounding [FallbackToyDetector] is what swaps to mock if
/// [initialize] cannot reach the server at all.
class RemoteVisionDetector implements ToyDetector {
  RemoteVisionDetector({
    RemoteVisionConfig? config,
    RemoteVisionClient? client,
    CameraImageJpegEncoder? encoder,
  })  : _config = config ?? RemoteVisionConfig.defaults,
        _client = client ??
            HttpRemoteVisionClient(
              config: config ?? RemoteVisionConfig.defaults,
            ),
        _encoder = encoder ?? const CameraImageJpegEncoder();

  final RemoteVisionConfig _config;
  final RemoteVisionClient _client;
  final CameraImageJpegEncoder _encoder;
  bool _disposed = false;

  RemoteVisionConfig get config => _config;

  @override
  Future<void> initialize() async {
    final ok = await _client.health();
    if (kDebugMode) {
      debugPrint(
        'CandidateDX: remote.initialize url=${_config.baseUrl} health=$ok',
      );
    }
    if (!ok) {
      throw const RemoteVisionException(
        'local vision server is unreachable',
      );
    }
  }

  @override
  Future<List<RawDetection>> detect(DetectionFrame frame) async {
    if (_disposed) return const [];
    final image = frame.cameraImage;
    final w = image?.width ?? 1280;
    final h = image?.height ?? 720;

    // Phase 5.0.1: encode the CameraImage to JPEG → base64. The encoded
    // bytes are sent to the local Python server, which decodes them
    // in-memory and discards immediately. Failed encoding (unsupported
    // format) drops the frame quietly so the live loop is unaffected.
    String? jpegB64;
    if (image != null) {
      final jpeg = _encoder.encode(image);
      if (jpeg != null) {
        jpegB64 = base64Encode(jpeg);
      } else if (kDebugMode) {
        debugPrint(
          'CandidateDX: remote.encode.skip format=${image.format.group}',
        );
      }
    }

    final RemoteDetectResponse resp;
    try {
      resp = await _client.detect(
        RemoteDetectRequest(
          frameIndex: frame.frameIndex,
          width: w,
          height: h,
          imageJpegBase64: jpegB64,
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('CandidateDX: remote.detect.error $e');
      }
      return const [];
    }

    if (kDebugMode) {
      debugPrint(
        'CandidateDX: remote.detect frame=${frame.frameIndex} '
        'model=${resp.model} latency=${resp.latencyMs}ms '
        'detections=${resp.detections.length}',
      );
    }

    return resp.detections
        .map(
          (d) => RawDetection(
            label: d.mappedLabel,
            confidence: d.confidence,
            box: BoundingBox(
              x: d.box.x,
              y: d.box.y,
              width: d.box.width,
              height: d.box.height,
            ),
          ),
        )
        .toList(growable: false);
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _client.close();
  }
}
