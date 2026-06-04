import 'package:flutter/material.dart';

/// Reveals [text] one character at a time, like a friendly robot speaking.
///
/// Presentation only. Two safeguards keep it robust:
///   - it reserves the full text's size up front (an invisible sizer), so the
///     surrounding bubble never resizes/jumps as characters appear;
///   - it honours reduced-motion — when the platform disables animations
///     (also how widget tests run) the full text shows instantly, so
///     `find.text(...)` and accessibility both keep working.
class TypewriterText extends StatefulWidget {
  const TypewriterText({
    super.key,
    required this.text,
    this.style,
    this.textAlign = TextAlign.start,
    this.perCharacter = const Duration(milliseconds: 45),
    this.loop = false,
    this.holdAfter = const Duration(milliseconds: 2400),
  });

  final String text;
  final TextStyle? style;
  final TextAlign textAlign;

  /// Delay between revealed characters. Total run = [perCharacter] × length.
  final Duration perCharacter;

  /// When true, Tobi keeps "talking": after the full line shows it holds for
  /// [holdAfter] then retypes, forever. Used on the splash/start screen.
  final bool loop;

  /// How long the full line stays before a looping retype.
  final Duration holdAfter;

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _start();
  }

  @override
  void didUpdateWidget(TypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) _start();
  }

  void _start() {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _controller.stop();
    if (reduceMotion || widget.text.isEmpty) {
      _controller.value = 1.0; // show everything at once
      return;
    }
    final typing = widget.perCharacter * widget.text.length;
    if (widget.loop) {
      // One cycle = type the whole line, then hold it before retyping.
      _controller.duration = typing + widget.holdAfter;
      _controller.repeat();
    } else {
      _controller.duration = typing;
      _controller.forward(from: 0);
    }
  }

  /// Characters to show for the current controller value. In loop mode the
  /// line types out over the "typing" slice and then sits full during the
  /// trailing hold slice.
  int _visibleCount() {
    final len = widget.text.length;
    final duration = _controller.duration;
    if (!widget.loop || duration == null || duration.inMilliseconds == 0) {
      return (len * _controller.value).round().clamp(0, len);
    }
    final typingMs = widget.perCharacter.inMilliseconds * len;
    final elapsedMs = _controller.value * duration.inMilliseconds;
    final frac = typingMs == 0 ? 1.0 : (elapsedMs / typingMs).clamp(0.0, 1.0);
    return (len * frac).round().clamp(0, len);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The invisible full-text sizer fixes the box size; the animated partial
    // text overlays it and wraps identically (same loose constraints).
    return Stack(
      children: [
        Opacity(
          opacity: 0,
          child: Text(
            widget.text,
            style: widget.style,
            textAlign: widget.textAlign,
          ),
        ),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Text(
              widget.text.substring(0, _visibleCount()),
              style: widget.style,
              textAlign: widget.textAlign,
            );
          },
        ),
      ],
    );
  }
}
