/// The challenge a mission is framed around.
///
/// Toy Vision is a **responsibility challenge**, not a room inventory: the goal
/// is a target number of pickups to celebrate, NOT "how many toys exist". The
/// child may keep collecting past the goal to break a personal record.
enum MissionChallenge {
  /// Quick win — 3 pickups.
  quick,

  /// The default — 5 pickups.
  normal,

  /// Super challenge — 10 pickups.
  superChallenge,

  /// Free / record mode — no fixed goal, collect as many as you can.
  record,
}

/// A mission's goal: a [MissionChallenge] and the pickup target it implies.
/// [targetPickupGoal] is `null` for [MissionChallenge.record] (free mode).
class MissionGoal {
  const MissionGoal(this.challenge);

  final MissionChallenge challenge;

  /// Pickups needed to complete the challenge, or `null` for free/record mode.
  int? get targetPickupGoal => switch (challenge) {
        MissionChallenge.quick => 3,
        MissionChallenge.normal => 5,
        MissionChallenge.superChallenge => 10,
        MissionChallenge.record => null,
      };

  /// Free mode has no fixed target — every pickup is already a record attempt.
  bool get isRecordMode => targetPickupGoal == null;

  /// Whether [collected] pickups have reached the challenge goal. Always false
  /// in free mode (there is no goal to reach — only a record to beat).
  bool hasReachedGoalAt(int collected) {
    final goal = targetPickupGoal;
    return goal != null && collected >= goal;
  }

  /// Kid-facing title for the start screen card.
  String get title => switch (challenge) {
        MissionChallenge.quick => 'Misión rápida',
        MissionChallenge.normal => 'Misión normal',
        MissionChallenge.superChallenge => 'Súper reto',
        MissionChallenge.record => 'Rompe récord',
      };

  /// Kid-facing one-liner shown when the mission starts.
  String get startMessage => switch (challenge) {
        MissionChallenge.quick => 'Recojamos 3 juguetes.',
        MissionChallenge.normal => 'Vamos por 5 juguetes.',
        MissionChallenge.superChallenge => '¿Puedes recoger 10?',
        MissionChallenge.record => 'Recoge todos los que puedas.',
      };

  static const MissionGoal quick = MissionGoal(MissionChallenge.quick);
  static const MissionGoal normal = MissionGoal(MissionChallenge.normal);
  static const MissionGoal superChallenge =
      MissionGoal(MissionChallenge.superChallenge);
  static const MissionGoal record = MissionGoal(MissionChallenge.record);

  /// The default when the child doesn't pick one.
  static const MissionGoal defaultGoal = normal;

  /// All selectable challenges, in display order.
  static const List<MissionGoal> all = [
    quick,
    normal,
    superChallenge,
    record,
  ];

  /// Resolve from a persisted [targetPickupGoal] value (`null` = record mode).
  factory MissionGoal.fromTarget(int? target) => switch (target) {
        3 => quick,
        5 => normal,
        10 => superChallenge,
        _ => target == null ? record : normal,
      };
}
