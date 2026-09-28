import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/settings/app_settings_controller.dart';
import '../app_assets.dart';
import '../theme/app_colors.dart';
import 'app_image.dart';

enum TobiMotion { idle, searching, found, encouraging, celebrating, confused }

/// Tobi, the app mascot, bobbing gently up and down so he reads as a friendly,
/// "alive" guide. The bob is disabled automatically under reduced-motion.
///
/// Single source of the mascot image and its idle animation: every surface that
/// shows Tobi (the welcome bubble, the mission intro, the live-camera coach
/// bubble) renders him through this widget so the character and motion stay
/// identical — only the words around him change.
class TobiMascot extends ConsumerStatefulWidget {
  const TobiMascot({
    super.key,
    this.size = 92,
    this.motion = TobiMotion.idle,
  });

  /// Edge length of the mascot image.
  final double size;
  final TobiMotion motion;

  @override
  ConsumerState<TobiMascot> createState() => _TobiMascotState();
}

class _TobiMascotState extends ConsumerState<TobiMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bob;

  @override
  void initState() {
    super.initState();
    _bob =
        AnimationController(vsync: this, duration: _durationFor(widget.motion));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(TobiMascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.motion != widget.motion) {
      _bob
        ..duration = _durationFor(widget.motion)
        ..value = 0;
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _bob.stop();
      _bob.value = 0;
    } else if (!_bob.isAnimating) {
      _bob.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animationsEnabled = ref.watch(
      appSettingsProvider.select((settings) => settings.animationsEnabled),
    );
    return TickerMode(
      enabled: animationsEnabled,
      child: AnimatedBuilder(
        animation: _bob,
        builder: (context, child) {
          final phase = animationsEnabled ? _bob.value : 0.0;
          final wave = math.sin(phase * math.pi * 2);
          final motion = _transformFor(widget.motion, wave);
          return Transform.translate(
            offset: Offset(0, motion.$1),
            child: Transform.rotate(
              angle: motion.$2,
              child: Transform.scale(scale: motion.$3, child: child),
            ),
          );
        },
        child: AppImage(
          assetPath: AppAssets.robotMascot,
          fallbackIcon: Icons.smart_toy_rounded,
          size: widget.size,
          fallbackColor: AppColors.primaryBlue,
        ),
      ),
    );
  }

  Duration _durationFor(TobiMotion motion) => switch (motion) {
        TobiMotion.found ||
        TobiMotion.celebrating =>
          const Duration(milliseconds: 700),
        TobiMotion.searching ||
        TobiMotion.confused =>
          const Duration(milliseconds: 1000),
        TobiMotion.idle ||
        TobiMotion.encouraging =>
          const Duration(milliseconds: 1200),
      };

  (double, double, double) _transformFor(TobiMotion motion, double wave) =>
      switch (motion) {
        TobiMotion.searching => (-3.0, wave * 0.035, 1.0),
        TobiMotion.found => (
            -8.0 * wave.abs(),
            -wave * 0.025,
            1 + 0.05 * wave.abs()
          ),
        TobiMotion.encouraging => (-5.0 * wave.abs(), wave * 0.018, 1.0),
        TobiMotion.celebrating => (
            -12.0 * wave.abs(),
            wave * 0.045,
            1 + 0.07 * wave.abs()
          ),
        TobiMotion.confused => (-2.0, wave * 0.055, 1.0),
        TobiMotion.idle => (-4.0 * wave, 0.0, 1.0),
      };
}
