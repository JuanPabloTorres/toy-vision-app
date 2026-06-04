import 'package:flutter/material.dart';

import '../../business/progress/progress_summary.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Month calendar card for the progress dashboard. Each day cell shows the
/// day number tinted by status (green = a mission was completed, yellow =
/// a mission ran but wasn't completed, plain = nothing). Days with any
/// activity are tappable and call [onTapDay] so the parent can push the
/// day-detail screen.
class ProgressCalendarMonth extends StatelessWidget {
  const ProgressCalendarMonth({
    super.key,
    required this.month,
    required this.today,
    required this.daysByDate,
    required this.onTapDay,
  });

  /// Any day within the month to render.
  final DateTime month;
  final DateTime today;
  final Map<DateTime, DailyProgress> daysByDate;
  final ValueChanged<DateTime> onTapDay;

  static const _weekdayLabels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
  static const _monthNames = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // Monday-based offset of the 1st (Dart weekday: Mon=1 … Sun=7).
    final leadingBlanks = firstOfMonth.weekday - 1;

    final cells = <Widget>[
      for (var i = 0; i < leadingBlanks; i++) const SizedBox.shrink(),
      for (var day = 1; day <= daysInMonth; day++)
        _DayCell(
          date: DateTime(month.year, month.month, day),
          today: today,
          progress: daysByDate[DateTime(month.year, month.month, day)],
          onTapDay: onTapDay,
        ),
    ];

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
              const Icon(
                Icons.calendar_month_rounded,
                color: AppColors.primaryBlue,
                size: 22,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${_monthNames[month.month - 1]} ${month.year}',
                style: AppTypography.missionTitle,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              for (final label in _weekdayLabels)
                Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: AppTypography.parentLabel.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.xs,
            crossAxisSpacing: AppSpacing.xs,
            children: cells,
          ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.today,
    required this.progress,
    required this.onTapDay,
  });

  final DateTime date;
  final DateTime today;
  final DailyProgress? progress;
  final ValueChanged<DateTime> onTapDay;

  @override
  Widget build(BuildContext context) {
    final isToday = date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
    final hasActivity = progress != null;
    final completed = progress?.hasCompleted ?? false;

    final Color background;
    final Color textColor;
    if (completed) {
      background = AppColors.progressGreen;
      textColor = Colors.white;
    } else if (hasActivity) {
      background = AppColors.missionYellow;
      textColor = AppColors.textBlueDark;
    } else {
      background = Colors.transparent;
      textColor = AppColors.textBlueDark;
    }

    final cell = Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border:
            isToday ? Border.all(color: AppColors.primaryBlue, width: 2) : null,
      ),
      child: Text(
        '${date.day}',
        style: TextStyle(
          color: textColor,
          fontSize: 13,
          fontWeight: isToday ? FontWeight.w900 : FontWeight.w600,
        ),
      ),
    );

    if (!hasActivity) return cell;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTapDay(date),
      child: cell,
    );
  }
}
