import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/application/cleanup/cleanup_session_service.dart';
import 'package:toyvision_realtime/application/observability/session_evidence.dart';
import 'package:toyvision_realtime/infrastructure/observability/jsonl_perception_evidence_recorder.dart';
import 'package:toyvision_realtime/perception/perception_engine.dart';

import '../support/camera_replay.dart';

void main() {
  test('opt-in recorder writes replayable pixels and complete frame evidence',
      () async {
    final temporary =
        await Directory.systemTemp.createTemp('toyvision_capture_');
    addTearDown(() => temporary.delete(recursive: true));
    final recorder = JsonlPerceptionEvidenceRecorder(
      configuration: const CaptureConfiguration(
        enabled: true,
        includeFrames: true,
        scenario: 'recorder_contract',
      ),
      rootProvider: () async => temporary,
    );
    final replay = CameraReplay.load(
      'test/fixtures/replays/cleanup_adverse.json',
    );
    final engine = HybridToyPerceptionEngine();
    final cleanup = CleanupSessionService();
    final frame = replay.render(
      replay.frames.first,
      frameId: 0,
      origin: DateTime.utc(2026),
    );
    await recorder.startSession(frame.timestamp);
    final perception = await engine.processFrame(frame, discoveryMode: true);
    final outcome = cleanup.process(perception);
    await recorder.record(
      SessionEvidenceFrame(
        frame: frame,
        perception: perception,
        events: outcome.events,
        session: outcome.session,
        completionEvidence: outcome.completionEvidence,
      ),
    );
    final path = recorder.sessionPath!;
    await recorder.close();

    final metadata = jsonDecode(
      File('$path/session.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    expect(metadata['framesStored'], isTrue);
    expect(metadata['privacy'], contains('EXPLICITLY_ENABLED'));
    final record = jsonDecode(
      File('$path/frames.jsonl').readAsLinesSync().single,
    ) as Map<String, dynamic>;
    expect(record['frameId'], 0);
    expect(record['analysis'], isA<Map<String, dynamic>>());
    expect(
      (record['analysis'] as Map<String, dynamic>)['embeddingExtractor'],
      'perceptual-v1-non-semantic',
    );
    expect(record['fusion'], isA<Map<String, dynamic>>());
    expect(record['tracking'], isA<Map<String, dynamic>>());
    expect(record['disappearance'], isA<List<dynamic>>());
    expect(record['domain'], isA<Map<String, dynamic>>());
    expect(record['latency'], isA<Map<String, dynamic>>());
    expect(File('$path/${record['imagePath']}').lengthSync(), greaterThan(0));
  });

  test('metadata-only recorder never persists frame pixels', () async {
    final temporary =
        await Directory.systemTemp.createTemp('toyvision_metadata_');
    addTearDown(() => temporary.delete(recursive: true));
    final recorder = JsonlPerceptionEvidenceRecorder(
      configuration: const CaptureConfiguration(
        enabled: true,
        includeFrames: false,
        scenario: 'metadata_only',
      ),
      rootProvider: () async => temporary,
    );
    final replay = CameraReplay.load(
      'test/fixtures/replays/cleanup_adverse.json',
    );
    final engine = HybridToyPerceptionEngine();
    final cleanup = CleanupSessionService();
    final frame = replay.render(
      replay.frames.first,
      frameId: 0,
      origin: DateTime.utc(2026),
    );
    await recorder.startSession(frame.timestamp);
    final perception = await engine.processFrame(frame, discoveryMode: true);
    final outcome = cleanup.process(perception);
    await recorder.record(
      SessionEvidenceFrame(
        frame: frame,
        perception: perception,
        events: outcome.events,
        session: outcome.session,
        completionEvidence: outcome.completionEvidence,
      ),
    );
    final path = recorder.sessionPath!;
    await recorder.close();

    final record = jsonDecode(
      File('$path/frames.jsonl').readAsLinesSync().single,
    ) as Map<String, dynamic>;
    expect(record.containsKey('imagePath'), isFalse);
    expect(Directory('$path/frames').existsSync(), isFalse);
  });
}
