import 'progress_models.dart';

class CleanupCompletionPolicy {
  const CleanupCompletionPolicy();

  CleanupCompletionDecision calculate(CleanupCompletionContext context) {
    final request = context.request;
    final session = request.session;
    final completedAt = session.completedAt;
    final durationSeconds = completedAt.difference(session.startedAt).inSeconds;
    final previousBest = context.roomProgress.bestCleanupSeconds;
    final isNewBest = previousBest == null || durationSeconds < previousBest;
    final rewards = <RewardTransaction>[
      _reward(request, 'room_completed', 3),
      if (!context.completedOnSameLocalDay)
        _reward(request, 'first_cleanup_of_day', 1),
      if (session.confirmedCollected == session.initialToyCount)
        _reward(request, 'room_cleared', 1),
      if (isNewBest) _reward(request, 'personal_best', 1),
    ];
    final nextSessionCount = context.totalCompletedSessions + 1;

    return CleanupCompletionDecision(
      roomProgress: RoomProgress(
        childId: request.childId,
        roomId: request.roomId,
        sessionsCompleted: context.roomProgress.sessionsCompleted + 1,
        toysCollected:
            context.roomProgress.toysCollected + session.confirmedCollected,
        bestCleanupSeconds: isNewBest
            ? durationSeconds
            : context.roomProgress.bestCleanupSeconds,
        lastCompletedAt: completedAt,
      ),
      streak: _nextStreak(context.streak, completedAt),
      rewards: rewards,
      achievements: [
        if (nextSessionCount == 1) _achievement(request, 'first_cleanup'),
        if (nextSessionCount == 5) _achievement(request, 'five_cleanups'),
        if (nextSessionCount == 10) _achievement(request, 'ten_cleanups'),
      ],
    );
  }

  RewardTransaction _reward(
    CleanupCompletionRequest request,
    String reason,
    int amount,
  ) =>
      RewardTransaction(
        id: '${request.session.id}:$reason',
        childId: request.childId,
        sessionId: request.session.id,
        rewardType: 'stars',
        amount: amount,
        reason: reason,
        createdAt: request.session.completedAt,
      );

  Achievement _achievement(
    CleanupCompletionRequest request,
    String key,
  ) =>
      Achievement(
        id: '${request.childId}:$key',
        childId: request.childId,
        key: key,
        unlockedAt: request.session.completedAt,
      );

  DailyStreak _nextStreak(DailyStreak current, DateTime completedAt) {
    final successDay = _localDay(completedAt);
    final previousDay = current.lastSuccessDay;
    if (previousDay != null && _sameDay(previousDay, successDay)) {
      return current;
    }
    final consecutive = previousDay != null &&
        _sameDay(
          DateTime(previousDay.year, previousDay.month, previousDay.day + 1),
          successDay,
        );
    final nextCurrent = consecutive ? current.current + 1 : 1;
    return DailyStreak(
      childId: current.childId,
      current: nextCurrent,
      longest: nextCurrent > current.longest ? nextCurrent : current.longest,
      lastSuccessDay: successDay,
    );
  }

  DateTime _localDay(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  bool _sameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}
