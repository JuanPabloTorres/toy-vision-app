import 'package:sqflite/sqflite.dart';

abstract final class SqliteMigrations {
  static const currentVersion = 1;

  static Future<void> create(Database database, int version) async {
    await _version1(database);
  }

  static Future<void> upgrade(
    Database database,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 1) await _version1(database);
  }

  static Future<void> _version1(Database database) async {
    await database.execute('''
      CREATE TABLE children (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE rooms (
        id TEXT PRIMARY KEY,
        child_id TEXT NOT NULL,
        name TEXT NOT NULL,
        icon_key TEXT,
        is_unlocked INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        FOREIGN KEY(child_id) REFERENCES children(id) ON DELETE CASCADE
      )
    ''');
    await database.execute('''
      CREATE TABLE room_progress (
        id TEXT PRIMARY KEY,
        room_id TEXT NOT NULL,
        child_id TEXT NOT NULL,
        sessions_completed INTEGER NOT NULL DEFAULT 0,
        toys_collected INTEGER NOT NULL DEFAULT 0,
        best_cleanup_seconds INTEGER,
        last_completed_at TEXT,
        updated_at TEXT NOT NULL,
        UNIQUE(child_id, room_id),
        FOREIGN KEY(child_id) REFERENCES children(id) ON DELETE CASCADE,
        FOREIGN KEY(room_id) REFERENCES rooms(id) ON DELETE CASCADE
      )
    ''');
    await database.execute('''
      CREATE TABLE cleanup_sessions (
        id TEXT PRIMARY KEY,
        child_id TEXT NOT NULL,
        room_id TEXT NOT NULL,
        started_at TEXT NOT NULL,
        completed_at TEXT NOT NULL,
        local_completion_day TEXT NOT NULL,
        duration_seconds INTEGER NOT NULL,
        detected_toys INTEGER NOT NULL,
        collected_toys INTEGER NOT NULL,
        stars_awarded INTEGER NOT NULL,
        completion_reason TEXT NOT NULL,
        status TEXT NOT NULL,
        FOREIGN KEY(child_id) REFERENCES children(id) ON DELETE CASCADE,
        FOREIGN KEY(room_id) REFERENCES rooms(id) ON DELETE CASCADE
      )
    ''');
    await database.execute('''
      CREATE TABLE reward_ledger (
        id TEXT PRIMARY KEY,
        child_id TEXT NOT NULL,
        session_id TEXT,
        reward_type TEXT NOT NULL,
        amount INTEGER NOT NULL,
        reason TEXT NOT NULL,
        created_at TEXT NOT NULL,
        UNIQUE(session_id, reward_type, reason),
        FOREIGN KEY(child_id) REFERENCES children(id) ON DELETE CASCADE,
        FOREIGN KEY(session_id) REFERENCES cleanup_sessions(id) ON DELETE CASCADE
      )
    ''');
    await database.execute('''
      CREATE TABLE streaks (
        child_id TEXT PRIMARY KEY,
        current_streak INTEGER NOT NULL DEFAULT 0,
        longest_streak INTEGER NOT NULL DEFAULT 0,
        last_success_date TEXT,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(child_id) REFERENCES children(id) ON DELETE CASCADE
      )
    ''');
    await database.execute('''
      CREATE TABLE achievements (
        id TEXT PRIMARY KEY,
        child_id TEXT NOT NULL,
        achievement_key TEXT NOT NULL,
        unlocked_at TEXT NOT NULL,
        UNIQUE(child_id, achievement_key),
        FOREIGN KEY(child_id) REFERENCES children(id) ON DELETE CASCADE
      )
    ''');
    await database.execute(
      'CREATE INDEX cleanup_sessions_child_completed_idx '
      'ON cleanup_sessions(child_id, completed_at DESC)',
    );
    await database.execute(
      'CREATE INDEX reward_ledger_child_idx ON reward_ledger(child_id)',
    );
  }
}
