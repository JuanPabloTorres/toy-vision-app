import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled 3D model exposes every domain-driven animation', () async {
    final data = await rootBundle.loadString('assets/models/tobi.gltf');
    final gltf = jsonDecode(data) as Map<String, dynamic>;
    final names = (gltf['animations']! as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map((animation) => animation['name'])
        .toSet();

    expect(
      names,
      containsAll(<String>{
        'idle',
        'scan',
        'happy',
        'celebrate',
        'confused',
        'clap',
      }),
    );
  });

  test('Rive, Lottie and audio feedback assets are bundled and non-empty',
      () async {
    final rive = await rootBundle.load('assets/rive/rewards.riv');
    expect(rive.lengthInBytes, greaterThan(1000));

    for (final path in <String>[
      'assets/lottie/toy_collected.json',
      'assets/lottie/celebration.json',
    ]) {
      final animation =
          jsonDecode(await rootBundle.loadString(path)) as Map<String, dynamic>;
      expect(animation['layers'], isNotEmpty, reason: path);
    }

    for (final path in <String>[
      'assets/audio/mission_playground_loop.wav',
      'assets/audio/button_success_chime.wav',
      'assets/audio/button_tap_pop.wav',
      'assets/audio/mission_complete_reward.wav',
    ]) {
      final audio = await rootBundle.load(path);
      expect(audio.lengthInBytes, greaterThan(44), reason: path);
    }
  });
}
