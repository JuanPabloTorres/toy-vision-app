import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

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
      'assets/audio/tobi_adventure_loop.wav',
      'assets/audio/button_success_chime.wav',
      'assets/audio/button_tap_pop.wav',
      'assets/audio/mission_complete_reward.wav',
      'assets/audio/tobi_session_start.wav',
      'assets/audio/tobi_toy_collected.wav',
      'assets/audio/tobi_almost_finished.wav',
      'assets/audio/tobi_room_verification.wav',
      'assets/audio/tobi_cleanup_completed.wav',
      'assets/audio/tobi_detection_uncertain.wav',
    ]) {
      final audio = await rootBundle.load(path);
      expect(audio.lengthInBytes, greaterThan(44), reason: path);
      expect(
        String.fromCharCodes(audio.buffer.asUint8List(0, 4)),
        'RIFF',
        reason: path,
      );
    }
  });

  test('Tobi voice clips are mono PCM and retain safe peak headroom', () async {
    for (final path in <String>[
      'assets/audio/tobi_session_start.wav',
      'assets/audio/tobi_toy_collected.wav',
      'assets/audio/tobi_almost_finished.wav',
      'assets/audio/tobi_room_verification.wav',
      'assets/audio/tobi_cleanup_completed.wav',
      'assets/audio/tobi_detection_uncertain.wav',
    ]) {
      final audio = await rootBundle.load(path);
      expect(audio.getUint16(20, Endian.little), 1, reason: path);
      expect(audio.getUint16(22, Endian.little), 1, reason: path);
      expect(audio.getUint16(34, Endian.little), 16, reason: path);
      expect(audio.getUint32(24, Endian.little), 44100, reason: path);
      final durationSeconds = audio.getUint32(40, Endian.little) / 2 / 44100;
      expect(durationSeconds, inInclusiveRange(1.0, 7.0), reason: path);
      var peak = 0;
      for (var offset = 44; offset + 1 < audio.lengthInBytes; offset += 2) {
        final sample = audio.getInt16(offset, Endian.little).abs();
        if (sample > peak) peak = sample;
      }
      expect(peak, lessThan(32760), reason: path);
      expect(peak, greaterThan(16000), reason: path);
    }
  });

  test('tap bubble is long and strong enough for a phone speaker', () async {
    final audio = await rootBundle.load('assets/audio/button_tap_pop.wav');
    expect(audio.getUint16(20, Endian.little), 1);
    expect(audio.getUint16(22, Endian.little), 1);
    expect(audio.getUint16(34, Endian.little), 16);
    final sampleRate = audio.getUint32(24, Endian.little);
    final sampleCount = audio.getUint32(40, Endian.little) ~/ 2;
    final durationSeconds = sampleCount / sampleRate;
    expect(durationSeconds, inInclusiveRange(0.2, 0.4));

    var peak = 0;
    var sumSquares = 0.0;
    for (var offset = 44; offset + 1 < audio.lengthInBytes; offset += 2) {
      final sample = audio.getInt16(offset, Endian.little).abs();
      if (sample > peak) peak = sample;
      sumSquares += sample * sample;
    }
    final rms = math.sqrt(sumSquares / sampleCount);
    expect(peak, greaterThan(23000));
    expect(rms, greaterThan(5000));
  });
}
