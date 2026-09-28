import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/home/home_progress.dart';
import '../../ui/app_assets.dart';
import '../../ui/components/app_image.dart';
import '../../ui/components/toy_surface.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';
import '../navigation/toy_app_shell.dart';
import '../widgets/tobi_3d_stage.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(homeProgressProvider);
    return ToyAppShell(
      section: ToyAppSection.progress,
      title: 'Tu progreso',
      child: progress.when(
        loading: () => const ToyStateCard(
          icon: Icons.auto_awesome_rounded,
          assetPath: AppAssets.progressIcon,
          title: 'Preparando tu progreso',
          message: 'Estamos contando tus estrellas y aventuras.',
          action: CircularProgressIndicator(),
        ),
        error: (_, __) => const ToyStateCard(
          icon: Icons.cloud_off_rounded,
          assetPath: AppAssets.progressIcon,
          title: 'Tus estrellas están a salvo',
          message: 'No pude cargarlas ahora. Inténtalo de nuevo en un momento.',
        ),
        data: (value) => _ProgressContent(progress: value),
      ),
    );
  }
}

class _ProgressContent extends StatelessWidget {
  const _ProgressContent({required this.progress});

  final HomeProgress progress;

  @override
  Widget build(BuildContext context) {
    final lastCollected = progress.lastSession?.confirmedCollected ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ToyPageHero(
          mascot: Tobi3dStage(enable3d: false, fallbackSize: 96),
          message: '¡Cada juguete guardado hace brillar tu aventura!',
        ),
        const SizedBox(height: AppSpacing.lg),
        LayoutBuilder(
          builder: (context, constraints) {
            final cards = [
              _ProgressMetric(
                assetPath: AppAssets.starIcon,
                fallbackIcon: Icons.star_rounded,
                color: AppColors.missionYellow,
                value: '${progress.totalStars}',
                label: 'Estrellas',
              ),
              _ProgressMetric(
                assetPath: AppAssets.streakIcon,
                fallbackIcon: Icons.local_fire_department_rounded,
                color: AppColors.celebrationOrange,
                value: '${progress.currentStreak}',
                label: 'Días de racha',
              ),
              _ProgressMetric(
                assetPath: AppAssets.completedIcon,
                fallbackIcon: Icons.task_alt_rounded,
                color: AppColors.actionGreen,
                value: '${progress.completedSessions}',
                label: 'Habitaciones',
              ),
            ];
            if (constraints.maxWidth < 520) {
              return Column(
                children: [
                  for (final card in cards) ...[
                    card,
                    const SizedBox(height: AppSpacing.md),
                  ],
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < cards.length; index++) ...[
                  Expanded(child: cards[index]),
                  if (index != cards.length - 1)
                    const SizedBox(width: AppSpacing.md),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        ToyCard(
          borderColor: AppColors.overlayCyan,
          child: Row(
            children: [
              const AppImage(
                assetPath: AppAssets.collectedIcon,
                fallbackIcon: Icons.inventory_2_rounded,
                fallbackColor: AppColors.primaryBlue,
                size: 72,
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Última aventura',
                      style: AppTypography.cardTitle,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      progress.lastSession == null
                          ? 'Tu primera habitación te está esperando.'
                          : 'Guardaste $lastCollected ${lastCollected == 1 ? 'juguete' : 'juguetes'}.',
                      style: AppTypography.body,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProgressMetric extends StatelessWidget {
  const _ProgressMetric({
    required this.assetPath,
    required this.fallbackIcon,
    required this.color,
    required this.value,
    required this.label,
  });

  final String assetPath;
  final IconData fallbackIcon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => ToyCard(
        borderColor: color.withValues(alpha: 0.38),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppImage(
              assetPath: assetPath,
              fallbackIcon: fallbackIcon,
              fallbackColor: color,
              size: 58,
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: AppTypography.displayNumber),
                  Text(label, style: AppTypography.caption),
                ],
              ),
            ),
          ],
        ),
      );
}
