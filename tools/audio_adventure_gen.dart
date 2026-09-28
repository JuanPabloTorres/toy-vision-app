/// Generates Toy Vision's original chiptune mission loop.
///
/// This uses only mathematical waveforms and an original note sequence. It
/// intentionally does not sample or reproduce music from another game.
///
/// Run:
///   dart run tools/audio_adventure_gen.dart
///
/// Output:
///   assets/audio/tobi_adventure_loop.wav
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const _sampleRate = 22050;
const _bpm = 132.0;
const _stepsPerBeat = 4;
const _bars = 8;
const _stepsPerBar = 16;
const _outputPath = 'assets/audio/tobi_adventure_loop.wav';

const _leadBars = <List<int>>[
  [72, -1, 76, 79, -1, 76, 74, -1, 77, -1, 81, 79, -1, 76, -1, -1],
  [74, -1, 77, 81, -1, 79, 77, -1, 76, -1, 74, 72, 69, -1, -1, -1],
  [72, 76, -1, 79, 81, -1, 79, -1, 77, 74, -1, 76, -1, 72, -1, -1],
  [69, -1, 72, 76, -1, 74, 72, -1, 67, 69, 72, -1, 67, -1, -1, -1],
  [76, -1, 79, 84, -1, 83, 79, -1, 77, -1, 81, 84, -1, 81, -1, -1],
  [74, 77, -1, 81, -1, 79, 77, -1, 76, 74, -1, 72, 69, -1, -1, -1],
  [72, -1, 76, 79, 81, -1, 84, -1, 83, 79, -1, 77, 76, -1, -1, -1],
  [74, -1, 77, 76, -1, 72, 69, -1, 67, 69, 72, -1, 67, -1, -1, -1],
];

const _chordRoots = [48, 45, 53, 43, 48, 45, 50, 43];

double _midiFrequency(int midi) =>
    (440 * math.pow(2, (midi - 69) / 12)).toDouble();

double _square(double phase) => math.sin(2 * math.pi * phase) >= 0 ? 1 : -1;

double _triangle(double phase) =>
    2 / math.pi * math.asin(math.sin(2 * math.pi * phase));

double _envelope(double local, double duration, {double release = 0.15}) {
  if (local < 0 || local >= duration) return 0;
  final attack = math.min(1.0, local / 0.008);
  final releaseStart = duration * (1 - release);
  final tail = local < releaseStart
      ? 1.0
      : 1 - ((local - releaseStart) / (duration - releaseStart));
  return attack * tail.clamp(0.0, 1.0);
}

double _noise(int sample) {
  final value = (sample * 1103515245 + 12345) & 0x7fffffff;
  return (value / 0x3fffffff) - 1;
}

void main() {
  const stepDuration = 60 / _bpm / _stepsPerBeat;
  const totalSteps = _bars * _stepsPerBar;
  final totalSamples = (totalSteps * stepDuration * _sampleRate).round();
  final samples = Float64List(totalSamples);

  for (var i = 0; i < totalSamples; i++) {
    final time = i / _sampleRate;
    final stepPosition = time / stepDuration;
    final step = stepPosition.floor().clamp(0, totalSteps - 1);
    final localStep = (stepPosition - step) * stepDuration;
    final bar = step ~/ _stepsPerBar;
    final barStep = step % _stepsPerBar;
    var value = 0.0;

    final lead = _leadBars[bar][barStep];
    if (lead >= 0) {
      final frequency = _midiFrequency(lead);
      final phase = time * frequency;
      value += 0.105 *
          _envelope(localStep, stepDuration * 0.82, release: 0.32) *
          (0.72 * _square(phase) + 0.28 * math.sin(2 * math.pi * phase));
    }

    if (barStep % 4 == 0) {
      final bass = _midiFrequency(_chordRoots[bar]);
      value += 0.13 *
          _envelope(localStep, stepDuration * 3.35, release: 0.38) *
          _triangle(time * bass);
    }

    if (barStep == 2 || barStep == 6 || barStep == 10 || barStep == 14) {
      final chordTone =
          _chordRoots[bar] + (barStep == 6 || barStep == 14 ? 19 : 12);
      final frequency = _midiFrequency(chordTone);
      value += 0.055 *
          _envelope(localStep, stepDuration * 0.62, release: 0.5) *
          _triangle(time * frequency);
    }

    if (barStep % 8 == 0) {
      final kickPhase = localStep * (105 - 55 * localStep / stepDuration);
      value += 0.16 *
          _envelope(localStep, stepDuration * 0.72, release: 0.8) *
          math.sin(2 * math.pi * kickPhase);
    }
    if (barStep % 8 == 4) {
      value += 0.07 *
          _envelope(localStep, stepDuration * 0.42, release: 0.9) *
          _noise(i);
    }
    if (barStep.isEven) {
      value += 0.018 *
          _envelope(localStep, stepDuration * 0.22, release: 0.95) *
          _noise(i * 7);
    }

    final driven = value * 1.15;
    samples[i] = (driven / (1 + driven.abs())) * 0.82;
  }

  final output = File(_outputPath);
  output.parent.createSync(recursive: true);
  output.writeAsBytesSync(_wavBytes(samples));
  stdout.writeln(
    '[audio] wrote $_outputPath '
    '(${(samples.length / _sampleRate).toStringAsFixed(2)}s)',
  );
}

Uint8List _wavBytes(Float64List samples) {
  final dataLength = samples.length * 2;
  final bytes = ByteData(44 + dataLength);
  void ascii(int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      bytes.setUint8(offset + i, value.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  bytes.setUint32(4, 36 + dataLength, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  bytes.setUint32(16, 16, Endian.little);
  bytes.setUint16(20, 1, Endian.little);
  bytes.setUint16(22, 1, Endian.little);
  bytes.setUint32(24, _sampleRate, Endian.little);
  bytes.setUint32(28, _sampleRate * 2, Endian.little);
  bytes.setUint16(32, 2, Endian.little);
  bytes.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  bytes.setUint32(40, dataLength, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    final sample = (samples[i].clamp(-1.0, 1.0) * 32767).round();
    bytes.setInt16(44 + i * 2, sample, Endian.little);
  }
  return bytes.buffer.asUint8List();
}
