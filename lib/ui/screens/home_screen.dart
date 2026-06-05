import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../business/app_audio_service.dart';
import '../../storage/mission_history_repository.dart';
import '../app_assets.dart';
import '../components/app_image.dart';
import '../components/app_playful_icon.dart';
import '../components/home_action_tile.dart';
import '../components/robot_welcome.dart';
import '../components/sound_toggle_button.dart';
import '../navigation/app_bottom_navigation.dart';
import '../navigation/app_shell.dart';
import '../panels/daily_mission_card.dart';
import '../panels/mission_calendar_card.dart';
import '../screens/mission_intro_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Home tab. A structured kids' home: a greeting header with the day's
/// status, Tobi welcoming the child with a typewriter speech bubble, the
/// central "Misión del día" card, the two big side-by-side actions
/// ("Nueva misión" / "Ver progreso"), and the weekly calendar.
///
/// The layout fits without scrolling on normal phones (fit-or-scroll: a
/// `ConstrainedBox(minHeight: viewport)` lets the content settle to its
/// natural height and only scrolls on very small screens).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(missionHistoryProvider); // rebuild when history changes
    final repo = ref.read(missionHistoryProvider.notifier);
    final now = DateTime.now();

    return Stack(
      children: [
        // Real playroom background fills the whole page behind the content;
        // cards sit on top so the page still reads cleanly.
        const Positioned.fill(
          child: AppImage(
            assetPath: AppAssets.homeBackground,
            fallbackIcon: Icons.blur_on,
            fallbackColor: Colors.transparent,
            fit: BoxFit.cover,
          ),
        ),
        SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight:
                        constraints.maxHeight - AppSpacing.md - AppSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _TopBar(stars: repo.totalStars),
                      const SizedBox(height: AppSpacing.sm),
                      RobotWelcome(
                        message: '¡Hola! ¿Recogemos los juguetes? '
                            'Toca «Nueva misión».',
                        robotSize: 62,
                        dense: true,
                        showSpeaker: false,
                        messageStyle: AppTypography.coachMessage.copyWith(
                          fontSize: 13.5,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      DailyMissionCard(
                        collectedToday: repo.collectedToday(now),
                        goal: kDailyToyGoal,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: HomeActionTile(
                                label: 'Nueva misión',
                                icon: Icons.rocket_launch_rounded,
                                accent: AppColors.missionYellow,
                                onPressed: () {
                                  ref
                                      .read(appAudioServiceProvider)
                                      .playPrimaryAction();
                                  _openMissionIntro(context);
                                },
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: HomeActionTile(
                                label: 'Ver progreso',
                                icon: Icons.emoji_events_rounded,
                                accent: AppColors.progressGreen,
                                onPressed: () {
                                  ref
                                      .read(appAudioServiceProvider)
                                      .playButtonTap();
                                  ref.read(appTabProvider.notifier).state =
                                      AppTab.progress;
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      MissionCalendarCard(
                        days: _buildWeek(repo, now),
                        onSeeMore: () => ref
                            .read(appTabProvider.notifier)
                            .state = AppTab.progress,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// "Nueva misión" opens the pre-camera intro step. The camera only
  /// mounts once the child confirms there ("¡Vamos!"), keeping the active
  /// flow separate from this Home screen.
  void _openMissionIntro(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const MissionIntroScreen(),
      ),
    );
  }

  List<CalendarDay> _buildWeek(
    InMemoryMissionHistoryRepository repo,
    DateTime now,
  ) {
    // Monday-based week containing today.
    final monday = now.subtract(Duration(days: now.weekday - 1));
    const labels = ['LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB', 'DOM'];
    return List.generate(7, (i) {
      final day = DateTime(monday.year, monday.month, monday.day + i);
      final isToday =
          day.year == now.year && day.month == now.month && day.day == now.day;
      final status = repo.hasCompletedOn(day)
          ? CalendarDayStatus.completed
          : (repo.hasAnyOn(day)
              ? CalendarDayStatus.partial
              : CalendarDayStatus.none);
      return CalendarDay(
        weekdayLabel: labels[i],
        dayNumber: day.day,
        status: status,
        isToday: isToday,
        isWeekend: i >= 5,
      );
    });
  }
}

/// Greeting + day status on the left, sound toggle + avatar on the right.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.stars});

  final int stars;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '¡Hola, explorador!',
                style: AppTypography.missionTitle.copyWith(
                  fontSize: 22,
                  color: AppColors.textBlueDark,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              _DayStatusPill(stars: stars),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        const SoundToggleButton(),
        const SizedBox(width: AppSpacing.sm),
        Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            color: AppColors.cardWhite,
            shape: BoxShape.circle,
            boxShadow: AppShadows.card,
          ),
          clipBehavior: Clip.antiAlias,
          child: const Center(
            child: AppPlayfulIcon(
              symbol: AppPlayfulIconSymbol.childAvatar,
              size: 34,
              color: AppColors.primaryBlue,
            ),
          ),
        ),
      ],
    );
  }
}

/// Small pill that doubles as the day status: a star + the running total, so
/// the child sees their reward at a glance.
class _DayStatusPill extends StatelessWidget {
  const _DayStatusPill({required this.stars});

  final int stars;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardWhite.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.star_rounded,
            color: AppColors.missionYellow,
            size: 18,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '$stars estrellas · ¡a jugar!',
            style: AppTypography.coachName.copyWith(
              color: AppColors.textBlueDark,
              fontSize: 13,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}
