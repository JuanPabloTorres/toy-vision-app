/// A marker that a cleanup mission is currently in progress, persisted so the
/// app can recover (resume or cleanly close) an interrupted mission after a
/// crash or force-quit.
///
/// Deliberately tiny: when the mission started and, once the opening scan has
/// settled, how many toys formed the baseline. Counts + timestamps only —
/// **no frames, no images, no bounding boxes** (privacy-first).
///
/// This is NOT written per frame. It is created once when a mission begins and
/// removed once the mission ends, so it never touches the live detection loop.
class ActiveMissionRecord {
  const ActiveMissionRecord({
    required this.startedAt,
    this.baselineToyCount,
  });

  /// When the child tapped "Nueva misión".
  final DateTime startedAt;

  /// Toys established as the mission baseline once the opening scan settled.
  /// Null while the scan is still running (mission just started).
  final int? baselineToyCount;

  ActiveMissionRecord copyWith({int? baselineToyCount}) => ActiveMissionRecord(
        startedAt: startedAt,
        baselineToyCount: baselineToyCount ?? this.baselineToyCount,
      );

  Map<String, dynamic> toJson() => {
        'startedAt': startedAt.toIso8601String(),
        'baselineToyCount': baselineToyCount,
      };

  factory ActiveMissionRecord.fromJson(Map<String, dynamic> j) =>
      ActiveMissionRecord(
        startedAt: DateTime.parse(j['startedAt'] as String),
        baselineToyCount: j['baselineToyCount'] as int?,
      );
}
