import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/perception/perception_engine.dart';

import '../support/camera_replay.dart';

void main() {
  test('desktop replay pipeline stays within the local regression budget',
      () async {
    final replay = CameraReplay.load(
      'test/fixtures/replays/cleanup_adverse.json',
    );
    final engine = HybridToyPerceptionEngine();
    final origin = DateTime.utc(2026);
    final wallMs = <double>[];
    final analysisMs = <double>[];
    final rssBefore = ProcessInfo.currentRss;

    for (var index = 0; index < replay.frames.length; index++) {
      final stopwatch = Stopwatch()..start();
      final result = await engine.processFrame(
        replay.render(replay.frames[index], frameId: index, origin: origin),
        discoveryMode: index < 11,
      );
      stopwatch.stop();
      wallMs.add(stopwatch.elapsedMicroseconds / 1000);
      analysisMs.add(result.metrics.analysisUs / 1000);
    }
    final rssDeltaMb = (ProcessInfo.currentRss - rssBefore) / (1024 * 1024);
    wallMs.sort();
    analysisMs.sort();
    final wallP95 =
        wallMs[(wallMs.length * 0.95).floor().clamp(0, wallMs.length - 1)];
    final analysisP95 = analysisMs[
        (analysisMs.length * 0.95).floor().clamp(0, analysisMs.length - 1)];
    // ignore: avoid_print
    print(
      '[LOCAL_REPLAY_BENCHMARK] frames=${wallMs.length} '
      'wallP95Ms=${wallP95.toStringAsFixed(2)} '
      'analysisP95Ms=${analysisP95.toStringAsFixed(2)} '
      'rssDeltaMb=${rssDeltaMb.toStringAsFixed(2)}',
    );

    expect(wallP95, lessThan(250));
    expect(analysisP95, lessThan(240));
    expect(rssDeltaMb, lessThan(180));
  });
}
