import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../business/app_audio_service.dart';
import '../../camera/controllers/toy_cleanup_controller.dart';
import '../app_assets.dart';
import '../components/app_image.dart';
import '../components/app_playful_icon.dart';
import '../components/primary_action_button.dart';
import '../components/robot_welcome.dart';
import '../navigation/app_bottom_navigation.dart';
import '../navigation/app_shell.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// "Prepara tu misión" — the pre-camera step reached from Home's "Nueva
/// misión". It feels like the start of an adventure: Tobi in a soft halo, a
/// short promise, three simple numbered steps, and one big "¡Vamos!" CTA.
/// The camera only mounts after the child taps "¡Vamos!".
class MissionIntroScreen extends ConsumerWidget {
  const MissionIntroScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
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
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _RoundButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: () {
                        ref.read(appAudioServiceProvider).playButtonTap();
                        Navigator.of(context).maybePop();
                      },
                    ),
                  ),
                  // Content centers when it fits (normal phones, no scroll) and
                  // only scrolls on very small screens; the CTA stays pinned.
                  const Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            SizedBox(height: AppSpacing.md),
                            Text(
                              '¡Preparados para la misión!',
                              textAlign: TextAlign.center,
                              style: AppTypography.celebrationHeadline,
                            ),
                            SizedBox(height: AppSpacing.lg),
                            // Tobi speaks in his dialog bubble (mascot + bob
                            // animation + speech bubble) like every other
                            // surface — only the words change here.
                            RobotWelcome(
                              message: 'Voy a ayudarte a encontrar juguetes.',
                              showSpeaker: false,
                              robotSize: 96,
                            ),
                            SizedBox(height: AppSpacing.lg),
                            _StepCard(
                              number: 1,
                              icon: Icons.photo_camera_rounded,
                              text: 'Apunta la cámara',
                            ),
                            SizedBox(height: AppSpacing.sm),
                            _StepCard(
                              number: 2,
                              icon: Icons.center_focus_strong_rounded,
                              text: 'Busca el juguete marcado',
                            ),
                            SizedBox(height: AppSpacing.sm),
                            _StepCard(
                              number: 3,
                              icon: Icons.check_circle_rounded,
                              text: 'Toca "Listo, ya lo guarde"',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PrimaryActionButton(
                    label: '¡Vamos!',
                    color: AppColors.missionYellow,
                    pulse: true,
                    leading: const AppPlayfulIcon(
                      symbol: AppPlayfulIconSymbol.missionStart,
                      size: 32,
                      color: Colors.white,
                    ),
                    onPressed: () => _begin(context, ref),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _begin(BuildContext context, WidgetRef ref) {
    // Fun "let's go" sound, then move to the Mission tab and start scanning.
    ref.read(appAudioServiceProvider).playPrimaryAction();
    ref.read(appTabProvider.notifier).state = AppTab.mission;
    ref.read(toyCleanupControllerProvider.notifier).startMission();
    Navigator.of(context).pop();
  }
}

/// A numbered step: badge + icon + short instruction, in a white card.
class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.number,
    required this.icon,
    required this.text,
  });

  final int number;
  final IconData icon;
  final String text;

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
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.missionYellow,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Icon(icon, color: AppColors.primaryBlue, size: 26),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: AppTypography.coachMessage.copyWith(
                color: AppColors.textBlueDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardWhite,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Icon(icon, color: AppColors.textBlueDark, size: 24),
        ),
      ),
    );
  }
}
