import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/application/cleanup/cleanup_session_service.dart';
import 'package:toyvision_realtime/application/observability/session_evidence.dart';
import 'package:toyvision_realtime/infrastructure/observability/jsonl_perception_evidence_recorder.dart';
import 'package:toyvision_realtime/perception/perception_engine.dart';

import '../../tools/certification/corpus_evaluator.dart';
import '../../tools/certification/corpus_models.dart';
import '../support/camera_replay.dart';

void main() {
  test('captured pixels replay through production perception and score corpus',
      () async {
    final temporary =
        await Directory.systemTemp.createTemp('toyvision_corpus_');
    addTearDown(() => temporary.delete(recursive: true));
    final replay = CameraReplay.load(
      'test/fixtures/replays/cleanup_full_flow.json',
    );
    final recorder = JsonlPerceptionEvidenceRecorder(
      configuration: const CaptureConfiguration(
        enabled: true,
        includeFrames: true,
        scenario: 'synthetic_contract_only',
      ),
      rootProvider: () async => temporary,
    );
    final engine = HybridToyPerceptionEngine();
    final cleanup = CleanupSessionService();
    final origin = DateTime.utc(2026);
    await recorder.startSession(origin);
    for (var index = 0; index < replay.frames.length; index++) {
      final frame =
          replay.render(replay.frames[index], frameId: index, origin: origin);
      final perception = await engine.processFrame(
        frame,
        discoveryMode: cleanup.snapshot == null,
      );
      final outcome = cleanup.process(
        perception,
        allowCollection: cleanup.session != null,
      );
      if (outcome.initialSnapshot != null && cleanup.session == null) {
        cleanup.startCleanup(frame.timestamp);
      }
      for (final trackId in outcome.tracksToMarkCollected) {
        engine.markCollected(trackId, frame.timestamp);
      }
      await recorder.record(
        SessionEvidenceFrame(
          frame: frame,
          perception: perception,
          events: outcome.events,
          session: outcome.session,
          completionEvidence: outcome.completionEvidence,
        ),
      );
    }
    final capturePath = recorder.sessionPath!;
    await recorder.close();

    final annotationFiles = <CorpusSplit, File>{};
    final captureDirectories = <CorpusSplit, Directory>{};
    for (final split in CorpusSplit.values) {
      final file = File('${temporary.path}/${split.name}.annotations.json');
      _writeAnnotations(file, split.name, replay);
      annotationFiles[split] = file;
      final capture = Directory('${temporary.path}/capture_${split.name}');
      _copyCapture(Directory(capturePath), capture);
      captureDirectories[split] = capture;
    }
    final sessions = [
      for (final split in CorpusSplit.values)
        CorpusSession(
          id: split.name,
          captureDirectory: captureDirectories[split]!,
          annotationsFile: annotationFiles[split]!,
          split: split,
          tags: split == CorpusSplit.train ? requiredScenarioTags : const {},
        ),
    ];
    final corpus = CorpusDefinition(
      rootFile: File('${temporary.path}/dataset.json'),
      sessions: sessions,
      acceptance: const AcceptanceCriteria(
        minimumPrecision: 0,
        minimumRecall: 0,
        minimumF1: 0,
        maximumIdSwitches: 100,
        maximumDuplicateCollections: 0,
        maximumFalseCollections: 0,
        minimumIdentityAuc: 0,
        minimumToyNonToyAuc: 0,
      ),
    );
    final output = Directory('${temporary.path}/results');
    final report = await CorpusEvaluator().evaluate(
      corpus,
      outputDirectory: output,
    );

    expect(report.isBlocked, isFalse);
    expect(report.metrics.frames, replay.frames.length);
    final replayRecords = File('${output.path}/test/replay_trace.jsonl')
        .readAsLinesSync()
        .map((line) => jsonDecode(line) as Map<String, dynamic>)
        .toList(growable: false);
    final collectionFrames = [
      for (final record in replayRecords)
        for (final event in record['domain']['events'] as List)
          if ((event as Map<String, dynamic>)['type'] == 'toyCollected')
            record['frameId'],
    ];
    expect(
      report.metrics.duplicateCollections,
      0,
      reason: 'collection frames: $collectionFrames',
    );
    expect(report.metrics.falseCollections, 0);
    expect(
      report.metrics.missedCollections,
      0,
      reason: 'collection frames: $collectionFrames\n'
          '${_coreTimeline(replayRecords).join('\n')}',
    );
    expect(report.metrics.completionMismatches, 0);
    expect(report.embeddingAudit.identityAuc, isNotNull);
    expect(report.embeddingAudit.toyNonToyAuc, isNotNull);
    expect(File('${output.path}/metrics.json').existsSync(), isTrue);
    expect(
      File('${output.path}/test/replay_trace.jsonl').readAsLinesSync(),
      hasLength(replay.frames.length),
    );
  });
}

List<String> _coreTimeline(List<Map<String, dynamic>> records) {
  return [
    for (final record in records)
      if ((record['frameId'] as int) >= 10)
        () {
          final frameId = record['frameId'];
          final tracking = record['tracking'] as Map<String, dynamic>;
          final scene = record['scene'] as Map<String, dynamic>;
          final domain = record['domain'] as Map<String, dynamic>;
          final session = domain['session'] as Map<String, dynamic>?;
          final tracks = <dynamic>[
            ...(tracking['active'] as List),
            ...(tracking['missing'] as List),
          ];
          final trackSummary = tracks.map((item) {
            final track = item as Map<String, dynamic>;
            return '${track['trackId']}:${track['presence']}'
                '/m${track['missingFrames']}'
                '/i${(track['interactionEvidence'] as num).toStringAsFixed(2)}';
          }).join(',');
          final disappearance = (record['disappearance'] as List).map((item) {
            final evidence = item as Map<String, dynamic>;
            return '${evidence['trackId']}:'
                '${evidence['rejectionReasons']}';
          }).join(',');
          return 'f$frameId scene=${scene['state']}'
              '/stable=${scene['stableFrameCount']}'
              '/anchor=${(scene['similarityToStableAnchor'] as num?)?.toStringAsFixed(2)}'
              ' session=${session?['status'] ?? '-'}'
              ' tracks=[$trackSummary] disappearance=[$disappearance]';
        }(),
  ];
}

void _copyCapture(Directory source, Directory target) {
  target.createSync(recursive: true);
  for (final entity in source.listSync(recursive: true)) {
    final relative = entity.path.substring(source.path.length + 1);
    final destination = '${target.path}${Platform.pathSeparator}$relative';
    if (entity is Directory) {
      Directory(destination).createSync(recursive: true);
    } else if (entity is File) {
      File(destination).parent.createSync(recursive: true);
      entity.copySync(destination);
    }
  }
}

void _writeAnnotations(File file, String sessionId, CameraReplay replay) {
  file.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'schemaVersion': 1,
      'sessionId': sessionId,
      'annotationStatus': 'COMPLETE',
      'frames': [
        for (var index = 0; index < replay.frames.length; index++)
          {
            'frameId': index,
            'cameraMoving': index >= 6 && index <= 12,
            'objects': [
              {
                'objectId': 'toy_1',
                'kind': 'toy',
                'visible': replay.frames[index].toy,
                'occluded': false,
                if (replay.frames[index].toy)
                  'bounds': {
                    'x': 0.2,
                    'y': 0.3,
                    'width': 0.2,
                    'height': 0.25,
                  },
              },
              {
                'objectId': 'hard_negative_1',
                'kind': 'nonToy',
                'visible': true,
                'occluded': false,
                'bounds': {
                  'x': 0.72,
                  'y': 0.10,
                  'width': 0.15,
                  'height': 0.15,
                },
              },
            ],
          },
      ],
      'expectedCollections': [
        {
          'objectId': 'toy_1',
          'minimumFrameId': 18,
          'maximumFrameId': 30,
        },
      ],
      // This replay never performs the required final-room coverage sweep.
      'expectCompletion': false,
    }),
  );
}
