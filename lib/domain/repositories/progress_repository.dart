import '../progress/progress_models.dart';

typedef CleanupCompletionDecider = CleanupCompletionDecision Function(
  CleanupCompletionContext context,
);

abstract interface class ProgressRepository {
  Future<ChildProgress> getProgress(String childId);

  Future<CleanupCompletionResult> completeCleanup(
    CleanupCompletionRequest request,
    CleanupCompletionDecider decide,
  );

  Future<void> clear(String childId);
}
