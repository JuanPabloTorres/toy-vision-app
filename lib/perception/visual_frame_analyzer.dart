import 'dart:math' as math;

import 'package:image/image.dart' as img;

import '../core/math/vector_math.dart';
import '../domain/toy/normalized_box.dart';
import '../domain/toy/toy_observation.dart';
import 'embeddings/perceptual_embedding_extractor.dart';
import 'embeddings/embedding_extractor.dart';
import 'perception_models.dart';
import 'proposals/grid_object_proposal_generator.dart';
import 'toy_confirmation_policy.dart';

class FrameAnalysisException implements Exception {
  const FrameAnalysisException(this.message);
  final String message;

  @override
  String toString() => 'FrameAnalysisException: $message';
}

class VisualFrameAnalyzer {
  const VisualFrameAnalyzer({
    this.embeddingExtractor = const PerceptualEmbeddingExtractor(),
    this.proposalGenerator = const GridObjectProposalGenerator(),
    this.confirmationPolicy = ToyConfirmationPolicy.conservative,
  });

  final EmbeddingExtractor embeddingExtractor;
  final GridObjectProposalGenerator proposalGenerator;
  final ToyConfirmationPolicy confirmationPolicy;

  FrameAnalysis analyze(
    CameraPerceptionFrame frame, {
    Map<int, NormalizedBox> trackedRegions = const {},
    Iterable<NormalizedBox> sceneAnchorRegions = const [],
    bool maskDetectorProposalsForScene = true,
    bool generateOpenSetProposals = true,
  }) {
    final stopwatch = Stopwatch()..start();
    final decoded = img.decodeImage(frame.encodedImage);
    if (decoded == null) {
      throw const FrameAnalysisException('Camera frame could not be decoded');
    }
    final oriented = img.bakeOrientation(decoded);
    final scale =
        math.min(1.0, 192 / math.max(oriented.width, oriented.height));
    final scaled = scale < 1
        ? img.copyResize(
            oriented,
            width: math.max(1, (oriented.width * scale).round()),
            height: math.max(1, (oriented.height * scale).round()),
            interpolation: img.Interpolation.average,
          )
        : oriented;
    // The Android stream's detector runs after rotating the sensor bitmap to
    // the upright portrait preview, yet `originalImage` is the unrotated
    // landscape bitmap. Align pixels to the detector coordinate space once,
    // at the reduced analysis resolution, so crops and UI boxes agree.
    final working =
        frame.detectorCoordinatesAreUpright && scaled.width > scaled.height
            ? img.copyRotate(scaled, angle: 90)
            : scaled;
    final openSet = generateOpenSetProposals
        ? proposalGenerator.generate(working)
        : const <OpenSetProposal>[];
    final candidates = <VisualCandidate>[];

    for (final detector in frame.detectorProposals) {
      if (!detector.bounds.isValid) continue;
      candidates.add(
        VisualCandidate(
          bounds: detector.bounds,
          detectorConfidence: detector.confidence.clamp(0.0, 1.0),
          proposalConfidence: _proposalSupport(detector.bounds, openSet),
          embedding: embeddingExtractor.embed(working, detector.bounds),
          source: ObservationSource.detector,
          knownClass: detector.knownClass,
        ),
      );
    }
    for (final proposal in openSet) {
      final overlapsDetector = frame.detectorProposals.any(
        (detector) {
          final detectorBounds = detector.bounds;
          return detectorBounds.intersectionOverUnion(proposal.bounds) >=
                  0.25 ||
              detectorBounds.intersectionOverSmaller(proposal.bounds) >= 0.5;
        },
      );
      if (overlapsDetector) continue;
      candidates.add(
        VisualCandidate(
          bounds: proposal.bounds,
          detectorConfidence: 0,
          proposalConfidence: proposal.objectness,
          embedding: embeddingExtractor.embed(working, proposal.bounds),
          source: ObservationSource.openSetProposal,
        ),
      );
    }
    final trackedEmbeddings = <int, List<double>>{
      for (final entry in trackedRegions.entries)
        if (entry.value.isValid)
          entry.key: embeddingExtractor.embed(working, entry.value),
    };
    // Scene motion must describe the room, not the toys being removed. Mask
    // tracked/detected object regions consistently before computing the global
    // descriptor; otherwise a legitimate pickup looks like a camera change.
    final sceneImage = img.copyCrop(
      working,
      x: 0,
      y: 0,
      width: working.width,
      height: working.height,
    );
    final sceneMasks = <NormalizedBox>{...sceneAnchorRegions};
    var detectorMaskBudget = confirmationPolicy.maximumSceneMaskCoverage;
    final semanticProposals = (maskDetectorProposalsForScene
            ? frame.detectorProposals
            : const <DetectorProposal>[])
        .where(
          (proposal) =>
              proposal.confidence >=
                  confirmationPolicy.minimumSemanticConfidence &&
              proposal.bounds.area <=
                  confirmationPolicy.maximumSceneMaskObjectArea,
        )
        .toList()
      ..sort((a, b) => b.confidence.compareTo(a.confidence));
    for (final proposal in semanticProposals) {
      if (proposal.bounds.area > detectorMaskBudget) continue;
      sceneMasks.add(proposal.bounds);
      detectorMaskBudget -= proposal.bounds.area;
    }
    for (final mask in sceneMasks) {
      if (!mask.isValid) continue;
      img.fillRect(
        sceneImage,
        x1: (mask.x * sceneImage.width).floor(),
        y1: (mask.y * sceneImage.height).floor(),
        x2: (mask.right * sceneImage.width).ceil().clamp(
              0,
              sceneImage.width - 1,
            ),
        y2: (mask.bottom * sceneImage.height).ceil().clamp(
              0,
              sceneImage.height - 1,
            ),
        color: img.ColorRgb8(127, 127, 127),
      );
    }
    final sceneEmbedding = _sceneSignature(sceneImage);
    final quality = _quality(working);
    stopwatch.stop();
    return FrameAnalysis(
      embeddingExtractorIdentifier: embeddingExtractor.identifier,
      candidates: candidates,
      sceneEmbedding: sceneEmbedding,
      trackedRegionEmbeddings: trackedEmbeddings,
      sharpness: quality.$1,
      luminance: quality.$2,
      coverage: 1,
      sourceWidth: working.width,
      sourceHeight: working.height,
      decodeAndEmbeddingUs: stopwatch.elapsedMicroseconds,
    );
  }

  double _proposalSupport(
    NormalizedBox detector,
    List<OpenSetProposal> proposals,
  ) {
    var support = 0.0;
    for (final proposal in proposals) {
      final overlap = detector.intersectionOverUnion(proposal.bounds);
      support = math.max(support, overlap * proposal.objectness);
    }
    return support.clamp(0.0, 1.0);
  }

  (double, double) _quality(img.Image image) {
    final step = math.max(1, math.min(image.width, image.height) ~/ 64);
    var luminance = 0.0;
    var edge = 0.0;
    var count = 0;
    for (var y = 0; y + step < image.height; y += step) {
      for (var x = 0; x + step < image.width; x += step) {
        final current = _luminance(image.getPixel(x, y));
        final right = _luminance(image.getPixel(x + step, y));
        final bottom = _luminance(image.getPixel(x, y + step));
        luminance += current;
        edge += (right - current).abs() + (bottom - current).abs();
        count += 1;
      }
    }
    if (count == 0) return (0, 0);
    return ((edge / count / 2).clamp(0.0, 1.0), luminance / count);
  }

  List<double> _sceneSignature(img.Image image) {
    // Identity descriptors should tolerate small appearance changes, while a
    // room anchor must notice a camera pan. A mean-centred spatial signature
    // preserves coarse layout and direction instead of comparing only
    // positive colour histograms whose cosine remains near 1 across views.
    final grid = img.copyResize(
      image,
      width: 12,
      height: 9,
      interpolation: img.Interpolation.average,
    );
    var meanRed = 0.0;
    var meanGreen = 0.0;
    var meanBlue = 0.0;
    final pixels = <(double, double, double)>[];
    for (final pixel in grid) {
      final red = pixel.r.toDouble() / 255;
      final green = pixel.g.toDouble() / 255;
      final blue = pixel.b.toDouble() / 255;
      pixels.add((red, green, blue));
      meanRed += red;
      meanGreen += green;
      meanBlue += blue;
    }
    meanRed /= pixels.length;
    meanGreen /= pixels.length;
    meanBlue /= pixels.length;
    return l2Normalize([
      for (final pixel in pixels) pixel.$1 - meanRed,
      for (final pixel in pixels) pixel.$2 - meanGreen,
      for (final pixel in pixels) pixel.$3 - meanBlue,
      meanRed * 0.15,
      meanGreen * 0.15,
      meanBlue * 0.15,
    ]);
  }

  double _luminance(img.Pixel pixel) =>
      (pixel.r * 0.299 + pixel.g * 0.587 + pixel.b * 0.114).toDouble() / 255;
}
