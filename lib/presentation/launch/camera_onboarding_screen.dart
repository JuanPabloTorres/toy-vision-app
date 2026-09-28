import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../app/app_router.dart';
import '../../application/launch/launch_controller.dart';
import '../../ui/app_assets.dart';
import '../../ui/components/app_image.dart';
import '../../ui/components/primary_action_button.dart';
import '../../ui/components/toy_surface.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';
import '../widgets/tobi_3d_stage.dart';

class CameraOnboardingScreen extends ConsumerStatefulWidget {
  const CameraOnboardingScreen({super.key});

  @override
  ConsumerState<CameraOnboardingScreen> createState() =>
      _CameraOnboardingScreenState();
}

class _CameraOnboardingScreenState
    extends ConsumerState<CameraOnboardingScreen> {
  bool _requesting = false;

  Future<void> _requestCamera() async {
    if (_requesting) return;
    setState(() => _requesting = true);
    await Permission.camera.request();
    await _finish();
  }

  Future<void> _finish() async {
    await ref.read(launchControllerProvider.notifier).completeOnboarding();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.home,
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: ToyBackground(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  children: [
                    const ToyWordmark(fontSize: 30),
                    const SizedBox(height: AppSpacing.lg),
                    const ToyPageHero(
                      mascot: Tobi3dStage(
                        enable3d: false,
                        fallbackSize: 110,
                      ),
                      message:
                          '¡Hola! Soy Tobi.\nNecesito ver el cuarto para ayudarte.',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const _OnboardingSteps(),
                    const SizedBox(height: AppSpacing.lg),
                    const ToyCard(
                      borderColor: AppColors.overlayCyan,
                      child: Row(
                        children: [
                          AppImage(
                            assetPath: AppAssets.privacyIcon,
                            fallbackIcon: Icons.privacy_tip_rounded,
                            size: 42,
                          ),
                          SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              'Las imágenes se procesan en este dispositivo. No se envían ni se guardan.',
                              style: AppTypography.body,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    PrimaryActionButton(
                      key: const Key('allow-camera'),
                      label: _requesting ? 'ABRIENDO…' : 'USAR LA CÁMARA',
                      color: AppColors.actionGreen,
                      leading: const Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.white,
                      ),
                      onPressed: _requestCamera,
                    ),
                    TextButton(
                      key: const Key('skip-camera'),
                      onPressed: _finish,
                      child: const Text('Ahora no'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

class _OnboardingSteps extends StatelessWidget {
  const _OnboardingSteps();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          const steps = [
            _OnboardingStep(
              icon: Icons.camera_alt_rounded,
              assetPath: AppAssets.cameraIcon,
              title: 'Mira',
            ),
            _OnboardingStep(
              icon: Icons.search_rounded,
              assetPath: AppAssets.searchIcon,
              title: 'Encuentra',
            ),
            _OnboardingStep(
              icon: Icons.inventory_2_rounded,
              assetPath: AppAssets.collectedIcon,
              title: 'Recoge',
            ),
          ];
          if (constraints.maxWidth < 300) {
            return Column(
              children: [
                for (final step in steps) ...[
                  step,
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < steps.length; index++) ...[
                Expanded(child: steps[index]),
                if (index < steps.length - 1)
                  const SizedBox(width: AppSpacing.sm),
              ],
            ],
          );
        },
      );
}

class _OnboardingStep extends StatelessWidget {
  const _OnboardingStep({
    required this.icon,
    required this.assetPath,
    required this.title,
  });

  final IconData icon;
  final String assetPath;
  final String title;

  @override
  Widget build(BuildContext context) => ToyCard(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Column(
          children: [
            AppImage(
              assetPath: assetPath,
              fallbackIcon: icon,
              fallbackColor: AppColors.primaryBlue,
              size: 48,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(title, style: AppTypography.bodyStrong),
          ],
        ),
      );
}
