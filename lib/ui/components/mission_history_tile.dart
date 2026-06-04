import 'package:flutter/material.dart';

import '../../storage/mission_record.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_playful_icon.dart';

/// One past mission as a card row: trophy/flag badge, date + summary, and
/// the stars earned. Shared by the day-detail screen (and any future
/// history list) so the visual stays single-sourced.
class MissionHistoryTile extends StatelessWidget {
  const MissionHistoryTile({super.key, required this.record});

  final MissionRecord record;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: (record.completed
                      ? AppColors.progressGreen
                      : AppColors.missionYellow)
                  .withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: AppPlayfulIcon(
              symbol: AppPlayfulIconSymbol.reward,
              size: 28,
              color: record.completed
                  ? AppColors.progressGreen
                  : AppColors.missionYellow,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(record.date),
                  style: AppTypography.missionTitle.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  '${record.collectedToyCount} de ${record.initialToyCount} '
                  'juguetes · ${record.completed ? "Completada" : "Incompleta"}',
                  style: AppTypography.parentLabel,
                ),
              ],
            ),
          ),
          _StarRow(count: record.starsEarned),
        ],
      ),
    );
  }

  static String _formatTime(DateTime d) {
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}

class _StarRow extends StatelessWidget {
  const _StarRow({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final filled = i < count;
        return Icon(
          filled ? Icons.star_rounded : Icons.star_outline_rounded,
          color: filled
              ? AppColors.missionYellow
              : AppColors.textSecondary.withValues(alpha: 0.4),
          size: 18,
        );
      }),
    );
  }
}
