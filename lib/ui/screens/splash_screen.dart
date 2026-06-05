import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_router.dart';
import '../../business/app_audio_service.dart';
import '../app_assets.dart';
import '../components/app_image.dart';
import '../components/brand_wordmark.dart';
import '../components/primary_action_button.dart';
import '../components/robot_welcome.dart';
import '../navigation/app_bottom_navigation.dart';
import '../navigation/app_shell.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// First screen Mateo sees. Playful playground background, Tobi waving with a
/// speech bubble that keeps talking, the brand wordmark, a big "Comenzar"
/// button, and a quiet "Para padres" link. Navigates into the [AppShell].
///
/// It also starts the gentle background music on this very first screen (when
/// sound is on) so the app "begins with music" — the same shared player the
/// [AppShell] then takes over, so the track continues seamlessly into Home.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    final audio = ref.read(appAudioServiceProvider);
    audio.preload();
    // Start music once we know the saved sound preference. We do NOT stop it
    // on dispose — the AppShell owns the same player and keeps it going.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final muted = await audio.loadMutedPreference();
      if (!mounted) return;
      ref.read(audioMutedProvider.notifier).state = muted;
      if (!muted) audio.playHomeMusic();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _Background(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              children: [
                const Spacer(),
                const BrandWordmark(fontSize: 48),
                const SizedBox(height: AppSpacing.xl),
                // Tobi waving + a speech bubble that keeps "talking"
                // (continuous typewriter) — the lively welcome the child sees.
                const RobotWelcome(
                  message: '¡Hola! ¿Listo para recoger tus juguetes '
                      'y divertirnos?',
                  robotSize: 132,
                  showSpeaker: false,
                  loopMessage: true,
                ),
                const Spacer(),
                PrimaryActionButton(
                  label: 'Comenzar',
                  color: AppColors.missionYellow,
                  fontSize: 24,
                  trailingChevron: true,
                  pulse: true,
                  onPressed: () {
                    ref.read(appAudioServiceProvider).playPrimaryAction();
                    _goToShell(AppTab.home);
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                _ParentsLink(
                  onPressed: () {
                    ref.read(appAudioServiceProvider).playButtonTap();
                    _goToShell(AppTab.parents);
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _goToShell(AppTab tab) {
    ref.read(appTabProvider.notifier).state = tab;
    Navigator.of(context).pushReplacementNamed(AppRoutes.shell);
  }
}

class _Background extends StatelessWidget {
  const _Background({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.skyLight, AppColors.bgLight],
        ),
      ),
      child: _MaybeBackgroundImage(child: child),
    );
  }
}

/// Paints the playground background image when present; otherwise just
/// the gradient from [_Background].
class _MaybeBackgroundImage extends StatelessWidget {
  const _MaybeBackgroundImage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Real playroom background fills the screen; the gradient in
        // [_Background] shows through if the asset is ever missing.
        const AppImage(
          assetPath: AppAssets.splashBackground,
          fallbackIcon: Icons.blur_on,
          fallbackColor: Colors.transparent,
          fit: BoxFit.cover,
        ),
        child,
      ],
    );
  }
}

class _ParentsLink extends StatelessWidget {
  const _ParentsLink({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(
        Icons.people_alt_rounded,
        color: AppColors.primaryBlue,
        size: 20,
      ),
      label: Text(
        'Para padres',
        style: AppTypography.coachName.copyWith(
          fontSize: 15,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}
