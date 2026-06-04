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
      };

  factory MissionRecord.fromJson(Map<String, dynamic> j) => MissionRecord(
        id: j['id'] as String,
        date: DateTime.parse(j['date'] as String),
        initialToyCount: j['initialToyCount'] as int,
        collectedToyCount: j['collectedToyCount'] as int,
        completed: j['completed'] as bool,
        durationSeconds: j['durationSeconds'] as int,
        starsEarned: j['starsEarned'] as int,
      );
}
