import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'tobi_mascot.dart';
import 'typewriter_text.dart';

/// Tobi greeting the child: the mascot beside a speech bubble whose [message]
/// types itself out, so the robot feels alive and "talking". Tobi also bobs
/// gently up and down so he reads as a friendly guide encouraging the child
/// to start — disabled automatically under reduced-motion.
///
/// Presentation only — the caller supplies the words. Reused on Home (and
/// available to any screen that wants a guided welcome), so it lives in
/// `components/` rather than being a private widget.
class RobotWelcome extends StatelessWidget {
  const RobotWelcome({
    super.key,
    required this.message,
    this.speaker = 'Tobi',
    this.robotSize = 92,
    this.showSpeaker = true,
    this.loopMessage = false,
    this.messageStyle,
    this.dense = false,
  });

  /// The line Tobi says (kept short and friendly for early readers).
  final String message;

  /// Small label above the message ("Tobi").
  final String speaker;

  final double robotSize;

  /// Show the "TOBI" label above the message. Hidden on compact surfaces.
  final bool showSpeaker;

  /// Keep retyping forever (continuous "talking") — splash/start screen.
  final bool loopMessage;

  /// Override the message text style (e.g. smaller on Home so the welcome
  /// takes less vertical space).
  final TextStyle? messageStyle;

  /// Tighter padding for compact placements (Home).
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        TobiMascot(size: robotSize),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: _SpeechBubble(
            speaker: speaker,
            message: message,
            showSpeaker: showSpeaker,
            loopMessage: loopMessage,
            messageStyle: messageStyle,
            dense: dense,
          ),
        ),
      ],
    );
  }
}

/// A rounded white bubble with a small tail pointing left toward the robot.
class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({
    required this.speaker,
    required this.message,
    required this.showSpeaker,
    required this.loopMessage,
    required this.messageStyle,
    required this.dense,
  });

  final String speaker;
  final String message;
  final bool showSpeaker;
  final bool loopMessage;
  final TextStyle? messageStyle;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // The little tail that visually connects the bubble to the robot.
        const CustomPaint(
          size: Size(10, 18),
          painter: _BubbleTailPainter(color: AppColors.cardWhite),
        ),
        Expanded(
          child: Container(
            padding: EdgeInsets.all(dense ? AppSpacing.sm : AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.cardWhite,
              borderRadius: BorderRadius.circular(AppRadii.lg),
              boxShadow: AppShadows.card,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showSpeaker) ...[
                  Text(speaker.toUpperCase(), style: AppTypography.coachName),
                  const SizedBox(height: AppSpacing.xs),
                ],
                TypewriterText(
                  text: message,
                  loop: loopMessage,
                  style: messageStyle ?? AppTypography.coachMessage,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  const _BubbleTailPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    // A small triangle whose point sits on the left edge (toward the robot)
    // and whose flat side merges into the bubble on the right.
    final path = Path()
      ..moveTo(size.width, size.height * 0.25)
      ..lineTo(0, size.height * 0.5)
      ..lineTo(size.width, size.height * 0.75)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_BubbleTailPainter oldDelegate) =>
      oldDelegate.color != color;
}
