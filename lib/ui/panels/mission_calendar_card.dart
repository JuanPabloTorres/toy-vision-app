import 'package:flutter/material.dart';

import '../components/app_playful_icon.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Per-day status used by the calendar strip.
enum CalendarDayStatus {
  /// A mission was completed this day → green check.
  completed,

  /// A mission ran but wasn't fully completed → yellow star.
  partial,

  /// No activity → empty ring.
  none,
}

/// One day's data for the calendar strip.
class CalendarDay {
  const CalendarDay({
    required this.weekdayLabel,
    required this.dayNumber,
    required this.status,
    this.isToday = false,
    this.isWeekend = false,
  });

  final String weekdayLabel; // "LUN", "MAR", …
  final int dayNumber;
  final CalendarDayStatus status;
  final bool isToday;
  final bool isWeekend;
}

/// "Calendario" card on Home: a 7-day strip with a check / star / empty
/// ring per day, mirroring the concept art.
class MissionCalendarCard extends StatelessWidget {
  const MissionCalendarCard({
    super.key,
    required this.days,
    this.onSeeMore,
  });

  final List<CalendarDay> days;
  final VoidCallback? onSeeMore;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: const AppPlayfulIcon(
                  symbol: AppPlayfulIconSymbol.calendar,
                  color: AppColors.primaryBlue,
                  size: 18,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Expanded(
                child: Text('Calendario', style: AppTypography.missionTitle),
              ),
              if (onSeeMore != null)
                TextButton(
                  onPressed: onSeeMore,
                  child: Text(
                    'Ver más',
                    style: AppTypography.coachName.copyWith(fontSize: 14),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [for (final d in days) _DayColumn(day: d)],
          ),
        ],
      ),
    );
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({required this.day});

  final CalendarDay day;

  @override
  Widget build(BuildContext context) {
    final labelColor = day.isWeekend && day.weekdayLabel == 'DOM'
        ? AppColors.gameOrange
        : AppColors.textSecondary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          day.weekdayLabel,
          style: TextStyle(
            color: labelColor,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${day.dayNumber}',
          style: TextStyle(
            color: AppColors.textBlueDark,
            fontSize: 14,
            fontWeight: day.isToday ? FontWeight.w900 : FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        _StatusMark(status: day.status, isToday: day.isToday),
      ],
    );
  }
}

class _StatusMark extends StatelessWidget {
  const _StatusMark({required this.status, required this.isToday});

  final CalendarDayStatus status;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case CalendarDayStatus.completed:
        return _circle(
          color: AppColors.progressGreen,
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
        );
      case CalendarDayStatus.partial:
        return _circle(
          color: AppColors.missionYellow,
          child: const Icon(Icons.star_rounded, color: Colors.white, size: 18),
        );
      case CalendarDayStatus.none:
        return Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isToday
                  ? AppColors.primaryBlue
                  : AppColors.textSecondary.withValues(alpha: 0.4),
              width: 2,
            ),
          ),
        );
    }
  }

  Widget _circle({required Color color, required Widget child}) => Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: child,
      );
}
