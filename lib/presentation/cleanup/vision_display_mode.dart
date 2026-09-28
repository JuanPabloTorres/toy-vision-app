import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum VisionDisplayMode { kid, developerDebug }

/// Raw perception evidence is a development surface, never release UI.
const bool developerVisionAvailable = !kReleaseMode;

final visionDisplayModeProvider = StateProvider<VisionDisplayMode>(
  (ref) => VisionDisplayMode.kid,
);
