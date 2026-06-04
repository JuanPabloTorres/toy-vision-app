import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../camera/live_detection_controller.dart';
import 'app_status_chip.dart';

/// Tappable chip indicating which detector is currently active.
///
/// Phase 5.0 restored the toggle so QA can cycle between Demo, Object
/// Assist (ML Kit), and Open-Vocab (local Python server). Cycle order:
/// `Demo → Object Assist → Open-Vocab → Demo`.
///
/// Mock is still the safest default (no Wi-Fi / no ML Kit native plugin
/// needed). Each tap cycles to the next mode and a snackbar names what
/// just got activated so the user always knows what is producing the
/// boxes on screen.
class DetectorModeChip extends ConsumerWidget {
  const DetectorModeChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(toyDetectorModeProvider);
    final (label, kind) = switch (mode) {
      ToyDetectorMode.mock => ('Demo · TAP', AppStatusKind.busy),
      ToyDetectorMode.mlkitWithFallback =>
        ('Object Assist · TAP', AppStatusKind.ready),
      ToyDetectorMode.remoteVisionServer =>
        ('Open-Vocab · TAP', AppStatusKind.ready),
    };
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _cycle(context, ref),
      child: AppStatusChip(label: label, kind: kind),
    );
  }

  void _cycle(BuildContext context, WidgetRef ref) {
    ref.read(toyDetectorModeProvider.notifier).toggle();
    final next = ref.read(toyDetectorModeProvider);
    final message = switch (next) {
      ToyDetectorMode.mock =>
        'Demo Mode — generated test objects; not real detection.',
      ToyDetectorMode.mlkitWithFallback =>
        'Object Assist Mode — generic on-device detections; review to count.',
      ToyDetectorMode.remoteVisionServer =>
        'Open-Vocab Mode — sends frame metadata to your local PC. '
            'Server must be running.',
    };
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
        ),
      );
  }
}
