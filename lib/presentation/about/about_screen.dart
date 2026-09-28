import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../ui/app_assets.dart';
import '../../ui/components/toy_surface.dart';
import '../../ui/theme/app_spacing.dart';
import '../navigation/toy_app_shell.dart';
import '../widgets/tobi_3d_stage.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) => ToyAppShell(
        section: ToyAppSection.about,
        title: 'Acerca de Tobi Ordena',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ToyPageHero(
              mascot: Tobi3dStage(enable3d: false, fallbackSize: 104),
              message: '¡Recoger también puede ser una aventura!',
            ),
            const SizedBox(height: AppSpacing.lg),
            const ToyFeatureCard(
              icon: Icons.route_rounded,
              title: 'Cómo funciona',
              body:
                  'Escanea el cuarto, recoge los juguetes, la ropa y los objetos sueltos que Tobi encontró, y celebra cuando el espacio queda limpio.',
            ),
            const ToyFeatureCard(
              icon: Icons.privacy_tip_rounded,
              assetPath: AppAssets.privacyIcon,
              title: 'Privacidad primero',
              body:
                  'La cámara y la inteligencia visual funcionan localmente. Las imágenes no salen del dispositivo.',
            ),
            const ToyFeatureCard(
              icon: Icons.psychology_rounded,
              assetPath: AppAssets.modelIcon,
              title: 'Visión inteligente',
              body:
                  'Detección híbrida, identidad temporal y verificación de desaparición ejecutadas on-device.',
            ),
            FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) => ToyFeatureCard(
                icon: Icons.info_outline_rounded,
                title: 'Versión',
                body: snapshot.hasData
                    ? '${snapshot.data!.version} (${snapshot.data!.buildNumber})'
                    : 'Cargando…',
              ),
            ),
            ToyFeatureCard(
              icon: Icons.description_outlined,
              assetPath: AppAssets.licenseIcon,
              title: 'Licencias',
              body: 'Software y recursos de terceros',
              onTap: () => showLicensePage(
                context: context,
                applicationName: 'Tobi Ordena',
              ),
            ),
            const ToyFeatureCard(
              icon: Icons.favorite_rounded,
              assetPath: AppAssets.supportIcon,
              title: 'Ayuda',
              body:
                  'Consejos claros para preparar la cámara y completar una aventura.',
            ),
          ],
        ),
      );
}
