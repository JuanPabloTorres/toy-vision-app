import 'package:path/path.dart' as paths;
import 'package:sqflite/sqflite.dart';

import 'sqlite_migrations.dart';

class AppDatabase {
  AppDatabase._(this.database);

  final Database database;

  static Future<AppDatabase> open({
    DatabaseFactory? factory,
    String? databasePath,
  }) async {
    final selectedFactory = factory ?? databaseFactory;
    final path = databasePath ??
        paths.join(await selectedFactory.getDatabasesPath(), 'toy_vision.db');
    final database = await selectedFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: SqliteMigrations.currentVersion,
        onConfigure: (database) => database.execute('PRAGMA foreign_keys = ON'),
        onCreate: SqliteMigrations.create,
        onUpgrade: SqliteMigrations.upgrade,
      ),
    );
    return AppDatabase._(database);
  }

  Future<void> close() => database.close();
}
