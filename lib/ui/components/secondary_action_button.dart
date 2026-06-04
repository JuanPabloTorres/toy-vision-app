import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Soft, low-emphasis pill for the *secondary* action on a screen
/// ("Ver progreso", "Para padres"). Deliberately quieter than
/// [PrimaryActionButton]: translucent fill, no drop shadow, so the child's
/// eye still lands on the primary CTA first.
///
/// Presentation only — holds no business logic.
class SecondaryActionButton extends StatefulWidget {
  const SecondaryActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.leading,
    this.fill = const Color(0x8C7EF0C3), // mint @ 55%
    this.labelColor = AppColors.textBlueDark,
    this.expand = true,
  });

  final String label;
  final VoidCallback onPressed;

  /// Optional leading widget — typically a small white circle wrapping an
  /// icon (see [SecondaryActionButton.circledIcon]).
  final Widget? leading;

  final Color fill;
  final Color labelColor;
  final bool expand;

  /// Convenience for the common "icon inside a white circle" leading badge.
  static Widget circledIcon(
    IconData icon, {
    Color color = AppColors.progressGreen,
  }) {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.cardWhite,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }

  @override
  State<SecondaryActionButton> createState() => _SecondaryActionButtonState();
}

class _SecondaryActionButtonState extends State<SecondaryActionButton> {
  static const double _depthOffset = 4;

  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadii.pill);
    final topColor = _lighten(widget.fill, 0.08);
    final baseColor = _darken(widget.fill, 0.20);
    final button = Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        onTap: widget.onPressed,
        onHighlightChanged: (pressed) {
          if (_isPressed == pressed) return;
          setState(() => _isPressed = pressed);
        },
        borderRadius: radius,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          margin: EdgeInsets.only(
            top: _isPressed ? _depthOffset : 0,
            bottom: _isPressed ? 0 : _depthOffset,
          ),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [topColor, widget.fill],
              ),
              borderRadius: radius,
              border: Border.all(color: Colors.white.withOpacity(0.45), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: _isPressed ? const Color(0x18000000) : const Color(0x26000000),
                  blurRadius: _isPressed ? 6 : 10,
                  offset: Offset(0, _isPressed ? 2 : 4),
                ),
              ],
              color: _isPressed ? baseColor : widget.fill,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Row(
                mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.leading != null) ...[
                    widget.leading!,
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Text(
                    widget.label,
                    style: AppTypography.missionTitle.copyWith(
                      color: widget.labelColor,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return widget.expand
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }

  Color _lighten(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    final lightness = (hsl.lightness + amount).clamp(0.0, 1.0);
    return hsl.withLightness(lightness).toColor();
  }

  Color _darken(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    final lightness = (hsl.lightness - amount).clamp(0.0, 1.0);
    return hsl.withLightness(lightness).toColor();
  }
}
