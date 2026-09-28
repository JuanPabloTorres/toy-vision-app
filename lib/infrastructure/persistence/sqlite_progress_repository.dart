import 'package:sqflite/sqflite.dart';

import '../../domain/progress/progress_models.dart';
import '../../domain/repositories/cleanup_history_repository.dart';
import '../../domain/repositories/progress_repository.dart';
import 'sqlite_database.dart';

class SqliteProgressRepository
    implements ProgressRepository, CleanupHistoryRepository {
  SqliteProgressRepository(this._database);

  final AppDatabase _database;

  @override
  Future<CleanupCompletionResult> completeCleanup(
    CleanupCompletionRequest request,
    CleanupCompletionDecider decide,
  ) =>
      _database.database.transaction((transaction) async {
        final existing = await transaction.query(
          'cleanup_sessions',
          columns: ['stars_awarded'],
          where: 'id = ?',
          whereArgs: [request.session.id],
          limit: 1,
        );
        if (existing.isNotEmpty) {
          return CleanupCompletionResult(
            sessionId: request.session.id,
            starsAwarded: existing.single['stars_awarded']! as int,
            wasAlreadyCompleted: true,
          );
        }

        await _ensureChildAndRoom(transaction, request);
        final context = CleanupCompletionContext(
          request: request,
          roomProgress: await _roomProgress(transaction, request),
          streak: await _streak(transaction, request.childId),
          completedOnSameLocalDay:
              await _hasCompletionOnDay(transaction, request),
          totalCompletedSessions:
              await _completedSessionCount(transaction, request.childId),
        );
        final decision = decide(context);
        await _insertSession(transaction, request, decision.starsAwarded);
        await _saveRoomProgress(transaction, decision.roomProgress);
        await _saveStreak(transaction, decision.streak);
        for (final reward in decision.rewards) {
          await transaction.insert('reward_ledger', _rewardRow(reward));
        }
        for (final achievement in decision.achievements) {
          await transaction.insert(
            'achievements',
            _achievementRow(achievement),
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
        return CleanupCompletionResult(
          sessionId: request.session.id,
          starsAwarded: decision.starsAwarded,
          wasAlreadyCompleted: false,
        );
      });

  @override
  Future<ChildProgress> getProgress(String childId) async {
    final database = _database.database;
    final sessionRows = await database.query(
      'cleanup_sessions',
      where: 'child_id = ?',
      whereArgs: [childId],
      orderBy: 'completed_at DESC',
    );
    if (sessionRows.isEmpty) return ChildProgress.empty(childId);
    final rewardTotal = Sqflite.firstIntValue(
          await database.rawQuery(
            'SELECT COALESCE(SUM(amount), 0) FROM reward_ledger '
            'WHERE child_id = ? AND reward_type = ?',
            [childId, 'stars'],
          ),
        ) ??
        0;
    final roomRows = await database.query(
      'room_progress',
      where: 'child_id = ?',
      whereArgs: [childId],
      orderBy: 'last_completed_at DESC',
    );
    final achievementRows = await database.query(
      'achievements',
      where: 'child_id = ?',
      whereArgs: [childId],
      orderBy: 'unlocked_at',
    );
    final toysCollected = sessionRows.fold<int>(
      0,
      (sum, row) => sum + (row['collected_toys']! as int),
    );
    return ChildProgress(
      childId: childId,
      totalStars: rewardTotal,
      streak: _effectiveStreak(await _readStreak(database, childId)),
      completedSessions: sessionRows.length,
      toysCollected: toysCollected,
      rooms: roomRows.map(_decodeRoomProgress).toList(growable: false),
      achievements:
          achievementRows.map(_decodeAchievement).toList(growable: false),
      lastSession: _decodeSession(sessionRows.first),
    );
  }

  @override
  Future<List<CleanupSessionSummary>> load() async {
    final rows = await _database.database.query(
      'cleanup_sessions',
      where: 'child_id = ?',
      whereArgs: [ProgressIdentity.primaryChildId],
      orderBy: 'completed_at',
    );
    return rows.map(_decodeSession).toList(growable: false);
  }

  @override
  Future<void> clear([String childId = ProgressIdentity.primaryChildId]) async {
    await _database.database.delete(
      'children',
      where: 'id = ?',
      whereArgs: [childId],
    );
  }

  Future<void> _ensureChildAndRoom(
    Transaction transaction,
    CleanupCompletionRequest request,
  ) async {
    final now = request.session.completedAt.toUtc().toIso8601String();
    await transaction.insert(
      'children',
      {
        'id': request.childId,
        'name': request.childName,
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    await transaction.insert(
      'rooms',
      {
        'id': request.roomId,
        'child_id': request.childId,
        'name': request.roomName,
        'is_unlocked': 1,
        'created_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<RoomProgress> _roomProgress(
    Transaction transaction,
    CleanupCompletionRequest request,
  ) async {
    final rows = await transaction.query(
      'room_progress',
      where: 'child_id = ? AND room_id = ?',
      whereArgs: [request.childId, request.roomId],
      limit: 1,
    );
    return rows.isEmpty
        ? RoomProgress.empty(
            childId: request.childId,
            roomId: request.roomId,
          )
        : _decodeRoomProgress(rows.single);
  }

  Future<DailyStreak> _streak(
    Transaction transaction,
    String childId,
  ) async {
    final rows = await transaction.query(
      'streaks',
      where: 'child_id = ?',
      whereArgs: [childId],
      limit: 1,
    );
    return rows.isEmpty
        ? DailyStreak.empty(childId)
        : _decodeStreak(rows.single);
  }

  Future<DailyStreak> _readStreak(Database database, String childId) async {
    final rows = await database.query(
      'streaks',
      where: 'child_id = ?',
      whereArgs: [childId],
      limit: 1,
    );
    return rows.isEmpty
        ? DailyStreak.empty(childId)
        : _decodeStreak(rows.single);
  }

  Future<bool> _hasCompletionOnDay(
    Transaction transaction,
    CleanupCompletionRequest request,
  ) async {
    final rows = await transaction.query(
      'cleanup_sessions',
      columns: ['id'],
      where: 'child_id = ? AND local_completion_day = ?',
      whereArgs: [request.childId, _localDay(request.session.completedAt)],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<int> _completedSessionCount(
    Transaction transaction,
    String childId,
  ) async =>
      Sqflite.firstIntValue(
        await transaction.rawQuery(
          'SELECT COUNT(*) FROM cleanup_sessions WHERE child_id = ?',
          [childId],
        ),
      ) ??
      0;

  Future<void> _insertSession(
    Transaction transaction,
    CleanupCompletionRequest request,
    int starsAwarded,
  ) async {
    final session = request.session;
    await transaction.insert('cleanup_sessions', {
      'id': session.id,
      'child_id': request.childId,
      'room_id': request.roomId,
      'started_at': session.startedAt.toUtc().toIso8601String(),
      'completed_at': session.completedAt.toUtc().toIso8601String(),
      'local_completion_day': _localDay(session.completedAt),
      'duration_seconds':
          session.completedAt.difference(session.startedAt).inSeconds,
      'detected_toys': session.initialToyCount,
      'collected_toys': session.confirmedCollected,
      'stars_awarded': starsAwarded,
      'completion_reason': 'room_clean_confirmed',
      'status': 'completed',
    });
  }

  Future<void> _saveRoomProgress(
    Transaction transaction,
    RoomProgress progress,
  ) =>
      transaction.insert(
        'room_progress',
        {
          'id': '${progress.childId}:${progress.roomId}',
          'child_id': progress.childId,
          'room_id': progress.roomId,
          'sessions_completed': progress.sessionsCompleted,
          'toys_collected': progress.toysCollected,
          'best_cleanup_seconds': progress.bestCleanupSeconds,
          'last_completed_at':
              progress.lastCompletedAt?.toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<void> _saveStreak(
    Transaction transaction,
    DailyStreak streak,
  ) =>
      transaction.insert(
        'streaks',
        {
          'child_id': streak.childId,
          'current_streak': streak.current,
          'longest_streak': streak.longest,
          'last_success_date': streak.lastSuccessDay == null
              ? null
              : _dateOnly(streak.lastSuccessDay!),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Map<String, Object?> _rewardRow(RewardTransaction reward) => {
        'id': reward.id,
        'child_id': reward.childId,
        'session_id': reward.sessionId,
        'reward_type': reward.rewardType,
        'amount': reward.amount,
        'reason': reward.reason,
        'created_at': reward.createdAt.toUtc().toIso8601String(),
      };

  Map<String, Object?> _achievementRow(Achievement achievement) => {
        'id': achievement.id,
        'child_id': achievement.childId,
        'achievement_key': achievement.key,
        'unlocked_at': achievement.unlockedAt.toUtc().toIso8601String(),
      };

  CleanupSessionSummary _decodeSession(Map<String, Object?> row) =>
      CleanupSessionSummary(
        id: row['id']! as String,
        startedAt: DateTime.parse(row['started_at']! as String),
        completedAt: DateTime.parse(row['completed_at']! as String),
        initialToyCount: row['detected_toys']! as int,
        confirmedCollected: row['collected_toys']! as int,
        starsAwarded: row['stars_awarded']! as int,
      );

  RoomProgress _decodeRoomProgress(Map<String, Object?> row) => RoomProgress(
        childId: row['child_id']! as String,
        roomId: row['room_id']! as String,
        sessionsCompleted: row['sessions_completed']! as int,
        toysCollected: row['toys_collected']! as int,
        bestCleanupSeconds: row['best_cleanup_seconds'] as int?,
        lastCompletedAt: _optionalDate(row['last_completed_at']),
      );

  DailyStreak _decodeStreak(Map<String, Object?> row) => DailyStreak(
        childId: row['child_id']! as String,
        current: row['current_streak']! as int,
        longest: row['longest_streak']! as int,
        lastSuccessDay: _optionalDate(row['last_success_date']),
      );

  Achievement _decodeAchievement(Map<String, Object?> row) => Achievement(
        id: row['id']! as String,
        childId: row['child_id']! as String,
        key: row['achievement_key']! as String,
        unlockedAt: DateTime.parse(row['unlocked_at']! as String),
      );

  DateTime? _optionalDate(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;

  DailyStreak _effectiveStreak(DailyStreak streak) {
    final lastSuccessDay = streak.lastSuccessDay;
    if (lastSuccessDay == null) return streak;
    final today = DateTime.now();
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    final active = _dateOnly(lastSuccessDay) == _dateOnly(today) ||
        _dateOnly(lastSuccessDay) == _dateOnly(yesterday);
    if (active) return streak;
    return DailyStreak(
      childId: streak.childId,
      current: 0,
      longest: streak.longest,
      lastSuccessDay: streak.lastSuccessDay,
    );
  }

  String _localDay(DateTime value) => _dateOnly(value.toLocal());

  String _dateOnly(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
