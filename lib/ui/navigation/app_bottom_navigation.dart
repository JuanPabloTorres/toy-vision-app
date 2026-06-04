import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';

/// The four destinations of Toy Vision.
///
/// `progress` (the "Ver progreso" destination) replaced the old `history`
/// tab: it hosts the [ProgressDashboardScreen] — calendar, streak, totals,
/// achievements — and is fully separate from the camera/`mission` flow.
enum AppTab { home, mission, progress, parents }

/// Rounded, friendly bottom navigation matching the concept art. Large
/// touch targets, the active tab highlighted with a soft pill.
class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    super.key,
    required this.current,
    required this.onSelect,
  });

  final AppTab current;
  final ValueChanged<AppTab> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardWhite,
        boxShadow: AppShadows.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                tab: AppTab.home,
                icon: Icons.home_rounded,
                label: 'Inicio',
                current: current,
                onSelect: onSelect,
              ),
              _NavItem(
                tab: AppTab.mission,
                icon: Icons.rocket_launch_rounded,
                label: 'Misión',
                current: current,
                onSelect: onSelect,
              ),
              _NavItem(
                tab: AppTab.progress,
                icon: Icons.insights_rounded,
                label: 'Progreso',
                current: current,
                onSelect: onSelect,
              ),
              _NavItem(
                tab: AppTab.parents,
                icon: Icons.people_alt_rounded,
                label: 'Padres',
                current: current,
                onSelect: onSelect,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tab,
    required this.icon,
    required this.label,
    required this.current,
    required this.onSelect,
  });

  final AppTab tab;
  final IconData icon;
  final String label;
  final AppTab current;
  final ValueChanged<AppTab> onSelect;

  @override
  Widget build(BuildContext context) {
    final selected = tab == current;
    final color = selected ? AppColors.primaryBlue : AppColors.textSecondary;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onSelect(tab),
          borderRadius: BorderRadius.circular(AppRadii.lg),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.sm,
              horizontal: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primaryBlue.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadii.lg),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 26),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
