import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/settings/app_settings_controller.dart';

enum VisionDisplayMode { kid, developerDebug }

/// Raw perception evidence is a development surface, never release UI.
const bool developerVisionAvailable = !kReleaseMode;

final visionDisplayModeProvider = StateProvider<VisionDisplayMode>(
  (ref) => VisionDisplayMode.kid,
);

/// Kid Mode and release builds always resolve to the child-safe surface, even
/// if a development diagnostic mode was selected earlier.
final effectiveVisionDisplayModeProvider = Provider<VisionDisplayMode>((ref) {
  if (!developerVisionAvailable ||
      ref.watch(appSettingsProvider).kidModeEnabled) {
    return VisionDisplayMode.kid;
  }
  return ref.watch(visionDisplayModeProvider);
});
