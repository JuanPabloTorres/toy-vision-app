import 'package:flutter/material.dart';

import '../app_assets.dart';
import '../theme/app_radii.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import 'app_image.dart';

enum ToyButtonState { idle, loading, success, disabled }

/// The one canonical "big friendly pill" call-to-action for Mateo's flow.
///
/// Before this existed every screen (home, intro, mission-complete,
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
    this.state = ToyButtonState.idle,
    this.successLabel = '¡LISTO!',
  });

  /// Button text, e.g. "¡Jugar!", "Continuar", "Sí, terminamos".
  final String label;

  /// Pill fill color — use a token (missionYellow for the main CTA,
  /// progressGreen to confirm/finish, primaryBlue for neutral actions).
  final Color color;

  final VoidCallback onPressed;

  /// Optional leading widget (a playful icon or a circled [Icon]). Kept as a
  /// free-form [Widget] so the component never has to depend on a specific
  /// icon family.
  final Widget? leading;

  /// Shows a soft chevron on the trailing edge for forward CTAs.
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
  final ToyButtonState state;
  final String successLabel;

  @override
  State<PrimaryActionButton> createState() => _PrimaryActionButtonState();
}

class _PrimaryActionButtonState extends State<PrimaryActionButton>
    with TickerProviderStateMixin {
  static const double _depthOffset = 5;

  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  late final Animation<double> _pulseScale =
      Tween<double>(begin: 1.0, end: 1.04).animate(
    CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
  );
  late final AnimationController _tapController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  late final Animation<double> _tapScale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.96), weight: 35),
    TweenSequenceItem(tween: Tween(begin: 0.96, end: 1.03), weight: 35),
    TweenSequenceItem(tween: Tween(begin: 1.03, end: 1.0), weight: 30),
  ]).animate(CurvedAnimation(parent: _tapController, curve: Curves.easeOut));

  bool _isPressed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(PrimaryActionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pulse != widget.pulse || oldWidget.state != widget.state) {
      _syncAnimation();
    }
  }

  /// The pulse runs only when both the caller asks for it AND the platform
  /// is not in reduced-motion mode — an accessibility safeguard.
  void _syncAnimation() {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (widget.pulse && widget.state == ToyButtonState.idle && !reduceMotion) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      _pulseController.stop();
      _pulseController.value = 0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _tapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pill = AnimatedBuilder(
      animation: _tapScale,
      builder: (context, child) => Transform.scale(
        scale: _tapScale.value,
        child: child,
      ),
      child: _buildPill(),
    );
    final sized =
        widget.expand ? SizedBox(width: double.infinity, child: pill) : pill;
    final enabled = widget.state != ToyButtonState.loading &&
        widget.state != ToyButtonState.disabled;
    final presented = Semantics(
      button: true,
      enabled: enabled,
      label: widget.state == ToyButtonState.loading
          ? '${widget.label}, cargando'
          : widget.state == ToyButtonState.success
              ? widget.successLabel
              : widget.label,
      child: AnimatedOpacity(
        duration: AppDurations.fast,
        opacity: widget.state == ToyButtonState.disabled ? 0.48 : 1,
        child: sized,
      ),
    );

    if (!widget.pulse) return presented;
    return ScaleTransition(scale: _pulseScale, child: presented);
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
          onTap: widget.state == ToyButtonState.loading ||
                  widget.state == ToyButtonState.disabled
              ? null
              : _activate,
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
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.45),
                width: 2,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.lg,
              ),
              child: Row(
                mainAxisSize:
                    widget.expand ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_leading != null) ...[
                    _leading!,
                    const SizedBox(width: AppSpacing.md),
                  ],
                  Flexible(
                    child: Text(
                      widget.state == ToyButtonState.success
                          ? widget.successLabel
                          : widget.label,
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
                  if (widget.trailingChevron &&
                      widget.state == ToyButtonState.idle) ...[
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

  Widget? get _leading => switch (widget.state) {
        ToyButtonState.loading => const SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 3,
            ),
          ),
        ToyButtonState.success => const AppImage(
            assetPath: AppAssets.starIcon,
            fallbackIcon: Icons.star_rounded,
            fallbackColor: Colors.white,
            size: 28,
          ),
        ToyButtonState.idle || ToyButtonState.disabled => widget.leading,
      };

  void _activate() {
    if (!(MediaQuery.maybeOf(context)?.disableAnimations ?? false)) {
      _tapController.forward(from: 0);
    }
    widget.onPressed();
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
