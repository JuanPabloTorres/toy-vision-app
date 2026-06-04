import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;

import '../models/raw_detection.dart';

/// Debug-only diagnostics for the live detection pipeline.
///
/// Phase 3.6 simplified the original Phase 3.5.1 TFLite-specific diagnostic
/// because the ML Kit detector no longer surfaces tensor-level data — there is
/// no parser, no adapter, no input preprocessor to inspect. What still helps
/// for on-device validation is a one-line per-frame summary showing the
/// detector mode, fallback state, the count of detections produced by the
/// detector, the count after business validation, and per-reason reject
/// histograms.
///
/// Strictly debug-mode only — every public entry point short-circuits in
/// release builds. Emits via `debugPrint`, which surfaces to Android logcat
/// under the Flutter tag. Filter with `adb logcat | grep ToyVisionDX`.
class DetectionDiagnostics {
  DetectionDiagnostics._();

  /// Master gate. Defaults to [kDebugMode]; release builds emit nothing.
  static bool enabled = kDebugMode;

  /// logcat name. The prefix is hard-coded in every emitted line so the user
  /// can grep without knowing internal channel routing.
  static const String logName = 'ToyVisionDX';

  /// Minimum gap between consecutive emissions. Without this the live loop
  /// would spam logcat at the inference frame rate.
  static const Duration throttle = Duration(seconds: 1);

  static int _lastEmitMs = -1 << 30;

  /// Emit a per-frame diagnostic line. Throttled to one log per [throttle].
  ///
  /// `topRaw` is an optional preview of the highest-confidence raw detections
  /// produced this frame (useful for "what is ML Kit calling this thing?")
  /// without dumping every detection on a busy scene.
  static void emitFrame({
    required String mode,
    required bool usingFallback,
    required int rawDetections,
    required int validatedCount,
    required Map<String, int> rejectReasons,
    List<RawDetection> topRaw = const [],
  }) {
    if (!enabled) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastEmitMs < throttle.inMilliseconds) return;
    _lastEmitMs = now;

    final buf = StringBuffer()
      ..writeln('mode=$mode usingFallback=$usingFallback')
      ..writeln(
        'detectorRaw=$rawDetections '
        'validated=$validatedCount '
        'rejects=$rejectReasons',
      );
    if (topRaw.isNotEmpty) {
      buf.writeln('top raw (sorted by confidence):');
      final sorted = [...topRaw]
        ..sort((a, b) => b.confidence.compareTo(a.confidence));
      final limit = sorted.length < 5 ? sorted.length : 5;
      for (var i = 0; i < limit; i++) {
        final d = sorted[i];
        buf.writeln(
          '  [$i] label="${d.label}" '
          'conf=${d.confidence.toStringAsFixed(3)} '
          'box=[x=${d.box.x.toStringAsFixed(2)},'
          'y=${d.box.y.toStringAsFixed(2)},'
          'w=${d.box.width.toStringAsFixed(2)},'
          'h=${d.box.height.toStringAsFixed(2)}]',
        );
      }
    }
    for (final line in buf.toString().split('\n')) {
      if (line.isEmpty) continue;
      debugPrint('$logName: $line');
    }
  }
}
