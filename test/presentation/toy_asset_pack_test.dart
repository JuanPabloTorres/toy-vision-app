import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/ui/app_assets.dart';
import 'package:toyvision_realtime/ui/components/app_image.dart';
import 'package:toyvision_realtime/ui/components/primary_action_button.dart';

const iconAssets = <String>[
  AppAssets.carIcon,
  AppAssets.bearIcon,
  AppAssets.ballIcon,
  AppAssets.blocksIcon,
  AppAssets.dinosaurIcon,
  AppAssets.trainIcon,
  AppAssets.puzzleIcon,
  AppAssets.cameraIcon,
  AppAssets.soundIcon,
  AppAssets.musicIcon,
  AppAssets.progressIcon,
  AppAssets.settingsIcon,
  AppAssets.homeIcon,
  AppAssets.replayIcon,
  AppAssets.backIcon,
  AppAssets.infoIcon,
  AppAssets.voiceIcon,
  AppAssets.animationIcon,
  AppAssets.childModeIcon,
  AppAssets.privacyIcon,
  AppAssets.modelIcon,
  AppAssets.licenseIcon,
  AppAssets.supportIcon,
  AppAssets.trophyIcon,
  AppAssets.starIcon,
  AppAssets.streakIcon,
  AppAssets.completedIcon,
  AppAssets.rewardIcon,
  AppAssets.scanIcon,
  AppAssets.searchIcon,
  AppAssets.confirmedIcon,
  AppAssets.targetIcon,
  AppAssets.collectedIcon,
  AppAssets.emptyRoomIcon,
];

void main() {
  testWidgets('original 3D icon pack is present in the Flutter asset bundle',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Wrap(
          children: [
            for (final asset in iconAssets)
              AppImage(
                assetPath: asset,
                fallbackIcon: Icons.broken_image_rounded,
                size: 48,
              ),
          ],
        ),
      ),
    );
    await tester.pump();

    final rendered = tester.widgetList<Image>(find.byType(Image)).toList();
    expect(rendered, hasLength(iconAssets.length));
    expect(
      rendered.map((image) => (image.image as AssetImage).assetName),
      containsAll(iconAssets),
    );
  });

  test('asset manifest registers every production icon', () {
    final manifest = File('assets/ASSET_MANIFEST.yaml').readAsStringSync();
    for (final asset in iconAssets) {
      expect(
        manifest,
        contains(asset),
        reason: 'Missing manifest entry: $asset',
      );
    }
  });

  testWidgets('button loading and disabled states block activation',
      (tester) async {
    var activations = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            PrimaryActionButton(
              key: const Key('loading-button'),
              label: 'Cargar',
              color: Colors.blue,
              state: ToyButtonState.loading,
              onPressed: () => activations++,
            ),
            PrimaryActionButton(
              key: const Key('disabled-button'),
              label: 'Desactivado',
              color: Colors.blue,
              state: ToyButtonState.disabled,
              onPressed: () => activations++,
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('loading-button')));
    await tester.tap(find.byKey(const Key('disabled-button')));
    expect(activations, 0);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('success button presents its confirmation state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PrimaryActionButton(
          label: 'Guardar',
          successLabel: '¡GUARDADO!',
          color: Colors.green,
          state: ToyButtonState.success,
          onPressed: () {},
        ),
      ),
    );

    expect(find.text('¡GUARDADO!'), findsOneWidget);
    final successIcon = tester.widget<AppImage>(find.byType(AppImage));
    expect(successIcon.assetPath, AppAssets.starIcon);
  });
}
