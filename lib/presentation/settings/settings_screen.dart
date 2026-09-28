import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/home/home_progress.dart';
import '../../application/feedback/audio_feedback_service.dart';
import '../../application/settings/app_settings_controller.dart';
import '../../infrastructure/feedback/cleanup_feedback_coordinator.dart';
import '../../ui/app_assets.dart';
import '../../ui/components/app_image.dart';
import '../../ui/components/toy_surface.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';
import '../cleanup/vision_display_mode.dart';
import '../navigation/toy_app_shell.dart';
import '../widgets/tobi_3d_stage.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final controller = ref.read(appSettingsProvider.notifier);
    final debug = ref.watch(visionDisplayModeProvider) ==
        VisionDisplayMode.developerDebug;
    return ToyAppShell(
      section: ToyAppSection.settings,
      title: 'Ajustes',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ToyPageHero(
            mascot: Tobi3dStage(enable3d: false, fallbackSize: 96),
            message: 'Aquí los adultos pueden ajustar la aventura.',
          ),
          const SizedBox(height: AppSpacing.md),
          ToyCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _SettingSwitch(
                  icon: Icons.volume_up_rounded,
                  assetPath: AppAssets.soundIcon,
                  title: 'Sonidos',
                  value: settings.soundEnabled,
                  onChanged: (value) async {
                    await controller.setSound(value);
                    if (!value) {
                      await ref
                          .read(audioFeedbackServiceProvider)
                          .stop(AudioChannel.effects);
                    }
                  },
                ),
                _SettingSwitch(
                  icon: Icons.record_voice_over_rounded,
                  assetPath: AppAssets.voiceIcon,
                  title: 'Voz de Tobi',
                  value: settings.voiceEnabled,
                  onChanged: (value) async {
                    await controller.setVoice(value);
                    if (!value) {
                      await ref
                          .read(audioFeedbackServiceProvider)
                          .stop(AudioChannel.voice);
                    }
                  },
                ),
                _SettingSwitch(
                  icon: Icons.music_note_rounded,
                  assetPath: AppAssets.musicIcon,
                  title: 'Música',
                  value: settings.musicEnabled,
                  onChanged: (value) async {
                    await controller.setMusic(value);
                    if (!value) {
                      await ref
                          .read(audioFeedbackServiceProvider)
                          .stop(AudioChannel.music);
                    }
                  },
                ),
                _SettingSwitch(
                  icon: Icons.animation_rounded,
                  assetPath: AppAssets.animationIcon,
                  title: 'Animaciones',
                  value: settings.animationsEnabled,
                  onChanged: controller.setAnimations,
                ),
                _SettingSwitch(
                  icon: Icons.child_care_rounded,
                  assetPath: AppAssets.childModeIcon,
                  title: 'Modo infantil',
                  subtitle: 'Mantiene la interfaz simple y sin datos técnicos',
                  value: settings.kidModeEnabled,
                  onChanged: controller.setKidMode,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ToyCard(
            padding: EdgeInsets.zero,
            child: ExpansionTile(
              leading: const Icon(Icons.admin_panel_settings_rounded),
              title: const Text('Opciones avanzadas'),
              subtitle: const Text('Para adultos'),
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.camera_outlined),
                  title: const Text('Diagnóstico de cámara'),
                  subtitle: const Text(
                    'Muestra etapas, IDs y razones de rechazo. Nunca aparece en modo infantil.',
                  ),
                  value: debug,
                  onChanged: settings.kidModeEnabled
                      ? null
                      : (enabled) {
                          ref.read(visionDisplayModeProvider.notifier).state =
                              enabled
                                  ? VisionDisplayMode.developerDebug
                                  : VisionDisplayMode.kid;
                        },
                ),
                const ListTile(
                  leading: AppImage(
                    assetPath: AppAssets.modelIcon,
                    fallbackIcon: Icons.memory_rounded,
                    size: 38,
                  ),
                  title: Text('Modelo de visión'),
                  subtitle: Text('Detector híbrido on-device · TFLite'),
                ),
                const ListTile(
                  leading: AppImage(
                    assetPath: AppAssets.privacyIcon,
                    fallbackIcon: Icons.privacy_tip_rounded,
                    size: 38,
                  ),
                  title: Text('Privacidad'),
                  subtitle: Text(
                    'Los frames se procesan localmente y no se guardan por defecto.',
                  ),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.restart_alt_rounded,
                    color: AppColors.stopRed,
                  ),
                  title: const Text('Reiniciar progreso'),
                  onTap: () => _confirmReset(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text(
            'Los cambios se guardan en este dispositivo.',
            textAlign: TextAlign.center,
            style: AppTypography.caption,
          ),
        ],
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Reiniciar progreso?'),
        content: const Text(
          'Se borrarán las estrellas y sesiones guardadas. La configuración se conservará.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reiniciar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(appSettingsProvider.notifier).resetProgress();
    ref.invalidate(homeProgressProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Progreso reiniciado')),
      );
    }
  }
}

class _SettingSwitch extends StatelessWidget {
  const _SettingSwitch({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.assetPath,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? assetPath;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
        secondary: CircleAvatar(
          backgroundColor: AppColors.surfaceSoft,
          child: assetPath == null
              ? Icon(icon, color: AppColors.primaryBlue)
              : AppImage(
                  assetPath: assetPath!,
                  fallbackIcon: icon,
                  fallbackColor: AppColors.primaryBlue,
                  size: 34,
                ),
        ),
        title: Text(title, style: AppTypography.cardTitle),
        subtitle: subtitle == null ? null : Text(subtitle!),
        value: value,
        onChanged: onChanged,
      );
}
