import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../business/app_audio_service.dart';
import '../../camera/screens/toy_cleanup_camera_screen.dart';
import '../screens/home_screen.dart';
import '../screens/parent_screen.dart';
import '../screens/progress_dashboard_screen.dart';
import 'app_bottom_navigation.dart';

/// Currently-selected bottom-nav tab. A plain StateProvider so any screen
/// (e.g. Home's "Nueva misión" button) can switch tabs.
final appTabProvider = StateProvider<AppTab>((ref) => AppTab.home);

/// Root scaffold that hosts the four tabs and the bottom navigation.
///
/// The Mission tab is built **lazily** — its `ToyCleanupCameraScreen`
/// (which owns the camera) only mounts while the Mission tab is selected,
/// so the camera is off on Home/History/Parents (battery + privacy).
///
/// Also owns the gentle Home background music lifecycle: it plays ONLY on
/// the Home tab and is stopped before any other tab (especially the camera),
/// per the product rule "no music during detection".
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  // Captured in initState so dispose() never touches `ref` (illegal after the
  // element is disposed — flutter_riverpod throws "Cannot use ref after the
  // widget was disposed").
  late final AppAudioService _audio;

  @override
  void initState() {
    super.initState();
    _audio = ref.read(appAudioServiceProvider);
    // Warm up players/decoders so the first tap and music start without lag.
    _audio.preload();
    // Restore the saved sound preference, then start Home music if we open
    // on Home and sound is on.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final muted = await _audio.loadMutedPreference();
      if (!mounted) return;
      ref.read(audioMutedProvider.notifier).state = muted;
      if (!muted && ref.read(appTabProvider) == AppTab.home) {
        _audio.playHomeMusic();
      }
    });
  }

  @override
  void dispose() {
    _audio.stopHomeMusic();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(appTabProvider);

    // Music by tab. Home → home theme. Mission → the mission screen swaps in
    // its own playground loop (a single play() call replaces the home track,
    // so the shell must NOT also stop here — two ops on one player race and
    // the stop kills the just-started mission music). Progress/Parents → quiet.
    ref.listen(appTabProvider, (prev, next) {
      switch (next) {
        case AppTab.home:
          _audio.playHomeMusic();
        case AppTab.mission:
          break; // mission screen owns its music
        case AppTab.progress:
        case AppTab.parents:
          _audio.stopHomeMusic();
      }
    });

    // Turning sound back ON while on Home resumes the music; muting stops it
    // (setMuted already does that). Keeps the SoundToggleButton generic.
    ref.listen(audioMutedProvider, (prev, muted) {
      if (!muted && ref.read(appTabProvider) == AppTab.home) {
        _audio.playHomeMusic();
      }
    });

    final body = switch (tab) {
      AppTab.home => const HomeScreen(),
      AppTab.mission => const ToyCleanupCameraScreen(),
      AppTab.progress => const ProgressDashboardScreen(),
      AppTab.parents => const ParentScreen(),
    };

    return Scaffold(
      body: body,
      bottomNavigationBar: AppBottomNavigation(
        current: tab,
        onSelect: (t) {
          _audio.playButtonTap();
          ref.read(appTabProvider.notifier).state = t;
        },
      ),
    );
  }
}
