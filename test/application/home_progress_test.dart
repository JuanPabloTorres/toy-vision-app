import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/application/home/home_progress.dart';
import 'package:toyvision_realtime/domain/progress/progress_models.dart';
import 'package:toyvision_realtime/domain/repositories/cleanup_history_repository.dart';
import 'package:toyvision_realtime/domain/repositories/progress_repository.dart';

void main() {
  test('home progress reads persisted stars and most recent session', () async {
    final now = DateTime.now();
    final repository = _Progress(
      ChildProgress(
        childId: ProgressIdentity.primaryChildId,
        totalStars: 9,
        streak: DailyStreak(
          childId: ProgressIdentity.primaryChildId,
          current: 1,
          longest: 2,
          lastSuccessDay: now,
        ),
        completedSessions: 2,
        toysCollected: 6,
        rooms: const [],
        achievements: const [],
        lastSession: _summary('latest', now, 4),
      ),
    );

    final progress = await LoadHomeProgress(repository)();

    expect(progress.totalStars, 9);
    expect(progress.completedSessions, 2);
    expect(progress.lastSession?.id, 'latest');
    expect(progress.currentStreak, 1);
  });
}

CleanupSessionSummary _summary(String id, DateTime at, int collected) =>
    CleanupSessionSummary(
      id: id,
      startedAt: at.subtract(const Duration(minutes: 1)),
      completedAt: at,
      initialToyCount: collected,
      confirmedCollected: collected,
      starsAwarded: 6,
    );

class _Progress implements ProgressRepository {
  _Progress(this.progress);

  final ChildProgress progress;

  @override
  Future<void> clear(String childId) async {}

  @override
  Future<CleanupCompletionResult> completeCleanup(
    CleanupCompletionRequest request,
    CleanupCompletionDecider decide,
  ) =>
      throw UnimplementedError();

  @override
  Future<ChildProgress> getProgress(String childId) async => progress;
}
