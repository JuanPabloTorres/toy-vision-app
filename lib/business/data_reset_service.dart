import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/active_mission_repository.dart';
import '../storage/mission_history_repository.dart';
import '../storage/settings_repository.dart';
import 'app_audio_service.dart';

/// Orchestrates the two local-data reset levels so the UI never touches the
/// repositories directly. Each repository persists its own clear (write-through
/// to disk), so a reset survives an app restart.
///
///  - [resetProgress] wipes the child's *progress* (mission history + any
///    in-progress mission marker) and KEEPS preferences (sound / music /
///    haptics / parent mode).
///  - [resetAll] wipes progress AND restores every preference to its first-run
///    default (sound back on).
class DataResetService {
  const DataResetService(this._ref);

  final Ref _ref;

  /// Reset progress only — missions + the active-mission recovery marker.
  /// Preferences are left untouched.
  void resetProgress() {
    _ref.read(missionHistoryProvider.notifier).clear();
    _ref.read(activeMissionProvider.notifier).clear();
  }

  /// Reset everything — progress + preferences back to first-run defaults.
  void resetAll() {
    resetProgress();
    _ref.read(settingsProvider.notifier).resetToDefaults();
    // Sound lives in the audio service (the runtime authority). Flip it back
    // on and keep the UI mirror in sync so the speaker icon updates too.
    _ref.read(appAudioServiceProvider).setSoundEnabled(true);
    _ref.read(audioMutedProvider.notifier).state = false;
  }
}

final dataResetServiceProvider = Provider<DataResetService>(
  DataResetService.new,
);
