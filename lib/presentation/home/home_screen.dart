import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_router.dart';
import '../../application/cleanup/cleanup_controller.dart';
import '../../application/feedback/audio_feedback_service.dart';
import '../../application/home/home_progress.dart';
import '../../infrastructure/feedback/cleanup_feedback_coordinator.dart';
import '../../ui/app_assets.dart';
import '../../ui/components/app_image.dart';
import '../../ui/components/toy_surface.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_radii.dart';
import '../../ui/theme/app_shadows.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';
import '../navigation/toy_app_shell.dart';
import '../widgets/tobi_3d_stage.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(homeProgressProvider);
    return ToyAppShell(
      section: ToyAppSection.home,
      maxContentWidth: 560,
      header: _HomeStatusBar(progress: progress),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MissionHeader(progress: progress),
          const SizedBox(height: AppSpacing.md),
          _AdventurePath(
            onStart: () => _startCleanup(context, ref),
          ),
        ],
      ),
    );
  }

  void _startCleanup(BuildContext context, WidgetRef ref) {
    ref.read(cleanupFeedbackCoordinatorProvider);
    unawaited(
      ref.read(audioFeedbackServiceProvider).play(
            AudioCue.gameReady,
            enabledChannels: ref.read(enabledAudioChannelsProvider),
          ),
    );
    ref.read(cleanupControllerProvider.notifier).start();
    Navigator.of(context).pushNamed(AppRoutes.cleanup);
  }
}

class _HomeStatusBar extends StatelessWidget {
  const _HomeStatusBar({required this.progress});

  final AsyncValue<HomeProgress> progress;

  @override
  Widget build(BuildContext context) {
    final value = progress.valueOrNull;
    return Row(
      children: [
        const Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: ToyWordmark(fontSize: 23, centered: false),
            ),
          ),
        ),
        _StatusPill(
          semanticsLabel: '${value?.currentStreak ?? 0} días de racha',
          assetPath: AppAssets.streakIcon,
          icon: Icons.local_fire_department_rounded,
          value: '${value?.currentStreak ?? 0}',
          color: AppColors.celebrationOrange,
        ),
        const SizedBox(width: AppSpacing.sm),
        _StatusPill(
          semanticsLabel: '${value?.totalStars ?? 0} estrellas',
          assetPath: AppAssets.starIcon,
          icon: Icons.star_rounded,
          value: '${value?.totalStars ?? 0}',
          color: AppColors.missionYellow,
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.semanticsLabel,
    required this.icon,
    required this.value,
    required this.color,
    this.assetPath,
  });

  final String semanticsLabel;
  final IconData icon;
  final String value;
  final Color color;
  final String? assetPath;

  @override
  Widget build(BuildContext context) => Semantics(
        label: semanticsLabel,
        child: Container(
          constraints: const BoxConstraints(minWidth: 58, minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(color: color.withValues(alpha: 0.24), width: 2),
            boxShadow: AppShadows.card,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (assetPath == null)
                Icon(icon, color: color, size: 25)
              else
                AppImage(
                  assetPath: assetPath!,
                  fallbackIcon: icon,
                  fallbackColor: color,
                  size: 27,
                ),
              const SizedBox(width: AppSpacing.xs),
              Text(value, style: AppTypography.bodyStrong),
            ],
          ),
        ),
      );
}

class _MissionHeader extends StatelessWidget {
  const _MissionHeader({required this.progress});

  final AsyncValue<HomeProgress> progress;

  @override
  Widget build(BuildContext context) {
    final value = progress.valueOrNull;
    final hasPlayed = (value?.completedSessions ?? 0) > 0;
    final lastCollected = value?.lastSession?.confirmedCollected;
    return Semantics(
      container: true,
      label: 'Tu aventura. Ruta al cuarto limpio.',
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primaryBlue, Color(0xFF42A5FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppRadii.xl),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x331479FF),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TU AVENTURA',
                    style: AppTypography.progressLabel.copyWith(
                      color: Colors.white.withValues(alpha: 0.86),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Ruta al cuarto limpio',
                    style: AppTypography.heading.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    hasPlayed && lastCollected != null
                        ? 'La última vez guardaste $lastCollected ${lastCollected == 1 ? 'cosa' : 'cosas'}. ¿Repetimos?'
                        : 'Sigue el camino con Tobi y pon cada juguete en su lugar.',
                    style: AppTypography.body.copyWith(
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Container(
              width: 66,
              height: 66,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadii.lg),
              ),
              child: const AppImage(
                assetPath: AppAssets.emptyRoomIcon,
                fallbackIcon: Icons.cleaning_services_rounded,
                fallbackColor: AppColors.overlayCyan,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdventurePath extends StatefulWidget {
  const _AdventurePath({required this.onStart});

  final VoidCallback onStart;

  @override
  State<_AdventurePath> createState() => _AdventurePathState();
}

class _AdventurePathState extends State<_AdventurePath>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  late final Animation<double> _scale = Tween<double>(
    begin: 1,
    end: 1.06,
  ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _pulse
        ..stop()
        ..value = 0;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        label: 'Ruta hacia un cuarto limpio y recogido',
        child: SizedBox(
          height: 1100,
          child: LayoutBuilder(
            builder: (context, constraints) => CustomPaint(
              painter: _AdventurePathPainter(),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    right: constraints.maxWidth * 0.02,
                    top: 18,
                    child: const _ToyScatter(),
                  ),
                  Positioned(
                    left: constraints.maxWidth * 0.03,
                    top: 24,
                    child: ScaleTransition(
                      scale: _scale,
                      child: _StartNode(onPressed: widget.onStart),
                    ),
                  ),
                  Positioned(
                    left: constraints.maxWidth * 0.01,
                    top: 338,
                    child: const _TobiGuide(),
                  ),
                  Positioned(
                    right: constraints.maxWidth * 0.02,
                    top: 350,
                    child: const _RouteStop(
                      number: '2',
                      title: 'Encuentra lo que hay que recoger',
                      subtitle: 'Mira con calma',
                      assetPath: AppAssets.searchIcon,
                      icon: Icons.search_rounded,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                  Positioned(
                    left: constraints.maxWidth * 0.03,
                    top: 610,
                    child: const _RouteStop(
                      number: '3',
                      title: 'Ponlos en su lugar',
                      subtitle: 'Uno por uno',
                      assetPath: AppAssets.collectedIcon,
                      icon: Icons.inventory_2_rounded,
                      color: AppColors.gamePurple,
                    ),
                  ),
                  Positioned(
                    right: constraints.maxWidth * 0.02,
                    top: 865,
                    child: const _RouteStop(
                      number: '4',
                      title: '¡Cuarto brillante!',
                      subtitle: 'Llegaste a la meta',
                      assetPath: AppAssets.emptyRoomIcon,
                      icon: Icons.cleaning_services_rounded,
                      color: AppColors.actionGreen,
                      finish: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _StartNode extends StatelessWidget {
  const _StartNode({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Empezar aventura. Explorar el cuarto.',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: const Key('start-cleanup'),
            onTap: onPressed,
            borderRadius: BorderRadius.circular(AppRadii.xl),
            child: SizedBox(
              width: 164,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.actionGreen,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x40119B38),
                          blurRadius: 12,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Text(
                      '¡EMPIEZA AQUÍ!',
                      style: AppTypography.progressLabel.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    width: 112,
                    height: 112,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [
                          AppColors.energyGreen,
                          AppColors.actionGreen,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      border: Border.all(color: Colors.white, width: 6),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0xFF119B38),
                          offset: Offset(0, 9),
                        ),
                        BoxShadow(
                          color: Color(0x5520C84B),
                          blurRadius: 22,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const AppImage(
                      assetPath: AppAssets.scanIcon,
                      fallbackIcon: Icons.center_focus_strong_rounded,
                      fallbackColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const _PathLabel(
                    number: '1',
                    title: 'Explora el cuarto',
                    subtitle: 'Toca para jugar',
                    active: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _ToyScatter extends StatelessWidget {
  const _ToyScatter();

  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 104,
        height: 100,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 8,
              child: AppImage(
                assetPath: AppAssets.ballIcon,
                fallbackIcon: Icons.sports_soccer_rounded,
                fallbackColor: AppColors.celebrationOrange,
                size: 42,
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              child: AppImage(
                assetPath: AppAssets.carIcon,
                fallbackIcon: Icons.toys_rounded,
                fallbackColor: AppColors.primaryBlue,
                size: 48,
              ),
            ),
            Positioned(
              left: 32,
              bottom: 0,
              child: AppImage(
                assetPath: AppAssets.blocksIcon,
                fallbackIcon: Icons.extension_rounded,
                fallbackColor: AppColors.gamePurple,
                size: 46,
              ),
            ),
          ],
        ),
      );
}

class _TobiGuide extends StatelessWidget {
  const _TobiGuide();

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 116,
        height: 174,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Positioned(
              top: 0,
              child: Container(
                width: 116,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  border: Border.all(color: AppColors.overlayCyan, width: 2),
                  boxShadow: AppShadows.card,
                ),
                child: const Text(
                  '¡Vamos paso a paso!',
                  textAlign: TextAlign.center,
                  style: AppTypography.caption,
                ),
              ),
            ),
            const Positioned(
              bottom: 0,
              child: SizedBox(
                width: 106,
                height: 106,
                child: Tobi3dStage(
                  enable3d: false,
                  fallbackSize: 100,
                ),
              ),
            ),
          ],
        ),
      );
}

class _RouteStop extends StatelessWidget {
  const _RouteStop({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.assetPath,
    required this.icon,
    required this.color,
    this.finish = false,
  });

  final String number;
  final String title;
  final String subtitle;
  final String assetPath;
  final IconData icon;
  final Color color;
  final bool finish;

  @override
  Widget build(BuildContext context) => Semantics(
        label: '$number. $title. $subtitle',
        child: ExcludeSemantics(
          child: SizedBox(
            width: 164,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PathNode(
                  icon: icon,
                  color: color,
                  assetPath: assetPath,
                  highlighted: finish,
                ),
                const SizedBox(height: AppSpacing.md),
                _PathLabel(
                  number: number,
                  title: title,
                  subtitle: subtitle,
                  active: finish,
                ),
              ],
            ),
          ),
        ),
      );
}

class _PathNode extends StatelessWidget {
  const _PathNode({
    required this.icon,
    required this.color,
    this.assetPath,
    this.highlighted = false,
  });

  final IconData icon;
  final Color color;
  final String? assetPath;
  final bool highlighted;

  @override
  Widget build(BuildContext context) => Container(
        width: highlighted ? 100 : 90,
        height: highlighted ? 100 : 90,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: highlighted
              ? const Color(0xFFF1FFF4)
              : Colors.white.withValues(alpha: 0.96),
          border: Border.all(
            color: color.withValues(alpha: highlighted ? 0.75 : 0.42),
            width: highlighted ? 5 : 4,
          ),
          boxShadow: highlighted
              ? const [
                  BoxShadow(
                    color: Color(0x5534C759),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ]
              : AppShadows.card,
        ),
        child: assetPath == null
            ? Icon(icon, color: color, size: 40)
            : AppImage(
                assetPath: assetPath!,
                fallbackIcon: icon,
                fallbackColor: color,
              ),
      );
}

class _PathLabel extends StatelessWidget {
  const _PathLabel({
    required this.number,
    required this.title,
    required this.subtitle,
    this.active = false,
  });

  final String number;
  final String title;
  final String subtitle;
  final bool active;

  @override
  Widget build(BuildContext context) => Container(
        width: 164,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFF1FFF4) : Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(
            color: active
                ? AppColors.actionGreen
                : AppColors.primaryBlue.withValues(alpha: 0.15),
            width: active ? 3 : 2,
          ),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active
                    ? AppColors.actionGreen
                    : AppColors.primaryBlue.withValues(alpha: 0.10),
              ),
              child: Text(
                number,
                style: AppTypography.bodyStrong.copyWith(
                  color: active ? Colors.white : AppColors.primaryBlue,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.bodyStrong,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    subtitle,
                    style: AppTypography.caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _AdventurePathPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final leftX = size.width * 0.03 + 82;
    final rightX = size.width * 0.98 - 82;
    final path = Path()
      ..moveTo(leftX, 124)
      ..cubicTo(
        leftX,
        210,
        rightX,
        285,
        rightX,
        395,
      )
      ..cubicTo(
        rightX,
        500,
        leftX,
        525,
        leftX,
        655,
      )
      ..cubicTo(
        leftX,
        780,
        rightX,
        790,
        rightX,
        915,
      );
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.92)
        ..strokeWidth = 22
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.primaryBlue.withValues(alpha: 0.22)
        ..strokeWidth = 8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
