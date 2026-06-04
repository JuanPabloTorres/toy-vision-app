import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:lottie/lottie.dart';

import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';

/// Renders a Lottie animation when its `.json` is present in
/// `assets/lottie/`; otherwise gracefully falls back to a Material icon
/// with a gentle scale-pulse so the UI is never empty.
///
/// This keeps the app fully functional before any animation files are
/// added to the repo — Mateo gets a sensible icon today and a polished
/// animation tomorrow without any code change.
class LottieStatusView extends StatefulWidget {
  const LottieStatusView({
    super.key,
    required this.fallbackIcon,
    this.assetPath,
    this.size = 96,
    this.repeat = true,
    this.fallbackColor,
  });

  /// Asset path inside `assets/lottie/` (e.g. `assets/lottie/mission_loading.json`).
  /// May be null — in which case the fallback always shows.
  final String? assetPath;

  /// Material icon shown when the Lottie asset is missing or fails to load.
  final IconData fallbackIcon;

  final double size;
  final bool repeat;
  final Color? fallbackColor;

  @override
  State<LottieStatusView> createState() => _LottieStatusViewState();
}

class _LottieStatusViewState extends State<LottieStatusView> {
  Future<bool>? _assetExists;

  @override
  void initState() {
    super.initState();
    _assetExists = _checkAsset();
  }

  Future<bool> _checkAsset() async {
    final path = widget.assetPath;
    if (path == null) return false;
    try {
      // rootBundle throws when the asset is not registered; we treat that
      // as "fall back" rather than letting the error propagate.
      await rootBundle.load(path);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _assetExists,
      builder: (context, snapshot) {
        if (snapshot.data == true) {
          return SizedBox(
            width: widget.size,
            height: widget.size,
            child: Lottie.asset(
              widget.assetPath!,
              repeat: widget.repeat,
              fit: BoxFit.contain,
            ),
          );
        }
        return _IconFallback(
          icon: widget.fallbackIcon,
          size: widget.size,
          color: widget.fallbackColor ?? AppColors.gameBlue,
        );
      },
    );
  }
}

class _IconFallback extends StatefulWidget {
  const _IconFallback({
    required this.icon,
    required this.size,
    required this.color,
  });

  final IconData icon;
  final double size;
  final Color color;

  @override
  State<_IconFallback> createState() => _IconFallbackState();
}

class _IconFallbackState extends State<_IconFallback>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 0.85, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
      ),
      child: Container(
        width: widget.size,
        height: widget.size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: widget.color.withValues(alpha: 0.15),
          shape: BoxShape.circle,
          boxShadow: AppShadows.floatingBubble,
        ),
        child: Icon(
          widget.icon,
          size: widget.size * 0.55,
          color: widget.color,
        ),
      ),
    );
  }
}
