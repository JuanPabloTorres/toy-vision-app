import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Three dots that pulse in sequence — a calmer, friendlier "buscando…"
/// loader than a spinning ring. Used while the robot scans for toys.
///
/// Respects reduced-motion: when the platform disables animations the dots
/// render statically at full size. Presentation only.
class SearchingDots extends StatefulWidget {
  const SearchingDots({
    super.key,
    this.color = AppColors.primaryBlue,
    this.dotSize = 9,
  });

  final Color color;
  final double dotSize;

  @override
  State<SearchingDots> createState() => _SearchingDotsState();
}

class _SearchingDotsState extends State<SearchingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) SizedBox(width: widget.dotSize * 0.7),
          _Dot(controller: _controller, index: i, widget: widget),
        ],
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({
    required this.controller,
    required this.index,
    required this.widget,
  });

  final AnimationController controller;
  final int index;
  final SearchingDots widget;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        // Each dot peaks a third of a cycle after the previous one, so the
        // pulse travels left→right.
        final phase = (controller.value - index / 3) % 1.0;
        // A short bump near the start of each dot's phase, eased back down.
        final t = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
        final scale = 0.7 + 0.3 * Curves.easeInOut.transform(t.clamp(0.0, 1.0));
        return Container(
          width: widget.dotSize * scale,
          height: widget.dotSize * scale,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}
