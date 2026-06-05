import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../business/app_audio_service.dart';
import '../../business/data_reset_service.dart';
import '../../business/live_detection_state.dart';
import '../../business/progress/progress_stats_service.dart';
import '../../camera/controllers/toy_cleanup_controller.dart';
import '../../storage/active_mission_repository.dart';
import '../../storage/mission_history_repository.dart';
import '../components/sound_toggle_button.dart';
import '../theme/app_button_styles.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// App version + build, loaded once from the platform.
final packageInfoProvider = FutureProvider<PackageInfo>(
  (ref) => PackageInfo.fromPlatform(),
);

/// Parents tab. All the technical detail Mateo never sees lives here:
/// system/version, detector status, model, thresholds, mission + audio
/// state, privacy summary, and diagnostic controls.
class ParentScreen extends ConsumerWidget {
  const ParentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(toyCleanupControllerProvider);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        children: [
          const Text('Para padres', style: AppTypography.celebrationHeadline),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Información y ajustes de Toy Vision',
            style: AppTypography.parentLabel.copyWith(fontSize: 14),
          ),
          const SizedBox(height: AppSpacing.lg),
          _SystemSection(),
          const SizedBox(height: AppSpacing.lg),
          _ProgressSection(),
          const SizedBox(height: AppSpacing.lg),
          // Parent-friendly assurance — confirms the app works and is safe
          // WITHOUT exposing internal model/system details.
          _Section(
            title: 'Seguro y privado',
            icon: Icons.shield_rounded,
            children: [
              _StatusRow(status: state.status),
              const _Row('Cómo funciona', 'En el dispositivo, sin internet'),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _AudioSection(),
          const SizedBox(height: AppSpacing.lg),
          const _Section(
            title: 'Privacidad',
            icon: Icons.lock_rounded,
            children: [
              _Bullet('La inferencia ocurre 100% en el dispositivo.'),
              _Bullet('No se guardan fotos ni video.'),
              _Bullet('No se suben imágenes a ningún servidor.'),
              _Bullet('Sin analítica, sin reconocimiento facial.'),
              _Bullet('El historial guarda solo conteos y fechas.'),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _DataSection(),
        ],
      ),
    );
  }
}

/// Real progress stats for parents, sourced from the persisted mission
/// history (via [progressSummaryProvider]) — never mock or hard-coded.
class _ProgressSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(progressSummaryProvider);
    final history = ref.watch(missionHistoryProvider);
    final last = history.isEmpty ? null : history.first; // newest-first

    return _Section(
      title: 'Progreso',
      icon: Icons.insights_rounded,
      children: [
        _Row('Misiones completadas', '${summary.totalMissionsCompleted}'),
        _Row('Juguetes recogidos', '${summary.totalToysCollected}'),
        _Row(
          'Racha',
          summary.currentStreakDays == 1
              ? '1 día'
              : '${summary.currentStreakDays} días',
        ),
        _Row('Estrellas', '${summary.totalStars}'),
        _Row(
          'Última misión',
          last == null
              ? '—'
              : '${last.collectedToyCount} de ${last.initialToyCount} juguetes',
        ),
        _Row('Última actividad', last == null ? '—' : _formatDate(last.date)),
        // Trust signals for the LAST mission: did the robot visually confirm
        // the area was clean, and how independent was the run. This is what
        // tells a parent the task was really finished — not just tapped away.
        _Row(
          'Verificación visual',
          last == null
              ? '—'
              : (last.visuallyVerified ? 'Sí, área revisada' : 'Sin verificar'),
        ),
        _Row(
          'Recogida',
          last == null
              ? '—'
              : (last.usedManualHelp ? 'Con ayuda manual' : 'Automática'),
        ),
      ],
    );
  }
}

const _monthAbbr = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

String _formatDate(DateTime d) =>
    '${d.day} ${_monthAbbr[d.month - 1]} ${d.year}';

/// The data/reset controls: saved-mission count, an interrupted-mission
/// surface (debug only), and the two reset levels — all going through
/// [dataResetServiceProvider], never touching storage directly.
class _DataSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(missionHistoryProvider);
    final active = ref.watch(activeMissionProvider);

    return _Section(
      title: 'Datos',
      icon: Icons.storage_rounded,
      children: [
        _Row('Misiones guardadas', '${history.length}'),
        // Debug-only: surface a mission marker that was never closed (e.g. the
        // app was killed mid-mission) so it can be cleared manually instead of
        // lingering silently. It is NEVER auto-marked completed.
        if (kDebugMode && active != null) ...[
          const SizedBox(height: AppSpacing.sm),
          _Row('Misión sin cerrar', _formatDate(active.startedAt)),
          TextButton.icon(
            onPressed: () =>
                ref.read(activeMissionProvider.notifier).clear(),
            icon: const Icon(Icons.flag_circle_outlined, size: 18),
            label: const Text('Cerrar misión activa'),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: (history.isEmpty && active == null)
              ? null
              : () => _confirmResetProgress(context, ref),
          icon: const Icon(Icons.restart_alt_rounded),
          label: const Text('Reiniciar progreso'),
          style: AppButtonStyles.outlined(color: AppColors.gameOrange),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: () => _confirmResetAll(context, ref),
          icon: const Icon(Icons.delete_forever_rounded),
          label: const Text('Borrar todo'),
          style: AppButtonStyles.outlined(color: AppColors.stopRed),
        ),
      ],
    );
  }

  Future<void> _confirmResetProgress(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final ok = await _confirm(
      context,
      title: '¿Reiniciar progreso?',
      message: 'Se borrarán las misiones y el progreso del calendario. Se '
          'conservan los ajustes de sonido. Esta acción no se puede deshacer.',
    );
    if (ok) ref.read(dataResetServiceProvider).resetProgress();
  }

  Future<void> _confirmResetAll(BuildContext context, WidgetRef ref) async {
    final ok = await _confirm(
      context,
      title: '¿Borrar todo?',
      message: 'Se borrarán las misiones, el progreso y todos los ajustes, '
          'dejando la app como recién instalada. Esta acción no se puede '
          'deshacer.',
    );
    if (ok) ref.read(dataResetServiceProvider).resetAll();
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: AppButtonStyles.filled(background: AppColors.stopRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    return ok == true;
  }
}

/// App name + version + build, from package_info_plus (async).
class _SystemSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(packageInfoProvider);
    return _Section(
      title: 'Sistema',
      icon: Icons.info_outline_rounded,
      children: [
        const _Row('App', 'Toy Vision'),
        info.when(
          data: (i) => Column(
            children: [
              _Row('Versión', i.version),
              _Row('Build', i.buildNumber),
            ],
          ),
          loading: () => const _Row('Versión', 'cargando…'),
          error: (_, __) => const _Row('Versión', '—'),
        ),
      ],
    );
  }
}

/// Sound on/off + a quick "probar sonido" so a parent can confirm audio works.
class _AudioSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muted = ref.watch(audioMutedProvider);
    return _Section(
      title: 'Sonido',
      icon: Icons.music_note_rounded,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              muted ? 'Silencio' : 'Sonido activado',
              style: AppTypography.parentLabel,
            ),
            const SoundToggleButton(size: 24),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: () =>
              ref.read(appAudioServiceProvider).playButtonSuccess(),
          icon: const Icon(Icons.play_circle_outline_rounded),
          label: const Text('Probar sonido'),
          style: AppButtonStyles.outlined(color: AppColors.primaryBlue),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.children,
    this.icon,
  });

  final String title;
  final IconData? icon;
  final List<Widget> children;

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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: AppColors.primaryBlue, size: 20),
                const SizedBox(width: AppSpacing.sm),
              ],
              Text(title, style: AppTypography.missionTitle),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    );
  }
}

/// The detector "Estado" row, with a colored status pill instead of plain
/// text so a parent can read model health at a glance.
class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.status});

  final ModelStatus status;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Flexible(
            child: Text('Estado', style: AppTypography.parentLabel),
          ),
          const SizedBox(width: AppSpacing.md),
          _StatusPill(status: status),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final ModelStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      ModelStatus.initializing => ('Inicializando', AppColors.missionYellow),
      ModelStatus.ready => ('Listo', AppColors.progressGreen),
      ModelStatus.error => ('Error', AppColors.stopRed),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: AppTypography.parentValue.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(child: Text(label, style: AppTypography.parentLabel)),
          const SizedBox(width: AppSpacing.md),
          Text(value, style: AppTypography.parentValue),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: AppColors.progressGreen,
            size: 18,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: AppTypography.parentLabel)),
        ],
      ),
    );
  }
}
