import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_theme.dart';
import '../../camera/live_detection_controller.dart';

/// Phase 4 product banner shown only in Object Assist Mode.
///
/// The product reframe is explicit: the on-device detector is a **candidate
/// generator**, not a toy classifier. This banner sets the parent's
/// expectation BEFORE they see boxes — so they don't read generic boxes as
/// confirmed toy identifications. It hides itself in Demo Mode (where the
/// mock detector is just rendering fixed shapes) so it doesn't clutter the
/// developer/QA path.
class ObjectAssistBanner extends ConsumerWidget {
  const ObjectAssistBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(toyDetectorModeProvider);
    final message = switch (mode) {
      ToyDetectorMode.mock => null, // no banner in Demo
      ToyDetectorMode.mlkitWithFallback =>
        'Detected objects need review before counting.',
      ToyDetectorMode.remoteVisionServer =>
        'Open-Vocab mode: frame metadata is sent to your local PC only '
            'while this mode is on. No images leave the device in this phase.',
    };
    if (message == null) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.candidatePending.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.candidatePending),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.info_outline,
            size: 16,
            color: AppColors.candidatePending,
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
