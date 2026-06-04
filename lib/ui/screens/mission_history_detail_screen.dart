import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../storage/mission_history_repository.dart';
import '../app_assets.dart';
import '../components/app_image.dart';
import '../components/mission_history_tile.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Detail of a single calendar day: every mission that ran that day, plus
/// a small summary (toys collected, missions completed). Pushed from the
/// progress dashboard's calendar. Read-only — no camera, no detection.
class MissionHistoryDetailScreen extends ConsumerWidget {
  const MissionHistoryDetailScreen({super.key, required this.day});

  /// Any timestamp within the day to show; bucketed to midnight.
  final DateTime day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = DateTime(day.year, day.month, day.day);
    final records = ref
        .watch(missionHistoryProvider)
        .where((r) => r.day == target)
        .toList(growable: false);

    final toys = records.fold<int>(0, (s, r) => s + r.collectedToyCount);
    final completed = records.where((r) => r.completed).length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textBlueDark,
        title: Text(_formatDay(target), style: AppTypography.missionTitle),
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: AppImage(
              assetPath: AppAssets.missionBackground,
              fallbackIcon: Icons.blur_on,
              fallbackColor: Colors.transparent,
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DaySummary(toys: toys, completed: completed),
                  const SizedBox(height: AppSpacing.lg),
                  Expanded(
                    child: records.isEmpty
                        ? const _EmptyDay()
                        : ListView.separated(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.xl,
                            ),
                            itemCount: records.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: AppSpacing.sm),
                            itemBuilder: (_, i) =>
                                MissionHistoryTile(record: records[i]),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDay(DateTime d) {
    const months = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    return '${d.day} de ${months[d.month - 1]}';
  }
}

class _DaySummary extends StatelessWidget {
  const _DaySummary({required this.toys, required this.completed});

  final int toys;
  final int completed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Metric(
            icon: Icons.toys_rounded,
            color: AppColors.primaryBlue,
            value: '$toys',
            label: 'Juguetes',
          ),
          _Metric(
            icon: Icons.emoji_events_rounded,
            color: AppColors.progressGreen,
            value: '$completed',
            label: 'Completadas',
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          style: AppTypography.celebrationHeadline.copyWith(fontSize: 24),
        ),
        Text(label, style: AppTypography.parentLabel),
      ],
    );
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'No hubo misiones este día.',
        style: AppTypography.parentLabel,
      ),
    );
  }
}
