import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:toyvision_realtime/domain/progress/cleanup_completion_policy.dart';
import 'package:toyvision_realtime/domain/progress/progress_models.dart';
import 'package:toyvision_realtime/domain/repositories/cleanup_history_repository.dart';
import 'package:toyvision_realtime/infrastructure/persistence/legacy_progress_migrator.dart';
import 'package:toyvision_realtime/infrastructure/persistence/sqlite_database.dart';
import 'package:toyvision_realtime/infrastructure/persistence/sqlite_progress_repository.dart';

void main() {
  sqfliteFfiInit();

  late AppDatabase database;
  late SqliteProgressRepository repository;

  setUp(() async {
    database = await AppDatabase.open(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    repository = SqliteProgressRepository(database);
  });

  tearDown(() => database.close());

  test('completion is atomic, queryable, and idempotent', () async {
    final request = _request('session-1', DateTime(2026, 9, 27, 10));
    const policy = CleanupCompletionPolicy();

    final first = await repository.completeCleanup(request, policy.calculate);
    final retry = await repository.completeCleanup(request, policy.calculate);
    final progress = await repository.getProgress(request.childId);

    expect(first.wasAlreadyCompleted, isFalse);
    expect(first.starsAwarded, 6);
    expect(retry.wasAlreadyCompleted, isTrue);
    expect(retry.starsAwarded, 6);
    expect(progress.completedSessions, 1);
    expect(progress.totalStars, 6);
    expect(progress.toysCollected, 4);
    expect(progress.streak.current, 1);
    expect(progress.rooms.single.sessionsCompleted, 1);
    expect(progress.achievements.single.key, 'first_cleanup');
  });

  test('multiple rooms on one local day do not increment the daily streak',
      () async {
    const policy = CleanupCompletionPolicy();
    await repository.completeCleanup(
      _request('session-1', DateTime(2026, 9, 27, 10)),
      policy.calculate,
    );
    await repository.completeCleanup(
      _request('session-2', DateTime(2026, 9, 27, 18)),
      policy.calculate,
    );

    final progress =
        await repository.getProgress(ProgressIdentity.primaryChildId);
    expect(progress.streak.current, 1);
    expect(progress.completedSessions, 2);
    expect(progress.totalStars, 10);
  });

  test('consecutive local calendar days advance the streak once', () async {
    const policy = CleanupCompletionPolicy();
    final today = DateTime.now();
    final yesterday = DateTime(today.year, today.month, today.day - 1, 10);
    final todayAtTen = DateTime(today.year, today.month, today.day, 10);
    await repository.completeCleanup(
      _request('session-1', yesterday),
      policy.calculate,
    );
    await repository.completeCleanup(
      _request('session-2', todayAtTen),
      policy.calculate,
    );

    final progress =
        await repository.getProgress(ProgressIdentity.primaryChildId);
    expect(progress.streak.current, 2);
    expect(progress.streak.longest, 2);
  });

  test('a policy failure rolls back every progress write', () async {
    final request = _request('session-1', DateTime(2026, 9, 27, 10));

    await expectLater(
      repository.completeCleanup(request, (_) => throw StateError('failed')),
      throwsStateError,
    );

    final progress = await repository.getProgress(request.childId);
    expect(progress.completedSessions, 0);
    expect(progress.totalStars, 0);
    expect(await repository.load(), isEmpty);
  });

  test('legacy SharedPreferences history migrates once without changing stars',
      () async {
    SharedPreferences.setMockInitialValues({
      LegacyProgressMigrator.legacyHistoryKey: jsonEncode([
        {
          'id': 'legacy-1',
          'startedAt': DateTime.utc(2026, 9, 26, 10).toIso8601String(),
          'completedAt': DateTime.utc(2026, 9, 26, 10, 3).toIso8601String(),
          'initialToyCount': 4,
          'confirmedCollected': 4,
        },
      ]),
    });
    final preferences = await SharedPreferences.getInstance();
    final migrator = LegacyProgressMigrator(preferences, repository);

    await migrator.migrate();
    await migrator.migrate();

    final progress =
        await repository.getProgress(ProgressIdentity.primaryChildId);
    expect(progress.completedSessions, 1);
    expect(progress.totalStars, 4);
    expect(
      preferences.containsKey(LegacyProgressMigrator.legacyHistoryKey),
      isFalse,
    );
  });

  test('reset cascades through every progress table', () async {
    const policy = CleanupCompletionPolicy();
    final request = _request('session-1', DateTime.now());
    await repository.completeCleanup(request, policy.calculate);

    await repository.clear(request.childId);

    final progress = await repository.getProgress(request.childId);
    expect(progress.completedSessions, 0);
    expect(progress.totalStars, 0);
    expect(progress.rooms, isEmpty);
    expect(progress.achievements, isEmpty);
  });
}

CleanupCompletionRequest _request(String id, DateTime completedAt) =>
    CleanupCompletionRequest(
      childId: ProgressIdentity.primaryChildId,
      childName: ProgressIdentity.primaryChildName,
      roomId: ProgressIdentity.primaryRoomId,
      roomName: ProgressIdentity.primaryRoomName,
      session: CleanupSessionSummary(
        id: id,
        startedAt: completedAt.subtract(const Duration(minutes: 3)),
        completedAt: completedAt,
        initialToyCount: 4,
        confirmedCollected: 4,
      ),
    );
