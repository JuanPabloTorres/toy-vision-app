import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_router.dart';
import '../../application/launch/launch_controller.dart';
import '../../ui/app_assets.dart';
import '../../ui/components/app_image.dart';
import '../../ui/components/toy_surface.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';
import '../widgets/tobi_3d_stage.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 1400), _continue);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _continue() {
    if (!mounted) return;
    final onboarded = ref.read(launchControllerProvider);
    Navigator.of(context).pushReplacementNamed(
      onboarded ? AppRoutes.home : AppRoutes.onboarding,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: ToyBackground(
          asset: AppAssets.homeBackground,
          overlay: const Color(0x8AFFFFFF),
          safeArea: false,
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - AppSpacing.xl * 2,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const ToyWordmark(fontSize: 40),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'Haz que recoger sea una aventura',
                            textAlign: TextAlign.center,
                            style: AppTypography.bodyStrong.copyWith(
                              color: AppColors.primaryBlue,
                              fontSize: 17,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          const ToyCard(
                            padding: EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                              vertical: AppSpacing.md,
                            ),
                            borderColor: AppColors.overlayCyan,
                            child: SizedBox(
                              height: 230,
                              width: 270,
                              child: Tobi3dStage(
                                enable3d: false,
                                fallbackSize: 210,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          const CircularProgressIndicator(strokeWidth: 4),
                          const SizedBox(height: AppSpacing.md),
                          const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AppImage(
                                assetPath: AppAssets.privacyIcon,
                                fallbackIcon: Icons.privacy_tip_rounded,
                                size: 28,
                              ),
                              SizedBox(width: AppSpacing.sm),
                              Flexible(
                                child: Text(
                                  'Visión privada · En tu dispositivo',
                                  textAlign: TextAlign.center,
                                  style: AppTypography.caption,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
