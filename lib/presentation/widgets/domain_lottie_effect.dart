import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';

import '../../application/settings/app_settings_controller.dart';
import '../feedback/animation_director.dart';

class DomainLottieEffect extends ConsumerWidget {
  const DomainLottieEffect({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final animation = ref.watch(animationDirectorProvider);
    final appAnimations = ref.watch(
      appSettingsProvider.select((settings) => settings.animationsEnabled),
    );
    final asset = animation.lottieEffect;
    final motionEnabled =
        appAnimations && !MediaQuery.disableAnimationsOf(context);
    if (asset == null || !motionEnabled) return const SizedBox.shrink();
    return IgnorePointer(
      child: Center(
        child: SizedBox.square(
          dimension: 240,
          child: Lottie.asset(
            asset,
            key: ValueKey('${animation.sequence}:$asset'),
            repeat: false,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
