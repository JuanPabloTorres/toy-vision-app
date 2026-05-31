import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../camera/live_detection_controller.dart';
import 'app_status_chip.dart';

/// Small chip indicating which detector is active. Exists so dev/QA can tell
/// at a glance whether they are looking at mock data or the real model — and
/// so screenshots can never be mistaken for real-AI accuracy results.
class DetectorModeChip extends ConsumerWidget {
  const DetectorModeChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(toyDetectorModeProvider);
    final label = switch (mode) {
      ToyDetectorMode.mock => 'Mode: Mock',
      ToyDetectorMode.tfliteWithFallback => 'Mode: TFLite + fallback',
    };
    return AppStatusChip(label: label, kind: AppStatusKind.busy);
  }
}
