import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:toyvision_realtime/application/cleanup/cleanup_session_service.dart';
import 'package:toyvision_realtime/application/observability/session_evidence.dart';
import 'package:toyvision_realtime/core/math/vector_math.dart';
import 'package:toyvision_realtime/domain/cleanup/cleanup_event.dart';
import 'package:toyvision_realtime/domain/toy/normalized_box.dart';
import 'package:toyvision_realtime/domain/toy/toy_observation.dart';
import 'package:toyvision_realtime/domain/toy/toy_track.dart';
import 'package:toyvision_realtime/perception/embeddings/embedding_extractor.dart';
import 'package:toyvision_realtime/perception/embeddings/perceptual_embedding_extractor.dart';
import 'package:toyvision_realtime/perception/perception_engine.dart';
import 'package:toyvision_realtime/perception/perception_models.dart';

import 'corpus_models.dart';

class CorpusEvaluator {
  CorpusEvaluator({
    this.embeddingExtractor = const PerceptualEmbeddingExtractor(),
    this.matchIou = 0.30,
  });

  final EmbeddingExtractor embeddingExtractor;
  final double matchIou;

  Future<EmbeddingCalibrationReport> calibrateEmbedding(
    CorpusDefinition corpus, {
    required File outputFile,
  }) async {
    final validationErrors = corpus.validate();
    if (validationErrors.isNotEmpty) {
      return EmbeddingCalibrationReport.blocked(validationErrors);
    }
    final training = <EmbeddingSample>[];
    final validation = <EmbeddingSample>[];
    for (final session in corpus.sessions) {
      final samples = await _extractEmbeddingSamples(session);
      if (session.split == CorpusSplit.train) training.addAll(samples);
      if (session.split == CorpusSplit.validation) {
        validation.addAll(samples);
      }
    }
    final blockers = <String>[
      if (training.isEmpty) 'no training embedding samples',
      if (validation.isEmpty) 'no validation embedding samples',
      if (training.map((item) => item.sessionId).toSet().length < 2)
        'embedding calibration requires at least two training sessions',
    ];
    if (blockers.isNotEmpty) {
      return EmbeddingCalibrationReport.blocked(blockers);
    }

    final trainingIdentity = _identityScores(training);
    final identityThreshold = _bestThreshold(
      trainingIdentity.$1,
      trainingIdentity.$2,
      minimum: 0,
      maximum: 1,
    );
    final validationIdentity = _identityScores(validation);
    final identityValidation = _scoreThreshold(
      validationIdentity.$1,
      validationIdentity.$2,
      identityThreshold.threshold,
    );

    final trainingSemantic = _semanticScores(training, training);
    final semanticThreshold = _bestThreshold(
      trainingSemantic.$1,
      trainingSemantic.$2,
      minimum: -1,
      maximum: 1,
    );
    final validationSemantic = _semanticScores(validation, training);
    final semanticValidation = _scoreThreshold(
      validationSemantic.$1,
      validationSemantic.$2,
      semanticThreshold.threshold,
    );
    final report = EmbeddingCalibrationReport(
      blockedReasons: const [],
      extractor: embeddingExtractor.identifier,
      identityThreshold: identityThreshold.threshold,
      identityTrainingF1: identityThreshold.f1,
      identityValidationF1: identityValidation.f1,
      toyNonToyScoreThreshold: semanticThreshold.threshold,
      toyNonToyTrainingF1: semanticThreshold.f1,
      toyNonToyValidationF1: semanticValidation.f1,
      trainingSamples: training.length,
      validationSamples: validation.length,
    );
    await outputFile.parent.create(recursive: true);
    await outputFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(report.toJson()),
    );
    return report;
  }

  Future<EvaluationReport> evaluate(
    CorpusDefinition corpus, {
    CorpusSplit split = CorpusSplit.test,
    required Directory outputDirectory,
  }) async {
    final validationErrors = corpus.validate();
    if (validationErrors.isNotEmpty) {
      return EvaluationReport.blocked(validationErrors);
    }
    await outputDirectory.create(recursive: true);
    final totals = _MutableMetrics();
    final embeddingSamples = <EmbeddingSample>[];
    final sessionReports = <SessionReport>[];
    final selected =
        corpus.sessions.where((session) => session.split == split).toList();
    for (final session in selected) {
      final result = await _evaluateSession(
        session,
        Directory('${outputDirectory.path}/${session.id}'),
      );
      sessionReports.add(result.report);
      totals.add(result.metrics);
      embeddingSamples.addAll(result.embeddingSamples);
    }

    // Reference samples from the non-test splits are used only for the
    // leave-one-session-out toy/non-toy experiment, never for pipeline tuning.
    final referenceSamples = <EmbeddingSample>[];
    for (final session
        in corpus.sessions.where((item) => item.split != split)) {
      referenceSamples.addAll(await _extractEmbeddingSamples(session));
    }
    final embeddingAudit = _auditEmbeddings(
      [...embeddingSamples, ...referenceSamples],
      evaluationSessionIds: selected.map((session) => session.id).toSet(),
    );
    final report = EvaluationReport(
      blockedReasons: const [],
      metrics: totals.freeze(),
      embeddingAudit: embeddingAudit,
      sessions: sessionReports,
      acceptance: corpus.acceptance,
    );
    await File('${outputDirectory.path}/metrics.json').writeAsString(
      const JsonEncoder.withIndent('  ').convert(report.toJson()),
    );
    await File('${outputDirectory.path}/report.md').writeAsString(
      report.toMarkdown(split),
    );
    return report;
  }

  Future<_SessionEvaluation> _evaluateSession(
    CorpusSession session,
    Directory outputDirectory,
  ) async {
    await outputDirectory.create(recursive: true);
    final annotations = SessionAnnotations.load(session.annotationsFile);
    if (!annotations.isComplete) {
      throw FormatException('${session.id}: annotations are not COMPLETE');
    }
    if (annotations.sessionId != session.id) {
      throw FormatException(
        '${session.id}: annotation sessionId is ${annotations.sessionId}',
      );
    }
    final records = _readJsonLines(
      File('${session.captureDirectory.path}/frames.jsonl'),
    );
    if (records.isEmpty) {
      throw FormatException('${session.id}: frames.jsonl is empty');
    }
    final engine = HybridToyPerceptionEngine();
    final cleanup = CleanupSessionService();
    final metrics = _MutableMetrics();
    final trackToObject = <int, String>{};
    final objectToLastTrack = <String, int>{};
    final collectionCounts = <String, int>{};
    var actualCompletionEvents = 0;
    final replaySink =
        File('${outputDirectory.path}/replay_trace.jsonl').openWrite();
    final embeddingSamples = <EmbeddingSample>[];

    try {
      for (final record in records) {
        final frameId = record['frameId']! as int;
        final annotation = annotations.frames[frameId];
        if (annotation == null) {
          throw FormatException(
            '${session.id}: frame $frameId has no annotation',
          );
        }
        final imagePath = record['imagePath'] as String?;
        if (imagePath == null) {
          throw FormatException(
            '${session.id}: frame $frameId has no retained pixels; recapture '
            'with TOYVISION_CAPTURE_FRAMES=true',
          );
        }
        final imageFile = File('${session.captureDirectory.path}/$imagePath');
        if (!imageFile.existsSync()) {
          throw FormatException('${session.id}: missing $imagePath');
        }
        final encoded = imageFile.readAsBytesSync();
        final frame = _frameFromRecord(record, encoded);
        final result = await engine.processFrame(
          frame,
          discoveryMode: cleanup.snapshot == null,
        );
        final outcome = cleanup.process(
          result,
          allowCollection: cleanup.session != null,
        );
        if (outcome.initialSnapshot != null && cleanup.session == null) {
          cleanup.startCleanup(frame.timestamp);
        }
        for (final trackId in outcome.tracksToMarkCollected) {
          engine.markCollected(trackId, frame.timestamp);
        }
        replaySink.writeln(
          jsonEncode(
            sessionEvidenceToJson(
              SessionEvidenceFrame(
                frame: frame,
                perception: result,
                events: outcome.events,
                session: outcome.session,
                completionEvidence: outcome.completionEvidence,
              ),
              imagePath: imagePath,
            ),
          ),
        );
        _scoreDetections(metrics, result.acceptedObservations, annotation);
        _scoreTracking(
          metrics,
          result.worldModel.activeTracks.values,
          annotation,
          trackToObject,
          objectToLastTrack,
        );
        for (final event in outcome.events) {
          if (event is ToyCollected) {
            final objectId = trackToObject[event.trackId];
            if (objectId == null) {
              metrics.falseCollections += 1;
              continue;
            }
            collectionCounts.update(
              objectId,
              (value) => value + 1,
              ifAbsent: () => 1,
            );
            final expected = annotations.expectedCollections
                .where((item) => item.objectId == objectId)
                .toList();
            if (expected.isEmpty ||
                !expected.any((item) => item.includes(frameId))) {
              metrics.falseCollections += 1;
            }
          } else if (event is CleanupCompleted) {
            actualCompletionEvents += 1;
          }
        }
        metrics.nativeInferenceMs.add(frame.nativeInferenceMs);
        metrics.analysisMs.add(result.metrics.analysisUs / 1000);
        metrics.fusionMs.add(result.metrics.fusionUs / 1000);
        metrics.trackingMs.add(result.metrics.trackingUs / 1000);
        metrics.frames += 1;
        embeddingSamples.addAll(
          _samplesFromFrame(session.id, encoded, annotation),
        );
      }
    } finally {
      await replaySink.close();
    }

    for (final expectation in annotations.expectedCollections) {
      final count = collectionCounts[expectation.objectId] ?? 0;
      if (count == 0) metrics.missedCollections += 1;
      if (count > 1) metrics.duplicateCollections += count - 1;
    }
    if (annotations.expectCompletion != (actualCompletionEvents == 1)) {
      metrics.completionMismatches += 1;
    }
    if (actualCompletionEvents > 1) {
      metrics.completionMismatches += actualCompletionEvents - 1;
    }
    return _SessionEvaluation(
      metrics: metrics,
      embeddingSamples: embeddingSamples,
      report: SessionReport(
        id: session.id,
        split: session.split,
        metrics: metrics.freeze(),
      ),
    );
  }

  Future<List<EmbeddingSample>> _extractEmbeddingSamples(
    CorpusSession session,
  ) async {
    if (!session.annotationsFile.existsSync()) return const [];
    final annotations = SessionAnnotations.load(session.annotationsFile);
    if (!annotations.isComplete) return const [];
    final records = _readJsonLines(
      File('${session.captureDirectory.path}/frames.jsonl'),
    );
    final samples = <EmbeddingSample>[];
    for (final record in records) {
      final annotation = annotations.frames[record['frameId'] as int];
      final imagePath = record['imagePath'] as String?;
      if (annotation == null || imagePath == null) continue;
      final image = File('${session.captureDirectory.path}/$imagePath');
      if (!image.existsSync()) continue;
      samples.addAll(
        _samplesFromFrame(session.id, image.readAsBytesSync(), annotation),
      );
    }
    return samples;
  }

  List<EmbeddingSample> _samplesFromFrame(
    String sessionId,
    Uint8List encoded,
    FrameAnnotation annotation,
  ) {
    final image = img.decodeImage(encoded);
    if (image == null) return const [];
    return [
      for (final object in annotation.objects)
        if (object.visible && object.bounds != null)
          EmbeddingSample(
            sessionId: sessionId,
            objectId: '$sessionId:${object.objectId}',
            isToy: object.kind == AnnotatedObjectKind.toy,
            embedding: embeddingExtractor.embed(image, object.bounds!),
          ),
    ];
  }

  void _scoreDetections(
    _MutableMetrics metrics,
    List<ToyObservation> predictions,
    FrameAnnotation annotation,
  ) {
    final truth = annotation.objects
        .where(
          (object) =>
              object.kind == AnnotatedObjectKind.toy &&
              object.visible &&
              object.bounds != null,
        )
        .toList();
    final matches = _greedyMatches(
      predictions.map((item) => item.bounds).toList(),
      truth.map((item) => item.bounds!).toList(),
    );
    metrics.truePositives += matches.length;
    metrics.falsePositives += predictions.length - matches.length;
    metrics.falseNegatives += truth.length - matches.length;
    final matchedPredictions = matches.map((item) => item.$1).toSet();
    final hardNegatives = annotation.objects.where(
      (object) =>
          object.kind == AnnotatedObjectKind.nonToy &&
          object.visible &&
          object.bounds != null,
    );
    for (var index = 0; index < predictions.length; index++) {
      if (matchedPredictions.contains(index)) continue;
      if (hardNegatives.any(
        (item) =>
            item.bounds!.intersectionOverUnion(predictions[index].bounds) >=
            matchIou,
      )) {
        metrics.hardNegativeFalsePositives += 1;
      }
    }
  }

  void _scoreTracking(
    _MutableMetrics metrics,
    Iterable<ToyTrack> tracks,
    FrameAnnotation annotation,
    Map<int, String> trackToObject,
    Map<String, int> objectToLastTrack,
  ) {
    final visibleToys = annotation.objects
        .where(
          (item) =>
              item.kind == AnnotatedObjectKind.toy &&
              item.visible &&
              item.bounds != null,
        )
        .toList();
    final trackList = tracks.toList();
    final matches = _greedyMatches(
      trackList.map((item) => item.lastBounds).toList(),
      visibleToys.map((item) => item.bounds!).toList(),
    );
    for (final match in matches) {
      final trackId = trackList[match.$1].id;
      final objectId = visibleToys[match.$2].objectId;
      final previous = objectToLastTrack[objectId];
      if (previous != null && previous != trackId) metrics.idSwitches += 1;
      objectToLastTrack[objectId] = trackId;
      trackToObject[trackId] = objectId;
    }
  }

  List<(int, int, double)> _greedyMatches(
    List<NormalizedBox> predicted,
    List<NormalizedBox> truth,
  ) {
    final candidates = <(int, int, double)>[];
    for (var prediction = 0; prediction < predicted.length; prediction++) {
      for (var actual = 0; actual < truth.length; actual++) {
        final iou = predicted[prediction].intersectionOverUnion(truth[actual]);
        if (iou >= matchIou) candidates.add((prediction, actual, iou));
      }
    }
    candidates.sort((a, b) => b.$3.compareTo(a.$3));
    final usedPredictions = <int>{};
    final usedTruth = <int>{};
    return [
      for (final candidate in candidates)
        if (usedPredictions.add(candidate.$1) && usedTruth.add(candidate.$2))
          candidate,
    ];
  }

  EmbeddingAudit _auditEmbeddings(
    List<EmbeddingSample> samples, {
    required Set<String> evaluationSessionIds,
  }) {
    final same = <double>[];
    final different = <double>[];
    for (var first = 0; first < samples.length; first++) {
      for (var second = first + 1; second < samples.length; second++) {
        if (same.length + different.length >= 10000) break;
        final a = samples[first];
        final b = samples[second];
        final similarity = cosineSimilarity(a.embedding, b.embedding);
        if (a.objectId == b.objectId) {
          same.add(similarity);
        } else {
          different.add(similarity);
        }
      }
    }
    final toyScores = <double>[];
    final nonToyScores = <double>[];
    for (final sample in samples.where(
      (item) => evaluationSessionIds.contains(item.sessionId),
    )) {
      final references = samples.where(
        (item) => item.sessionId != sample.sessionId,
      );
      var nearestToy = -1.0;
      var nearestNonToy = -1.0;
      for (final reference in references) {
        final similarity = cosineSimilarity(
          sample.embedding,
          reference.embedding,
        );
        if (reference.isToy) {
          nearestToy = math.max(nearestToy, similarity);
        } else {
          nearestNonToy = math.max(nearestNonToy, similarity);
        }
      }
      if (nearestToy < 0 || nearestNonToy < 0) continue;
      final score = nearestToy - nearestNonToy;
      (sample.isToy ? toyScores : nonToyScores).add(score);
    }
    return EmbeddingAudit(
      identifier: embeddingExtractor.identifier,
      sampleCount: samples.length,
      sameIdentityMedian: _median(same),
      differentIdentityMedian: _median(different),
      identityAuc: _auc(same, different),
      toyNonToyAuc: _auc(toyScores, nonToyScores),
      semanticClaim: false,
    );
  }

  (List<double>, List<double>) _identityScores(
    List<EmbeddingSample> samples,
  ) {
    final positives = <double>[];
    final negatives = <double>[];
    for (var first = 0; first < samples.length; first++) {
      for (var second = first + 1; second < samples.length; second++) {
        if (positives.length + negatives.length >= 20000) break;
        final similarity = cosineSimilarity(
          samples[first].embedding,
          samples[second].embedding,
        );
        if (samples[first].objectId == samples[second].objectId) {
          positives.add(similarity);
        } else {
          negatives.add(similarity);
        }
      }
    }
    return (positives, negatives);
  }

  (List<double>, List<double>) _semanticScores(
    List<EmbeddingSample> subjects,
    List<EmbeddingSample> references,
  ) {
    final positives = <double>[];
    final negatives = <double>[];
    for (final sample in subjects) {
      var nearestToy = -1.0;
      var nearestNonToy = -1.0;
      for (final reference in references) {
        if (identical(sample, reference) ||
            (sample.objectId == reference.objectId &&
                sample.sessionId == reference.sessionId)) {
          continue;
        }
        final similarity = cosineSimilarity(
          sample.embedding,
          reference.embedding,
        );
        if (reference.isToy) {
          nearestToy = math.max(nearestToy, similarity);
        } else {
          nearestNonToy = math.max(nearestNonToy, similarity);
        }
      }
      if (nearestToy < 0 || nearestNonToy < 0) continue;
      final score = nearestToy - nearestNonToy;
      (sample.isToy ? positives : negatives).add(score);
    }
    return (positives, negatives);
  }

  CameraPerceptionFrame _frameFromRecord(
    Map<String, dynamic> record,
    Uint8List bytes,
  ) {
    final input = record['input']! as Map<String, dynamic>;
    return CameraPerceptionFrame(
      frameId: record['frameId']! as int,
      timestamp: DateTime.parse(record['timestamp']! as String),
      encodedImage: bytes,
      detectorProposals:
          (input['detections'] as List<dynamic>? ?? const []).map((item) {
        final value = item as Map<String, dynamic>;
        return DetectorProposal(
          bounds: _box(value['bounds']! as Map<String, dynamic>),
          confidence: (value['confidence']! as num).toDouble(),
          knownClass: value['knownClassDiagnostic'] as String?,
        );
      }).toList(growable: false),
      nativeInferenceMs: (input['nativeInferenceMs']! as num).toDouble(),
      nativeFps: (input['nativeFps']! as num).toDouble(),
      detectorCoordinatesAreUpright:
          input['detectorCoordinatesAreUpright'] as bool? ?? false,
    );
  }

  NormalizedBox _box(Map<String, dynamic> value) => NormalizedBox(
        x: (value['x']! as num).toDouble(),
        y: (value['y']! as num).toDouble(),
        width: (value['width']! as num).toDouble(),
        height: (value['height']! as num).toDouble(),
      );
}

List<Map<String, dynamic>> _readJsonLines(File file) {
  if (!file.existsSync()) return const [];
  return file
      .readAsLinesSync()
      .where((line) => line.trim().isNotEmpty)
      .map((line) => jsonDecode(line) as Map<String, dynamic>)
      .toList(growable: false);
}

double? _median(List<double> values) {
  if (values.isEmpty) return null;
  final sorted = [...values]..sort();
  final middle = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[middle]
      : (sorted[middle - 1] + sorted[middle]) / 2;
}

double? _auc(List<double> positives, List<double> negatives) {
  if (positives.isEmpty || negatives.isEmpty) return null;
  var wins = 0.0;
  for (final positive in positives) {
    for (final negative in negatives) {
      if (positive > negative) {
        wins += 1;
      } else if (positive == negative) {
        wins += 0.5;
      }
    }
  }
  return wins / (positives.length * negatives.length);
}

_ThresholdScore _bestThreshold(
  List<double> positives,
  List<double> negatives, {
  required double minimum,
  required double maximum,
}) {
  if (positives.isEmpty || negatives.isEmpty) {
    return const _ThresholdScore(threshold: 0, f1: 0);
  }
  var best = const _ThresholdScore(threshold: 0, f1: -1);
  for (var step = 0; step <= 200; step++) {
    final threshold = minimum + (maximum - minimum) * step / 200;
    final score = _scoreThreshold(positives, negatives, threshold);
    if (score.f1 > best.f1) {
      best = _ThresholdScore(threshold: threshold, f1: score.f1);
    }
  }
  return best;
}

_ThresholdScore _scoreThreshold(
  List<double> positives,
  List<double> negatives,
  double threshold,
) {
  final truePositives = positives.where((value) => value >= threshold).length;
  final falseNegatives = positives.length - truePositives;
  final falsePositives = negatives.where((value) => value >= threshold).length;
  final precision = truePositives + falsePositives == 0
      ? 0.0
      : truePositives / (truePositives + falsePositives);
  final recall = truePositives + falseNegatives == 0
      ? 0.0
      : truePositives / (truePositives + falseNegatives);
  final f1 = precision + recall == 0
      ? 0.0
      : 2 * precision * recall / (precision + recall);
  return _ThresholdScore(threshold: threshold, f1: f1);
}

class _ThresholdScore {
  const _ThresholdScore({required this.threshold, required this.f1});
  final double threshold;
  final double f1;
}

class EmbeddingSample {
  const EmbeddingSample({
    required this.sessionId,
    required this.objectId,
    required this.isToy,
    required this.embedding,
  });

  final String sessionId;
  final String objectId;
  final bool isToy;
  final List<double> embedding;
}

class EmbeddingAudit {
  const EmbeddingAudit({
    required this.identifier,
    required this.sampleCount,
    required this.sameIdentityMedian,
    required this.differentIdentityMedian,
    required this.identityAuc,
    required this.toyNonToyAuc,
    required this.semanticClaim,
  });

  final String identifier;
  final int sampleCount;
  final double? sameIdentityMedian;
  final double? differentIdentityMedian;
  final double? identityAuc;
  final double? toyNonToyAuc;
  final bool semanticClaim;

  Map<String, Object?> toJson() => {
        'identifier': identifier,
        'sampleCount': sampleCount,
        'sameIdentityMedian': sameIdentityMedian,
        'differentIdentityMedian': differentIdentityMedian,
        'identityAuc': identityAuc,
        'toyNonToyAuc': toyNonToyAuc,
        'semanticClaim': semanticClaim,
      };
}

class EmbeddingCalibrationReport {
  const EmbeddingCalibrationReport({
    required this.blockedReasons,
    required this.extractor,
    required this.identityThreshold,
    required this.identityTrainingF1,
    required this.identityValidationF1,
    required this.toyNonToyScoreThreshold,
    required this.toyNonToyTrainingF1,
    required this.toyNonToyValidationF1,
    required this.trainingSamples,
    required this.validationSamples,
  });

  factory EmbeddingCalibrationReport.blocked(List<String> reasons) =>
      EmbeddingCalibrationReport(
        blockedReasons: List.unmodifiable(reasons),
        extractor: 'not-run',
        identityThreshold: null,
        identityTrainingF1: null,
        identityValidationF1: null,
        toyNonToyScoreThreshold: null,
        toyNonToyTrainingF1: null,
        toyNonToyValidationF1: null,
        trainingSamples: 0,
        validationSamples: 0,
      );

  final List<String> blockedReasons;
  final String extractor;
  final double? identityThreshold;
  final double? identityTrainingF1;
  final double? identityValidationF1;
  final double? toyNonToyScoreThreshold;
  final double? toyNonToyTrainingF1;
  final double? toyNonToyValidationF1;
  final int trainingSamples;
  final int validationSamples;

  bool get isBlocked => blockedReasons.isNotEmpty;

  Map<String, Object?> toJson() => {
        'status': isBlocked ? 'BLOCKED' : 'CALIBRATED_NOT_APPLIED',
        'blockedReasons': blockedReasons,
        'extractor': extractor,
        'trainingSamples': trainingSamples,
        'validationSamples': validationSamples,
        'identity': {
          'recommendedCosineThreshold': identityThreshold,
          'trainingF1': identityTrainingF1,
          'validationF1': identityValidationF1,
        },
        'toyNonToyExperiment': {
          'recommendedNearestNeighborScoreThreshold': toyNonToyScoreThreshold,
          'trainingF1': toyNonToyTrainingF1,
          'validationF1': toyNonToyValidationF1,
          'semanticClaim': false,
        },
        'warning':
            'Recommendations are corpus-wide experiments and are not applied '
                'to production automatically. Confirm on the held-out test split.',
      };
}

class EvaluationMetrics {
  const EvaluationMetrics({
    required this.frames,
    required this.truePositives,
    required this.falsePositives,
    required this.falseNegatives,
    required this.hardNegativeFalsePositives,
    required this.idSwitches,
    required this.duplicateCollections,
    required this.falseCollections,
    required this.missedCollections,
    required this.completionMismatches,
    required this.nativeInferenceMs,
    required this.analysisMs,
    required this.fusionMs,
    required this.trackingMs,
  });

  final int frames;
  final int truePositives;
  final int falsePositives;
  final int falseNegatives;
  final int hardNegativeFalsePositives;
  final int idSwitches;
  final int duplicateCollections;
  final int falseCollections;
  final int missedCollections;
  final int completionMismatches;
  final List<double> nativeInferenceMs;
  final List<double> analysisMs;
  final List<double> fusionMs;
  final List<double> trackingMs;

  double get precision => truePositives + falsePositives == 0
      ? 0
      : truePositives / (truePositives + falsePositives);
  double get recall => truePositives + falseNegatives == 0
      ? 0
      : truePositives / (truePositives + falseNegatives);
  double get f1 => precision + recall == 0
      ? 0
      : 2 * precision * recall / (precision + recall);

  Map<String, Object?> toJson() => {
        'frames': frames,
        'truePositives': truePositives,
        'falsePositives': falsePositives,
        'falseNegatives': falseNegatives,
        'precision': precision,
        'recall': recall,
        'f1': f1,
        'hardNegativeFalsePositives': hardNegativeFalsePositives,
        'idSwitches': idSwitches,
        'duplicateCollections': duplicateCollections,
        'falseCollections': falseCollections,
        'missedCollections': missedCollections,
        'completionMismatches': completionMismatches,
        'latencyMs': {
          'nativeInference': _percentiles(nativeInferenceMs),
          'analysis': _percentiles(analysisMs),
          'fusion': _percentiles(fusionMs),
          'tracking': _percentiles(trackingMs),
        },
      };
}

class _MutableMetrics {
  int frames = 0;
  int truePositives = 0;
  int falsePositives = 0;
  int falseNegatives = 0;
  int hardNegativeFalsePositives = 0;
  int idSwitches = 0;
  int duplicateCollections = 0;
  int falseCollections = 0;
  int missedCollections = 0;
  int completionMismatches = 0;
  final List<double> nativeInferenceMs = [];
  final List<double> analysisMs = [];
  final List<double> fusionMs = [];
  final List<double> trackingMs = [];

  void add(_MutableMetrics other) {
    frames += other.frames;
    truePositives += other.truePositives;
    falsePositives += other.falsePositives;
    falseNegatives += other.falseNegatives;
    hardNegativeFalsePositives += other.hardNegativeFalsePositives;
    idSwitches += other.idSwitches;
    duplicateCollections += other.duplicateCollections;
    falseCollections += other.falseCollections;
    missedCollections += other.missedCollections;
    completionMismatches += other.completionMismatches;
    nativeInferenceMs.addAll(other.nativeInferenceMs);
    analysisMs.addAll(other.analysisMs);
    fusionMs.addAll(other.fusionMs);
    trackingMs.addAll(other.trackingMs);
  }

  EvaluationMetrics freeze() => EvaluationMetrics(
        frames: frames,
        truePositives: truePositives,
        falsePositives: falsePositives,
        falseNegatives: falseNegatives,
        hardNegativeFalsePositives: hardNegativeFalsePositives,
        idSwitches: idSwitches,
        duplicateCollections: duplicateCollections,
        falseCollections: falseCollections,
        missedCollections: missedCollections,
        completionMismatches: completionMismatches,
        nativeInferenceMs: List.unmodifiable(nativeInferenceMs),
        analysisMs: List.unmodifiable(analysisMs),
        fusionMs: List.unmodifiable(fusionMs),
        trackingMs: List.unmodifiable(trackingMs),
      );
}

Map<String, double?> _percentiles(List<double> values) => {
      'p50': _percentile(values, 0.50),
      'p95': _percentile(values, 0.95),
      'p99': _percentile(values, 0.99),
    };

double? _percentile(List<double> values, double fraction) {
  if (values.isEmpty) return null;
  final sorted = [...values]..sort();
  return sorted[((sorted.length - 1) * fraction).round()];
}

class SessionReport {
  const SessionReport({
    required this.id,
    required this.split,
    required this.metrics,
  });

  final String id;
  final CorpusSplit split;
  final EvaluationMetrics metrics;

  Map<String, Object?> toJson() => {
        'id': id,
        'split': split.name,
        'metrics': metrics.toJson(),
      };
}

class EvaluationReport {
  const EvaluationReport({
    required this.blockedReasons,
    required this.metrics,
    required this.embeddingAudit,
    required this.sessions,
    required this.acceptance,
  });

  factory EvaluationReport.blocked(List<String> reasons) => EvaluationReport(
        blockedReasons: List.unmodifiable(reasons),
        metrics: const EvaluationMetrics(
          frames: 0,
          truePositives: 0,
          falsePositives: 0,
          falseNegatives: 0,
          hardNegativeFalsePositives: 0,
          idSwitches: 0,
          duplicateCollections: 0,
          falseCollections: 0,
          missedCollections: 0,
          completionMismatches: 0,
          nativeInferenceMs: [],
          analysisMs: [],
          fusionMs: [],
          trackingMs: [],
        ),
        embeddingAudit: const EmbeddingAudit(
          identifier: 'not-run',
          sampleCount: 0,
          sameIdentityMedian: null,
          differentIdentityMedian: null,
          identityAuc: null,
          toyNonToyAuc: null,
          semanticClaim: false,
        ),
        sessions: const [],
        acceptance: const AcceptanceCriteria(
          minimumPrecision: 0.90,
          minimumRecall: 0.85,
          minimumF1: 0.87,
          maximumIdSwitches: 0,
          maximumDuplicateCollections: 0,
          maximumFalseCollections: 0,
          minimumIdentityAuc: 0.90,
          minimumToyNonToyAuc: 0.85,
        ),
      );

  final List<String> blockedReasons;
  final EvaluationMetrics metrics;
  final EmbeddingAudit embeddingAudit;
  final List<SessionReport> sessions;
  final AcceptanceCriteria acceptance;

  bool get isBlocked => blockedReasons.isNotEmpty;
  bool get passed => !isBlocked && failures.isEmpty;

  List<String> get failures {
    if (isBlocked) return blockedReasons;
    return [
      if (metrics.precision < acceptance.minimumPrecision)
        'precision ${metrics.precision} < ${acceptance.minimumPrecision}',
      if (metrics.recall < acceptance.minimumRecall)
        'recall ${metrics.recall} < ${acceptance.minimumRecall}',
      if (metrics.f1 < acceptance.minimumF1)
        'F1 ${metrics.f1} < ${acceptance.minimumF1}',
      if (metrics.idSwitches > acceptance.maximumIdSwitches)
        'ID switches ${metrics.idSwitches} > ${acceptance.maximumIdSwitches}',
      if (metrics.duplicateCollections > acceptance.maximumDuplicateCollections)
        'duplicate collections ${metrics.duplicateCollections}',
      if (metrics.falseCollections > acceptance.maximumFalseCollections)
        'false collections ${metrics.falseCollections}',
      if (metrics.missedCollections > 0)
        'missed collections ${metrics.missedCollections}',
      if (metrics.completionMismatches > 0)
        'completion mismatches ${metrics.completionMismatches}',
      if (embeddingAudit.identityAuc == null)
        'identity embedding AUC unavailable',
      if (embeddingAudit.identityAuc != null &&
          embeddingAudit.identityAuc! < acceptance.minimumIdentityAuc)
        'identity AUC ${embeddingAudit.identityAuc} < '
            '${acceptance.minimumIdentityAuc}',
      if (embeddingAudit.toyNonToyAuc == null)
        'toy/non-toy embedding AUC unavailable',
      if (embeddingAudit.toyNonToyAuc != null &&
          embeddingAudit.toyNonToyAuc! < acceptance.minimumToyNonToyAuc)
        'toy/non-toy AUC ${embeddingAudit.toyNonToyAuc} < '
            '${acceptance.minimumToyNonToyAuc}',
    ];
  }

  Map<String, Object?> toJson() => {
        'status': isBlocked
            ? 'BLOCKED'
            : passed
                ? 'PASS'
                : 'FAIL',
        'blockedReasons': blockedReasons,
        'failures': failures,
        'metrics': metrics.toJson(),
        'embeddingAudit': embeddingAudit.toJson(),
        'sessions': sessions.map((item) => item.toJson()).toList(),
      };

  String toMarkdown(CorpusSplit split) => '''
# Toy Vision corpus evaluation

Status: **${isBlocked ? 'BLOCKED' : passed ? 'PASS' : 'FAIL'}**

Split: `${split.name}` — ${sessions.length} sessions, ${metrics.frames} frames.

| Metric | Value |
|---|---:|
| Precision | ${metrics.precision.toStringAsFixed(4)} |
| Recall | ${metrics.recall.toStringAsFixed(4)} |
| F1 | ${metrics.f1.toStringAsFixed(4)} |
| False positives | ${metrics.falsePositives} |
| False negatives | ${metrics.falseNegatives} |
| Hard-negative false positives | ${metrics.hardNegativeFalsePositives} |
| ID switches | ${metrics.idSwitches} |
| Duplicate collections | ${metrics.duplicateCollections} |
| False collections | ${metrics.falseCollections} |
| Missed collections | ${metrics.missedCollections} |
| Completion mismatches | ${metrics.completionMismatches} |
| Identity embedding AUC | ${embeddingAudit.identityAuc?.toStringAsFixed(4) ?? 'UNAVAILABLE'} |
| Toy/non-toy embedding AUC | ${embeddingAudit.toyNonToyAuc?.toStringAsFixed(4) ?? 'UNAVAILABLE'} |

Embedding `${embeddingAudit.identifier}` is explicitly classified as
**non-semantic** until the corpus gates pass.

## Blocking/failing checks

${failures.isEmpty ? '- None.' : failures.map((failure) => '- $failure').join('\n')}
''';
}

class _SessionEvaluation {
  const _SessionEvaluation({
    required this.metrics,
    required this.embeddingSamples,
    required this.report,
  });

  final _MutableMetrics metrics;
  final List<EmbeddingSample> embeddingSamples;
  final SessionReport report;
}
