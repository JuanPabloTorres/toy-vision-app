import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../business/progress/progress_stats_service.dart';
import '../../business/progress/progress_summary.dart';
import '../components/app_screen_header.dart';
import '../components/stat_tile.dart';
import '../panels/achievements_grid.dart';
import '../panels/progress_calendar_month.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'mission_history_detail_screen.dart';

/// "Ver progreso" destination — a read-only dashboard of streak, totals,
/// a month calendar, and achievements. It deliberately mounts **no
/// camera** and starts **no detection**: it is the historical-review flow,
/// fully separate from the active-mission flow.
class ProgressDashboardScreen extends ConsumerWidget {
  const ProgressDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(progressSummaryProvider);
    final now = DateTime.now();

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppScreenHeader(
              title: 'Mis estrellas',
              subtitle: '¡Mira todo lo que has logrado!',
              titleStyle: AppTypography.celebrationHeadline,
            ),
            const SizedBox(height: AppSpacing.lg),
            _StarsHero(stars: summary.totalStars),
            const SizedBox(height: AppSpacing.md),
            _StatChips(summary: summary),
            const SizedBox(height: AppSpacing.lg),
            ProgressCalendarMonth(
              month: now,
              today: now,
              daysByDate: summary.daysByDate,
              onTapDay: (day) => _openDay(context, day),
            ),
            const SizedBox(height: AppSpacing.lg),
            AchievementsGrid(achievements: summary.achievements),
          ],
        ),
      ),
    );
  }

  void _openDay(BuildContext context, DateTime day) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MissionHistoryDetailScreen(day: day),
      ),
    );
  }
}

/// The motivating focal point: one big, sunny card celebrating the stars
/// earned. Everything else on the screen is secondary to this number.
class _StarsHero extends StatelessWidget {
  const _StarsHero({required this.stars});

  final int stars;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.missionYellowLight, AppColors.missionYellow],
        ),
        borderRadius: BorderRadius.circular(AppRadii.xl),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.cardWhite,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.star_rounded,
              color: AppColors.missionYellow,
              size: 46,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$stars',
                  style: AppTypography.celebrationHeadline.copyWith(
                    fontSize: 44,
                    color: AppColors.textBlueDark,
                  ),
                ),
                Text(
                  stars == 0
                      ? '¡Tu primera estrella te espera!'
                      : 'estrellas ganadas',
                  style: AppTypography.missionTitle.copyWith(
                    fontSize: 16,
                    color: AppColors.textBlueDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The three smaller stats below the hero: streak, toys, missions.
class _StatChips extends StatelessWidget {
  const _StatChips({required this.summary});

  final ProgressSummary summary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: StatTile(
            icon: Icons.local_fire_department_rounded,
            color: AppColors.gameOrange,
            value: '${summary.currentStreakDays}',
            label: summary.currentStreakDays == 1 ? 'Día' : 'Días',
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: StatTile(
            icon: Icons.toys_rounded,
            color: AppColors.primaryBlue,
            value: '${summary.totalToysCollected}',
            label: 'Juguetes',
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: StatTile(
            icon: Icons.flag_rounded,
            color: AppColors.progressGreen,
            value: '${summary.totalMissionsCompleted}',
            label: 'Misiones',
          ),
        ),
      ],
    );
  }
}
