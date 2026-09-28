import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/toyvision_app.dart';
import 'application/cleanup/cleanup_controller.dart';
import 'application/history/cleanup_history_provider.dart';
import 'infrastructure/observability/jsonl_perception_evidence_recorder.dart';
import 'infrastructure/persistence/legacy_progress_migrator.dart';
import 'infrastructure/persistence/shared_preferences_provider.dart';
import 'infrastructure/persistence/sqlite_database.dart';
import 'infrastructure/persistence/sqlite_progress_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // SharedPreferences remains limited to non-progress UI settings. SQLite is
  // the sole persistent source of truth for cleanup sessions and rewards.
  final prefs = await SharedPreferences.getInstance();
  final database = await AppDatabase.open();
  final progressRepository = SqliteProgressRepository(database);
  await LegacyProgressMigrator(prefs, progressRepository).migrate();
  final evidenceRecorder = JsonlPerceptionEvidenceRecorder();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        progressRepositoryProvider.overrideWithValue(progressRepository),
        perceptionEvidenceSinkProvider.overrideWithValue(evidenceRecorder),
      ],
      child: const ToyVisionApp(),
    ),
  );
}
