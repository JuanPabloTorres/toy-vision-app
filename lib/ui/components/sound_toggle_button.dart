import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../business/app_audio_service.dart';
import '../theme/app_colors.dart';

/// The one canonical sound on/off control. Toggles [audioMutedProvider] and
/// the [AppAudioService]; gives a tiny tap cue when turning sound back on.
///
/// Pure UI — it does not decide what plays where. Resuming Home music when
/// sound returns is the AppShell's job (it listens to [audioMutedProvider]),
/// so this button is reusable on any screen (Home header, Parents settings).
class SoundToggleButton extends ConsumerWidget {
  const SoundToggleButton({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muted = ref.watch(audioMutedProvider);
    return Semantics(
      button: true,
      label: muted ? 'Activar sonido' : 'Silenciar',
      child: Material(
        color: AppColors.cardWhite,
        shape: const CircleBorder(),
        elevation: 2,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            final next = !muted;
            ref.read(audioMutedProvider.notifier).state = next;
            final audio = ref.read(appAudioServiceProvider);
            audio.setMuted(next);
            if (!next) audio.playButtonTap(); // confirm "sound is back"
          },
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(
              muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              color: AppColors.primaryBlue,
              size: size,
            ),
          ),
        ),
      ),
    );
  }
}
