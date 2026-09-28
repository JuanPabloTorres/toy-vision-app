import 'package:flutter_riverpod/flutter_riverpod.dart';

enum VisionDisplayMode { kid, developerDebug }

final visionDisplayModeProvider = StateProvider<VisionDisplayMode>(
  (ref) => VisionDisplayMode.kid,
);
