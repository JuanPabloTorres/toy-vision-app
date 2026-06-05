import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../business/app_audio_service.dart';
import '../../business/mission/mission_goal.dart';
import '../../camera/controllers/toy_cleanup_controller.dart';
import '../app_assets.dart';
import '../components/app_back_button.dart';
import '../components/app_image.dart';
import '../components/app_playful_icon.dart';
import '../components/challenge_card.dart';
import '../components/primary_action_button.dart';
import '../components/robot_welcome.dart';
import '../navigation/app_bottom_navigation.dart';
import '../navigation/app_shell.dart';
import '../theme/app_colors.dart';
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
                    child: AppBackButton(
                      onPressed: () {
                        ref.read(appAudioServiceProvider).playButtonTap();
                        Navigator.of(context).maybePop();
                      },
                    ),
                  ),
                  // Content centers when it fits (normal phones, no scroll) and
                  // only scrolls on very small screens; the CTA stays pinned.
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            const SizedBox(height: AppSpacing.md),
                            const Text(
                              '¡Preparados para la misión!',
                              textAlign: TextAlign.center,
                              style: AppTypography.celebrationHeadline,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            // Tobi speaks in his dialog bubble (mascot + bob
                            // animation + speech bubble) like every other
                            // surface — only the words change here.
                            RobotWelcome(
                              message: ref
                                  .watch(selectedMissionGoalProvider)
                                  .startMessage,
                              showSpeaker: false,
                              robotSize: 88,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            const Text(
                              'Elige tu reto',
                              style: AppTypography.missionTitle,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            for (final goal in MissionGoal.all) ...[
                              ChallengeCard(
                                title: goal.title,
                                subtitle: goal.startMessage,
                                badge: goal.targetPickupGoal == null
                                    ? '∞'
                                    : '${goal.targetPickupGoal}',
                                selected: ref
                                        .watch(selectedMissionGoalProvider)
                                        .challenge ==
                                    goal.challenge,
                                onTap: () {
                                  ref
                                      .read(appAudioServiceProvider)
                                      .playButtonTap();
                                  ref
                                      .read(selectedMissionGoalProvider.notifier)
                                      .state = goal;
                                },
                              ),
                              const SizedBox(height: AppSpacing.sm),
                            ],
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
    // Fun "let's go" sound, then move to the Mission tab and start the chosen
    // challenge.
    final goal = ref.read(selectedMissionGoalProvider);
    ref.read(appAudioServiceProvider).playPrimaryAction();
    ref.read(appTabProvider.notifier).state = AppTab.mission;
    ref.read(toyCleanupControllerProvider.notifier).startMission(goal: goal);
    Navigator.of(context).pop();
  }
}

/// The challenge the child picked on the intro screen. Resets to the default
/// (normal / 5) each time it is read fresh; the card taps update it.
final selectedMissionGoalProvider =
    StateProvider<MissionGoal>((ref) => MissionGoal.defaultGoal);

/// (The selectable challenge card now lives in the reusable
/// [ChallengeCard] component, and the back control in [AppBackButton].)
