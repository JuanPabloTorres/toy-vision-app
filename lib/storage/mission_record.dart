/// A completed (or ended) cleanup mission, persisted for the History and
/// Calendar views. Counts only — **no frames, no images** are ever stored
/// (privacy-first).
class MissionRecord {
  const MissionRecord({
    required this.id,
    required this.date,
    required this.initialToyCount,
    required this.collectedToyCount,
    required this.completed,
    required this.durationSeconds,
    required this.starsEarned,
    this.visuallyVerified = false,
    this.usedManualHelp = false,
    this.hadUncertainty = false,
    this.targetPickupGoal,
  });

  final String id;

  /// When the mission finished. Used to bucket records by calendar day.
  final DateTime date;

  final int initialToyCount;
  final int collectedToyCount;

  /// True when every baseline toy was collected (vs. ended early).
  final bool completed;

  final int durationSeconds;

  /// Simple reward: 1 star for finishing, +1 if fully completed, +1 if
  /// the mission had 5+ toys. Range 0..3.
  final int starsEarned;

  /// True when the mission ended through a passed **clean-area verification**
  /// sweep (the robot actually saw the area and confirmed nothing was left),
  /// rather than a bare manual finish. This is the "evidence-based completion"
  /// flag the Parents view surfaces as "Verificación visual".
  final bool visuallyVerified;

  /// True when the child needed a manual assist during the mission: tapping a
  /// toy the model missed, the "Necesito ayuda" tap hint, or answering the
  /// rare "¿Lo recogiste?" fallback. Lets parents see how independent the run
  /// was. Default false (a fully automatic run).
  final bool usedManualHelp;

  /// True when the run hit at least one uncertainty event — the robot lost the
  /// target and had to re-scan (camera moved / blank view) or fall back to the
  /// manual "¿Lo recogiste?" question. Default false (a clean, confident run).
  final bool hadUncertainty;

  /// The challenge pickup goal this mission was started with (3/5/10), or
  /// `null` for free/record mode. A CHALLENGE target — never a room inventory.
  /// Nullable + read with a fallback so older records load without migration.
  final int? targetPickupGoal;

  /// The calendar day (midnight) this record belongs to.
  DateTime get day => DateTime(date.year, date.month, date.day);

  /// Compute stars from a mission outcome.
  static int starsFor({
    required bool completed,
    required int initialToyCount,
    required int collectedToyCount,
  }) {
    var stars = 1; // showed up
    if (completed) stars += 1;
    if (initialToyCount >= 5 && collectedToyCount >= 5) stars += 1;
    return stars.clamp(0, 3);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'initialToyCount': initialToyCount,
        'collectedToyCount': collectedToyCount,
        'completed': completed,
        'durationSeconds': durationSeconds,
        'starsEarned': starsEarned,
        'visuallyVerified': visuallyVerified,
        'usedManualHelp': usedManualHelp,
        'hadUncertainty': hadUncertainty,
        'targetPickupGoal': targetPickupGoal,
      };

  // The three verification flags are read with a `?? false` fallback so that
  // records written by an earlier schema (v1, before the flags existed) still
  // load cleanly — no migration needed, they simply read as "not verified".
  factory MissionRecord.fromJson(Map<String, dynamic> j) => MissionRecord(
        id: j['id'] as String,
        date: DateTime.parse(j['date'] as String),
        initialToyCount: j['initialToyCount'] as int,
        collectedToyCount: j['collectedToyCount'] as int,
        completed: j['completed'] as bool,
        durationSeconds: j['durationSeconds'] as int,
        starsEarned: j['starsEarned'] as int,
        visuallyVerified: j['visuallyVerified'] as bool? ?? false,
        usedManualHelp: j['usedManualHelp'] as bool? ?? false,
        hadUncertainty: j['hadUncertainty'] as bool? ?? false,
        targetPickupGoal: j['targetPickupGoal'] as int?,
      );
}
