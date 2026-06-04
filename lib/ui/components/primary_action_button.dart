import 'package:flutter/material.dart';

import '../theme/app_radii.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';

/// The one canonical "big friendly pill" call-to-action for Mateo's flow.
///
/// Before this existed every screen (splash, home, intro, mission-complete,
/// camera action row) hand-rolled its own near-identical pill button. This
/// widget is the single source of truth — CLAUDE.md forbids forking visual
/// components, so new CTAs add a *parameter* here, never a new private
/// `_Button`.
///
/// It is presentation only: it holds no business logic and never decides
/// what an action does — callers pass [onPressed].
class PrimaryActionButton extends StatefulWidget {
  const PrimaryActionButton({
    super.key,
    required this.label,
    required this.color,
    required this.onPressed,
    this.leading,
    this.trailingChevron = false,
    this.expand = true,
    this.fontSize = 22,
    this.borderRadius = AppRadii.pill,
    this.pulse = false,
  });

  /// Button text, e.g. "Comenzar", "Nueva misión", "Ya lo recogí".
  final String label;

  /// Pill fill color — use a token (missionYellow for the main CTA,
  /// progressGreen to confirm/finish, primaryBlue for neutral actions).
  final Color color;

  final VoidCallback onPressed;

  /// Optional leading widget (a playful icon or a circled [Icon]). Kept as a
  /// free-form [Widget] so the component never has to depend on a specific
  /// icon family.
  final Widget? leading;

  /// Shows a soft chevron on the trailing edge (splash / home "forward" CTAs).
  final bool trailingChevron;

  /// Stretch to fill the available width. When false the pill hugs its
  /// content (used inside the completion celebration).
  final bool expand;

  final double fontSize;
  final double borderRadius;

  /// Gently breathes (scale 1.0 ↔ 1.04) to pull the child's eye to the one
  /// action that matters. Disabled automatically when the platform requests
  /// reduced motion. Use it only on the *primary* CTA of a screen.
  final bool pulse;

  @override
  State<PrimaryActionButton> createState() => _PrimaryActionButtonState();
}

class _PrimaryActionButtonState extends State<PrimaryActionButton>
    with SingleTickerProviderStateMixin {
  static const double _depthOffset = 5;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  late final Animation<double> _scale = Tween<double>(begin: 1.0, end: 1.04)
      .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  bool _isPressed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(PrimaryActionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pulse != widget.pulse) _syncAnimation();
  }

  /// The pulse runs only when both the caller asks for it AND the platform
  /// is not in reduced-motion mode — an accessibility safeguard.
  void _syncAnimation() {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (widget.pulse && !reduceMotion) {
      if (!_controller.isAnimating) _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pill = _buildPill();
    final sized =
        widget.expand ? SizedBox(width: double.infinity, child: pill) : pill;

    if (!widget.pulse) return sized;
    return ScaleTransition(scale: _scale, child: sized);
  }

  Widget _buildPill() {
    final radius = BorderRadius.circular(widget.borderRadius);
    final topColor = _lighten(widget.color, 0.18);
    final bottomColor = _darken(widget.color, 0.10);
    final baseColor = _darken(widget.color, 0.28);

    return AnimatedContainer(
      duration: AppDurations.fast,
      curve: Curves.easeOut,
      margin: EdgeInsets.only(
        top: _isPressed ? _depthOffset : 0,
        bottom: _isPressed ? 0 : _depthOffset,
      ),
      decoration: BoxDecoration(
        borderRadius: radius,
        color: _isPressed ? baseColor : widget.color,
        boxShadow: _isPressed
            ? const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ]
            : AppShadows.floatingBubble,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: widget.onPressed,
          onHighlightChanged: (pressed) {
            if (_isPressed == pressed) return;
            setState(() => _isPressed = pressed);
          },
          borderRadius: radius,
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [topColor, widget.color, bottomColor],
                stops: const [0.0, 0.55, 1.0],
              ),
              borderRadius: radius,
              border: Border.all(color: Colors.white.withOpacity(0.45), width: 2),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.lg,
              ),
              child: Row(
                mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.leading != null) ...[
                    widget.leading!,
                    const SizedBox(width: AppSpacing.md),
                  ],
                  Flexible(
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: widget.fontSize,
                        fontWeight: FontWeight.w900,
                        shadows: const [
                          Shadow(
                            color: Color(0x40000000),
                            offset: Offset(0, 1),
                            blurRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (widget.trailingChevron) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white,
                      size: widget.fontSize + 4,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
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
