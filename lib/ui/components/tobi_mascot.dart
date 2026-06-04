import 'package:flutter/material.dart';

import '../app_assets.dart';
import '../theme/app_colors.dart';
import 'app_image.dart';

/// Tobi, the app mascot, bobbing gently up and down so he reads as a friendly,
/// "alive" guide. The bob is disabled automatically under reduced-motion.
///
/// Single source of the mascot image and its idle animation: every surface that
/// shows Tobi (the welcome bubble, the mission intro, the live-camera coach
/// bubble) renders him through this widget so the character and motion stay
/// identical — only the words around him change.
class TobiMascot extends StatefulWidget {
  const TobiMascot({super.key, this.size = 92});

  /// Edge length of the mascot image.
  final double size;

  @override
  State<TobiMascot> createState() => _TobiMascotState();
}

class _TobiMascotState extends State<TobiMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bob = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
    return AnimatedBuilder(
      animation: _bob,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, -6 * Curves.easeInOut.transform(_bob.value)),
        child: child,
      ),
      child: AppImage(
        assetPath: AppAssets.robotMascot,
        fallbackIcon: Icons.smart_toy_rounded,
        size: widget.size,
        fallbackColor: AppColors.primaryBlue,
      ),
    );
  }
}
