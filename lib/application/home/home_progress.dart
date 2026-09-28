import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/progress/progress_models.dart';
import '../../domain/repositories/cleanup_history_repository.dart';
import '../../domain/repositories/progress_repository.dart';
import '../history/cleanup_history_provider.dart';

class HomeProgress {
  const HomeProgress({
    required this.totalStars,
    required this.currentStreak,
    required this.completedSessions,
    this.lastSession,
  });

  final int totalStars;
  final int currentStreak;
  final int completedSessions;
  final CleanupSessionSummary? lastSession;
}

class LoadHomeProgress {
  const LoadHomeProgress(this._progress);

  final ProgressRepository _progress;

  Future<HomeProgress> call() async {
    final progress =
        await _progress.getProgress(ProgressIdentity.primaryChildId);
    return HomeProgress(
      totalStars: progress.totalStars,
      currentStreak: progress.streak.current,
      completedSessions: progress.completedSessions,
      lastSession: progress.lastSession,
    );
  }
}

final homeProgressProvider = FutureProvider.autoDispose<HomeProgress>((ref) {
  return LoadHomeProgress(ref.watch(progressRepositoryProvider))();
});
