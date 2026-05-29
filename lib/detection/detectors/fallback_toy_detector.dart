import '../models/detection_frame.dart';
import '../models/raw_detection.dart';
import 'toy_detector.dart';

/// Wraps a primary detector with a fallback. If the primary fails to initialize
/// (e.g. the TFLite model is unavailable), the fallback is used instead.
///
/// This keeps the app working when the real model isn't ready: in Phase 2b the
/// primary is [TfliteToyDetector] (which fails until the runtime is wired) and
/// the fallback is the proven [MockToyDetector].
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
    } catch (_) {
      _active = fallback;
      _usingFallback = true;
      await fallback.initialize();
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
