import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;

import '../models/detection_frame.dart';
import '../models/raw_detection.dart';
import 'toy_detector.dart';

/// Wraps a primary detector with a fallback. If the primary fails to initialize
/// (e.g. the ML Kit plugin is unavailable, or the local vision server is
/// unreachable), the fallback is used instead. Per-frame errors on the primary
/// also degrade to the fallback for the rest of the session.
///
/// Phase 5.0 wiring: primary is either `MlKitObjectDetector` (Object Assist) or
/// `RemoteVisionDetector` (Open-Vocab); fallback is the deterministic
/// `MockToyDetector`. This keeps the live loop running on any device or
/// configuration.
class FallbackToyDetector implements ToyDetector {
  FallbackToyDetector({required this.primary, required this.fallback});

  final ToyDetector primary;
  final ToyDetector fallback;

  ToyDetector? _active;
  bool _usingFallback = false;

  /// Whether the fallback (not the primary) is the active detector.
  bool get usingFallback => _usingFallback;

  @override
  Future<void> initialize() async {
    try {
      await primary.initialize();
      _active = primary;
      _usingFallback = false;
      if (kDebugMode) {
        debugPrint(
          'ToyVisionDX: lifecycle.fallback.initialize active=primary '
          '(${primary.runtimeType})',
        );
      }
    } catch (e) {
      _active = fallback;
      _usingFallback = true;
      await fallback.initialize();
      if (kDebugMode) {
        debugPrint(
          'ToyVisionDX: lifecycle.fallback.initialize active=fallback '
          '(${fallback.runtimeType}) reason=$e',
        );
      }
    }
  }

  @override
  Future<List<RawDetection>> detect(DetectionFrame frame) {
    final active = _active;
    if (active == null) {
      throw StateError('FallbackToyDetector.initialize() not called.');
    }
    return active.detect(frame);
  }

  @override
  void dispose() {
    primary.dispose();
    fallback.dispose();
  }
}
