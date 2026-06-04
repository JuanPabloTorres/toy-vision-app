import '../../detection/models/bounding_box.dart';
import '../../tracking/tracked_toy.dart';

/// A toy candidate accumulated across several scan frames.
class ToyCandidate {
  ToyCandidate({
    required this.trackerId,
    required this.box,
    required this.confidence,
    required this.framesSeen,
    required this.lastFrame,
  });

  final int trackerId;
  BoundingBox box;
  double confidence;
  int framesSeen;
  int lastFrame;
}

/// Turns the noisy per-frame detector/tracker output into a **stable** list
/// of toy candidates over a short scan window.
///
/// The model only sees a couple of toys per frame and flickers; this
/// service accumulates what was seen, keyed by the tracker's stable id (the
/// tracker already fuses detections across frames by IoU), counts how many
/// frames each toy persisted, and only reports a candidate once it has been
/// seen enough frames to be trusted — filtering one-frame false positives.
///
/// The model finds candidates; the mission decides what to do with them.
class ToyCandidateFusionService {
  final Map<int, ToyCandidate> _byId = {};
  int _frame = 0;

  int get frame => _frame;

  void reset() {
    _byId.clear();
    _frame = 0;
  }

  /// Fold one frame of tracked toys into the accumulator.
  void observe(List<TrackedToy> tracked) {
    _frame += 1;
    for (final t in tracked) {
      if (!t.isVisible) continue;
      final existing = _byId[t.id];
      if (existing == null) {
        _byId[t.id] = ToyCandidate(
          trackerId: t.id,
          box: t.box,
          confidence: t.confidence,
          framesSeen: 1,
          lastFrame: _frame,
        );
      } else {
        existing.box = t.box; // latest position wins
        if (t.confidence > existing.confidence) {
          existing.confidence = t.confidence;
        }
        existing.framesSeen += 1;
        existing.lastFrame = _frame;
      }
    }
  }

  /// Candidates seen on at least [minFrames] frames of the window, ordered
  /// by reading order (top→bottom, then left→right) so the child is guided
  /// in a natural sweep.
  List<ToyCandidate> stableCandidates({int minFrames = 2}) {
    final stable =
        _byId.values.where((c) => c.framesSeen >= minFrames).toList();
    stable.sort((a, b) {
      final dy = a.box.centerY.compareTo(b.box.centerY);
      if (dy.abs() > 0.12) return dy; // different rows
      return a.box.centerX.compareTo(b.box.centerX);
    });
    return stable;
  }
}
