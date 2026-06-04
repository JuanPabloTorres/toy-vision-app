import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/toyvision_app.dart';
import 'storage/active_mission_repository.dart';
import 'storage/mission_history_repository.dart';
import 'storage/persistence/shared_preferences_provider.dart';
import 'storage/persistent_mission_history_repository.dart';
import 'storage/settings_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load SharedPreferences once, up front, so the persistent repositories can
  // seed their state synchronously inside Notifier.build() — keeping every
  // existing synchronous `ref.watch(...)` call site unchanged. The in-memory
  // repositories remain the defaults (and the test doubles); production swaps
  // in the disk-backed implementations here.
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        missionHistoryProvider.overrideWith(
          PersistentMissionHistoryRepository.new,
        ),
        activeMissionProvider.overrideWith(
          PersistentActiveMissionRepository.new,
        ),
        settingsProvider.overrideWith(PersistentSettingsRepository.new),
      ],
      child: const ToyVisionApp(),
    ),
  );
}
