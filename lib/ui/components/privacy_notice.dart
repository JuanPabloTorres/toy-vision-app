import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_theme.dart';
import 'app_glass_panel.dart';

/// Tracks whether the user has acknowledged the privacy notice in this session.
/// Defaults to `false` so the notice shows expanded on first appearance.
class PrivacyAcknowledgement extends Notifier<bool> {
  @override
  bool build() => false;

  void acknowledge() => state = true;
  void reset() => state = false;
  void toggle() => state = !state;
}

final privacyAcknowledgementProvider =
    NotifierProvider<PrivacyAcknowledgement, bool>(
  PrivacyAcknowledgement.new,
);

/// Always-visible privacy reminder for the live screen.
///
/// Expanded on first show; tap to collapse to a compact "On-device only" chip
/// for the rest of the session. Privacy messaging is never removed entirely —
/// only condensed once the user has acknowledged it.
class PrivacyNotice extends ConsumerWidget {
  const PrivacyNotice({super.key});

  static const String _fullText =
      'Toys only. Runs on your device. No video saved or uploaded. '
      'People are ignored.';
  static const String _compactText = 'On-device only';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final acknowledged = ref.watch(privacyAcknowledgementProvider);
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () =>
          ref.read(privacyAcknowledgementProvider.notifier).toggle(),
      child: AppGlassPanel(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.lock_outline,
              size: 16,
              color: AppColors.onSurfaceMuted,
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                acknowledged ? _compactText : _fullText,
                style: textTheme.bodyMedium
                    ?.copyWith(color: AppColors.onSurfaceMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
