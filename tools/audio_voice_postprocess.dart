/// Gives Tobi a youthful synthetic character, then applies a short edge fade
/// and conservative peak normalization to the generated 16-bit mono PCM clips.
///
/// Run once after freshly synthesizing the files listed in [_voiceFiles]:
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

const _characterPitchSemitones = 5.0;
const _targetPeak = 0.86;

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
    final source = List<double>.generate(
      sampleCount,
      (index) => data.getInt16(44 + index * 2, Endian.little).toDouble(),
      growable: false,
    );
    final pitchFactor = math.pow(2, _characterPitchSemitones / 12).toDouble();
    final samples = _resample(source, pitchFactor);
    var peak = 1;
    for (final sample in samples) {
      peak = math.max(peak, sample.abs().round());
    }
    final gain = math.min(1.0, (32767 * _targetPeak) / peak);
    final fadeSamples = (sampleRate * 0.008).round();
    final output = Uint8List(44 + samples.length * 2);
    final outputData = ByteData.sublistView(output);
    _writeHeader(outputData, sampleRate, samples.length);
    for (var i = 0; i < samples.length; i++) {
      final edgeGain = math.min(
        1.0,
        math.min((i + 1) / fadeSamples, (samples.length - i) / fadeSamples),
      );
      outputData.setInt16(
        44 + i * 2,
        (samples[i] * gain * edgeGain).round().clamp(-32768, 32767),
        Endian.little,
      );
    }
    file.writeAsBytesSync(output, flush: true);
    stdout.writeln(
      '[voice] characterized $path '
      '(pitch +${_characterPitchSemitones.toStringAsFixed(1)} st, '
      '${(samples.length / sampleRate).toStringAsFixed(2)}s)',
    );
  }
}

List<double> _resample(List<double> source, double factor) {
  final outputLength = (source.length / factor).floor();
  return List<double>.generate(
    outputLength,
    (index) {
      final position = index * factor;
      final center = position.floor();
      final fraction = position - center;
      final a = source[(center - 1).clamp(0, source.length - 1)];
      final b = source[center.clamp(0, source.length - 1)];
      final c = source[(center + 1).clamp(0, source.length - 1)];
      final d = source[(center + 2).clamp(0, source.length - 1)];
      final c0 = b;
      final c1 = 0.5 * (c - a);
      final c2 = a - 2.5 * b + 2 * c - 0.5 * d;
      final c3 = 0.5 * (d - a) + 1.5 * (b - c);
      return ((c3 * fraction + c2) * fraction + c1) * fraction + c0;
    },
    growable: false,
  );
}

void _writeHeader(ByteData data, int sampleRate, int sampleCount) {
  _writeAscii(data, 0, 'RIFF');
  data.setUint32(4, 36 + sampleCount * 2, Endian.little);
  _writeAscii(data, 8, 'WAVE');
  _writeAscii(data, 12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  _writeAscii(data, 36, 'data');
  data.setUint32(40, sampleCount * 2, Endian.little);
}

void _writeAscii(ByteData data, int offset, String value) {
  for (var i = 0; i < value.length; i++) {
    data.setUint8(offset + i, value.codeUnitAt(i));
  }
}

String _ascii(Uint8List bytes, int start, int length) =>
    String.fromCharCodes(bytes.sublist(start, start + length));
