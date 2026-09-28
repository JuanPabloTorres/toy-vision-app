import '../repositories/cleanup_history_repository.dart';

abstract final class ProgressIdentity {
  static const primaryChildId = 'primary-child';
  static const primaryRoomId = 'primary-room';
  static const primaryChildName = 'Peque';
  static const primaryRoomName = 'Mi habitación';
}

class RoomProgress {
  const RoomProgress({
    required this.childId,
    required this.roomId,
    required this.sessionsCompleted,
    required this.toysCollected,
    this.bestCleanupSeconds,
    this.lastCompletedAt,
  });

  factory RoomProgress.empty({
    required String childId,
    required String roomId,
  }) =>
      RoomProgress(
        childId: childId,
        roomId: roomId,
        sessionsCompleted: 0,
        toysCollected: 0,
      );

  final String childId;
  final String roomId;
  final int sessionsCompleted;
  final int toysCollected;
  final int? bestCleanupSeconds;
  final DateTime? lastCompletedAt;
}

class DailyStreak {
  const DailyStreak({
    required this.childId,
    required this.current,
    required this.longest,
    this.lastSuccessDay,
  });

  factory DailyStreak.empty(String childId) => DailyStreak(
        childId: childId,
        current: 0,
        longest: 0,
      );

  final String childId;
  final int current;
  final int longest;
  final DateTime? lastSuccessDay;
}

class RewardTransaction {
  const RewardTransaction({
    required this.id,
    required this.childId,
    required this.sessionId,
    required this.rewardType,
    required this.amount,
    required this.reason,
    required this.createdAt,
  });

  final String id;
  final String childId;
  final String sessionId;
  final String rewardType;
  final int amount;
  final String reason;
  final DateTime createdAt;
}

class Achievement {
  const Achievement({
    required this.id,
    required this.childId,
    required this.key,
    required this.unlockedAt,
  });

  final String id;
  final String childId;
  final String key;
  final DateTime unlockedAt;
}

class ChildProgress {
  const ChildProgress({
    required this.childId,
    required this.totalStars,
    required this.streak,
    required this.completedSessions,
    required this.toysCollected,
    required this.rooms,
    required this.achievements,
    this.lastSession,
  });

  factory ChildProgress.empty(String childId) => ChildProgress(
        childId: childId,
        totalStars: 0,
        streak: DailyStreak.empty(childId),
        completedSessions: 0,
        toysCollected: 0,
        rooms: const [],
        achievements: const [],
      );

  final String childId;
  final int totalStars;
  final DailyStreak streak;
  final int completedSessions;
  final int toysCollected;
  final List<RoomProgress> rooms;
  final List<Achievement> achievements;
  final CleanupSessionSummary? lastSession;
}

class CleanupCompletionRequest {
  const CleanupCompletionRequest({
    required this.childId,
    required this.childName,
    required this.roomId,
    required this.roomName,
    required this.session,
  });

  final String childId;
  final String childName;
  final String roomId;
  final String roomName;
  final CleanupSessionSummary session;
}

class CleanupCompletionContext {
  const CleanupCompletionContext({
    required this.request,
    required this.roomProgress,
    required this.streak,
    required this.completedOnSameLocalDay,
    required this.totalCompletedSessions,
  });

  final CleanupCompletionRequest request;
  final RoomProgress roomProgress;
  final DailyStreak streak;
  final bool completedOnSameLocalDay;
  final int totalCompletedSessions;
}

class CleanupCompletionDecision {
  const CleanupCompletionDecision({
    required this.roomProgress,
    required this.streak,
    required this.rewards,
    required this.achievements,
  });

  final RoomProgress roomProgress;
  final DailyStreak streak;
  final List<RewardTransaction> rewards;
  final List<Achievement> achievements;

  int get starsAwarded => rewards.fold(0, (sum, reward) => sum + reward.amount);
}

class CleanupCompletionResult {
  const CleanupCompletionResult({
    required this.sessionId,
    required this.starsAwarded,
    required this.wasAlreadyCompleted,
  });

  final String sessionId;
  final int starsAwarded;
  final bool wasAlreadyCompleted;
}
