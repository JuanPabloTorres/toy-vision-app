import '../tracking/tracked_toy.dart';

/// Status of the detection engine, surfaced to the UI as a status indicator.
enum ModelStatus { initializing, ready, error }

/// Immutable per-category and total count summary.
class ToyCountSummary {
  const ToyCountSummary({required this.total, required this.perCategory});

  final int total;

  /// Display name -> count for categories that have been counted at least once.
  final Map<String, int> perCategory;

  static const ToyCountSummary empty =
      ToyCountSummary(total: 0, perCategory: {});
}

/// Immutable snapshot the UI renders. It contains no logic — it is produced by
/// the live detection controller after the rules → tracking → counting pipeline
/// runs. The UI never computes counts, IoU, or validity from this object.
class LiveDetectionState {
  const LiveDetectionState({
    required this.status,
    required this.isPaused,
    required this.visibleToys,
    required this.summary,
  });

  final ModelStatus status;
  final bool isPaused;

  /// Tracked toys visible in the latest processed frame (for the overlay).
  final List<TrackedToy> visibleToys;

  final ToyCountSummary summary;

  int get totalCount => summary.total;
  bool get hasVisibleToys => visibleToys.isNotEmpty;

  factory LiveDetectionState.initial() => const LiveDetectionState(
        status: ModelStatus.initializing,
        isPaused: false,
        visibleToys: [],
        summary: ToyCountSummary.empty,
      );

  LiveDetectionState copyWith({
    ModelStatus? status,
    bool? isPaused,
    List<TrackedToy>? visibleToys,
    ToyCountSummary? summary,
  }) {
    return LiveDetectionState(
      status: status ?? this.status,
      isPaused: isPaused ?? this.isPaused,
      visibleToys: visibleToys ?? this.visibleToys,
      summary: summary ?? this.summary,
    );
  }
}
