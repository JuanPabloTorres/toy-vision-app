/// A single unlockable achievement (logro) shown on the progress
/// dashboard. Achievements are **derived** from the completed-mission
/// history — they are never stored per record, so there is no stale state
/// to keep in sync. Each one is a pure threshold over the aggregate stats.
class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.emoji,
    required this.unlocked,
  });

  final String id;
  final String title;
  final String description;

  /// Kid-friendly emoji shown on the badge. Using an emoji (not an asset)
  /// keeps new achievements zero-cost to add and reads as playful.
  final String emoji;

  /// Whether the child has met this achievement's threshold.
  final bool unlocked;

  Achievement copyWith({bool? unlocked}) => Achievement(
        id: id,
        title: title,
        description: description,
        emoji: emoji,
        unlocked: unlocked ?? this.unlocked,
      );
}

/// The inputs an achievement rule reads. Kept as a small record so the
/// catalog stays a pure list of (definition + predicate) with no coupling
/// to the storage or UI layers.
class AchievementContext {
  const AchievementContext({
    required this.totalMissionsCompleted,
    required this.totalToysCollected,
    required this.currentStreakDays,
    required this.bestSingleMissionToys,
    required this.hadPerfectFivePlusDay,
  });

  final int totalMissionsCompleted;
  final int totalToysCollected;
  final int currentStreakDays;
  final int bestSingleMissionToys;

  /// True if any single mission completed with 5+ toys, all collected.
  final bool hadPerfectFivePlusDay;
}

/// The fixed catalog of achievements. Order is the display order. Each
/// entry pairs a static definition with a predicate over
/// [AchievementContext]; [evaluate] returns the catalog with each entry's
/// `unlocked` flag resolved against the given context.
class AchievementCatalog {
  const AchievementCatalog._();

  static const List<_AchievementRule> _rules = [
    _AchievementRule(
      id: 'first_mission',
      title: 'Primera misión',
      description: 'Completa tu primera misión',
      emoji: '🚀',
    ),
    _AchievementRule(
      id: 'five_toys',
      title: 'Cinco juguetes',
      description: 'Recoge 5 juguetes en total',
      emoji: '🧸',
    ),
    _AchievementRule(
      id: 'streak_3',
      title: 'Racha de 3 días',
      description: 'Completa misiones 3 días seguidos',
      emoji: '🔥',
    ),
    _AchievementRule(
      id: 'ten_missions',
      title: 'Diez misiones',
      description: 'Completa 10 misiones',
      emoji: '🏅',
    ),
    _AchievementRule(
      id: 'fifty_toys',
      title: 'Cincuenta juguetes',
      description: 'Recoge 50 juguetes en total',
      emoji: '🌟',
    ),
    _AchievementRule(
      id: 'perfect_day',
      title: 'Día perfecto',
      description: 'Recoge todos los juguetes de una misión grande',
      emoji: '🏆',
    ),
  ];

  /// Resolve the whole catalog against [context], returning each
  /// achievement with its `unlocked` flag set.
  static List<Achievement> evaluate(AchievementContext context) =>
      _rules.map((rule) => rule.resolve(context)).toList(growable: false);
}

class _AchievementRule {
  const _AchievementRule({
    required this.id,
    required this.title,
    required this.description,
    required this.emoji,
  });

  final String id;
  final String title;
  final String description;
  final String emoji;

  bool _isUnlocked(AchievementContext c) {
    switch (id) {
      case 'first_mission':
        return c.totalMissionsCompleted >= 1;
      case 'five_toys':
        return c.totalToysCollected >= 5;
      case 'streak_3':
        return c.currentStreakDays >= 3;
      case 'ten_missions':
        return c.totalMissionsCompleted >= 10;
      case 'fifty_toys':
        return c.totalToysCollected >= 50;
      case 'perfect_day':
        return c.hadPerfectFivePlusDay;
      default:
        return false;
    }
  }

  Achievement resolve(AchievementContext c) => Achievement(
        id: id,
        title: title,
        description: description,
        emoji: emoji,
        unlocked: _isUnlocked(c),
      );
}
