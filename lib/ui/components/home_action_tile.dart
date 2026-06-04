import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// A square-ish "big friendly" tile for Home's two primary actions
/// ("Nueva misión", "Ver progreso") shown side by side: a colored icon
/// circle over a bold label, with a soft press bounce and ripple.
///
/// Presentation only — it never decides what the action does. Equal width is
/// the caller's job (wrap each tile in [Expanded]); equal height comes from
/// wrapping the row in an [IntrinsicHeight].
class HomeActionTile extends StatefulWidget {
  const HomeActionTile({
    super.key,
    required this.label,
    required this.icon,
    required this.accent,
    required this.onPressed,
  });

  final String label;
  final IconData icon;

  /// Fill of the icon circle (the tile itself stays white for contrast).
  final Color accent;

  final VoidCallback onPressed;

  @override
  State<HomeActionTile> createState() => _HomeActionTileState();
}

class _HomeActionTileState extends State<HomeActionTile> {
  double _scale = 1;

  void _press(bool down) => setState(() => _scale = down ? 0.96 : 1);

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadii.xl);
    return GestureDetector(
      onTapDown: (_) => _press(true),
      onTapUp: (_) => _press(false),
      onTapCancel: () => _press(false),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: AppShadows.card,
          ),
          child: Material(
            color: AppColors.cardWhite,
            borderRadius: radius,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onPressed,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: widget.accent,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(widget.icon, color: Colors.white, size: 28),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      widget.label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: AppTypography.missionTitle.copyWith(
                        fontSize: 16,
                        color: AppColors.textBlueDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
