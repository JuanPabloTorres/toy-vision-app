import '../../domain/cleanup/cleanup_session.dart';
import '../../domain/progress/cleanup_completion_policy.dart';
import '../../domain/progress/progress_models.dart';
import '../../domain/repositories/cleanup_history_repository.dart';
import '../../domain/repositories/progress_repository.dart';

class CompleteCleanupSessionUseCase {
  const CompleteCleanupSessionUseCase(
    this._repository, {
    CleanupCompletionPolicy policy = const CleanupCompletionPolicy(),
  }) : _policy = policy;

  final ProgressRepository _repository;
  final CleanupCompletionPolicy _policy;

  Future<CleanupCompletionResult> call(
    CleanupSession session, {
    String childId = ProgressIdentity.primaryChildId,
    String childName = ProgressIdentity.primaryChildName,
    String roomId = ProgressIdentity.primaryRoomId,
    String roomName = ProgressIdentity.primaryRoomName,
  }) {
    if (session.status != CleanupStatus.completed ||
        session.completedAt == null) {
      throw StateError('Only completed cleanup sessions can update progress');
    }
    if (session.initialSnapshot.toys.isEmpty ||
        session.confirmedCollected <= 0) {
      throw StateError('A cleanup requires confirmed collection evidence');
    }
    final request = CleanupCompletionRequest(
      childId: childId,
      childName: childName,
      roomId: roomId,
      roomName: roomName,
      session: CleanupSessionSummary.fromSession(session),
    );
    return _repository.completeCleanup(request, _policy.calculate);
  }
}
