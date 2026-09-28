/// Applies a short edge fade and conservative peak normalization to Tobi's
/// generated 16-bit mono PCM voice clips.
///
/// Run after synthesizing the files listed in [_voiceFiles]:
///   dart run tools/audio_voice_postprocess.dart
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const _voiceFiles = <String>[
  'assets/audio/tobi_session_start.wav',
  'assets/audio/tobi_toy_collected.wav',
  'assets/audio/tobi_almost_finished.wav',
  'assets/audio/tobi_room_verification.wav',
  'assets/audio/tobi_cleanup_completed.wav',
  'assets/audio/tobi_detection_uncertain.wav',
];

void main() {
  for (final path in _voiceFiles) {
    final file = File(path);
    final bytes = file.readAsBytesSync();
    final data = ByteData.sublistView(bytes);
    if (_ascii(bytes, 0, 4) != 'RIFF' ||
        _ascii(bytes, 8, 4) != 'WAVE' ||
        _ascii(bytes, 36, 4) != 'data' ||
        data.getUint16(20, Endian.little) != 1 ||
        data.getUint16(22, Endian.little) != 1 ||
        data.getUint16(34, Endian.little) != 16) {
      throw FormatException('$path is not a standard mono 16-bit PCM WAV');
    }

    final sampleRate = data.getUint32(24, Endian.little);
    final sampleCount = data.getUint32(40, Endian.little) ~/ 2;
    var peak = 1;
    for (var i = 0; i < sampleCount; i++) {
      peak = math.max(peak, data.getInt16(44 + i * 2, Endian.little).abs());
    }
    final gain = math.min(1.0, (32767 * 0.88) / peak);
    final fadeSamples = (sampleRate * 0.008).round();
    for (var i = 0; i < sampleCount; i++) {
      final edgeGain = math.min(
        1.0,
        math.min((i + 1) / fadeSamples, (sampleCount - i) / fadeSamples),
      );
      final sample = data.getInt16(44 + i * 2, Endian.little);
      data.setInt16(
        44 + i * 2,
        (sample * gain * edgeGain).round(),
        Endian.little,
      );
    }
    file.writeAsBytesSync(bytes, flush: true);
    stdout.writeln('[voice] normalized $path');
  }
}

String _ascii(Uint8List bytes, int start, int length) =>
    String.fromCharCodes(bytes.sublist(start, start + length));
