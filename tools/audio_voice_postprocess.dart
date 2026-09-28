/// Trims silence, applies a short edge fade, and normalizes Tobi's generated
/// 16-bit mono PCM clips without changing the synthesized character timbre.
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

const _targetPeak = 0.86;
const _silenceThreshold = 0.012;

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
    final samples = _trimSilence(source, sampleRate);
    var peak = 1;
    for (final sample in samples) {
      peak = math.max(peak, sample.abs().round());
    }
    final gain = ((32767 * _targetPeak) / peak).clamp(0.0, 4.0);
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
      '[voice] normalized $path '
      '(${(samples.length / sampleRate).toStringAsFixed(2)}s)',
    );
  }
}

List<double> _trimSilence(List<double> source, int sampleRate) {
  const threshold = 32767 * _silenceThreshold;
  var first = source.indexWhere((sample) => sample.abs() >= threshold);
  var last = source.lastIndexWhere((sample) => sample.abs() >= threshold);
  if (first < 0 || last < first) return source;
  final padding = (sampleRate * 0.04).round();
  first = math.max(0, first - padding);
  last = math.min(source.length - 1, last + padding);
  return source.sublist(first, last + 1);
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
