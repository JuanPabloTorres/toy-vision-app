import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/progress/cleanup_completion_policy.dart';
import '../../domain/progress/progress_models.dart';
import '../../domain/repositories/cleanup_history_repository.dart';
import 'sqlite_progress_repository.dart';

class LegacyProgressMigrator {
  const LegacyProgressMigrator(this._preferences, this._repository);

  static const legacyHistoryKey = 'toyvision.cleanup_history.v3';

  final SharedPreferences _preferences;
  final SqliteProgressRepository _repository;

  Future<void> migrate() async {
    final raw = _preferences.getString(legacyHistoryKey);
    if (raw == null) return;
    final sessions = _decode(raw)
      ..sort(
        (first, second) => first.completedAt.compareTo(second.completedAt),
      );
    const policy = CleanupCompletionPolicy();
    for (final session in sessions) {
      final request = CleanupCompletionRequest(
        childId: ProgressIdentity.primaryChildId,
        childName: ProgressIdentity.primaryChildName,
        roomId: ProgressIdentity.primaryRoomId,
        roomName: ProgressIdentity.primaryRoomName,
        session: session,
      );
      await _repository.completeCleanup(request, (context) {
        final decision = policy.calculate(context);
        return CleanupCompletionDecision(
          roomProgress: decision.roomProgress,
          streak: decision.streak,
          achievements: decision.achievements,
          rewards: [
            RewardTransaction(
              id: '${session.id}:legacy_toys_collected',
              childId: request.childId,
              sessionId: session.id,
              rewardType: 'stars',
              amount: session.confirmedCollected,
              reason: 'legacy_toys_collected',
              createdAt: session.completedAt,
            ),
          ],
        );
      });
    }
    await _preferences.remove(legacyHistoryKey);
  }

  List<CleanupSessionSummary> _decode(String raw) {
    try {
      final values = jsonDecode(raw) as List<dynamic>;
      return values
          .whereType<Map<String, dynamic>>()
          .map(_decodeSession)
          .whereType<CleanupSessionSummary>()
          .toList(growable: true);
    } on FormatException {
      return [];
    } on TypeError {
      return [];
    }
  }

  CleanupSessionSummary? _decodeSession(Map<String, dynamic> value) {
    final id = value['id'];
    final startedAt = DateTime.tryParse(value['startedAt'] as String? ?? '');
    final completedAt =
        DateTime.tryParse(value['completedAt'] as String? ?? '');
    final initialToyCount = value['initialToyCount'];
    final confirmedCollected = value['confirmedCollected'];
    if (id is! String ||
        startedAt == null ||
        completedAt == null ||
        initialToyCount is! int ||
        confirmedCollected is! int ||
        initialToyCount <= 0 ||
        confirmedCollected <= 0) {
      return null;
    }
    return CleanupSessionSummary(
      id: id,
      startedAt: startedAt,
      completedAt: completedAt,
      initialToyCount: initialToyCount,
      confirmedCollected: confirmedCollected,
    );
  }
}
