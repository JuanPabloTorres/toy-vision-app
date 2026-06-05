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
    required this.missionId,
    required this.startedAt,
    this.baselineToyCount,
    this.scanCompletedAt,
    this.activeTargetId,
    this.baselineToyIds = const [],
  });

  /// Stable id for this in-progress mission.
  final String missionId;

  /// When the child tapped "Nueva misión".
  final DateTime startedAt;

  /// Toys established as the mission baseline once the opening scan settled.
  /// Null while the scan is still running (mission just started).
  final int? baselineToyCount;

  /// When the opening scan settled enough to establish the baseline.
  final DateTime? scanCompletedAt;

  /// Current active target at the moment the baseline was stored, if any.
  final int? activeTargetId;

  /// Stable tracker ids discovered in the opening scan. No boxes/images.
  final List<int> baselineToyIds;

  ActiveMissionRecord copyWith({
    int? baselineToyCount,
    DateTime? scanCompletedAt,
    int? activeTargetId,
    List<int>? baselineToyIds,
  }) =>
      ActiveMissionRecord(
        missionId: missionId,
        startedAt: startedAt,
        baselineToyCount: baselineToyCount ?? this.baselineToyCount,
        scanCompletedAt: scanCompletedAt ?? this.scanCompletedAt,
        activeTargetId: activeTargetId ?? this.activeTargetId,
        baselineToyIds: baselineToyIds ?? this.baselineToyIds,
      );

  Map<String, dynamic> toJson() => {
        'missionId': missionId,
        'startedAt': startedAt.toIso8601String(),
        'baselineToyCount': baselineToyCount,
        'scanCompletedAt': scanCompletedAt?.toIso8601String(),
        'activeTargetId': activeTargetId,
        'baselineToyIds': baselineToyIds,
      };

  factory ActiveMissionRecord.fromJson(Map<String, dynamic> j) =>
      ActiveMissionRecord(
        missionId: j['missionId'] as String? ??
            DateTime.parse(j['startedAt'] as String)
                .millisecondsSinceEpoch
                .toString(),
        startedAt: DateTime.parse(j['startedAt'] as String),
        baselineToyCount: j['baselineToyCount'] as int?,
        scanCompletedAt: j['scanCompletedAt'] == null
            ? null
            : DateTime.parse(j['scanCompletedAt'] as String),
        activeTargetId: j['activeTargetId'] as int?,
        baselineToyIds: (j['baselineToyIds'] as List<dynamic>? ?? const [])
            .whereType<int>()
            .toList(growable: false),
      );
}
