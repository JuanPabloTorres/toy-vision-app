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
    this.fill = AppColors.mint,
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
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.cardWhite,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 23),
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
    final topColor = _lighten(widget.fill, 0.14);
    final baseColor = _darken(widget.fill, 0.12);
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
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.7),
                width: 1.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: _isPressed
                      ? const Color(0x18000000)
                      : const Color(0x2A000000),
                  blurRadius: _isPressed ? 6 : 10,
                  offset: Offset(0, _isPressed ? 2 : 4),
                ),
              ],
              color: _isPressed ? baseColor : widget.fill,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Row(
                mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.leading != null) ...[
                    widget.leading!,
                    const SizedBox(width: AppSpacing.md),
                  ],
                  // Flexible so a long label + leading icon shrinks to fit the
                  // available width instead of overflowing the pill (a 5px
                  // horizontal overflow surfaced on "Ver mis estrellas").
                  Flexible(
                    child: Text(
                      widget.label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.missionTitle.copyWith(
                        color: widget.labelColor,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
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
